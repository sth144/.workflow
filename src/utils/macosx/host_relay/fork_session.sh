#!/usr/bin/env bash

# fork_session.sh — Spawn a Claude Code worker into a pane of the shared
# "claude-forks" tmux session. Two modes:
#
#   fork    (default) — branch THIS session via `claude --resume <id>
#           --fork-session`, inheriting the parent's full transcript. Good when
#           you want a true branch of the exact conversation. Optionally give a
#           task to orient it (see below).
#
#   handoff (--handoff) — spawn a FRESH `claude` session with NO inherited
#           transcript, seeded only with a self-contained brief. Avoids dragging
#           in (and immediately compacting) the parent's context, prevents the
#           worker from mistaking itself for the parent, and can run in ANY cwd.
#           The caller writes a condensed brief (context + task + done criteria).
#
# All workers land as tiled panes in one tmux session (claude-forks); toggle its
# Alacritty window with Cmd+Ctrl+F (Hammerspoon).
#
# Works in two environments:
#   1. MACOS HOST (no /.dockerenv) — adds a pane via `tmux split-window` if the
#      session exists, else creates it inside a new Alacritty window via the CLI.
#   2. DEVCONTAINER (/.dockerenv exists) — writes a host-shared .command launcher
#      and asks the host to run it via the host_relay bridge; the launcher adds a
#      pane or creates the session, running claude inside this container.
#
# Usage:
#   fork_session.sh [session-id] [cwd] [task]      # fork mode
#   fork_session.sh --handoff [cwd] <task>         # handoff mode (task required)
#
#   session-id  defaults to $CLAUDE_CODE_SESSION_ID
#   cwd         defaults to the current working directory
#   task        fork mode: optional. handoff mode: required. When present, a
#               "you are a worker, not the parent" system prompt is appended
#               (--append-system-prompt) and the task is passed as the first
#               user message so the worker starts immediately. Fold any context
#               the worker needs INTO the task string.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELAY_CLIENT="$SCRIPT_DIR/../../shared/os/host_relay_client.sh"
# Docker Desktop's CLI (and Homebrew tmux) live here; a GUI-launched terminal may
# have a minimal PATH, so the launcher prepends these to find docker and tmux.
DOCKER_PATHS="/usr/local/bin:/opt/homebrew/bin"
# Alacritty has no AppleScript dictionary, so (unlike the old iTerm flow) we open
# windows via its CLI. `alacritty msg create-window` attaches the window to a
# running instance so Hammerspoon can find it by title; we fall back to starting
# a fresh instance when none is running. On the host we resolve the binary
# directly (cask path) in case the caller's PATH is minimal; over the relay we
# rely on the host login shell's PATH.
ALACRITTY="$(command -v alacritty 2>/dev/null || echo /Applications/Alacritty.app/Contents/MacOS/alacritty)"
# All forks share this tmux session; Hammerspoon finds the Alacritty window by marker.
FORKS_SESSION="claude-forks"
FORKS_MARKER="HS-FORKS"

# Emit the shell command that opens an Alacritty window titled $2 running the
# launcher script $1. Non-blocking (the create-window message returns at once;
# the fresh-instance fallback is nohup-backgrounded) so the caller — or the relay
# request — returns immediately. $3 (optional) is the alacritty binary for the
# fallback; defaults to bare `alacritty` (resolved by the executing shell's PATH).
build_term_cmd() {
	local launcher="$1" marker="$2" bin="${3:-alacritty}"
	printf '%q msg create-window --title %q -o window.dynamic_title=false -e %q 2>/dev/null || (nohup %q --title %q -o window.dynamic_title=false -e %q >/dev/null 2>&1 &)' \
		"$bin" "$marker" "$launcher" "$bin" "$marker" "$launcher"
}

die() { echo "fork_session: $*" >&2; exit 1; }

manual_fallback() {
	echo "Host relay unreachable — open a new terminal yourself and run:" >&2
	if [ "$MODE" = "handoff" ]; then
		echo "  cd $(printf %q "$CWD") && claude" >&2
		echo "  (then paste your task as the first message)" >&2
	else
		echo "  claude --resume $SESSION --fork-session" >&2
	fi
	exit 1
}

# ---- Parse arguments / select mode -------------------------------------------
MODE="fork"
if [ "${1:-}" = "--handoff" ]; then
	MODE="handoff"
	shift
fi

USER_NAME="$(id -un)"

if [ "$MODE" = "handoff" ]; then
	CWD="${1:-$PWD}"
	TASK="${2:-}"
	SESSION=""
	[ -n "$TASK" ] || die "--handoff requires a task (the condensed brief) as the next argument"
else
	SESSION="${1:-${CLAUDE_CODE_SESSION_ID:-}}"
	CWD="${2:-$PWD}"
	TASK="${3:-}"
	[ -n "$SESSION" ] || die "no session id (set CLAUDE_CODE_SESSION_ID or pass one as \$1)"
fi

# Detect environment: container vs macOS host.
if [ -f /.dockerenv ]; then
	IN_CONTAINER=true
	CONTAINER="$(hostname)"
	RELAY_HOST="host.docker.internal"
	RELAY_PORT="7899"
	# Shared, host-visible, writable scratch dir (same absolute path on host and
	# container via bind mount).
	LAUNCHER_DIR="/usr/local/src/workflow-macos-1095/cache/claude-fork"
else
	IN_CONTAINER=false
	LAUNCHER_DIR="${TMPDIR:-/tmp}/claude-fork"
fi

# ---- Fork mode: resume is project-scoped, so cd into the session's own cwd ----
# `claude --resume` is scoped to the project derived from the cwd it starts in,
# so the fork MUST cd into the directory the session was created in — resuming
# from any other project silently fails ("No conversation found") and the pane
# flashes shut. The original cwd is recorded in the transcript; read it and
# override CWD, warning if the caller asked for a different (incompatible) dir.
# Handoff mode starts a fresh session, so any cwd is fine — skip the guard.
if [ "$MODE" = "fork" ]; then
	TRANSCRIPT=$(ls "$HOME/.claude/projects"/*/"$SESSION".jsonl 2>/dev/null | head -1 || true)
	if [ -n "$TRANSCRIPT" ]; then
		SESSION_CWD=$(grep -o '"cwd":"[^"]*"' "$TRANSCRIPT" | head -1 | sed 's/.*"cwd":"//;s/"$//')
		if [ -n "$SESSION_CWD" ] && [ "$SESSION_CWD" != "$CWD" ]; then
			echo "fork_session: session lives in project '$SESSION_CWD'; resuming there" >&2
			echo "fork_session: (requested cwd '$CWD' ignored — claude --resume is project-scoped)" >&2
			CWD="$SESSION_CWD"
		fi
	fi
fi

# ---- Inherit the parent session's permission mode ----------------------------
# Forks/handoffs should run with the same permission posture as the session that
# spawned them (otherwise a --dangerously-skip-permissions parent yields a child
# that prompts on every tool call). No env var exposes that flag, so walk the
# ancestor process tree and detect it on the parent `claude` invocation.
SKIP_PERMS=""
_detect_skip_perms() {
	local pid="$PPID" ppid cmd i
	for i in $(seq 1 15); do
		[ -n "$pid" ] && [ "$pid" -gt 1 ] || return
		read -r ppid cmd < <(ps -o ppid=,command= -p "$pid" 2>/dev/null) || return
		[ -n "$ppid" ] || return
		case "$cmd" in
			*--dangerously-skip-permissions*) SKIP_PERMS="--dangerously-skip-permissions"; return ;;
		esac
		pid="$ppid"
	done
}
_detect_skip_perms

# ---- Build the inner command + its positional args (per mode) ----------------
# Orientation system prompts (apostrophe-free so they embed cleanly everywhere).
FORK_ORIENT="You are an autonomous FORKED Claude Code session. You were branched from a parent conversation whose transcript you have inherited as BACKGROUND CONTEXT ONLY. You are NOT the parent session and you MUST NOT resume or continue the parent prior in-progress activity (for example an interactive interview, a ritual, or whatever task the parent was working on). Your one and only objective is the task given in the first user message. Use the inherited history purely as reference. Work autonomously and proactively; do not wait for further instructions to begin."
HANDOFF_ORIENT="You are an autonomous Claude Code worker session spawned to complete one specific task. You have NO prior conversation history; everything you need to know is in the first user message, which is a self-contained brief. You are NOT continuing anyone elses session. Work autonomously and proactively to complete the task; do not wait for further instructions to begin."

# Args are passed via tmux/execvp (no shell re-parsing), so quoting is preserved.
# The trailing skip-perms arg is referenced UNQUOTED in the claude invocation so
# an empty value contributes no argument and the flag (a single token) passes clean.
if [ "$MODE" = "handoff" ]; then
	# $1=cwd $2=orient $3=task $4=skip-perms. Fresh session, no resume.
	INNER_BODY='cd "$1" || exit 1; exec claude $4 --append-system-prompt "$2" "$3"'
	INNER_ARGS=("$CWD" "$HANDOFF_ORIENT" "$TASK" "$SKIP_PERMS")
else
	# $1=cwd $2=session $3=orient $4=task $5=skip-perms. Resume + fork; task optional.
	INNER_BODY='cd "$1" || exit 1; if [ -n "$4" ]; then exec claude --resume "$2" --fork-session $5 --append-system-prompt "$3" "$4"; else exec claude --resume "$2" --fork-session $5; fi'
	INNER_ARGS=("$CWD" "$SESSION" "$FORK_ORIENT" "$TASK" "$SKIP_PERMS")
fi

# Pre-quote the inner body and args for embedding in the .command launcher.
ESC_INNER=$(printf %q "$INNER_BODY")
ESC_ARGS=""
for a in "${INNER_ARGS[@]}"; do
	ESC_ARGS+=" $(printf %q "$a")"
done

LAUNCHER_TAG="${SESSION:-handoff}"

# --------------------------------------------------------------------------
# HOST PATH — direct tmux access, no relay needed
# --------------------------------------------------------------------------
if ! $IN_CONTAINER; then
	if tmux has-session -t "$FORKS_SESSION" 2>/dev/null; then
		# Session exists — add a pane directly (no new Alacritty window).
		tmux split-window -t "$FORKS_SESSION" \
			bash -lc "$INNER_BODY" _ "${INNER_ARGS[@]}"
		tmux select-layout -t "$FORKS_SESSION" tiled
		echo "Added $MODE worker as new pane in '$FORKS_SESSION'."
		echo "Toggle: Cmd+Ctrl+F | Reattach: tmux attach -t $FORKS_SESSION"
		exit 0
	fi

	# First worker — create the forks session inside a new Alacritty window.
	mkdir -p "$LAUNCHER_DIR"
	LAUNCHER="$LAUNCHER_DIR/fork-${LAUNCHER_TAG}-$$.command"
	cat > "$LAUNCHER" <<-LAUNCHER_EOF
	#!/usr/bin/env bash
	export PATH="$DOCKER_PATHS:\$PATH"
	tmux new-session -s $FORKS_SESSION \
	  bash -lc $ESC_INNER _$ESC_ARGS
	rm -f "\$0"
	LAUNCHER_EOF
	chmod +x "$LAUNCHER"

	bash -lc "$(build_term_cmd "$LAUNCHER" "$FORKS_MARKER" "$ALACRITTY")"

	echo "Created '$FORKS_SESSION' session in a new Alacritty window ($MODE worker)."
	echo "Toggle: Cmd+Ctrl+F | Reattach: tmux attach -t $FORKS_SESSION"
	exit 0
fi

# --------------------------------------------------------------------------
# CONTAINER PATH — relay through host
# --------------------------------------------------------------------------
[ -f "$RELAY_CLIENT" ] || die "relay client not found at $RELAY_CLIENT"
curl -sf --max-time 5 "http://$RELAY_HOST:$RELAY_PORT/health" >/dev/null 2>&1 || manual_fallback

ESC_CONTAINER=$(printf %q "$CONTAINER")
ESC_USER=$(printf %q "$USER_NAME")

mkdir -p "$LAUNCHER_DIR"
LAUNCHER="$LAUNCHER_DIR/fork-${LAUNCHER_TAG}-$$.command"

# Smart launcher: runs on the host, checks if the forks session exists.
# If it does, adds a pane and exits (the Alacritty window that ran this launcher
# will close — brief flash). If not, creates the session attached to this
# terminal (the Alacritty window stays open as the tmux client).
cat > "$LAUNCHER" <<-LAUNCHER_EOF
#!/usr/bin/env bash
export PATH="$DOCKER_PATHS:\$PATH"
if tmux has-session -t $FORKS_SESSION 2>/dev/null; then
  echo "Adding pane to $FORKS_SESSION ..."
  tmux split-window -t $FORKS_SESSION \
    docker exec -it -u $ESC_USER $ESC_CONTAINER bash -lc \
    $ESC_INNER _$ESC_ARGS
  tmux select-layout -t $FORKS_SESSION tiled
else
  tmux new-session -s $FORKS_SESSION \
    docker exec -it -u $ESC_USER $ESC_CONTAINER bash -lc \
    $ESC_INNER _$ESC_ARGS
fi
rm -f "\$0"
LAUNCHER_EOF
chmod +x "$LAUNCHER"

# Ask the host to open the Alacritty window via the relay's `shell` command.
bash "$RELAY_CLIENT" shell "$(build_term_cmd "$LAUNCHER" "$FORKS_MARKER")" </dev/null

echo "$MODE worker dispatched to '$FORKS_SESSION' session on host."
echo "Toggle: Cmd+Ctrl+F | Reattach: tmux attach -t $FORKS_SESSION"
