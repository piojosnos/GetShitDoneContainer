#!/usr/bin/env bash
# Usage, from the planning checkout root: bash .planning/phases/01.4-test-suite-refactor/harness/rules.sh   (exit 0 = "rules: proven")
# Scratch proof tool for the test suite refactor. Proves the guard split lost no rule and weakened no path list:
#   Part 1  every function and every constant line of tests/guard.sh at the baseline commit is defined exactly once
#           in tests/guard/*.sh (and tests/guard.sh while it exists), and its body is unchanged, except the three
#           rules whose file lists name the moved self-test paths.
#   Part 2  after a clean run, a violation is planted as a new last line in every location the three path-list
#           rules scan, and the guard must report "FAIL: RULE" for it.
# It tests the committed HEAD of the code branch, in a detached worktree inside one sbx-rules14 folder; nothing in
# the code tree itself is touched.
# Env:
#   CODE_TREE   the code worktree (default: the folder next to the planning checkout named GetShitDoneContainer-test-refactor)
#   PROVE_BASE  the baseline commit (default: origin/main when the phase was planned)
set -u
harnessDir=$(cd "$(dirname "$0")" && pwd -P) || exit 1
planRoot=$(cd "$harnessDir" && git rev-parse --show-toplevel) || exit 1

codeTree=${CODE_TREE:-$planRoot/../GetShitDoneContainer-test-refactor}
codeTree=$(cd "$codeTree" && pwd -P) || {
  echo "rules: no code tree at ${CODE_TREE:-$planRoot/../GetShitDoneContainer-test-refactor}"
  exit 1
}

baseCommit=${PROVE_BASE:-95c4bf534509c10bc9bf32702a37885defdb9fb3}
changedExpected="no_compromised_gsd_package host_tests_have_no_planning_ids sandbox_code_has_no_planning_ids"
problemCount=0
workDir=""

# The plants: RULE|TEXT|FILE, one per location a path-list rule scans.
plantList="host_tests_have_no_planning_ids|Phase 1|tests/selftest/lib-expect.sh
host_tests_have_no_planning_ids|Phase 1|tests/selftest/entrypoint/start-hooks.sh
host_tests_have_no_planning_ids|Phase 1|tests/selftest/bundle/lib.sh
host_tests_have_no_planning_ids|Phase 1|tests/selftest/host/h13-env-and-no-self-update.sh
host_tests_have_no_planning_ids|Phase 1|tests/selftest/host/support/fake-docker
host_tests_have_no_planning_ids|Phase 1|tests/host/support/fake-claude-api.js
host_tests_have_no_planning_ids|Phase 1|tests/host/h05-workspace-and-home.sh
sandbox_code_has_no_planning_ids|BP-01|tests/selftest/bundle/refresh.sh
sandbox_code_has_no_planning_ids|BP-01|tests/host-checklist.md
sandbox_code_has_no_planning_ids|BP-01|SANDBOX.md
no_compromised_gsd_package|get-shit-done-cc|tests/selftest/host/lib.sh
no_compromised_gsd_package|get-shit-done-cc|tests/selftest/bundle/fake-api.sh
no_compromised_gsd_package|get-shit-done-cc|tests/host-checklist.md
no_compromised_gsd_package|get-shit-done-cc|tests/host/run-all.sh"

# --------------------------------------------------------------------------------
# problem TEXT: prints a problem line and counts it.
# --------------------------------------------------------------------------------
problem() {
  echo "$1"
  problemCount=$((problemCount + 1))
}

# --------------------------------------------------------------------------------
# cleanup_work: removes the detached worktree and the work folder, and only a folder named like sbx-rules14.XXXXXX.
# --------------------------------------------------------------------------------
cleanup_work() {
  if [ -z "$workDir" ]; then
    return 0
  fi

  git -C "$codeTree" worktree remove --force "$workDir/tree" >/dev/null 2>&1
  git -C "$codeTree" worktree prune
  case "$workDir" in */sbx-rules14.*) rm -rf "$workDir" ;; esac
}

# --------------------------------------------------------------------------------
# body_of NAME FILE: prints a function definition: the definition line alone when it ends with }, else up to the first line that is exactly }.
# --------------------------------------------------------------------------------
body_of() {
  awk -v name="$1" '
    index($0, name "() ") == 1 {
      print
      if ($0 ~ /\}$/) { exit }
      inside = 1
      next
    }
    inside { print; if ($0 == "}") { exit } }' "$2"
}

# --------------------------------------------------------------------------------
# definition_count NAME: how many guard files of the worktree define the function NAME (a line starting NAME() ).
# --------------------------------------------------------------------------------
definition_count() {
  local file
  local total=0
  local count

  for file in $guardFiles; do
    count=$(grep -c "^$1() " "$file")
    total=$((total + count))
  done

  echo "$total"
}

# --------------------------------------------------------------------------------
# definition_file NAME: the guard file of the worktree that defines the function NAME.
# --------------------------------------------------------------------------------
definition_file() {
  grep -l "^$1() " $guardFiles | head -n 1
}

# --------------------------------------------------------------------------------
# line_count LINE: how many times the whole line LINE appears across the guard files of the worktree.
# --------------------------------------------------------------------------------
line_count() {
  local file
  local total=0
  local count

  for file in $guardFiles; do
    count=$(grep -Fxc -- "$1" "$file")
    total=$((total + count))
  done

  echo "$total"
}

# --------------------------------------------------------------------------------
# check_bodies: Part 1, every baseline function and constant line is defined once and moved unchanged.
# --------------------------------------------------------------------------------
check_bodies() {
  local name
  local constantLine
  local count
  local newFile
  local changedList=""

  echo "--- Part 1: bodies"
  git -C "$codeTree" show "$baseCommit:tests/guard.sh" >"$workDir/baseline-guard.sh" || {
    problem "PROBLEM: cannot read tests/guard.sh at $baseCommit"
    return 1
  }

  for name in $(grep -oE '^[a-z_]+\(\)' "$workDir/baseline-guard.sh" | tr -d '()'); do
    count=$(definition_count "$name")

    if [ "$count" -eq 0 ]; then
      problem "MISSING: $name"
      continue
    fi

    if [ "$count" -gt 1 ]; then
      problem "DUPLICATE: $name"
      continue
    fi

    newFile=$(definition_file "$name")
    body_of "$name" "$workDir/baseline-guard.sh" >"$workDir/body.before"
    body_of "$name" "$newFile" >"$workDir/body.after"

    if cmp -s "$workDir/body.before" "$workDir/body.after"; then
      echo "same: $name"
    else
      echo "CHANGED: $name"
      changedList="$changedList $name"
    fi
  done

  # FAILS is the old runner's failure counter; run_rules and run-all.sh keep their own.
  while IFS= read -r constantLine; do
    name=${constantLine%%=*}
    count=$(line_count "$constantLine")

    if [ "$count" -eq 0 ]; then
      problem "MISSING: $name"
    elif [ "$count" -gt 1 ]; then
      problem "DUPLICATE: $name"
    else
      echo "same: $name (constant line)"
    fi
  done <<EOF
$(grep -E '^[A-Z_]+=' "$workDir/baseline-guard.sh" | grep -v '^FAILS=')
EOF

  for name in $changedList; do
    case " $changedExpected " in
      *" $name "*) ;;
      *) problem "PROBLEM: $name changed and is not one of the three path-list rules" ;;
    esac
  done

  for name in $changedExpected; do
    case " $changedList " in
      *" $name "*) ;;
      *) problem "PROBLEM: $name did not change, so its file list still names the old paths" ;;
    esac
  done
}

# --------------------------------------------------------------------------------
# run_guard: runs the new guard runner, and the old guard while it still exists, in the worktree.
# --------------------------------------------------------------------------------
run_guard() {
  (
    cd "$workDir/tree" || exit 1
    bash tests/guard/run-all.sh 2>&1

    if [ -f tests/guard.sh ]; then
      bash tests/guard.sh 2>&1
    fi
  )
}

# --------------------------------------------------------------------------------
# check_plants: Part 2, a clean run, then one planted violation per scanned location.
# --------------------------------------------------------------------------------
check_plants() {
  local plantLine
  local rule
  local text
  local file
  local rest

  echo "--- Part 2: planted violations"
  run_guard >"$workDir/clean.out"

  if grep -q '^FAIL:' "$workDir/clean.out"; then
    problem "PROBLEM: the clean run prints a FAIL line"
    grep '^FAIL:' "$workDir/clean.out"
    return 1
  fi

  echo "clean: no FAIL line"

  while IFS= read -r plantLine; do
    rule=${plantLine%%|*}
    rest=${plantLine#*|}
    text=${rest%%|*}
    file=${rest#*|}

    if [ ! -f "$workDir/tree/$file" ]; then
      problem "PROBLEM: no such file to plant in: $file"
      continue
    fi

    printf '\n%s\n' "$text" >>"$workDir/tree/$file"
    run_guard >"$workDir/plant.out"
    git -C "$workDir/tree" checkout -- "$file"

    if grep -Fxq "FAIL: $rule" "$workDir/plant.out"; then
      echo "caught: $rule $file"
    else
      problem "MISSED: $rule $file"
    fi
  done <<EOF
$plantList
EOF

  if [ -n "$(git -C "$workDir/tree" status --porcelain)" ]; then
    problem "PROBLEM: the worktree is not clean after the plants"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
workDir=$(mktemp -d "${TMPDIR:-/tmp}/sbx-rules14.XXXXXX") || exit 1
trap cleanup_work EXIT
trap 'exit 130' INT TERM

git -C "$codeTree" worktree prune
codeHead=$(git -C "$codeTree" rev-parse HEAD) || exit 1
git -C "$codeTree" worktree add --detach "$workDir/tree" "$codeHead" >/dev/null 2>&1 || {
  echo "rules: cannot check out $codeHead"
  exit 1
}

guardFiles=$(cd "$workDir/tree" && ls tests/guard/*.sh tests/guard.sh 2>/dev/null | sed "s|^|$workDir/tree/|" | tr '\n' ' ')

check_bodies
check_plants

if [ "$problemCount" -eq 0 ]; then
  echo "rules: proven"
  exit 0
fi

echo "rules: $problemCount problem(s)"
exit 1
