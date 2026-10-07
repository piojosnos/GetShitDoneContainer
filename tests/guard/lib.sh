#!/usr/bin/env bash
# Shared by the guard rule groups: the sandbox file lists, the search helpers, and how a group runs its rules.
# - Sourced by the groups and the runner, never run directly; defines functions and constants only.
# - Reads files only.
# - Stock bash 3.2 with BSD tools, because the guard may run by hand on the Mac.
# - Loads tests/host/lib.sh for require_no_arguments and print_usage.

. "$(dirname "${BASH_SOURCE[0]}")/../host/lib.sh"

# --------------------------------------------------------------------------------
# Constants: the sandbox files and the host test files, as every group reads them
# --------------------------------------------------------------------------------
BASE=base/Dockerfile
CLAUDE=claude/Dockerfile
COMPOSE=compose.yml
ENTRY="base/sbx-entrypoint base/sbx-start-lib.sh"
DOCKERFILES="$BASE $CLAUDE"
SANDBOX_FILES="$BASE $CLAUDE $COMPOSE $ENTRY"

# The Mac host tests: every script, and the ones that must run unattended.
HOST_FILES="tests/host/*.sh tests/host/manual/*.sh"
HOST_UNATTENDED_FILES="tests/host/*.sh"

# --------------------------------------------------------------------------------
# nowhere_matches REGEX FILE...: true if no line matches; prints the offending lines. Fails when a file cannot be read or none is given.
# --------------------------------------------------------------------------------
# grep keeps its stderr, so its own message names the file it could not read.
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

# --------------------------------------------------------------------------------
# has_line FILE LINE: true if FILE has a line exactly equal to LINE.
# --------------------------------------------------------------------------------
has_line() { grep -Fxq -- "$2" "$1"; }

# --------------------------------------------------------------------------------
# frontmatter_of FILE: the lines between the opening and closing "---", when line 1 is "---".
# --------------------------------------------------------------------------------
frontmatter_of() {
  awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1 { print }' "$1"
}

# --------------------------------------------------------------------------------
# enter_repo_root: changes to the repository root and sets REPO and REPO_DIR to its physical path; returns 1 on failure.
# --------------------------------------------------------------------------------
enter_repo_root() {
  local libDir

  libDir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || return 1
  cd "$libDir/../.." || return 1

  REPO=$(pwd -P)
  REPO_DIR=$REPO
}

# --------------------------------------------------------------------------------
# run_rules RULE...: calls each rule function and prints PASS or FAIL for it; returns 1 when any rule failed.
# --------------------------------------------------------------------------------
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
