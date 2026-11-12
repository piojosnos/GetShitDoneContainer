#!/usr/bin/env bash
# Usage, from the repo root: bash prove.sh   (exit 0 = every output equals the baseline)
# Scratch proof tool for the layout phase. Compares five outputs of the current tree with the
# same five outputs of the baseline commit:
#   guard, host-selftest, bundle-selftest   the three required test scripts
#   transcript                              run-all and every check, once per failure knob (transcript.sh)
#   manual                                  the four manual helpers under a pty (manual.sh)
# PROVE_BASE (optional) overrides the baseline commit.
# The baseline outputs are cached in ${TMPDIR:-/tmp}/sbx-prove-<commit>, so only the first run pays for them.
set -u
harnessDir=$(cd "$(dirname "$0")" && pwd -P)
repoRoot=$(git rev-parse --show-toplevel) || exit 1
cd "$repoRoot" || exit 1

baseCommit=${PROVE_BASE:-0a58e7d855299f1dd2a8e9d69b132c4531a7f169}
cacheDir=${TMPDIR:-/tmp}/sbx-prove-$baseCommit
nameList="guard host-selftest bundle-selftest transcript manual"

# collect_outputs TREE PREFIX_DIR LABEL: writes the five outputs of TREE as PREFIX_DIR/LABEL.NAME.
collect_outputs() {
  local tree=$1
  local outDir=$2
  local label=$3
  local testName

  for testName in guard host-selftest bundle-selftest; do
    (cd "$tree" && bash "tests/$testName.sh") >"$outDir/$label.$testName" 2>&1
  done

  bash "$harnessDir/transcript.sh" "$tree" "$outDir/$label.transcript" >/dev/null
  bash "$harnessDir/manual.sh" "$tree" "$outDir/$label.manual" >/dev/null
}

# Baseline side: built once per commit, then reused.
if [ ! -f "$cacheDir/before.done" ]; then
  echo "prove: building the baseline for $baseCommit (first run only)"
  rm -rf "$cacheDir"
  git worktree prune
  mkdir -p "$cacheDir" || exit 1
  git worktree add --detach "$cacheDir/tree" "$baseCommit" >/dev/null 2>&1 || {
    echo "prove: cannot check out $baseCommit"
    exit 1
  }
  collect_outputs "$cacheDir/tree" "$cacheDir" before
  git worktree remove --force "$cacheDir/tree"
  : >"$cacheDir/before.done"
fi

# Current side
afterDir=$(mktemp -d "${TMPDIR:-/tmp}/sbx-prove-after.XXXXXX") || exit 1
collect_outputs "$repoRoot" "$afterDir" after

differCount=0

for testName in $nameList; do
  if diff -u "$cacheDir/before.$testName" "$afterDir/after.$testName" >"$afterDir/$testName.diff"; then
    echo "same: $testName"
  else
    echo "DIFFERENT: $testName"
    head -n 60 "$afterDir/$testName.diff"
    echo "full diff: $afterDir/$testName.diff"
    differCount=$((differCount + 1))
  fi
done

if [ "$differCount" -eq 0 ]; then
  rm -rf "$afterDir"
  echo "prove: identical"
  exit 0
fi

echo "prove: $differCount output(s) differ"
exit 1
