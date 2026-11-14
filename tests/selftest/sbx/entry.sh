#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of the registry reader and the refusals of sbx-start and sbx-stop
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/entry.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# refused_unrun LABEL TEXT MARKER: refused with TEXT, and MARKER was not made
# ------------------------------------------------------------------------------
refused_unrun() {
  refused_cleanly "$1" "$2" "" "$3"
}

# ------------------------------------------------------------------------------
# Case: a registry value is data; nothing in it is run
# ------------------------------------------------------------------------------
case_read_as_data() {
  SBX_CONFIG_DIR=$WORK/cfg-data
  export SBX_CONFIG_DIR

  echo '--- registry values are read as text'

  plant_entry planted "SBX_DIR=\$(touch $WORK/pwned)" "SBX_AGENT=claude"
  run_sbx planted sbx-start planted
  expect "registry: a value is read as text and never run" refused_unrun planted "has no absolute SBX_DIR" "$WORK/pwned"

  plant_entry semi "SBX_DIR=/x; touch $WORK/pwned2" "SBX_AGENT=claude"
  run_sbx semi sbx-start semi
  expect "registry: a value with a semicolon is never run" refused_unrun semi "missing" "$WORK/pwned2"
}

# ------------------------------------------------------------------------------
# Case: line order, a missing final newline and spaces do not change the result
# ------------------------------------------------------------------------------
case_line_forms() {
  local readText='read_registry_entry NAME; printf "%s|%s\n" "$entryDir" "$entryAgent"'
  local readOut

  SBX_CONFIG_DIR=$WORK/cfg-forms
  export SBX_CONFIG_DIR

  echo '--- registry line forms'

  plant_entry swapped "SBX_AGENT=claude" "SBX_DIR=/x/swapped"
  readOut=$(lib_eval "${readText/NAME/swapped}" 2>&1)
  expect "registry: swapped lines read the same" equals "$readOut" "/x/swapped|claude"

  printf 'SBX_DIR=/x/bare\nSBX_AGENT=claude' >"$SBX_CONFIG_DIR/sandboxes/bare"
  readOut=$(lib_eval "${readText/NAME/bare}" 2>&1)
  expect "registry: a last line without a newline reads the same" equals "$readOut" "/x/bare|claude"

  plant_entry spaced "SBX_DIR=/x/with space/dir" "SBX_AGENT=claude"
  readOut=$(lib_eval "${readText/NAME/spaced}" 2>&1)
  expect "registry: a path with a space reads whole" equals "$readOut" "/x/with space/dir|claude"
}

# ------------------------------------------------------------------------------
# Case: the agent picks the image
# ------------------------------------------------------------------------------
case_agents() {
  local readText='read_registry_entry NAME; printf "%s|%s\n" "$entryAgent" "$agentImage"'
  local readOut

  SBX_CONFIG_DIR=$WORK/cfg-agents
  export SBX_CONFIG_DIR

  echo '--- the agent picks the image'

  plant_entry cursorentry "SBX_DIR=/x/cursor" "SBX_AGENT=cursor"
  readOut=$(lib_eval "${readText/NAME/cursorentry}" 2>&1)
  expect "registry: a cursor entry maps to sbx-cursor:local" equals "$readOut" "cursor|sbx-cursor:local"

  plant_entry claudeentry "SBX_DIR=/x/claude" "SBX_AGENT=claude"
  readOut=$(lib_eval "${readText/NAME/claudeentry}" 2>&1)
  expect "registry: a claude entry maps to sbx-claude:local" equals "$readOut" "claude|sbx-claude:local"
}

# ------------------------------------------------------------------------------
# Case: an entry that is empty, relative or for another agent is refused
# ------------------------------------------------------------------------------
case_bad_entries() {
  SBX_CONFIG_DIR=$WORK/cfg-bad
  export SBX_CONFIG_DIR

  echo '--- bad registry entries'

  plant_entry empty
  run_sbx emptyentry sbx-start empty
  expect "registry: an empty entry is refused" refused_cleanly emptyentry "has no absolute SBX_DIR" "" ""

  plant_entry relative "SBX_DIR=rel/dir" "SBX_AGENT=claude"
  run_sbx relentry sbx-start relative
  expect "registry: a relative SBX_DIR is refused" refused_cleanly relentry "has no absolute SBX_DIR" "" ""

  plant_entry otheragent "SBX_DIR=/x" "SBX_AGENT=opencode"
  run_sbx agententry sbx-start otheragent
  expect "registry: another agent is refused" refused_cleanly agententry "names agent 'opencode'" "" ""

  plant_entry noagent "SBX_DIR=/x"
  run_sbx noagententry sbx-start noagent
  expect "registry: a missing SBX_AGENT is refused" refused_cleanly noagententry "names agent ''" "" ""

  run_sbx fresh sbx-add fresh "$WORK/fresh dir"
  expect "registry: a broken entry stops sbx-add" refused_cleanly fresh "has no absolute SBX_DIR" fresh "$WORK/fresh dir"
}

# ------------------------------------------------------------------------------
# Case: sbx-start and sbx-stop refuse bad input before they reach Docker
# ------------------------------------------------------------------------------
case_start_stop_refusals() {
  local ruleText='breaks the sandbox name rule'

  SBX_CONFIG_DIR=$WORK/cfg-refusals
  export SBX_CONFIG_DIR

  echo '--- sbx-start and sbx-stop refusals'

  run_sbx start1 sbx-start nosuch
  expect "sbx-start: an unregistered name is refused" refused_cleanly start1 "is not registered; run: sbx-add" "" ""

  run_sbx start2 sbx-start ../x
  expect "sbx-start: a path as a name is refused" refused_cleanly start2 "$ruleText" "" ""

  run_sbx start3 sbx-start Demo
  expect "sbx-start: an uppercase name is refused" refused_cleanly start3 "$ruleText" "" ""

  run_sbx moved sbx-add moved "$WORK/moved dir"
  mv "$WORK/moved dir/moved" "$WORK/moved dir/moved-aside"
  run_sbx start4 sbx-start moved
  expect "sbx-start: a missing project folder is refused before Docker" refused_cleanly start4 "missing" "" ""

  run_sbx start5 sbx-start
  expect "sbx-start: no argument prints the usage and exits 2" usage_printed start5 "Usage: sbx-start NAME"

  run_sbx start6 sbx-start one two
  expect "sbx-start: two arguments print the usage and exit 2" usage_printed start6 "Usage: sbx-start NAME"

  run_sbx stop1 sbx-stop nosuch
  expect "sbx-stop: an unregistered name is refused" refused_cleanly stop1 "is not registered; run: sbx-add" "" ""

  run_sbx stop2 sbx-stop ../x
  expect "sbx-stop: a path as a name is refused" refused_cleanly stop2 "$ruleText" "" ""

  run_sbx stop3 sbx-stop
  expect "sbx-stop: no argument prints the usage and exits 2" usage_printed stop3 "Usage: sbx-stop NAME"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_read_as_data
case_line_forms
case_agents
case_bad_entries
case_start_stop_refusals
finish_cases
