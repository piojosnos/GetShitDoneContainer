#!/usr/bin/env bash
# Self-test of the negative assertions: lacks_text, lacks_match and fails are false on input they cannot use.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/assertions.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of the negative assertions, run against a plain file, a missing file and a folder
# --------------------------------------------------------------------------------
case_negative_assertions() {
  echo "--- negative assertions"

  printf 'present\n' >"$WORK/plain.txt"

  expect "lacks_text: a missing file is not a pass" fails lacks_text "$WORK/no-such-file.txt" absent
  expect "lacks_text: a folder is not a pass" fails lacks_text "$WORK" absent
  expect "lacks_text: a readable file without the text passes" lacks_text "$WORK/plain.txt" absent
  expect "lacks_text: a readable file with the text fails" fails lacks_text "$WORK/plain.txt" present

  expect "lacks_match: a missing file is not a pass" fails lacks_match "$WORK/no-such-file.txt" '^abs'
  expect "lacks_match: a folder is not a pass" fails lacks_match "$WORK" '^abs'
  expect "lacks_match: a readable file without the match passes" lacks_match "$WORK/plain.txt" '^abs'
  expect "lacks_match: a readable file with the match fails" fails lacks_match "$WORK/plain.txt" '^pres'

  expect "fails: a command that exits non-zero counts" fails false
  expect "fails: a command that succeeds does not count" fails fails true
  expect "fails: a command that does not exist does not count" fails fails no_such_command_for_the_assertions_group
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_negative_assertions
finish_cases
