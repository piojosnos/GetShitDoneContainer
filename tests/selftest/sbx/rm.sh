#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of sbx-rm: usage, refusals and broken entries
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/rm.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# Docker points at a missing socket, so no case reaches a daemon.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

usageText='Usage: sbx-rm NAME [--unregister] [--yes]'

# ------------------------------------------------------------------------------
# broken_kept LABEL TEXT COPY: exit 1, TEXT in the error, the entry as in COPY
# ------------------------------------------------------------------------------
broken_kept() {
  [ "$SBX_RC" -eq 1 ] || return 1
  has_text "$WORK/$1.err" "$2" || return 1

  cmp -s "$SBX_CONFIG_DIR/sandboxes/broken" "$3"
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

  run_sbx rmusageyes sbx-rm --yes
  expect "sbx-rm: --yes alone prints the usage and exits 2" usage_printed rmusageyes "$usageText"

  run_sbx rmusageboth sbx-rm --yes --unregister
  expect "sbx-rm: both options and no name print the usage and exit 2" usage_printed rmusageboth "$usageText"

  run_sbx rmusagetwice sbx-rm demo --yes --yes
  expect "sbx-rm: --yes twice prints the usage and exits 2" usage_printed rmusagetwice "$usageText"

  run_sbx rmusagenames sbx-rm demo other
  expect "sbx-rm: two names print the usage and exit 2" usage_printed rmusagenames "$usageText"

  run_sbx rmusagefour sbx-rm demo --yes --unregister x
  expect "sbx-rm: four arguments print the usage and exit 2" usage_printed rmusagefour "$usageText"
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
# Case: a broken entry is refused without --unregister, and kept otherwise
# ------------------------------------------------------------------------------
# It is also kept when Docker does not answer or when its name breaks the rule.
# ------------------------------------------------------------------------------
case_rm_broken_entry() {
  local entryCopy=$WORK/entry-broken.before

  SBX_CONFIG_DIR=$WORK/cfg-rm-broken
  export SBX_CONFIG_DIR

  echo '--- sbx-rm broken entry'

  plant_entry broken "SBX_DIR=relative/folder" "SBX_AGENT=claude"
  cp "$SBX_CONFIG_DIR/sandboxes/broken" "$entryCopy"

  run_sbx brokenplain sbx-rm broken --yes
  expect "sbx-rm: a broken entry without --unregister is refused with the --unregister hint" broken_kept brokenplain "sbx-rm broken --unregister removes the container by name and clears the entry" "$entryCopy"
  expect "sbx-rm: the refusal says what is wrong with the entry" has_text "$WORK/brokenplain.err" "has no absolute SBX_DIR"

  run_sbx brokendown sbx-rm broken --unregister --yes
  expect "sbx-rm: a broken entry with Docker not answering is kept" broken_kept brokendown "cannot reach Docker; is Docker running?" "$entryCopy"

  plant_entry Bad_Name "SBX_AGENT=claude"
  run_sbx brokenbadname sbx-rm Bad_Name --unregister --yes
  expect "sbx-rm: an entry file with a name that breaks the rule is refused and kept" equals "$SBX_RC:$([ -f "$SBX_CONFIG_DIR/sandboxes/Bad_Name" ] && echo kept)" "1:kept"
  expect "sbx-rm: the bad name is refused by the name rule, not by Docker" has_text "$WORK/brokenbadname.err" "breaks the sandbox name rule"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_rm_usage
case_rm_refusals
case_rm_broken_entry
finish_cases
