#!/usr/bin/env bash
# Self-test of H-00 (tests/host/h00-compose-v2.sh) against the fake docker: Compose 2.x and 5.x pass; Compose 1.x and a failing compose version fail.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/h00-compose-v2.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Cases of H-00, each run alone against the fake docker
# --------------------------------------------------------------------------------
case_h00_alone() {
  echo "--- H-00 on its own"
  reset_state
  FIXTURE=""
  run_standalone "$WORK/out.h00" h00-compose-v2.sh
  expect "H-00: Compose 2.x passes" equals "$CHECK_RC" "0"
  expect "H-00: prints PASS: H-00" has_text "$WORK/out.h00" "PASS: H-00"
  expect "H-00: prints the Compose version" has_text "$WORK/out.h00" "INFO: Compose version 2.39.1"
  expect "H-00: prints the Docker Desktop version" has_text "$WORK/out.h00" "Docker Desktop 4.99.0"
  run_standalone "$WORK/out.h00.five" h00-compose-v2.sh FAKE_COMPOSE_VERSION=v5.0.2
  expect "H-00: Compose 5.x with a leading v passes" equals "$CHECK_RC" "0"
  run_standalone "$WORK/out.h00.one" h00-compose-v2.sh FAKE_COMPOSE_VERSION=1.29.2
  expect "H-00: Compose 1.x fails" equals "$CHECK_RC" "1"
  expect "H-00: Compose 1.x prints FAIL: H-00" has_text "$WORK/out.h00.one" "FAIL: H-00"
  run_standalone "$WORK/out.h00.broken" h00-compose-v2.sh FAKE_COMPOSE_FAIL=1
  expect "H-00: a failing docker compose version fails" equals "$CHECK_RC" "1"
  expect "H-00: a failing docker compose version prints FAIL: H-00" has_text "$WORK/out.h00.broken" "FAIL: H-00"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_h00_alone
finish_cases
