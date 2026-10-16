#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Shared by the self-test suites: case checks, the work folder, the group runner
# ------------------------------------------------------------------------------
# Usage: sourced by each suite's lib.sh and run-all.sh, never run directly.
# Loads tests/host/lib.sh for require_no_arguments and the pin readers.
# ------------------------------------------------------------------------------

. "$(dirname "${BASH_SOURCE[0]}")/../host/lib.sh"

FAILS=0

# ------------------------------------------------------------------------------
# expect NAME COMMAND...: prints PASS when the command succeeds, else FAIL
# ------------------------------------------------------------------------------
expect() {
  local name=$1

  shift

  if "$@"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    FAILS=$((FAILS + 1))
  fi
}

# ------------------------------------------------------------------------------
# equals A B: true if the two strings are equal
# ------------------------------------------------------------------------------
equals() { [ "$1" = "$2" ]; }

# ------------------------------------------------------------------------------
# has_text FILE TEXT: true if FILE contains TEXT
# ------------------------------------------------------------------------------
has_text() { grep -Fq -- "$2" "$1"; }

# ------------------------------------------------------------------------------
# lacks_text FILE TEXT: true if FILE is readable and does not contain TEXT
# ------------------------------------------------------------------------------
# A missing file is never a pass, so a negative check cannot win unread.
# ------------------------------------------------------------------------------
lacks_text() { [ -f "$1" ] && [ -r "$1" ] && ! grep -Fq -- "$2" "$1"; }

# ------------------------------------------------------------------------------
# finish_cases: ends a group program; exits 0 when every case passed, else 1
# ------------------------------------------------------------------------------
finish_cases() {
  if [ "$FAILS" -eq 0 ]; then
    exit 0
  fi

  exit 1
}

# ------------------------------------------------------------------------------
# report_and_exit: prints the summary and exits 0 only when every case passed
# ------------------------------------------------------------------------------
report_and_exit() {
  if [ "$FAILS" -eq 0 ]; then
    echo "All cases pass."
    exit 0
  fi

  echo "$FAILS case(s) failed."
  exit 1
}

# ------------------------------------------------------------------------------
# run_groups SUITE_DIR: runs every group program in SUITE_DIR, counts FAILS
# ------------------------------------------------------------------------------
# A group that crashes without a FAIL line counts as one failure.
# ------------------------------------------------------------------------------
run_groups() {
  local suiteDir=$1
  local group
  local groupName
  local groupOutput
  local groupStatus
  local groupFailCount

  for group in "$suiteDir"/*.sh; do
    groupName=${group##*/}

    case "$groupName" in
      lib.sh | run-all.sh)
        continue
        ;;
    esac

    groupOutput=$(bash "$group" </dev/null 2>&1)
    groupStatus=$?

    if [ -n "$groupOutput" ]; then
      printf '%s\n' "$groupOutput"
    fi

    groupFailCount=$(printf '%s\n' "$groupOutput" | grep -c '^FAIL:')
    FAILS=$((FAILS + groupFailCount))

    if [ "$groupStatus" -ne 0 ] && [ "$groupFailCount" -eq 0 ]; then
      echo "FAIL: $groupName stopped with exit status $groupStatus before reporting a case"
      FAILS=$((FAILS + 1))
    fi
  done
}

# ------------------------------------------------------------------------------
# enter_repo_root: changes to the repo root, sets REPO and REPO_DIR
# ------------------------------------------------------------------------------
enter_repo_root() {
  local libDir

  libDir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || return 1
  cd "$libDir/../.." || return 1

  REPO=$(pwd -P)
  REPO_DIR=$REPO
}

# ------------------------------------------------------------------------------
# make_work_folder PREFIX: makes sbx-PREFIX.XXXXXX under TMPDIR as WORK
# ------------------------------------------------------------------------------
# It removes that folder, and only it, at exit.
# ------------------------------------------------------------------------------
make_work_folder() {
  local physicalFolder

  if [ -z "${1:-}" ]; then
    return 1
  fi

  WORK=$(mktemp -d "${TMPDIR:-/tmp}/sbx-$1.XXXXXX") || return 1
  workPrefix=$1

  trap cleanup_work EXIT
  trap 'exit 130' INT TERM

  physicalFolder=$(cd "$WORK" && pwd -P) || return 1
  WORK=$physicalFolder
}

# ------------------------------------------------------------------------------
# cleanup_work: removes the work folder, only when its name carries the prefix
# ------------------------------------------------------------------------------
cleanup_work() {
  if [ -z "${workPrefix:-}" ]; then
    return 0
  fi

  case "${WORK:-}" in
    */sbx-"$workPrefix".*) rm -rf "$WORK" ;;
  esac
}
