#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of sbx-shell: refusals, the start paths, the running path
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/shell.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# The refusing stand-in stays first on PATH except inside run_sbx_scripted.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# opened_shell NAME: the last docker call opened bash in the folder of NAME
# ------------------------------------------------------------------------------
opened_shell() {
  [ "$(tail -n 1 "$WORK/standin-calls")" = "docker exec -it -w /home/sandbox/workspace/$1 sbx-$1 bash" ]
}

# ------------------------------------------------------------------------------
# opened_no_shell: no docker call opened a shell; a missing log counts as none
# ------------------------------------------------------------------------------
opened_no_shell() {
  if [ ! -e "$WORK/standin-calls" ]; then
    return 0
  fi

  ! grep -Fq -- 'docker exec -it' "$WORK/standin-calls"
}

# ------------------------------------------------------------------------------
# called_compose: the scripted docker saw a compose call
# ------------------------------------------------------------------------------
called_compose() {
  grep -Fq -- 'docker compose' "$WORK/standin-calls"
}

# ------------------------------------------------------------------------------
# refused_before_shell LABEL TEXT: exit 1, TEXT, no compose call, no shell
# ------------------------------------------------------------------------------
refused_before_shell() {
  refused_cleanly "$1" "$2" "" "" || return 1

  ! called_compose && opened_no_shell
}

# ------------------------------------------------------------------------------
# started_then_shell: exit 0, compose before the shell, shell in the folder
# ------------------------------------------------------------------------------
# The sandbox is demo. Used after the run of a sandbox that was not running.
# ------------------------------------------------------------------------------
started_then_shell() {
  [ "$SBX_RC" -eq 0 ] || return 1

  appears_before "$WORK/standin-calls" "docker compose" "docker exec -it" || return 1

  opened_shell demo
}

# ------------------------------------------------------------------------------
# entered_as_it_is: exit 0, no compose call, the shell opened in demo
# ------------------------------------------------------------------------------
entered_as_it_is() {
  [ "$SBX_RC" -eq 0 ] || return 1

  ! called_compose && opened_shell demo
}

# ------------------------------------------------------------------------------
# quiet_run LABEL: the run printed nothing about an older image
# ------------------------------------------------------------------------------
quiet_run() {
  lacks_text "$WORK/$1.out" "older image" && lacks_text "$WORK/$1.err" "older image"
}

# ------------------------------------------------------------------------------
# failed_without_shell LABEL TEXT: exit 1, TEXT in the error, no shell opened
# ------------------------------------------------------------------------------
failed_without_shell() {
  refused_cleanly "$1" "$2" "" "" && opened_no_shell
}

# ------------------------------------------------------------------------------
# Case: bad input is refused before any docker call
# ------------------------------------------------------------------------------
case_shell_refusals() {
  local ruleText='breaks the sandbox name rule'

  SBX_CONFIG_DIR=$WORK/cfg-shell-refusals
  export SBX_CONFIG_DIR

  echo '--- sbx-shell refusals'

  run_sbx shell1 sbx-shell
  expect "sbx-shell: no argument prints the usage and exits 2" usage_printed shell1 "Usage: sbx-shell NAME"

  run_sbx shell2 sbx-shell one two
  expect "sbx-shell: two arguments print the usage and exit 2" usage_printed shell2 "Usage: sbx-shell NAME"

  run_sbx shell3 sbx-shell nosuch
  expect "sbx-shell: an unregistered name is refused" refused_cleanly shell3 "is not registered; run: sbx-add" "" ""

  run_sbx shell4 sbx-shell ../x
  expect "sbx-shell: a path as a name is refused" refused_cleanly shell4 "$ruleText" "" ""

  run_sbx shell5 sbx-shell Demo
  expect "sbx-shell: an uppercase name is refused" refused_cleanly shell5 "$ruleText" "" ""
}

# ------------------------------------------------------------------------------
# Case: a wrong folder or image is refused before compose and the shell
# ------------------------------------------------------------------------------
case_shell_checks_before_compose() {
  local folderRoot="$WORK/shell dir/checks"

  SBX_CONFIG_DIR=$WORK/cfg-shell-checks
  export SBX_CONFIG_DIR

  echo '--- sbx-shell checks before compose'

  run_sbx nofolder sbx-add nofolder "$folderRoot/one"
  mv "$folderRoot/one/nofolder" "$folderRoot/one/nofolder-aside"
  set_standin_state sha256:new "" "" yes
  reset_standin_calls
  run_sbx_scripted nofolderrun sbx-shell nofolder
  expect "sbx-shell: a missing project folder is refused before compose and the shell" refused_before_shell nofolderrun "missing $folderRoot/one/nofolder"

  run_sbx nostate sbx-add nostate "$folderRoot/two"
  mv "$folderRoot/two/state" "$folderRoot/two/state-aside"
  set_standin_state sha256:new "" "" yes
  reset_standin_calls
  run_sbx_scripted nostaterun sbx-shell nostate
  expect "sbx-shell: a missing state folder is refused before compose and the shell" refused_before_shell nostaterun "missing $folderRoot/two/state"

  run_sbx noimage sbx-add noimage "$folderRoot/three"
  set_standin_state sha256:new "" "" yes
  set_standin_knob image-missing
  reset_standin_calls
  run_sbx_scripted noimagerun sbx-shell noimage
  expect "sbx-shell: a missing image is refused before compose and the shell" refused_before_shell noimagerun "is not built; run: sbx-upgrade"
}

# ------------------------------------------------------------------------------
# Case: a sandbox that is not running is started first; a running one is not
# ------------------------------------------------------------------------------
case_shell_start_paths() {
  local composeLine="docker compose --env-file /dev/null -p sbx-demo -f $REPO/compose.yml up -d --wait"

  SBX_CONFIG_DIR=$WORK/cfg-shell-start
  export SBX_CONFIG_DIR

  echo '--- sbx-shell start paths'

  run_sbx demo sbx-add demo "$WORK/shell dir/demo"

  set_standin_state sha256:new "" "" yes
  reset_standin_calls
  run_sbx_scripted newrun sbx-shell demo
  expect "sbx-shell: a sandbox with no container is started, then the shell opens" started_then_shell
  expect "sbx-shell: compose up runs for the sandbox's own project and folder" grep -qxF -- "$composeLine" "$WORK/standin-calls"
  expect "sbx-shell: the shell opens in the project folder" opened_shell demo

  set_standin_state sha256:new sha256:new false yes
  reset_standin_calls
  run_sbx_scripted stoppedrun sbx-shell demo
  expect "sbx-shell: a stopped sandbox is started, then the shell opens" started_then_shell

  set_standin_state sha256:new sha256:new true yes
  reset_standin_calls
  run_sbx_scripted currentrun sbx-shell demo
  expect "sbx-shell: a running sandbox gets the shell only" entered_as_it_is

  set_standin_state sha256:new sha256:old true yes
  reset_standin_calls
  run_sbx_scripted olderrun sbx-shell demo
  expect "sbx-shell: a running sandbox on an older image is entered as it is" entered_as_it_is
  expect "sbx-shell: an older image prints no message" quiet_run olderrun
}

# ------------------------------------------------------------------------------
# Case: the shell's exit status is passed on; a failed start opens no shell
# ------------------------------------------------------------------------------
case_shell_status_and_failures() {
  SBX_CONFIG_DIR=$WORK/cfg-shell-status
  export SBX_CONFIG_DIR

  echo '--- sbx-shell exit status and failed starts'

  run_sbx fails sbx-add fails "$WORK/shell dir/fails"

  set_standin_state sha256:new sha256:new true yes
  set_standin_knob shell-status 3
  reset_standin_calls
  run_sbx_scripted statusrun sbx-shell fails
  expect "sbx-shell: the exit status of the shell is the exit status of sbx-shell" equals "$SBX_RC" 3

  set_standin_state sha256:new "" "" yes
  set_standin_knob compose-fail
  reset_standin_calls
  run_sbx_scripted composefailrun sbx-shell fails
  expect "sbx-shell: a failed compose up opens no shell" failed_without_shell composefailrun "docker compose up failed"

  set_standin_state sha256:new "" "" no
  reset_standin_calls
  run_sbx_scripted stoppedstartrun sbx-shell fails
  expect "sbx-shell: a sandbox that stops during its start opens no shell" failed_without_shell stoppedstartrun "stopped during its start"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
make_scripted_docker
case_shell_refusals
case_shell_checks_before_compose
case_shell_start_paths
case_shell_status_and_failures
expect "sbx-shell: no case reached the refusing docker" no_docker_call
finish_cases
