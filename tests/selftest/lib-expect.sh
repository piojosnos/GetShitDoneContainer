#!/usr/bin/env bash
# Shared by the self-test suites in tests/selftest/: case assertions, the case count, the work folder, and running a suite's group programs.
# - Sourced by each suite's lib.sh and run-all.sh, never run directly; defines functions and one counter only.
# - Loads tests/host/lib.sh so every self-test reads its arguments the way the host tests do
#   (require_no_arguments) and shares their readers (claude_pin).
# - Linux only, in the dev sandbox.

. "$(dirname "${BASH_SOURCE[0]}")/../host/lib.sh"

FAILS=0

# --------------------------------------------------------------------------------
# expect NAME COMMAND...: PASS when the command succeeds.
# --------------------------------------------------------------------------------
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

# --------------------------------------------------------------------------------
# equals A B: true if the two strings are equal.
# --------------------------------------------------------------------------------
equals() { [ "$1" = "$2" ]; }

# --------------------------------------------------------------------------------
# has_text FILE TEXT: true if FILE contains TEXT.
# --------------------------------------------------------------------------------
has_text() { grep -Fq -- "$2" "$1"; }

# --------------------------------------------------------------------------------
# lacks_text FILE TEXT: true if FILE is a readable file that does not contain TEXT.
# --------------------------------------------------------------------------------
# A missing or unreadable file is never a pass, so a negative check cannot succeed on input it never read.
lacks_text() { [ -f "$1" ] && [ -r "$1" ] && ! grep -Fq -- "$2" "$1"; }

# --------------------------------------------------------------------------------
# fails COMMAND...: true if COMMAND ran and exited non-zero; its stderr is discarded.
# --------------------------------------------------------------------------------
# A command that could not run (status 126 or 127) is not the failure a case asked for.
fails() {
  local commandStatus

  "$@" 2>/dev/null
  commandStatus=$?

  [ "$commandStatus" -ne 0 ] && [ "$commandStatus" -ne 126 ] && [ "$commandStatus" -ne 127 ]
}

# --------------------------------------------------------------------------------
# finish_cases: ends a group program; exits 0 when every case passed, else 1, and prints nothing.
# --------------------------------------------------------------------------------
finish_cases() {
  if [ "$FAILS" -eq 0 ]; then
    exit 0
  fi

  exit 1
}

# --------------------------------------------------------------------------------
# report_and_exit: prints the summary and exits 0 only when every case passed.
# --------------------------------------------------------------------------------
report_and_exit() {
  if [ "$FAILS" -eq 0 ]; then
    echo "All cases pass."
    exit 0
  fi

  echo "$FAILS case(s) failed."
  exit 1
}

# --------------------------------------------------------------------------------
# run_groups SUITE_DIR GROUP...: runs each group program of a suite, prints its output and adds its FAIL lines to FAILS.
# --------------------------------------------------------------------------------
# A group that stops with a non-zero status and no FAIL line counts as one failure, so a crash is never silent.
run_groups() {
  local suiteDir=$1
  local group
  local groupOutput
  local groupStatus
  local groupFailCount

  shift

  for group in "$@"; do
    groupOutput=$(bash "$suiteDir/$group" </dev/null 2>&1)
    groupStatus=$?

    if [ -n "$groupOutput" ]; then
      printf '%s\n' "$groupOutput"
    fi

    groupFailCount=$(printf '%s\n' "$groupOutput" | grep -c '^FAIL:')
    FAILS=$((FAILS + groupFailCount))

    if [ "$groupStatus" -ne 0 ] && [ "$groupFailCount" -eq 0 ]; then
      echo "FAIL: $group stopped with exit status $groupStatus before reporting a case"
      FAILS=$((FAILS + 1))
    fi
  done
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
# make_work_folder PREFIX: makes sbx-PREFIX.XXXXXX under TMPDIR as WORK and removes it, and only it, at exit; returns 1 on failure.
# --------------------------------------------------------------------------------
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

# --------------------------------------------------------------------------------
# cleanup_work: removes the work folder made by make_work_folder, and only when its name carries the same prefix.
# --------------------------------------------------------------------------------
cleanup_work() {
  if [ -z "${workPrefix:-}" ]; then
    return 0
  fi

  case "${WORK:-}" in
    */sbx-"$workPrefix".*) rm -rf "$WORK" ;;
  esac
}
