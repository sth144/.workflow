#!/bin/bash
# test_cron.sh — validate (and optionally live-run) cron entries
#
# Parses /etc/cron.d/* files (6-field format with user) and the user crontab
# (5-field format without user). For each entry it checks:
#   - The specified user exists
#   - The command binary exists and is executable
#   - Scripts passed to bash/sh exist
#   - Log redirect target directories exist
#
# Usage:
#   test_cron.sh                        Validate all /etc/cron.d/* + user crontab
#   test_cron.sh /etc/cron.d/myjobs     Validate a specific cron.d file
#   test_cron.sh crontab                Validate the current user's crontab only
#   test_cron.sh --run [target]         Actually execute each command (with warning)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LIVE_RUN=false
TARGET=""
TOTAL=0
TOTAL_PASS=0
TOTAL_FAIL=0

pass() { printf "${GREEN}    ✓ %s${NC}\n" "$1"; }
fail() { printf "${RED}    ✗ %s${NC}\n" "$1"; }
warn() { printf "${YELLOW}    ! %s${NC}\n" "$1"; }
info() { printf "${BLUE}    … %s${NC}\n" "$1"; }

# ── argument parsing ──────────────────────────────────────────────────────────

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--run) LIVE_RUN=true ;;
			--help|-h)
				sed -n '2,/^$/{ s/^# \?//; p }' "$0"
				exit 0
				;;
			*) TARGET="$1" ;;
		esac
		shift
	done
}

# ── resolve home directory for a user ─────────────────────────────────────────

resolve_home() {
	local user="$1"
	if [ "$user" = "$USER" ]; then
		echo "$HOME"
		return
	fi
	# macOS: dscl; Linux: getent
	if command -v dscl >/dev/null 2>&1; then
		dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | awk '{print $2}'
	elif command -v getent >/dev/null 2>&1; then
		getent passwd "$user" 2>/dev/null | cut -d: -f6
	else
		echo "/home/$user"
	fi
}

# ── expand ~ to user home in a path ──────────────────────────────────────────

expand_tilde() {
	local path="$1" home="$2"
	if [[ "$path" == "~/"* ]]; then
		echo "${home}${path#\~}"
	elif [[ "$path" == "~" ]]; then
		echo "$home"
	else
		echo "$path"
	fi
}

# ── check whether a binary/path is reachable ─────────────────────────────────

check_binary() {
	local bin="$1" home="$2"
	bin=$(expand_tilde "$bin" "$home")

	if [[ "$bin" == /* ]]; then
		if [ ! -f "$bin" ]; then
			fail "Binary not found: $bin"
			return 1
		elif [ ! -x "$bin" ]; then
			fail "Not executable: $bin"
			return 1
		fi
		pass "Binary OK: $bin"
		return 0
	fi
	# bare name — resolve via PATH
	if command -v "$bin" >/dev/null 2>&1; then
		pass "Binary OK: $bin ($(command -v "$bin"))"
		return 0
	fi
	fail "Command not found in PATH: $bin"
	return 1
}

# ── check that a script argument to bash/sh exists ───────────────────────────

check_script_arg() {
	local cmd="$1" home="$2"
	# If the binary is *sh, the next non-flag token is the script path
	local first
	first=$(echo "$cmd" | awk '{print $1}')
	# Only match actual shell interpreters, not scripts ending in .sh
	case "$(basename "$first")" in
		bash|sh|zsh|dash|ksh) ;;
		*) return 0 ;;
	esac

	local script=""
	for token in $cmd; do
		# skip the shell binary itself
		[[ "$token" == "$first" ]] && continue
		# skip flags like -c, -e, -u
		[[ "$token" == -* ]] && continue
		script="$token"
		break
	done
	[ -z "$script" ] && return 0

	script=$(expand_tilde "$script" "$home")
	if [ ! -f "$script" ]; then
		fail "Script not found: $script"
		return 1
	fi
	pass "Script OK: $script"
	return 0
}

# ── check that redirect target directories exist ─────────────────────────────

check_redirects() {
	local cmd="$1" home="$2"
	local ok=0
	# match >> /path or >>/path (with or without space)
	local targets
	targets=$(echo "$cmd" | grep -oE '>>[[:space:]]*[^[:space:]&;|]+' | sed 's/^>>[[:space:]]*//')
	[ -z "$targets" ] && return 0

	while IFS= read -r target; do
		[ -z "$target" ] && continue
		# skip fd references like 2>&1
		[[ "$target" == "&"* ]] && continue
		target=$(expand_tilde "$target" "$home")
		local dir
		dir=$(dirname "$target")
		if [ ! -d "$dir" ]; then
			fail "Log directory missing: $dir"
			ok=1
		else
			pass "Log dir OK: $dir"
		fi
	done <<< "$targets"
	return $ok
}

# ── validate a single cron command ────────────────────────────────────────────

validate_entry() {
	local cmd="$1" run_user="$2"
	local home errors=0
	home=$(resolve_home "$run_user")

	# strip the first simple command (before any && or ; or |)
	local first_cmd
	first_cmd=$(echo "$cmd" | sed 's/[;&|].*//')
	# strip redirections from the check target
	local clean
	clean=$(echo "$first_cmd" | sed 's/[0-9]*>>[^ ]*//g; s/[0-9]*>[^ ]*//g; s/2>&1//g' \
		| sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

	local binary
	binary=$(echo "$clean" | awk '{print $1}')
	[ -z "$binary" ] && return 0

	check_binary "$binary" "$home" || errors=$((errors + 1))
	check_script_arg "$clean" "$home" || errors=$((errors + 1))
	check_redirects "$cmd" "$home" || errors=$((errors + 1))

	return $errors
}

# ── execute a command (--run mode) ────────────────────────────────────────────

run_entry() {
	local cmd="$1" run_user="$2" env_vars="$3"
	local run_cmd="$env_vars $cmd"
	local rc

	info "Executing as $run_user …"
	if [ "$run_user" = "$USER" ]; then
		bash -c "$run_cmd" 2>&1 | head -20
		rc=${PIPESTATUS[0]}
	else
		sudo -u "$run_user" bash -c "$run_cmd" 2>&1 | head -20
		rc=${PIPESTATUS[0]}
	fi

	if [ "$rc" -eq 0 ]; then
		pass "Exit 0"
	else
		fail "Exit $rc"
	fi
	return "$rc"
}

# ── parse a single cron line → CRON_USER + CRON_CMD ──────────────────────────
# cron.d format:  min hour dom mon dow USER command…
# crontab format: min hour dom mon dow command…
# @special:       @tag [USER] command…

parse_cron_line() {
	local line="$1" has_user="$2"

	if [[ "$line" =~ ^@ ]]; then
		if [ "$has_user" = "true" ]; then
			CRON_USER=$(echo "$line" | awk '{print $2}')
			CRON_CMD=$(echo "$line" | awk '{for(i=3;i<=NF;i++) printf "%s%s",(i>3?" ":""),$i; print ""}')
		else
			CRON_USER="$USER"
			CRON_CMD=$(echo "$line" | awk '{for(i=2;i<=NF;i++) printf "%s%s",(i>2?" ":""),$i; print ""}')
		fi
		return
	fi

	if [ "$has_user" = "true" ]; then
		CRON_USER=$(echo "$line" | awk '{print $6}')
		CRON_CMD=$(echo "$line" | awk '{for(i=7;i<=NF;i++) printf "%s%s",(i>7?" ":""),$i; print ""}')
	else
		CRON_USER="$USER"
		CRON_CMD=$(echo "$line" | awk '{for(i=6;i<=NF;i++) printf "%s%s",(i>6?" ":""),$i; print ""}')
	fi
}

# ── process one cron source (file path or "crontab") ─────────────────────────

process_file() {
	local file="$1" has_user="$2"
	local count=0 ok=0 bad=0
	local env_vars=""

	printf "\n${BLUE}━━━ %s ━━━${NC}\n" "$file"

	local contents
	if [ "$file" = "crontab" ]; then
		contents=$(crontab -l 2>/dev/null || true)
		if [ -z "$contents" ]; then
			warn "No user crontab installed"
			return
		fi
	elif [ ! -f "$file" ]; then
		fail "File not found: $file"
		return
	else
		contents=$(cat "$file")
	fi

	while IFS= read -r line; do
		# skip blanks and comments
		[[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

		# capture variable assignments into the test environment
		if [[ "$line" =~ ^[A-Z_]+= ]]; then
			env_vars="${env_vars}export ${line}; "
			info "Variable: $line"
			continue
		fi

		count=$((count + 1))
		CRON_USER="" CRON_CMD=""
		parse_cron_line "$line" "$has_user"

		printf "\n  ${YELLOW}[%s]${NC} %s\n" "$CRON_USER" "$CRON_CMD"

		# check user
		if ! id "$CRON_USER" >/dev/null 2>&1; then
			fail "User does not exist: $CRON_USER"
			bad=$((bad + 1))
			continue
		fi

		if validate_entry "$CRON_CMD" "$CRON_USER"; then
			ok=$((ok + 1))
		else
			bad=$((bad + 1))
		fi

		if [ "$LIVE_RUN" = "true" ]; then
			run_entry "$CRON_CMD" "$CRON_USER" "$env_vars" || true
		fi
	done <<< "$contents"

	TOTAL=$((TOTAL + count))
	TOTAL_PASS=$((TOTAL_PASS + ok))
	TOTAL_FAIL=$((TOTAL_FAIL + bad))
	printf "\n  Results: %d entries — ${GREEN}%d OK${NC}, ${RED}%d FAILED${NC}\n" \
		"$count" "$ok" "$bad"
}

# ── main ──────────────────────────────────────────────────────────────────────

main() {
	parse_args "$@"

	echo "╔══════════════════════════════════════╗"
	echo "║        Cron Validation Tool          ║"
	echo "╚══════════════════════════════════════╝"

	if [ "$LIVE_RUN" = "true" ]; then
		printf "\n${RED}WARNING: --run mode will EXECUTE every cron command.${NC}\n"
		printf "${RED}Some commands modify files, prune docker images, etc.${NC}\n\n"
		read -p "Proceed with live execution? (y/n) " response
		[ "$response" = "y" ] || exit 0
	fi

	if [ -n "$TARGET" ]; then
		# single target
		if [ "$TARGET" = "crontab" ]; then
			process_file "crontab" "false"
		else
			process_file "$TARGET" "true"
		fi
	else
		# everything
		if [ -d /etc/cron.d ]; then
			for f in /etc/cron.d/*; do
				[ -f "$f" ] || continue
				# workflow_crontab is a derived file (combined + user-stripped)
				# produced by install.sh for macOS — skip to avoid double-counting
				[ "$(basename "$f")" = "workflow_crontab" ] && continue
				process_file "$f" "true"
			done
		fi
		process_file "crontab" "false"
	fi

	printf "\n${BLUE}══════════════════════════════════════${NC}\n"
	printf "Total: %d entries — ${GREEN}%d OK${NC}, ${RED}%d FAILED${NC}\n" \
		"$TOTAL" "$TOTAL_PASS" "$TOTAL_FAIL"

	[ "$TOTAL_FAIL" -eq 0 ] && exit 0 || exit 1
}

main "$@"
