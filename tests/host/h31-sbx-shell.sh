#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-31: sbx-shell starts the sandbox if needed, then opens bash in its folder
# ------------------------------------------------------------------------------
# Needs: test sandbox running; takes it down and restores it
# BSD script gives sbx-shell a terminal; the shell writes its folder to a file.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init
. "$(dirname "$0")/lib-sbx.sh"

sbxDir=""
sbxPath=""
sbxStatus=0
firstId=""
firstStart=""

# ------------------------------------------------------------------------------
# Takes the test sandbox down; FAIL and return 1 if that fails
# ------------------------------------------------------------------------------
take_sandbox_down() {
  if ! compose_down >"$RUN/logs/h31-down.log" 2>&1; then
    fail H-31 "compose down failed before the test; log: $RUN/logs/h31-down.log"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Checks that sbx-shell is found through PATH
# ------------------------------------------------------------------------------
# A lost exec bit or a broken shebang fails here.
# ------------------------------------------------------------------------------
check_lookup() {
  local found

  found=$(PATH="$sbxPath" command -v sbx-shell)

  if [ "$found" != "$REPO_DIR/bin/sbx-shell" ]; then
    add_problem "sbx-shell was not found through PATH as $REPO_DIR/bin/sbx-shell (got: ${found:-nothing})"
  fi
}

# ------------------------------------------------------------------------------
# Registers the test sandbox on its own folder
# ------------------------------------------------------------------------------
register() {
  run_sbx h31-add sbx-add hosttest "$sbxDir"

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-add exited $sbxStatus; log: $RUN/logs/h31-add.err"
  fi
}

# ------------------------------------------------------------------------------
# Checks the start of a sandbox with no container, run without a terminal
# ------------------------------------------------------------------------------
# sbx-shell starts the sandbox and waits for its hooks, then Docker refuses the
# shell because stdin is not a terminal. Older Docker says "the input device is
# not a TTY", newer Docker says "stdin is not a terminal"; both count.
# ------------------------------------------------------------------------------
check_start_without_terminal() {
  run_sbx h31-noterm sbx-shell hosttest

  if [ "$sbxStatus" -eq 0 ]; then
    add_problem "sbx-shell without a terminal exited 0; log: $RUN/logs/h31-noterm.err"
  fi

  if ! grep -qiE 'TTY|not a terminal' "$RUN/logs/h31-noterm.err"; then
    add_problem "sbx-shell without a terminal printed no terminal refusal from Docker (neither 'not a TTY' nor 'not a terminal'); log: $RUN/logs/h31-noterm.err"
  fi

  if [ "$(sandbox_field '{{.State.Running}}')" != "true" ]; then
    add_problem "$CONTAINER is not running after sbx-shell started it"
  fi

  if ! docker exec "$CONTAINER" pgrep -x sleep >/dev/null 2>&1 </dev/null; then
    add_problem "the start hooks of $CONTAINER are not done after sbx-shell returned"
  fi

  firstId=$(sandbox_field '{{.Id}}')
  firstStart=$(sandbox_field '{{.State.StartedAt}}')
}

# ------------------------------------------------------------------------------
# drive_shell FILE_NAME: runs sbx-shell under script, feeds the shell two lines
# ------------------------------------------------------------------------------
# run_timeout starts its command in the background with stdin from /dev/null, so
# the input is made here. It waits for the shell, and stays open until the shell
# wrote its file, because some versions of script end with their input.
# ------------------------------------------------------------------------------
drive_shell() {
  local fileName=$1
  local hostFile="$sbxDir/hosttest/$fileName"
  local waitedSeconds=0

  {
    while [ "$waitedSeconds" -lt 240 ]; do
      if docker exec "$CONTAINER" pgrep -x sleep >/dev/null 2>&1 </dev/null && docker exec "$CONTAINER" pgrep -x bash >/dev/null 2>&1 </dev/null; then
        break
      fi

      sleep 1
      waitedSeconds=$((waitedSeconds + 1))
    done

    printf '%s\n' "pwd > $fileName"
    printf '%s\n' "exit"
    waitedSeconds=0

    while [ "$waitedSeconds" -lt 240 ] && [ ! -s "$hostFile" ]; do
      sleep 1
      waitedSeconds=$((waitedSeconds + 1))
    done

    sleep 1
  } | env PATH="$sbxPath" SBX_DIR=/nonexistent-ambient SBX_NAME=ambient COMPOSE_PROJECT_NAME=sbx-ambient script -q /dev/null sbx-shell hosttest
}

# ------------------------------------------------------------------------------
# run_shell LOG_NAME FILE_NAME: drive_shell with a time limit, output to a log
# ------------------------------------------------------------------------------
# The exit status is not checked: what script returns differs between macOS
# versions. The file the shell wrote is the proof.
# ------------------------------------------------------------------------------
run_shell() {
  run_timeout 300 drive_shell "$2" >"$RUN/logs/$1.log" 2>&1 </dev/null
}

# ------------------------------------------------------------------------------
# shell_wrote FILE_NAME: true when the file holds the one line of the folder
# ------------------------------------------------------------------------------
shell_wrote() {
  [ "$(cat "$sbxDir/hosttest/$1" 2>/dev/null)" = "/home/sandbox/workspace/hosttest" ]
}

# ------------------------------------------------------------------------------
# Checks the shell on the running sandbox: the folder, and no recreate
# ------------------------------------------------------------------------------
check_running_shell() {
  run_shell h31-running h31-running.txt

  if ! shell_wrote h31-running.txt; then
    add_problem "a shell opened through BSD script wrote no h31-running.txt with /home/sandbox/workspace/hosttest; script may not give sbx-shell a terminal on this Mac (log: $RUN/logs/h31-running.log); tests/host/manual/h31-jump-in.sh checks the same by hand"
  fi

  if [ -z "$firstId" ] || [ "$(sandbox_field '{{.Id}}')" != "$firstId" ] || [ "$(sandbox_field '{{.State.StartedAt}}')" != "$firstStart" ]; then
    add_problem "sbx-shell recreated or restarted the running sandbox"
  fi
}

# ------------------------------------------------------------------------------
# Checks the shell on a stopped sandbox: started again, not replaced
# ------------------------------------------------------------------------------
check_stopped_shell() {
  run_sbx h31-stop sbx-stop hosttest

  if [ "$sbxStatus" -ne 0 ]; then
    add_problem "sbx-stop exited $sbxStatus; log: $RUN/logs/h31-stop.err"
  fi

  run_shell h31-stopped h31-stopped.txt

  if ! shell_wrote h31-stopped.txt; then
    add_problem "a shell opened through BSD script wrote no h31-stopped.txt with /home/sandbox/workspace/hosttest; script may not give sbx-shell a terminal on this Mac (log: $RUN/logs/h31-stopped.log); tests/host/manual/h31-jump-in.sh checks the same by hand"
  fi

  if [ "$(sandbox_field '{{.State.Running}}')" != "true" ]; then
    add_problem "$CONTAINER is not running after sbx-shell of a stopped sandbox"
  fi

  if [ -z "$firstId" ] || [ "$(sandbox_field '{{.Id}}')" != "$firstId" ]; then
    add_problem "sbx-shell of a stopped sandbox replaced the container instead of starting it again"
  fi

  if ! docker exec "$CONTAINER" pgrep -x sleep >/dev/null 2>&1 </dev/null; then
    add_problem "the start hooks of $CONTAINER are not done after sbx-shell of a stopped sandbox"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-31 || exit 1
sbx_test_setup H-31 h31 || exit 1
take_sandbox_down || exit 1
check_lookup
register
check_start_without_terminal
check_running_shell
check_stopped_shell
restore_test_sandbox h31
report_check H-31 "sbx-shell did not start the sandbox or open bash in its project folder" \
  "sbx-shell started a sandbox with no container and waited for its hooks; without a terminal Docker refused the shell; through a terminal bash opened in /home/sandbox/workspace/hosttest on the running sandbox (not recreated) and on a stopped one (started again)"
