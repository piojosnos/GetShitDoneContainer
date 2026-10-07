#!/usr/bin/env bash
# Self-test of the host test rules: they fail when their scripts are missing and they name planted delete and GNU-only forms.
# - Run by run-all.sh; runs alone too.
# - Runs the real tests/guard/host-tests.sh inside a scratch copy of the tree, so a planted problem never touches the real files.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/guard/host-rules.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# plant_lines FILE LINE...: appends each LINE to FILE as its own code line.
# --------------------------------------------------------------------------------
plant_lines() {
  local plantFile=$1
  local plantLine

  shift

  for plantLine in "$@"; do
    printf '\n%s\n' "$plantLine" >>"$plantFile"
  done
}

# --------------------------------------------------------------------------------
# Cases on a clean copy and on copies that lack host scripts
# --------------------------------------------------------------------------------
case_missing_scripts() {
  echo "--- missing host scripts"

  make_scratch_repo || return 1
  run_scratch_guard "$WORK/clean.out" host-tests.sh
  expect "host rules: a clean copy of the tree passes" equals "$GUARD_RC" 0

  make_scratch_repo || return 1
  rm -rf "$WORK/repo/tests/host/manual"
  run_scratch_guard "$WORK/no-manual.out" host-tests.sh
  expect "host rules: no manual helper folder fails the portability rule" has_text "$WORK/no-manual.out" "FAIL: host_tests_are_portable"
  expect "host rules: no manual helper folder fails the delete rule" has_text "$WORK/no-manual.out" "FAIL: host_tests_never_delete"
  expect "host rules: the unreadable helper scripts are named" has_text "$WORK/no-manual.out" "cannot read: tests/host/manual/*.sh"

  make_scratch_repo || return 1
  rm -f "$WORK"/repo/tests/host/h[0-9][0-9]-*.sh "$WORK/repo/tests/host/coexistence.sh"
  run_scratch_guard "$WORK/no-checks.out" host-tests.sh
  expect "host rules: no host check at all fails" has_text "$WORK/no-checks.out" "FAIL: host_checks_declare_dependencies"
}

# --------------------------------------------------------------------------------
# Cases of the delete rule, one planted line each
# --------------------------------------------------------------------------------
case_delete_forms() {
  local deleteLine
  local deleteLineArray=(
    "docker compose down --rmi all"
    "docker compose rm -f"
    "docker network rm planted"
    "docker kill sbx-hosttest"
    "docker stop sbx-hosttest"
    "git clean -fdx"
    "mv planted-a planted-b"
    "truncate -s 0 planted-file"
  )

  echo "--- delete forms"

  make_scratch_repo || return 1
  plant_lines "$WORK/repo/tests/host/h04-nonroot-user.sh" "${deleteLineArray[@]}"
  run_scratch_guard "$WORK/delete.out" host-tests.sh

  for deleteLine in "${deleteLineArray[@]}"; do
    expect "host rules: the delete rule names $deleteLine" has_text "$WORK/delete.out" "$deleteLine"
  done
}

# --------------------------------------------------------------------------------
# Cases of the portability rule, one planted line each
# --------------------------------------------------------------------------------
case_gnu_only_forms() {
  local gnuLine
  local gnuLineArray=(
    "sed -r s/a/b/ planted"
    "sort -V planted"
    "xargs -r echo"
    "realpath planted"
    "date --date=@0"
    "mktemp --tmpdir planted.XXXXXX"
  )

  echo "--- GNU-only forms"

  make_scratch_repo || return 1
  plant_lines "$WORK/repo/tests/host/h04-nonroot-user.sh" "${gnuLineArray[@]}"
  run_scratch_guard "$WORK/gnu.out" host-tests.sh

  for gnuLine in "${gnuLineArray[@]}"; do
    expect "host rules: the portability rule names $gnuLine" has_text "$WORK/gnu.out" "$gnuLine"
  done
}

# --------------------------------------------------------------------------------
# Cases of the planning-ID rule: a code review finding ID in a host check
# --------------------------------------------------------------------------------
# The ID is built at run time, so this file never holds one itself.
case_finding_id() {
  local findingPrefix=WR
  local findingNumber=07
  local findingId=$findingPrefix-$findingNumber

  echo "--- finding ID"

  make_scratch_repo || return 1
  plant_lines "$WORK/repo/tests/host/h04-nonroot-user.sh" "# see $findingId for the reason"
  run_scratch_guard "$WORK/finding-id.out" planning-ids.sh
  expect "planning ids: a code review finding ID in a host check fails" equals "$GUARD_RC" 1
  expect "planning ids: the planted finding ID is named" has_text "$WORK/finding-id.out" "$findingId"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_missing_scripts
case_delete_forms
case_gnu_only_forms
case_finding_id
finish_cases
