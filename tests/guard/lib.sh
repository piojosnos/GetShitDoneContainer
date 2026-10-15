#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Shared by the guard groups: file lists, the search helper, the rule runner
# ------------------------------------------------------------------------------
# Sourced by the groups and the runner, never run; reads files only.
# Stock bash 3.2 with BSD tools: the guard may run by hand on the Mac.
# ------------------------------------------------------------------------------

. "$(dirname "${BASH_SOURCE[0]}")/../host/lib.sh"

# ------------------------------------------------------------------------------
# Constants: the sandbox files, as every group reads them
# ------------------------------------------------------------------------------
# SHELL_FILES uses globs, not git ls-files: the self-test copy has no .git.
# ------------------------------------------------------------------------------
BASE=base/Dockerfile
CLAUDE=claude/Dockerfile
COMPOSE=compose.yml
ENTRY="base/sbx-entrypoint base/sbx-start-lib.sh"
DOCKERFILES="$BASE $CLAUDE"
SANDBOX_FILES="$BASE $CLAUDE $COMPOSE $ENTRY versions.env build.sh clean.sh"
SHELL_FILES="build.sh clean.sh base/sbx-entrypoint base/sbx-start-lib.sh claude/start.d/* tests/*/*.sh tests/*/*/*.sh tests/selftest/*/support/fake-gsd"

# ------------------------------------------------------------------------------
# nowhere_matches REGEX FILE...: true if no line matches; prints the hits
# ------------------------------------------------------------------------------
nowhere_matches() {
  local regex=$1
  local hits
  local grepStatus

  shift

  if [ "$#" -eq 0 ]; then
    echo "    no file to scan"
    return 1
  fi

  hits=$(grep -En -- "$regex" "$@")
  grepStatus=$?

  if [ "$grepStatus" -gt 1 ]; then
    echo "    grep could not read every file it was given"
    return 1
  fi

  if [ -z "$hits" ]; then
    return 0
  fi

  echo "$hits" | sed 's/^/    /'
  return 1
}

# ------------------------------------------------------------------------------
# report_lines PREFIX: prints each stdin line after PREFIX; 1 if there was one
# ------------------------------------------------------------------------------
report_lines() {
  local line
  local found=0

  while IFS= read -r line; do
    echo "    $1$line"
    found=1
  done

  return "$found"
}

# ------------------------------------------------------------------------------
# enter_repo_root: changes to the repo root and sets REPO and REPO_DIR
# ------------------------------------------------------------------------------
enter_repo_root() {
  local libDir

  libDir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || return 1
  cd "$libDir/../.." || return 1

  REPO=$(pwd -P)
  REPO_DIR=$REPO
}

# ------------------------------------------------------------------------------
# run_rules RULE...: calls each rule and prints PASS or FAIL; 1 if any failed
# ------------------------------------------------------------------------------
run_rules() {
  local rule
  local failCount=0

  for rule in "$@"; do
    if "$rule"; then
      echo "PASS: $rule"
    else
      echo "FAIL: $rule"
      failCount=$((failCount + 1))
    fi
  done

  if [ "$failCount" -gt 0 ]; then
    return 1
  fi

  return 0
}
