#!/usr/bin/env bash
# Guard rules on planning IDs: internal references stay out of the test scripts, the sandbox code and its docs.
# - Run by tests/guard/run-all.sh; runs alone too.
# - Usage, from anywhere: bash tests/guard/planning-ids.sh   (exit 0 = every rule holds)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Constants: what counts as an internal planning reference
# --------------------------------------------------------------------------------
# Internal planning references: decision IDs, test-plan IDs, phase numbers, planning documents.
PLANNING_ID_REGEX='\bD-[0-9]{2}\b|\bHT-0[0-9]\b|Phase [0-9]|CONTEXT\.md|\.planning'

# --------------------------------------------------------------------------------
# host_tests_have_no_planning_ids: Internal planning IDs mean nothing to a reader of the scripts: keep them out.
# --------------------------------------------------------------------------------
host_tests_have_no_planning_ids() {
  nowhere_matches "$PLANNING_ID_REGEX" $HOST_FILES tests/host/support/* tests/selftest/*.sh tests/selftest/*/*.sh tests/selftest/*/support/*
}

# --------------------------------------------------------------------------------
# sandbox_code_has_no_planning_ids: The same holds for the sandbox code and docs: readers do not have the planning docs.
# --------------------------------------------------------------------------------
# best-practices/ is exempt: its rules quote such references as examples of what not to write, and
# the merged skill reads a GSD roadmap.
sandbox_code_has_no_planning_ids() {
  nowhere_matches "$PLANNING_ID_REGEX|\bBP-0[0-9]\b" $SANDBOX_FILES claude/start.d/* claude/managed-settings.json .dockerignore SANDBOX.md tests/host-checklist.md tests/selftest/bundle/*.sh
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  host_tests_have_no_planning_ids \
  sandbox_code_has_no_planning_ids || exit 1
