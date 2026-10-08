#!/usr/bin/env bash
# Self-test of tests/host/run-all.sh on a healthy run against the fake docker: every check passes, the summary and the Next block, and the docker log shows nothing destructive and no real sandbox name.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/host/runner-healthy.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# last_run_dir: the run folder the latest runner made.
# --------------------------------------------------------------------------------
last_run_dir() {
  ls -d "$WORK"/tmp/sbx-hosttest-* 2>/dev/null | tail -n 1
}

# --------------------------------------------------------------------------------
# Healthy run of the runner against the fake docker
# --------------------------------------------------------------------------------
case_healthy_run() {
  echo "--- healthy run"
  reset_state
  run_runner "$WORK/out.healthy"
  healthyRunDir=$(last_run_dir)
  sed 's/^.*ARGS: //' "$FAKE_LOG" >"$WORK/args.healthy"

  expect "runner: healthy run exits 0" equals "$RUNNER_RC" "0"
  expect "runner: healthy run prints PASS: H-00" has_text "$WORK/out.healthy" "PASS: H-00"
  expect "runner: healthy run prints PASS: H-01" has_text "$WORK/out.healthy" "PASS: H-01"
  expect "runner: healthy run prints PASS: H-02" has_text "$WORK/out.healthy" "PASS: H-02"
  expect "runner: healthy run prints PASS: H-03" has_text "$WORK/out.healthy" "PASS: H-03"
  expect "runner: healthy run prints PASS: H-04" has_text "$WORK/out.healthy" "PASS: H-04"
  expect "runner: healthy run prints PASS: H-05" has_text "$WORK/out.healthy" "PASS: H-05"
  expect "runner: healthy run prints PASS: H-06" has_text "$WORK/out.healthy" "PASS: H-06"
  expect "runner: healthy run prints PASS: H-08" has_text "$WORK/out.healthy" "PASS: H-08"
  expect "runner: healthy run prints PASS: H-09" has_text "$WORK/out.healthy" "PASS: H-09"
  expect "runner: healthy run prints PASS: H-16" has_text "$WORK/out.healthy" "PASS: H-16"
  expect "runner: healthy run prints PASS: H-10" has_text "$WORK/out.healthy" "PASS: H-10"
  expect "runner: healthy run prints PASS: H-20" has_text "$WORK/out.healthy" "PASS: H-20"
  expect "runner: healthy run prints PASS: H-21" has_text "$WORK/out.healthy" "PASS: H-21"
  expect "runner: healthy run prints PASS: H-11" has_text "$WORK/out.healthy" "PASS: H-11"
  expect "runner: healthy run prints PASS: H-12" has_text "$WORK/out.healthy" "PASS: H-12"
  expect "runner: healthy run has 21 PASS lines" equals "$(grep -c '^PASS:' "$WORK/out.healthy")" "21"
  expect "runner: healthy run prints PASS: Coexistence" has_text "$WORK/out.healthy" "PASS: Coexistence"
  expect "runner: healthy run prints PASS: H-13" has_text "$WORK/out.healthy" "PASS: H-13"
  expect "runner: healthy run prints PASS: H-14" has_text "$WORK/out.healthy" "PASS: H-14"
  expect "runner: healthy run prints PASS: H-15" has_text "$WORK/out.healthy" "PASS: H-15"
  expect "runner: healthy run prints PASS: H-17" has_text "$WORK/out.healthy" "PASS: H-17"
  expect "runner: healthy run prints PASS: H-18" has_text "$WORK/out.healthy" "PASS: H-18"
  expect "runner: healthy run prints the summary" has_text "$WORK/out.healthy" "Summary: 21 passed, 0 failed, 0 not run"
  expect "runner: healthy run points at tests/host/manual/ for diagnosis" has_text "$WORK/out.healthy" "If something looks wrong, see tests/host/manual/"
  expect "runner: healthy run no longer lists the helpers as a pass to run" lacks_text "$WORK/out.healthy" "h19-bundle-behaviour.sh"
  expect "runner: the cleanup line has docker compose down and the run folder" \
    has_text "$WORK/out.healthy" "SBX_DIR=$healthyRunDir docker compose down && rm -rf $healthyRunDir"
  expect "runner: the run folder is still there afterwards" test -d "$healthyRunDir"
  expect "runner: the old container snapshot was written" has_text "$healthyRunDir/logs/old-containers.before" "cc_oldbox"
  expect "runner: the old folder snapshot was written" has_match "$healthyRunDir/logs/old-folders.before" '^[0-9a-f]{40}$'
  expect "docker log: nothing is removed or pruned" \
    lacks_match "$WORK/args.healthy" '^(rm|rmi|system|container rm|image rm|volume rm|network rm)( |$)|prune'
  expect "docker log: no down with a volume flag" lacks_match "$WORK/args.healthy" 'down.*(-v|--volumes)'
  expect "docker log: the caller's decoy values never reach docker" lacks_match "$FAKE_LOG" 'demo|evil|/elsewhere'
  expect "docker log: every exec and inspect names sbx-hosttest" \
    equals "$(grep -E '^(exec|container inspect) ' "$WORK/args.healthy" | grep -vc 'sbx-hosttest')" "0"
  expect "docker log: every compose up and down carries the test name and the run folder" \
    equals "$(grep -E 'ARGS: compose .* (up|down)( |$)' "$FAKE_LOG" | grep -vcE "SBX_NAME=hosttest SBX_DIR=$healthyRunDir(/does-not-exist|/h20)? ")" "0"
  expect "docker log: the sandbox was started" has_match "$FAKE_LOG" 'ARGS: compose .* up -d --wait'
  expect "docker log: every compose call names the test name" \
    equals "$(grep 'ARGS: compose' "$FAKE_LOG" | grep -v 'SBX_DIR=/sbx-hosttest-config-only ' | grep -vc 'SBX_NAME=hosttest ')" "0"
  expect "docker log: the two name probes only render the config" \
    equals "$(grep -c 'SBX_DIR=/sbx-hosttest-config-only ' "$FAKE_LOG") $(grep 'SBX_DIR=/sbx-hosttest-config-only ' "$FAKE_LOG" | grep -vc 'ARGS: compose .* config$')" "2 0"
  expect "docker log: the SBX_DIR probe runs without SBX_DIR and with the test name" \
    has_match "$FAKE_LOG" 'SBX_NAME=hosttest SBX_DIR=unset COMPOSE_PROJECT_NAME=unset ARGS: compose .* config'
  expect "docker log: the plain docker run uses the real image tag" has_match "$WORK/args.healthy" '^run --rm sbx-claude:local claude --version'
  expect "docker log: the builds use the real tags" \
    has_match "$WORK/args.healthy" '^build -f .*/base/Dockerfile -t sbx-base:local /'
  expect "docker log: the claude image is built after the base image" \
    has_match "$WORK/args.healthy" '^build -f .*/claude/Dockerfile -t sbx-claude:local /'
}

# --------------------------------------------------------------------------------
# A run with DOCKER_HOST set and a named Docker context
# --------------------------------------------------------------------------------
case_docker_target() {
  echo "--- docker target"
  reset_state
  run_runner "$WORK/out.target" DOCKER_HOST=tcp://docker.test:2375 FAKE_CONTEXT=desktop-test

  expect "runner: a run with DOCKER_HOST set still passes" equals "$RUNNER_RC" "0"
  expect "runner: the run names the Docker it talks to" \
    has_text "$WORK/out.target" "INFO: docker context: desktop-test, DOCKER_HOST: tcp://docker.test:2375"
  expect "runner: the docker log is not empty" test -s "$FAKE_LOG"
  expect "runner: DOCKER_HOST reaches every docker call unchanged" \
    equals "$(grep '^ENV ' "$FAKE_LOG" | grep -vc '^ENV DOCKER_HOST=tcp://docker.test:2375 ')" "0"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_healthy_run
case_docker_target
finish_cases
