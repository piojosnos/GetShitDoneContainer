#!/usr/bin/env bash
# Shared by the host self-test groups: the fake docker on PATH, a work folder per group, and the helpers that run the host checks against the fake.
# - Sourced by the groups, never run directly.
# - Defines functions only.
# - run_runner and run_standalone export the decoys SBX_NAME=demo, SBX_DIR=/elsewhere and
#   COMPOSE_PROJECT_NAME=evil; the cases prove that no caller value reaches docker.
# - The host checks run from the repo root; tests/host/ stays exactly two levels deep,
#   because host_init finds the repo from there.
# - Linux only, in the dev sandbox.

. "$(dirname "${BASH_SOURCE[0]}")/../lib-expect.sh"

# --------------------------------------------------------------------------------
# start_group: enters the repository root, makes the work folder and puts the fake docker on PATH; returns 1 on failure.
# --------------------------------------------------------------------------------
start_group() {
  enter_repo_root || return 1
  make_work_folder selftest || return 1
  prepare_fake_docker || return 1
}

# --------------------------------------------------------------------------------
# prepare_fake_docker: copies the fake docker to WORK/bin/docker and exports the fake's variables, with WORK/bin first on PATH; returns 1 on failure.
# --------------------------------------------------------------------------------
# The fake is copied and made executable, never linked, so it works whatever mode git stores for it.
prepare_fake_docker() {
  mkdir -p "$WORK/bin" "$WORK/state" "$WORK/tmp" || return 1
  cp "$REPO/tests/selftest/host/support/fake-docker" "$WORK/bin/docker" || return 1
  chmod +x "$WORK/bin/docker" || return 1

  export FAKE_STATE="$WORK/state"
  export FAKE_LOG="$WORK/docker.log"
  export FAKE_REPO="$REPO"
  export PATH="$WORK/bin:$PATH"
  export TMPDIR="$WORK/tmp"
}

# --------------------------------------------------------------------------------
# has_match FILE REGEX: true if a line of FILE matches REGEX.
# --------------------------------------------------------------------------------
has_match() { grep -Eq -- "$2" "$1"; }

# --------------------------------------------------------------------------------
# lacks_match FILE REGEX: true if FILE is a readable file and no line of it matches REGEX.
# --------------------------------------------------------------------------------
# A missing or unreadable file is never a pass, so a negative check cannot succeed on input it never read.
lacks_match() { [ -f "$1" ] && [ -r "$1" ] && ! grep -Eq -- "$2" "$1"; }

# --------------------------------------------------------------------------------
# failed_with STATUS FILE TEXT: true if STATUS is 1 and FILE contains TEXT.
# --------------------------------------------------------------------------------
failed_with() {
  [ "$1" = 1 ] && has_text "$2" "$3"
}

# --------------------------------------------------------------------------------
# string_matches REGEX STRING: true if STRING matches REGEX.
# --------------------------------------------------------------------------------
string_matches() { printf '%s\n' "$2" | grep -Eq -- "$1"; }

# --------------------------------------------------------------------------------
# reset_state: empties the fake container state, the log and the run folders; stops when WORK is empty, so nothing outside the work folder is removed.
# --------------------------------------------------------------------------------
reset_state() {
  rm -rf "${WORK:?}/state" "${WORK:?}/tmp"
  mkdir -p "$WORK/state" "$WORK/tmp"
  : >"$FAKE_LOG"
}

# --------------------------------------------------------------------------------
# pre_create_container DIR: the fake docker starts with a sbx-hosttest container mounting DIR.
# --------------------------------------------------------------------------------
pre_create_container() {
  : >"$WORK/state/container"
  printf '%s\n' "$1" >"$WORK/state/container.dir"
}

# --------------------------------------------------------------------------------
# lib_eval SNIPPET: runs SNIPPET in a subshell after sourcing lib.sh and calling host_init.
# --------------------------------------------------------------------------------
lib_eval() {
  ( . tests/host/lib.sh; host_init; eval "$1" )
}

# --------------------------------------------------------------------------------
# run_runner OUTFILE [VAR=VALUE...]: runs run-all.sh with decoy sandbox variables exported.
# --------------------------------------------------------------------------------
run_runner() {
  local outFile=$1

  shift
  RUNNER_RC=0
  env SBX_NAME=demo SBX_DIR=/elsewhere COMPOSE_PROJECT_NAME=evil "$@" \
    bash tests/host/run-all.sh >"$outFile" 2>&1 </dev/null || RUNNER_RC=$?
}

# --------------------------------------------------------------------------------
# make_fixture_run: makes a run folder and a running fake test container that mounts it; sets FIXTURE.
# --------------------------------------------------------------------------------
make_fixture_run() {
  FIXTURE=$(lib_eval 'make_run_dir; printf "%s" "$RUN"')
  pre_create_container "$FIXTURE"
}

# --------------------------------------------------------------------------------
# run_standalone OUTFILE SCRIPT [VAR=VALUE...]: runs one check alone, with the decoys exported and SBXTEST_DIR pointing at FIXTURE (when set); sets CHECK_RC.
# --------------------------------------------------------------------------------
run_standalone() {
  local outFile=$1
  local script=$2

  shift 2
  CHECK_RC=0
  env SBX_NAME=demo SBX_DIR=/elsewhere COMPOSE_PROJECT_NAME=evil SBXTEST_DIR="${FIXTURE:-}" "$@" \
    bash "tests/host/$script" >"$outFile" 2>&1 </dev/null || CHECK_RC=$?
}

# --------------------------------------------------------------------------------
# fake_start_sync DIR: runs the real start hook into DIR/state/claude, as a container start would.
# --------------------------------------------------------------------------------
fake_start_sync() {
  mkdir -p "$1/state/claude"
  SBX_BUNDLE_DIR="$REPO/best-practices" CLAUDE_CONFIG_DIR="$1/state/claude" \
    bash "$REPO/claude/start.d/10-best-practices"
}
