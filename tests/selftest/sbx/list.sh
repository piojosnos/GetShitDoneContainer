#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of sbx-list: statuses, marker, broken rows, leftovers, order
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/list.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# The refusing stand-in stays first on PATH except inside run_sbx_scripted.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# has_line LABEL TEXT: the output of the run has a line exactly equal to TEXT
# ------------------------------------------------------------------------------
has_line() {
  grep -qxF -- "$2" "$WORK/$1.out"
}

# ------------------------------------------------------------------------------
# has_row LABEL NAME STATUS PATH: the output has the table row of the three
# ------------------------------------------------------------------------------
has_row() {
  has_line "$1" "$(printf '%-31s %-20s %s' "$2" "$3" "$4")"
}

# ------------------------------------------------------------------------------
# has_leftover LABEL CONTAINER STATUS: the output has the leftover line
# ------------------------------------------------------------------------------
has_leftover() {
  has_line "$1" "$(printf '  %-35s %s' "$2" "$3")"
}

# ------------------------------------------------------------------------------
# row_start NAME STATUS: the row text up to the folder, for appears_before
# ------------------------------------------------------------------------------
row_start() {
  printf '%-31s %-20s' "$1" "$2"
}

# ------------------------------------------------------------------------------
# line_starts_with LABEL NUMBER TEXT: line NUMBER of the output starts with TEXT
# ------------------------------------------------------------------------------
line_starts_with() {
  local lineText

  lineText=$(sed -n "$2p" "$WORK/$1.out")

  [ "${lineText#"$3"}" != "$lineText" ]
}

# ------------------------------------------------------------------------------
# row_ends_with LABEL NAME TEXT: the row of NAME ends with TEXT
# ------------------------------------------------------------------------------
row_ends_with() {
  local rowText

  rowText=$(grep -m1 -- "^$2 " "$WORK/$1.out")

  [ -n "$rowText" ] && [ "${rowText%"$3"}" != "$rowText" ]
}

# ------------------------------------------------------------------------------
# unmarked_row LABEL NAME STATUS PATH: the row is there and says nothing of an
# older image anywhere in the output
# ------------------------------------------------------------------------------
unmarked_row() {
  has_row "$1" "$2" "$3" "$4" && lacks_text "$WORK/$1.out" "older image"
}

# ------------------------------------------------------------------------------
# rows_in_name_order LABEL: lines 2, 3 and 4 are the rows alpha, beta and gamma
# ------------------------------------------------------------------------------
rows_in_name_order() {
  line_starts_with "$1" 2 alpha && line_starts_with "$1" 3 beta && line_starts_with "$1" 4 gamma
}

# ------------------------------------------------------------------------------
# leftover_after_table LABEL: sbx-stray is listed after the row of gamma
# ------------------------------------------------------------------------------
leftover_after_table() {
  has_leftover "$1" sbx-stray running && appears_before "$WORK/$1.out" "$WORK/list dir/gamma" "Containers with the sbx.name label"
}

# ------------------------------------------------------------------------------
# broken_row_beside_good LABEL: exit 0, the broken row and the good row print
# ------------------------------------------------------------------------------
broken_row_beside_good() {
  [ "$SBX_RC" -eq 0 ] && has_row "$1" broken "broken entry" "$SBX_CONFIG_DIR/sandboxes/broken" && has_row "$1" good "no container" "$WORK/list dir/good"
}

# ------------------------------------------------------------------------------
# adjacent_is_not_entry LABEL: demo has no container; sbx-demo-two is a leftover
# ------------------------------------------------------------------------------
adjacent_is_not_entry() {
  has_row "$1" demo "no container" "$WORK/list dir/demo" && has_leftover "$1" sbx-demo-two running
}

# ------------------------------------------------------------------------------
# one_ps_call_only: one docker ps with the label filter, no compose, no exec
# ------------------------------------------------------------------------------
one_ps_call_only() {
  local psCallCount

  psCallCount=$(grep -c '^docker ps ' "$WORK/standin-calls")

  [ "$psCallCount" -eq 1 ] || return 1

  grep -qxF -- 'docker ps -a --filter label=sbx.name --format {{.Names}} {{.State}}' "$WORK/standin-calls" || return 1

  ! grep -Eq '^docker (compose|exec)' "$WORK/standin-calls"
}

# ------------------------------------------------------------------------------
# registry_snapshot: prints each registry file name and its content
# ------------------------------------------------------------------------------
registry_snapshot() {
  local entryPath

  for entryPath in "$SBX_CONFIG_DIR/sandboxes"/*; do
    echo "== ${entryPath##*/}"
    cat "$entryPath"
  done
}

# ------------------------------------------------------------------------------
# usage_is_exact LABEL: exit 2 and the error is exactly the usage line
# ------------------------------------------------------------------------------
usage_is_exact() {
  usage_printed "$1" "Usage: sbx-list" && [ "$(cat "$WORK/$1.err")" = "Usage: sbx-list" ]
}

# ------------------------------------------------------------------------------
# failed_without_table LABEL: exit 1, the Docker error, nothing on stdout
# ------------------------------------------------------------------------------
failed_without_table() {
  refused_cleanly "$1" "cannot read the containers from Docker" "" "" && [ ! -s "$WORK/$1.out" ]
}

# ------------------------------------------------------------------------------
# Case: an argument is refused with the usage line
# ------------------------------------------------------------------------------
case_list_usage() {
  SBX_CONFIG_DIR=$WORK/cfg-list-usage
  export SBX_CONFIG_DIR

  echo '--- sbx-list usage'

  run_sbx listusage sbx-list extra
  expect "sbx-list: an argument prints the usage and exits 2" usage_is_exact listusage
}

# ------------------------------------------------------------------------------
# Case: a failed docker ps is an error, never an empty list
# ------------------------------------------------------------------------------
case_list_docker_failure() {
  SBX_CONFIG_DIR=$WORK/cfg-list-failure
  export SBX_CONFIG_DIR

  echo '--- sbx-list docker failure'

  run_sbx failadd sbx-add one "$WORK/list dir/one"

  set_standin_state sha256:new "" "" yes
  set_standin_knob ps-fail
  reset_standin_calls
  run_sbx_scripted failrun sbx-list
  expect "sbx-list: a failed docker ps exits 1 and prints no table" failed_without_table failrun
}

# ------------------------------------------------------------------------------
# Case: an empty registry says so, and still lists the leftovers
# ------------------------------------------------------------------------------
case_list_empty() {
  local emptyMessage='sbx-list: no sandboxes registered; register one with: sbx-add NAME HOST_PATH'

  SBX_CONFIG_DIR=$WORK/cfg-list-empty
  export SBX_CONFIG_DIR

  echo '--- sbx-list empty registry'

  set_standin_state sha256:new "" "" yes
  reset_standin_calls
  run_sbx_scripted emptyrun sbx-list
  expect "sbx-list: an empty registry says so and exits 0" equals "$SBX_RC:$(cat "$WORK/emptyrun.out")" "0:$emptyMessage"

  set_standin_state sha256:new "" "" yes
  set_standin_ps "sbx-stray running"
  reset_standin_calls
  run_sbx_scripted emptystray sbx-list
  expect "sbx-list: an empty registry still lists the leftovers" has_leftover emptystray sbx-stray running
}

# ------------------------------------------------------------------------------
# Case: the table, its order, one docker ps call and a read-only run
# ------------------------------------------------------------------------------
case_list_table() {
  local snapshotBefore
  local snapshotAfter

  SBX_CONFIG_DIR=$WORK/cfg-list-table
  export SBX_CONFIG_DIR

  echo '--- sbx-list table'

  run_sbx gamma sbx-add gamma "$WORK/list dir/gamma"
  run_sbx alpha sbx-add alpha "$WORK/list dir/alpha"
  run_sbx beta sbx-add beta "$WORK/list dir/beta"

  set_standin_state sha256:new sha256:new true yes
  set_standin_ps "sbx-beta exited" "sbx-alpha running" "sbx-stray running"
  snapshotBefore=$(registry_snapshot)
  reset_standin_calls
  run_sbx_scripted tablerun sbx-list
  snapshotAfter=$(registry_snapshot)

  expect "sbx-list: one docker ps call reads every labelled container" one_ps_call_only
  expect "sbx-list: the header comes first" equals "$(sed -n 1p "$WORK/tablerun.out")" "$(printf '%-31s %-20s %s' NAME STATUS PATH)"
  expect "sbx-list: a running sandbox reads running, with its path" has_row tablerun alpha running "$WORK/list dir/alpha"
  expect "sbx-list: a path with spaces is printed whole" row_ends_with tablerun alpha "$WORK/list dir/alpha"
  expect "sbx-list: an exited container reads stopped" has_row tablerun beta stopped "$WORK/list dir/beta"
  expect "sbx-list: a sandbox with no container reads no container" has_row tablerun gamma "no container" "$WORK/list dir/gamma"

  expect "sbx-list: rows are in name order" rows_in_name_order tablerun
  expect "sbx-list: a labelled container with no entry is listed after the table" leftover_after_table tablerun
  expect "sbx-list: the registry is unchanged" equals "$snapshotAfter" "$snapshotBefore"
}

# ------------------------------------------------------------------------------
# Case: rows come in byte order of the name
# ------------------------------------------------------------------------------
case_list_order() {
  SBX_CONFIG_DIR=$WORK/cfg-list-order
  export SBX_CONFIG_DIR

  echo '--- sbx-list order'

  run_sbx ab sbx-add ab "$WORK/list dir/ab"
  run_sbx ac sbx-add a-c "$WORK/list dir/a-c"

  set_standin_state sha256:new "" "" yes
  reset_standin_calls
  run_sbx_scripted orderrun sbx-list
  expect "sbx-list: rows are in byte order of the name" appears_before "$WORK/orderrun.out" "$(row_start a-c 'no container')" "$(row_start ab 'no container')"
}

# ------------------------------------------------------------------------------
# Case: only a running sandbox on another image is marked
# ------------------------------------------------------------------------------
case_list_marker() {
  local olderDir="$WORK/list dir/older"

  SBX_CONFIG_DIR=$WORK/cfg-list-marker
  export SBX_CONFIG_DIR

  echo '--- sbx-list older image marker'

  run_sbx older sbx-add older "$olderDir"

  set_standin_state sha256:new sha256:old true yes
  set_standin_ps "sbx-older running"
  reset_standin_calls
  run_sbx_scripted markedrun sbx-list
  expect "sbx-list: a running sandbox on an older image is marked" has_row markedrun older "running, older image" "$olderDir"
  expect "sbx-list: the older image note follows the table" appears_before "$WORK/markedrun.out" "$(row_start older 'running, older image')" "older image: sbx-start NAME recreates it"

  set_standin_state sha256:new sha256:new true yes
  set_standin_ps "sbx-older running"
  reset_standin_calls
  run_sbx_scripted currentrun sbx-list
  expect "sbx-list: a running sandbox on the current image is not marked" unmarked_row currentrun older running "$olderDir"
  expect "sbx-list: no leftover section when every container is registered" lacks_text "$WORK/currentrun.out" "Containers with the sbx.name label"

  set_standin_state sha256:new sha256:old false yes
  set_standin_ps "sbx-older exited"
  reset_standin_calls
  run_sbx_scripted stoppedrun sbx-list
  expect "sbx-list: a stopped sandbox on an older image is not marked" unmarked_row stoppedrun older stopped "$olderDir"

  set_standin_state sha256:new sha256:old false yes
  set_standin_ps "sbx-older paused"
  reset_standin_calls
  run_sbx_scripted pausedrun sbx-list
  expect "sbx-list: a paused container reads stopped" has_row pausedrun older stopped "$olderDir"
}

# ------------------------------------------------------------------------------
# Case: an unreadable entry or a bad file name is a row, not a failure
# ------------------------------------------------------------------------------
case_list_broken() {
  SBX_CONFIG_DIR=$WORK/cfg-list-broken
  export SBX_CONFIG_DIR

  echo '--- sbx-list broken entries'

  run_sbx good sbx-add good "$WORK/list dir/good"
  plant_entry broken
  plant_entry Bad_Name "SBX_DIR=$WORK/x" "SBX_AGENT=claude"

  set_standin_state sha256:new "" "" yes
  reset_standin_calls
  run_sbx_scripted brokenrun sbx-list

  expect "sbx-list: a broken entry is a row, and the other rows still print" broken_row_beside_good brokenrun
  expect "sbx-list: an entry file whose name breaks the rule is a broken row" has_row brokenrun Bad_Name "broken entry" "$SBX_CONFIG_DIR/sandboxes/Bad_Name"
}

# ------------------------------------------------------------------------------
# Case: a container named sbx-demo-two is not the sandbox demo
# ------------------------------------------------------------------------------
case_list_adjacency() {
  SBX_CONFIG_DIR=$WORK/cfg-list-adjacency
  export SBX_CONFIG_DIR

  echo '--- sbx-list adjacent names'

  run_sbx demo sbx-add demo "$WORK/list dir/demo"

  set_standin_state sha256:new sha256:new true yes
  set_standin_ps "sbx-demo-two running"
  reset_standin_calls
  run_sbx_scripted adjacentrun sbx-list

  expect "sbx-list: a container whose name only starts like an entry is not that entry" adjacent_is_not_entry adjacentrun
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
make_scripted_docker
case_list_usage
case_list_docker_failure
case_list_empty
case_list_table
case_list_order
case_list_marker
case_list_broken
case_list_adjacency
expect "sbx-list: no case reached the refusing docker" no_docker_call
finish_cases
