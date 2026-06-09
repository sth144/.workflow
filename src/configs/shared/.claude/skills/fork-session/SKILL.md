---
name: fork-session
description: Fork the current Claude Code conversation into a new pane in a shared "claude-forks" tmux session (in an iTerm2 window), keeping the original thread untouched. Optionally hand the fork a specific task so it works autonomously instead of resuming the parent's activity. Use when the user says "fork this session", "fork the conversation", "branch this into a new terminal", "spawn a fork to do X", or wants to run work in parallel without disturbing the current thread.
argument-hint: (forks the current session; optionally give it a task)
---

# Fork Session Into a Pane

Spawns a forked copy of the current conversation as a **pane in a shared
`claude-forks` tmux session**. The fork inherits the full history up to this
point but writes to a new session id, so the threads diverge independently —
**the original session (this one) is never modified.** All forks land as tiled
panes in the one `claude-forks` session; toggle its iTerm window with
**Cmd+Ctrl+F** (Hammerspoon). Because it runs in tmux, forks survive the window
closing and can be reattached.

## How it works

The helper auto-detects its environment:

- **macOS host** (no `/.dockerenv`): if `claude-forks` already exists, it adds a
  pane via `tmux split-window` (no new window). On the first fork it creates the
  session in a new iTerm2 window via `osascript`.
- **Devcontainer** (`/.dockerenv` exists): it writes a `.command` launcher to a
  host-shared path (`/usr/local/src/...`) and asks the host to run it via the
  `host_relay` bridge (`notify`/osascript key on `host.docker.internal:7899`).
  The launcher checks tmux state and either adds a pane or creates the session,
  running `docker exec -it <container> claude --resume <id> --fork-session ...`.

The helper also reads the parent session's original cwd from its transcript and
resumes there — `claude --resume` is scoped to the project derived from the cwd,
so resuming from a different directory fails ("No conversation found"). A
mismatching `cwd` argument is ignored (with a warning) rather than silently
failing.

## Two modes: fork vs handoff

**fork** (default) branches THIS session via `--resume <id> --fork-session`, so
the worker inherits the **entire parent transcript**. Use it when you genuinely
want a true branch of the exact conversation. Downside: it drags in (and, on a
near-full parent, immediately *compacts*) the whole context, and the inherited
history makes the worker prone to thinking it IS the parent.

**handoff** (`--handoff`) spawns a **fresh** `claude` session with NO inherited
transcript — seeded only with a self-contained brief you write. No compaction,
no identity confusion, and it can start in **any cwd**. This is the right choice
for "go do a specific task" forks. The cost: the worker only knows what you put
in the brief, so write it well.

Prefer **handoff** for delegating tasks; use **fork** only when the worker truly
needs the live conversation.

## Orienting the worker to a task

Both modes accept a **task** that, when present, appends a "you are a worker, not
the parent" system prompt (`--append-system-prompt`) and passes the task as the
worker's first user message so it starts immediately. In `--handoff` mode the
task is **required** (it is the only context the worker gets).

**Fold any context the worker needs INTO the task string** — a condensed summary
of the relevant context plus a clear definition of done. Write it the way you
would brief a fresh engineer. In fork mode the worker can also scroll back
through the inherited history; in handoff mode the brief is all it has.

## Steps

1. Run the helper. It reads `$CLAUDE_CODE_SESSION_ID` and the cwd automatically.

   Handoff — delegate a task to a fresh worker (RECOMMENDED for task delegation):

   ```bash
   bash /usr/local/src/workflow-macos-1095/src/utils/macosx/host_relay/fork_session.sh \
     --handoff "$(pwd)" \
     "Context: <condensed summary of what the worker needs>. Task: <what to do>. Done when: <criteria>."
   ```

   Plain fork (no task — true branch; the worker waits for the user to drive it):

   ```bash
   bash /usr/local/src/workflow-macos-1095/src/utils/macosx/host_relay/fork_session.sh "$CLAUDE_CODE_SESSION_ID" "$(pwd)"
   ```

   Fork with a task (true branch that also starts working immediately):

   ```bash
   bash /usr/local/src/workflow-macos-1095/src/utils/macosx/host_relay/fork_session.sh \
     "$CLAUDE_CODE_SESSION_ID" "$(pwd)" \
     "Context: <condensed summary>. Task: <what to do>. Done when: <criteria>."
   ```

2. Report the result to the user:
   - On success: relay whether a pane was added or the `claude-forks` session was
     created in a new window, the **Cmd+Ctrl+F** toggle, and the
     `tmux attach -t claude-forks` reattach hint the helper printed. This session
     is unchanged.
   - If the helper printed the **relay-unreachable fallback** (container only),
     relay the paste-able `claude --resume <id> --fork-session` command and ask
     the user to run it in a terminal themselves.

## Notes

- **Scope:** fork mode branches the *current* session by default (pass a
  different id as the first argument to branch another). Handoff mode is
  session-independent — it starts fresh and needs no session id.
- **Requirements on macOS host:** iTerm2 and tmux on PATH.
- **Requirements in devcontainer:** the `host_relay` server running on the Mac,
  plus iTerm2, tmux, and Docker Desktop on the host PATH, reachable via
  `docker exec`.
- **Closing the iTerm window only detaches tmux**; reattach with
  `tmux attach -t claude-forks`.
