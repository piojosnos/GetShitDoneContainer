#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Mac test run: every Docker check in one go, all output kept in host-test.log
# ------------------------------------------------------------------------------
# Usage: ./host-test.sh [--keep]   (exit 0 = every step passed; sh works too)
# --keep leaves the test sandbox up for the helpers in tests/host/manual/.
# ------------------------------------------------------------------------------
set -u

LOG_NAME=host-test.log
resultList=""
failedCount=0
keepSandbox=false
RUN=""

# ------------------------------------------------------------------------------
# record NAME STATUS: adds one OK, FAIL or SKIP line to the closing summary
# ------------------------------------------------------------------------------
record() {
  resultList="$resultList$2: $1
"

  if [ "$2" = FAIL ]; then
    failedCount=$((failedCount + 1))
  fi
}

# ------------------------------------------------------------------------------
# run_step NAME FUNCTION: runs FUNCTION under a heading, records its result
# ------------------------------------------------------------------------------
run_step() {
  printf '\n== %s\n' "$1"

  if "$2"; then
    record "$1" OK
  else
    record "$1" FAIL
  fi
}

# ------------------------------------------------------------------------------
# show_context: the commit under test and the Docker versions
# ------------------------------------------------------------------------------
show_context() {
  date
  printf 'branch %s, commit %s\n' "$(git rev-parse --abbrev-ref HEAD)" "$(git rev-parse --short HEAD)"
  git status --short
  docker --version && docker compose version
}

# ------------------------------------------------------------------------------
# host_checks: H-00 to H-27 and Coexistence; builds both images first
# ------------------------------------------------------------------------------
host_checks() {
  bash tests/host/run-all.sh
}

# ------------------------------------------------------------------------------
# find_run_dir: sets RUN to the host folder the test sandbox mounts
# ------------------------------------------------------------------------------
find_run_dir() {
  RUN=$(docker container inspect -f '{{range .Mounts}}{{.Source}}{{end}}' sbx-hosttest 2>/dev/null)
  printf 'run folder: %s\n' "${RUN:-none (the test sandbox is not running)}"
  [ -n "$RUN" ] && [ -d "$RUN" ]
}

# ------------------------------------------------------------------------------
# linter_versions: the linters sbx-base ships
# ------------------------------------------------------------------------------
linter_versions() {
  docker run --rm --entrypoint shellcheck sbx-base:local --version \
    && docker run --rm --entrypoint hadolint sbx-base:local --version
}

# ------------------------------------------------------------------------------
# pin_digests: every NAME=image@sha256 pin equals the registry's index digest
# ------------------------------------------------------------------------------
pin_digests() {
  local line pinName imageRef wantDigest gotDigest
  local status=0

  # A pin holds no space, so a plain word loop reads one pin per word.
  for line in $(grep -E '^[A-Z_]+=[^ ]+@sha256:[0-9a-f]{64}$' versions.env); do
    pinName=${line%%=*}
    imageRef=${line#*=}
    wantDigest=${imageRef##*@}
    gotDigest=$(docker buildx imagetools inspect "${imageRef%@*}" | sed -n 's/^Digest: *//p')

    if [ "$gotDigest" = "$wantDigest" ]; then
      printf 'PASS: %s %s\n' "$pinName" "$wantDigest"
    else
      printf 'FAIL: %s pins %s, the registry has %s\n' "$pinName" "$wantDigest" "${gotDigest:-nothing}"
      status=1
    fi
  done

  return "$status"
}

# ------------------------------------------------------------------------------
# sandbox_suites: the guard and both self-tests inside sbx-hosttest
# ------------------------------------------------------------------------------
# They run on a clone of the commit under test, so uncommitted edits are left
# out. Inside the sandbox both linters exist, so every guard rule must pass.
# ------------------------------------------------------------------------------
sandbox_suites() {
  local repoDir="$RUN/hosttest/repo"
  local suite
  local status=0

  rm -rf "$repoDir"
  git clone -q "$PWD" "$repoDir" && git -C "$repoDir" checkout -q "$(git rev-parse HEAD)" || return 1

  for suite in tests/guard/run-all.sh tests/selftest/guard/run-all.sh tests/selftest/entrypoint/run-all.sh; do
    printf -- '-- %s\n' "$suite"

    if ! docker exec -w /home/sandbox/workspace/hosttest/repo sbx-hosttest bash "$suite"; then
      status=1
    fi
  done

  return "$status"
}

# ------------------------------------------------------------------------------
# make_linter_standin DIR TOOL: writes DIR/TOOL, which runs TOOL from sbx-base
# ------------------------------------------------------------------------------
# The stand-in mounts the current folder read-only at the same path.
# ------------------------------------------------------------------------------
make_linter_standin() {
  printf '#!/bin/sh\nexec docker run --rm -v "$PWD:$PWD:ro" -w "$PWD" --entrypoint %s sbx-base:local "$@"\n' "$2" > "$1/$2"
  chmod +x "$1/$2"
}

# ------------------------------------------------------------------------------
# mac_guard: the guard in the Mac shell (stock bash 3.2 and BSD tools)
# ------------------------------------------------------------------------------
# The Mac has no shellcheck or hadolint. Two stand-ins on PATH run them from
# sbx-base:local, so every rule must pass here and any FAIL fails the step.
# ------------------------------------------------------------------------------
mac_guard() {
  local output standinDir status

  standinDir=$(mktemp -d "${TMPDIR:-/tmp}/sbx-linters.XXXXXX") || return 1
  make_linter_standin "$standinDir" shellcheck
  make_linter_standin "$standinDir" hadolint

  output=$(PATH="$standinDir:$PATH" bash tests/guard/run-all.sh 2>&1)
  status=$?
  rm -rf "$standinDir"

  printf '%s\n' "$output"

  return "$status"
}

# ------------------------------------------------------------------------------
# build_warnings: the build logs carry no Dockerfile warning
# ------------------------------------------------------------------------------
build_warnings() {
  if grep -r InvalidDefaultArgInFrom "$RUN/logs"; then
    return 1
  fi
  echo "no InvalidDefaultArgInFrom warning in $RUN/logs"
}

# ------------------------------------------------------------------------------
# remove_sandbox: stops the test sandbox and deletes its run folder
# ------------------------------------------------------------------------------
remove_sandbox() {
  SBX_NAME=hosttest SBX_DIR="$RUN" docker compose --env-file /dev/null -f compose.yml down </dev/null \
    && rm -rf "$RUN"
}

# ------------------------------------------------------------------------------
# main: every step in order, then the summary
# ------------------------------------------------------------------------------
main() {
  run_step "context" show_context
  run_step "host checks" host_checks
  run_step "run folder" find_run_dir

  if [ -n "$RUN" ] && [ -d "$RUN" ]; then
    run_step "linter versions" linter_versions
    run_step "pin digests" pin_digests
    run_step "guard and self-tests in sbx-hosttest" sandbox_suites
    run_step "guard in the Mac shell" mac_guard
    run_step "build warnings" build_warnings

    if [ "$keepSandbox" = true ]; then
      record "remove test sandbox (--keep: left at $RUN)" SKIP
    else
      run_step "remove test sandbox" remove_sandbox
    fi
  else
    record "steps that need the test sandbox" SKIP
  fi

  printf '\n== Summary\n%s' "$resultList"
  printf '%s step(s) failed. Log: %s\n' "$failedCount" "$PWD/$LOG_NAME"
  [ "$failedCount" -eq 0 ]
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
cd "$(dirname "$0")" || exit 1

if [ "${1:-}" = --keep ]; then
  keepSandbox=true
fi

main 2>&1 | tee "$LOG_NAME"
exit "${PIPESTATUS[0]}"
