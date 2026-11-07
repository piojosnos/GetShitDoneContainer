#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of sbx-rm: usage, refusals, the down call, the entry, the folder
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/rm.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# The refusing stand-in stays first on PATH except inside run_sbx_scripted.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

usageText='Usage: sbx-rm NAME [--unregister]'

# ------------------------------------------------------------------------------
# folder_listing DIR: prints every path under DIR, then the text of every file
# ------------------------------------------------------------------------------
# Two listings are equal only when nothing was added, deleted or changed.
# ------------------------------------------------------------------------------
folder_listing() {
  local listedFile

  find "$1" | LC_ALL=C sort

  find "$1" -type f | LC_ALL=C sort | while IFS= read -r listedFile; do
    echo "== $listedFile"
    cat "$listedFile"
  done
}

# ------------------------------------------------------------------------------
# plant_sandbox_files DIR NAME: puts a code file and a login file in the folder
# ------------------------------------------------------------------------------
plant_sandbox_files() {
  printf 'keep\n' >"$1/$2/keep.txt"
  printf 'login\n' >"$1/state/login.txt"
}

# ------------------------------------------------------------------------------
# closing_line LABEL NAME DIR: the last output line says only the container went
# ------------------------------------------------------------------------------
closing_line() {
  [ "$(tail -n 1 "$WORK/$1.out")" = "sbx-rm: the container sbx-$2 is gone; nothing in $3 was changed" ]
}

# ------------------------------------------------------------------------------
# down_call_is_exact NAME: one compose call, the scoped down with no option
# ------------------------------------------------------------------------------
down_call_is_exact() {
  local composeCallCount

  composeCallCount=$(grep -c '^docker compose ' "$WORK/standin-calls")

  [ "$composeCallCount" -eq 1 ] || return 1

  grep -qxF -- "docker compose --env-file /dev/null -p sbx-$1 -f $REPO/compose.yml down" "$WORK/standin-calls"
}

# ------------------------------------------------------------------------------
# no_compose_call: the scripted docker saw no compose call
# ------------------------------------------------------------------------------
no_compose_call() {
  ! grep -q '^docker compose ' "$WORK/standin-calls"
}

# ------------------------------------------------------------------------------
# warned_before_down LABEL NAME: the sessions warning comes before the down
# ------------------------------------------------------------------------------
warned_before_down() {
  has_text "$WORK/$1.out" "sbx-rm: sbx-$2 is running; removing it will close its open shells and Claude sessions" \
    && appears_before "$WORK/$1.out" "sbx-rm: sbx-$2 is running" "standin: compose"
}

# ------------------------------------------------------------------------------
# removed_quietly LABEL NAME DIR: exit 0, no warning, the closing line last
# ------------------------------------------------------------------------------
removed_quietly() {
  [ "$SBX_RC" -eq 0 ] && lacks_text "$WORK/$1.out" "will close" && closing_line "$1" "$2" "$3"
}

# ------------------------------------------------------------------------------
# unregistered_after_down LABEL NAME DIR: the entry went after the down
# ------------------------------------------------------------------------------
unregistered_after_down() {
  [ "$SBX_RC" -eq 0 ] || return 1
  [ ! -e "$SBX_CONFIG_DIR/sandboxes/$2" ] || return 1
  appears_before "$WORK/$1.out" "standin: compose" "deleted the registry entry" || return 1

  closing_line "$1" "$2" "$3"
}

# ------------------------------------------------------------------------------
# others_and_folder_kept ENTRY COPY DIR LISTING: entry and folder are as before
# ------------------------------------------------------------------------------
others_and_folder_kept() {
  cmp -s "$1" "$2" && [ "$(folder_listing "$3")" = "$4" ]
}

# ------------------------------------------------------------------------------
# unregister_refused_again LABEL OTHER_COPY: exit 1, no compose call, no change
# ------------------------------------------------------------------------------
unregister_refused_again() {
  refused_cleanly "$1" "is not registered" "" "" && no_compose_call && cmp -s "$SBX_CONFIG_DIR/sandboxes/other" "$2"
}

# ------------------------------------------------------------------------------
# failed_down_kept_entry LABEL NAME COPY: exit 1, the error, the entry as it was
# ------------------------------------------------------------------------------
failed_down_kept_entry() {
  [ "$SBX_RC" -eq 1 ] || return 1
  has_text "$WORK/$1.err" "docker compose down failed for sbx-$2; the registry entry stays" || return 1
  lacks_text "$WORK/$1.out" "deleted the registry entry" || return 1

  cmp -s "$SBX_CONFIG_DIR/sandboxes/$2" "$3"
}

# ------------------------------------------------------------------------------
# ran_compose_down NAME: the scripted docker saw the down call of sbx-NAME
# ------------------------------------------------------------------------------
ran_compose_down() {
  grep -qE -- "^docker compose .* -p sbx-$1 .* down$" "$WORK/standin-calls"
}

# ------------------------------------------------------------------------------
# Case: the wrong number of arguments or an unknown option is the usage
# ------------------------------------------------------------------------------
case_rm_usage() {
  SBX_CONFIG_DIR=$WORK/cfg-rm-usage
  export SBX_CONFIG_DIR

  echo '--- sbx-rm usage'

  run_sbx rmusage0 sbx-rm
  expect "sbx-rm: no argument prints the usage and exits 2" usage_printed rmusage0 "$usageText"

  run_sbx rmusage3 sbx-rm a b c
  expect "sbx-rm: three arguments print the usage and exit 2" usage_printed rmusage3 "$usageText"

  run_sbx rmusage1 sbx-rm --unregister
  expect "sbx-rm: --unregister alone prints the usage and exits 2" usage_printed rmusage1 "$usageText"

  run_sbx rmusage2 sbx-rm demo --force
  expect "sbx-rm: an unknown option prints the usage and exits 2" usage_printed rmusage2 "$usageText"
}

# ------------------------------------------------------------------------------
# Case: a name that is not registered or breaks the rule is refused
# ------------------------------------------------------------------------------
case_rm_refusals() {
  SBX_CONFIG_DIR=$WORK/cfg-rm-refusals
  export SBX_CONFIG_DIR

  echo '--- sbx-rm refusals'

  run_sbx rmghost sbx-rm ghost
  expect "sbx-rm: an unregistered name is refused" refused_cleanly rmghost "is not registered; run: sbx-add" "" ""

  run_sbx rmpath sbx-rm ../x
  expect "sbx-rm: a path as a name is refused" refused_cleanly rmpath "breaks the sandbox name rule" "" ""

  run_sbx rmpathflag sbx-rm --unregister ../x
  expect "sbx-rm: a path as a name with --unregister is refused" refused_cleanly rmpathflag "breaks the sandbox name rule" "" ""

  run_sbx rmupper sbx-rm Demo
  expect "sbx-rm: an uppercase name is refused" refused_cleanly rmupper "breaks the sandbox name rule" "" ""
}

# ------------------------------------------------------------------------------
# Case: a running sandbox is warned, taken down once and left otherwise as is
# ------------------------------------------------------------------------------
case_rm_running() {
  local demoDir="$WORK/rm dir/demo"
  local listingBefore
  local entryCopy=$WORK/entry-running.before

  SBX_CONFIG_DIR=$WORK/cfg-rm-running
  export SBX_CONFIG_DIR

  echo '--- sbx-rm running sandbox'

  run_sbx runadd sbx-add demo "$demoDir"
  plant_sandbox_files "$demoDir" demo
  listingBefore=$(folder_listing "$demoDir")
  cp "$SBX_CONFIG_DIR/sandboxes/demo" "$entryCopy"

  set_standin_state sha256:new sha256:new true yes
  reset_standin_calls
  run_sbx_scripted runrm sbx-rm demo

  expect "sbx-rm: compose down runs once, for the sandbox's own project, with no option" down_call_is_exact demo
  expect "sbx-rm: a running sandbox is warned before the down" warned_before_down runrm demo
  expect "sbx-rm: the last line says nothing in the folder was changed" closing_line runrm demo "$demoDir"
  expect "sbx-rm: the files in the sandbox folder are unchanged" equals "$(folder_listing "$demoDir")" "$listingBefore"
  expect "sbx-rm: without --unregister the entry stays" cmp -s "$SBX_CONFIG_DIR/sandboxes/demo" "$entryCopy"
}

# ------------------------------------------------------------------------------
# Case: a stopped sandbox and a sandbox with no container are removed quietly
# ------------------------------------------------------------------------------
case_rm_stopped_and_gone() {
  local idleDir="$WORK/rm dir/idle"

  SBX_CONFIG_DIR=$WORK/cfg-rm-idle
  export SBX_CONFIG_DIR

  echo '--- sbx-rm stopped sandbox and no container'

  run_sbx idleadd sbx-add idle "$idleDir"

  set_standin_state sha256:new sha256:new false yes
  reset_standin_calls
  run_sbx_scripted idlestopped sbx-rm idle
  expect "sbx-rm: a stopped sandbox is removed with no warning" removed_quietly idlestopped idle "$idleDir"

  set_standin_state sha256:new "" "" yes
  reset_standin_calls
  run_sbx_scripted idlegone sbx-rm idle
  expect "sbx-rm: a sandbox with no container is removed quietly" removed_quietly idlegone idle "$idleDir"

  reset_standin_calls
  run_sbx_scripted idleagain sbx-rm idle
  expect "sbx-rm: a second run succeeds too" removed_quietly idleagain idle "$idleDir"
}

# ------------------------------------------------------------------------------
# Case: --unregister deletes only the entry, only after the down, once
# ------------------------------------------------------------------------------
case_rm_unregister() {
  local demoDir="$WORK/rm dir/unreg-demo"
  local otherDir="$WORK/rm dir/unreg-other"
  local listingBefore
  local otherCopy=$WORK/entry-other.before

  SBX_CONFIG_DIR=$WORK/cfg-rm-unregister
  export SBX_CONFIG_DIR

  echo '--- sbx-rm unregister'

  run_sbx unregadd sbx-add demo "$demoDir"
  run_sbx unregotheradd sbx-add other "$otherDir"
  plant_sandbox_files "$demoDir" demo
  listingBefore=$(folder_listing "$demoDir")
  cp "$SBX_CONFIG_DIR/sandboxes/other" "$otherCopy"

  set_standin_state sha256:new sha256:new true yes
  reset_standin_calls
  run_sbx_scripted unregrun sbx-rm demo --unregister
  expect "sbx-rm: --unregister deletes the entry after the down" unregistered_after_down unregrun demo "$demoDir"
  expect "sbx-rm: --unregister keeps the other entries and the folder" others_and_folder_kept "$SBX_CONFIG_DIR/sandboxes/other" "$otherCopy" "$demoDir" "$listingBefore"

  reset_standin_calls
  run_sbx_scripted unregtwice sbx-rm demo --unregister
  expect "sbx-rm: a second --unregister is refused and changes nothing" unregister_refused_again unregtwice "$otherCopy"

  run_sbx unregagainadd sbx-add again "$WORK/rm dir/unreg-again"
  reset_standin_calls
  run_sbx_scripted unregfirst sbx-rm --unregister again
  expect "sbx-rm: --unregister before the name works the same" unregistered_after_down unregfirst again "$WORK/rm dir/unreg-again"
}

# ------------------------------------------------------------------------------
# Case: a failed down exits 1 and the entry stays as it was
# ------------------------------------------------------------------------------
case_rm_down_fails() {
  local entryCopy=$WORK/entry-stuck.before

  SBX_CONFIG_DIR=$WORK/cfg-rm-stuck
  export SBX_CONFIG_DIR

  echo '--- sbx-rm failed down'

  run_sbx stuckadd sbx-add stuck "$WORK/rm dir/stuck"
  cp "$SBX_CONFIG_DIR/sandboxes/stuck" "$entryCopy"

  set_standin_state sha256:new sha256:new true yes
  set_standin_knob compose-fail
  reset_standin_calls
  run_sbx_scripted stuckrun sbx-rm stuck --unregister
  expect "sbx-rm: a failed down exits 1 and keeps the entry" failed_down_kept_entry stuckrun stuck "$entryCopy"
}

# ------------------------------------------------------------------------------
# Case: a moved folder or a missing image does not stop the removal
# ------------------------------------------------------------------------------
case_rm_no_folder_or_image() {
  SBX_CONFIG_DIR=$WORK/cfg-rm-missing
  export SBX_CONFIG_DIR

  echo '--- sbx-rm missing folder and image'

  plant_entry gone "SBX_DIR=$WORK/no such folder" "SBX_AGENT=claude"
  set_standin_state sha256:new "" "" yes
  reset_standin_calls
  run_sbx_scripted gonerun sbx-rm gone
  expect "sbx-rm: a missing sandbox folder does not stop the removal" equals "$SBX_RC:$(ran_compose_down gone && echo down)" "0:down"

  run_sbx noimageadd sbx-add noimage "$WORK/rm dir/noimage"
  set_standin_state sha256:new "" "" yes
  set_standin_knob image-missing
  reset_standin_calls
  run_sbx_scripted noimagerun sbx-rm noimage
  expect "sbx-rm: a missing image does not stop the removal" equals "$SBX_RC:$(ran_compose_down noimage && echo down)" "0:down"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
make_scripted_docker
case_rm_usage
case_rm_refusals
case_rm_running
case_rm_stopped_and_gone
case_rm_unregister
case_rm_down_fails
case_rm_no_folder_or_image
expect "sbx-rm: no case reached the refusing docker" no_docker_call
finish_cases
