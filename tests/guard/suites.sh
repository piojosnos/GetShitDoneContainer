#!/usr/bin/env bash
# Guard rules on the suite runners: every group program runs, and every host check has a self-test group.
# - Run by tests/guard/run-all.sh; runs alone too.
# - Usage, from anywhere: bash tests/guard/suites.sh   (exit 0 = every rule holds)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Constants: the folders that hold a run-all.sh and its group programs
# --------------------------------------------------------------------------------
SUITE_DIRS="tests/guard tests/selftest/bundle tests/selftest/entrypoint tests/selftest/host tests/selftest/guard"

# --------------------------------------------------------------------------------
# group_list_of RUNNER: prints the names on the groupList line of RUNNER; prints a message and returns 1 when there is none.
# --------------------------------------------------------------------------------
group_list_of() {
  local runner=$1
  local listLine

  listLine=$(grep -m 1 '^groupList="' "$runner")

  if [ -z "$listLine" ]; then
    echo "    $runner has no groupList line"

    return 1
  fi

  listLine=${listLine#groupList=\"}
  listLine=${listLine%\"*}
  printf '%s\n' "$listLine"
}

# --------------------------------------------------------------------------------
# suite_groups_are_listed: A group program that is not named in its runner's groupList never runs, so its failures are never seen.
# --------------------------------------------------------------------------------
# Every program in a suite folder (other than lib.sh and run-all.sh) must be in the list, and every listed name must be a file.
suite_groups_are_listed() {
  local suite
  local runner
  local listText
  local groupFile
  local groupName
  local groupCount
  local ok=0

  for suite in $SUITE_DIRS; do
    runner=$suite/run-all.sh

    if [ ! -r "$runner" ]; then
      echo "    $runner cannot be read"
      ok=1

      continue
    fi

    if ! listText=$(group_list_of "$runner"); then
      echo "$listText"
      ok=1

      continue
    fi

    groupCount=0

    for groupFile in "$suite"/*.sh; do
      groupName=$(basename "$groupFile")

      if [ "$groupName" = "lib.sh" ] || [ "$groupName" = "run-all.sh" ]; then
        continue
      fi

      groupCount=$((groupCount + 1))

      case " $listText " in
        *" $groupName "*) ;;
        *)
          echo "    $suite/$groupName is not named in $runner"
          ok=1
          ;;
      esac
    done

    for groupName in $listText; do
      if [ ! -f "$suite/$groupName" ]; then
        echo "    $runner names $groupName, which does not exist"
        ok=1
      fi
    done

    if [ "$groupCount" -eq 0 ]; then
      echo "    $suite has no group program"
      ok=1
    fi
  done

  return "$ok"
}

# --------------------------------------------------------------------------------
# host_checks_have_self_test_groups: Every host check is run on the Linux side by a self-test group of the same name.
# --------------------------------------------------------------------------------
# A host check without one has logic that no run in the dev sandbox ever exercises.
host_checks_have_self_test_groups() {
  local checkFile
  local checkName
  local checkCount=0
  local ok=0

  for checkFile in tests/host/h[0-9][0-9]-*.sh tests/host/coexistence.sh; do
    if [ ! -e "$checkFile" ]; then
      continue
    fi

    checkCount=$((checkCount + 1))
    checkName=$(basename "$checkFile")

    if [ ! -f "tests/selftest/host/$checkName" ]; then
      echo "    tests/host/$checkName has no self-test group in tests/selftest/host/"
      ok=1
    fi
  done

  if [ "$checkCount" -eq 0 ]; then
    echo "    no host check found under tests/host/"
    ok=1
  fi

  return "$ok"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  suite_groups_are_listed \
  host_checks_have_self_test_groups || exit 1
