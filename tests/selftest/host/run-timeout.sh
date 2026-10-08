#!/usr/bin/env bash
# Self-test of the time limit in tests/host/lib-sandbox.sh (run_timeout): a shell function and everything it started stop at the limit; a function that ignores SIGTERM is killed after a grace period.
# - Run by run-all.sh; runs alone too.
# - run_timeout and the function it runs must share one shell, so each case writes a small script
#   into the work folder, runs it with stdin closed and reads its key=value lines.
# - Needs setsid, pgrep and ps (Linux); the first case fails loudly when one is missing.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/run-timeout.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# write_slow_script: writes WORK/slow.sh, which runs a two-statement function that starts a child sleeping 8 s
# --------------------------------------------------------------------------------
# The function has two statements, so bash cannot replace its shell with the child.
# MODE is "substitution" (the call sits in a command substitution and the timing is printed)
# or "plain" (a plain call, so the caller returns as soon as run_timeout does).
write_slow_script() {
  cat >"$WORK/slow.sh" <<'EOF'
set -u
. "$REPO_ROOT/tests/host/lib.sh"

slow_function() {
  sh -c 'echo $$ >"$1"; exec sleep 8' sh "$WORK_DIR/slow.$1.pid"
  true
}

if [ "$1" = "substitution" ]; then
  startSeconds=$(date +%s)
  captured=$(run_timeout 2 slow_function substitution)
  echo "status=$?"
  endSeconds=$(date +%s)
  echo "elapsed=$((endSeconds - startSeconds))"
else
  run_timeout 2 slow_function plain >/dev/null 2>&1
  echo "status=$?"
fi
EOF
}

# --------------------------------------------------------------------------------
# write_stubborn_script: writes WORK/stubborn.sh, which runs a function that ignores SIGTERM and starts a child sleeping 20 s
# --------------------------------------------------------------------------------
# The ignored signal is inherited by the child, so only SIGKILL stops either of them.
# The trailing true keeps bash from replacing the function's shell with the child.
write_stubborn_script() {
  cat >"$WORK/stubborn.sh" <<'EOF'
set -u
. "$REPO_ROOT/tests/host/lib.sh"

stubborn_function() {
  trap '' TERM
  sh -c 'echo $$ >"$1"; exec sleep 20' sh "$WORK_DIR/stubborn.pid"
  true
}

startSeconds=$(date +%s)
captured=$(run_timeout 2 stubborn_function)
echo "status=$?"
endSeconds=$(date +%s)
echo "elapsed=$((endSeconds - startSeconds))"
EOF
}

# --------------------------------------------------------------------------------
# write_quick_script: writes WORK/quick.sh, which runs a command that ends at once and prints its status and the time taken
# --------------------------------------------------------------------------------
# When SESSION_FILE is set, the script first writes its own session id there, so the case can look for leftovers.
write_quick_script() {
  cat >"$WORK/quick.sh" <<'EOF'
set -u
. "$REPO_ROOT/tests/host/lib.sh"

if [ -n "${SESSION_FILE:-}" ]; then
  ps -o sid= -p $$ | tr -d ' ' >"$SESSION_FILE"
fi

startSeconds=$(date +%s)
run_timeout 5 sh -c 'exit 7'
echo "status=$?"
endSeconds=$(date +%s)
echo "elapsed=$((endSeconds - startSeconds))"
EOF
}

# --------------------------------------------------------------------------------
# run_script OUTFILE SCRIPT ARG...: runs a script of the work folder with stdin closed; its output goes to OUTFILE
# --------------------------------------------------------------------------------
run_script() {
  local outFile=$1
  local script=$2

  shift 2
  REPO_ROOT="$REPO" WORK_DIR="$WORK" bash "$WORK/$script" "$@" >"$outFile" 2>&1 </dev/null
}

# --------------------------------------------------------------------------------
# value_of FILE KEY: prints the value of the key=value line KEY in FILE
# --------------------------------------------------------------------------------
value_of() {
  grep "^$2=" "$1" | cut -d= -f2
}

# --------------------------------------------------------------------------------
# tools_available: true when setsid, pgrep and ps can be found
# --------------------------------------------------------------------------------
tools_available() {
  command -v setsid >/dev/null && command -v pgrep >/dev/null && command -v ps >/dev/null
}

# --------------------------------------------------------------------------------
# is_under SECONDS VALUE: true when VALUE is a number below SECONDS
# --------------------------------------------------------------------------------
is_under() {
  case "$2" in
    '' | *[!0-9]*) return 1 ;;
  esac

  [ "$2" -lt "$1" ]
}

# --------------------------------------------------------------------------------
# quick_command_status_in_time OUTFILE: true when the quick script printed status 7 and took under 2 s
# --------------------------------------------------------------------------------
quick_command_status_in_time() {
  equals "$(value_of "$1" status)" "7" && is_under 2 "$(value_of "$1" elapsed)"
}

# --------------------------------------------------------------------------------
# child_is_gone PIDFILE: true when the pid in PIDFILE is a process that no longer exists after at most 2 s
# --------------------------------------------------------------------------------
child_is_gone() {
  local childPid i

  childPid=$(cat "$1" 2>/dev/null)

  case "$childPid" in
    '' | *[!0-9]*) return 1 ;;
  esac

  for i in $(seq 1 20); do
    if ! kill -0 "$childPid" 2>/dev/null; then
      return 0
    fi
    sleep 0.1
  done

  return 1
}

# --------------------------------------------------------------------------------
# nothing_left_after_quick_command: true when no process of the quick script's session is alive 0.5 s after it ends
# --------------------------------------------------------------------------------
nothing_left_after_quick_command() {
  local sessionId leftover

  setsid -w env REPO_ROOT="$REPO" WORK_DIR="$WORK" SESSION_FILE="$WORK/quick.sid" \
    bash "$WORK/quick.sh" >"$WORK/out.quick.session" 2>&1 </dev/null
  sessionId=$(cat "$WORK/quick.sid" 2>/dev/null)

  case "$sessionId" in
    '' | *[!0-9]*) return 1 ;;
  esac

  sleep 0.5
  leftover=$(pgrep -s "$sessionId")

  if [ -n "$leftover" ]; then
    echo "leftover processes of session $sessionId:" >&2
    ps -o pid,args -p "$(printf '%s' "$leftover" | tr '\n' ',')" >&2
    return 1
  fi

  return 0
}

# --------------------------------------------------------------------------------
# Cases of run_timeout: a shell function, its child, a quick command and the watcher
# --------------------------------------------------------------------------------
case_run_timeout() {
  echo "--- run_timeout"
  write_slow_script
  write_quick_script
  write_stubborn_script

  expect "run_timeout: setsid, pgrep and ps are available" tools_available

  run_script "$WORK/out.slow" slow.sh substitution
  expect "run_timeout: a shell function stops at the limit" is_under 5 "$(value_of "$WORK/out.slow" elapsed)"
  expect "run_timeout: the timeout status is 143" equals "$(value_of "$WORK/out.slow" status)" "143"

  run_script "$WORK/out.slow.plain" slow.sh plain
  expect "run_timeout: the function's child is gone" child_is_gone "$WORK/slow.plain.pid"

  run_script "$WORK/out.quick" quick.sh
  expect "run_timeout: a quick command keeps its own status" quick_command_status_in_time "$WORK/out.quick"
  expect "run_timeout: nothing is left running after a quick command" nothing_left_after_quick_command

  run_script "$WORK/out.stubborn" stubborn.sh
  expect "run_timeout: a function that ignores SIGTERM stops within the grace period" is_under 12 "$(value_of "$WORK/out.stubborn" elapsed)"
  expect "run_timeout: a function that had to be killed returns 137" equals "$(value_of "$WORK/out.stubborn" status)" "137"
  expect "run_timeout: the child that ignores SIGTERM is gone" child_is_gone "$WORK/stubborn.pid"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_run_timeout
finish_cases
