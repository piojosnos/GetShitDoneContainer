#!/usr/bin/env bash
# Usage, from the planning checkout root: bash .planning/phases/01.4-test-suite-refactor/harness/fake-transcript.sh   (exit 0 = "fake-transcript: identical")
# Scratch proof tool for the test suite refactor. Proves that the fake docker in its own file answers exactly like the
# old heredoc fake, for every retained knob. It builds one transcript per fake, with the Phase 1.3 procedure, against the
# host tests of the code tree, and diffs the two:
#   old fake  the heredoc body of tests/host-selftest.sh on the baseline commit
#   new fake  tests/selftest/host/support/fake-docker in the code tree
# Transcript: tests/host/run-all.sh healthy and once per knob, a leftover foreign container, every check alone with no
# sandbox, every check alone against a fixture run folder, and the coexistence check with a changed baseline.
# The three knobs no case sets (the docker info failure, the image architecture override, the base layer list) are not run.
# Env:
#   CODE_TREE   the code worktree (default: the folder next to the planning checkout named GetShitDoneContainer-test-refactor)
#   PROVE_BASE  the baseline commit (default: origin/main when the phase was planned)
# On "identical" the scratch folder sbx-fake14.XXXXXX is removed; on "differ" it is kept and its path is printed.
set -u
harnessDir=$(cd "$(dirname "$0")" && pwd -P) || exit 1
planRoot=$(cd "$harnessDir" && git rev-parse --show-toplevel) || exit 1

codeTree=${CODE_TREE:-$planRoot/../GetShitDoneContainer-test-refactor}
codeTree=$(cd "$codeTree" && pwd -P) || {
  echo "fake-transcript: no code tree at ${CODE_TREE:-$planRoot/../GetShitDoneContainer-test-refactor}"
  exit 1
}

baseCommit=${PROVE_BASE:-95c4bf534509c10bc9bf32702a37885defdb9fb3}
newFake=$codeTree/tests/selftest/host/support/fake-docker

# --------------------------------------------------------------------------------
# build_transcript FAKE_FILE OUT_FOLDER: writes OUT_FOLDER/transcript for the fake docker in FAKE_FILE.
# --------------------------------------------------------------------------------
# Runs in its own subshell (the caller starts it in the background), so the exports below stay local.
# Every reset makes fresh state and tmp folders instead of removing the old ones; the whole scratch folder goes at the end.
build_transcript() {
  local fakeFile=$1
  local outFolder=$2
  local outFile=$outFolder/transcript
  local resetCount=0
  local check
  local fixture

  mkdir -p "$outFolder/bin" || return 1
  cp "$fakeFile" "$outFolder/bin/docker" || return 1
  chmod +x "$outFolder/bin/docker" || return 1

  export FAKE_LOG="$outFolder/docker.log"
  export FAKE_REPO="$codeTree"
  export PATH="$outFolder/bin:$PATH"
  : >"$outFile"

  # reset: fresh fake state and run folders, an empty docker log.
  reset() {
    resetCount=$((resetCount + 1))
    mkdir -p "$outFolder/state.$resetCount" "$outFolder/tmp.$resetCount"
    export FAKE_STATE="$outFolder/state.$resetCount"
    export TMPDIR="$outFolder/tmp.$resetCount"
    : >"$FAKE_LOG"
  }

  # normalise: hides the paths, the run folder names, the pids and the timings that differ between two runs.
  normalise() {
    sed -E \
      -e "s#$codeTree#TREE#g" \
      -e "s#$outFolder#WORK#g" \
      -e 's#WORK/(state|tmp)\.[0-9]+#WORK/\1#g' \
      -e 's#sbx-hosttest-[0-9]{8}-[0-9]{6}\.[A-Za-z0-9]{6}#sbx-hosttest-RUN#g' \
      -e 's#(marker|h09|h11|h16)-[0-9]+-[0-9]{10}#\1-PID-EPOCH#g' \
      -e 's#h14-bundle-[0-9]+-[0-9]{10}#h14-bundle-PID-EPOCH#g' \
      -e 's#took [0-9]+ s#took N s#g' \
      -e 's#(compose down took )[0-9]+( s, the container)#\1N\2#'
  }

  # section LABEL: starts a labelled part of the transcript.
  section() {
    printf '\n##### %s\n' "$1" >>"$outFile"
  }

  # run_all LABEL [VAR=VALUE...]: runs tests/host/run-all.sh with the decoy variables and the knobs.
  run_all() {
    local label=$1

    shift
    reset
    section "run-all $label"
    ( cd "$codeTree" && env SBX_NAME=demo SBX_DIR=/elsewhere COMPOSE_PROJECT_NAME=evil "$@" bash tests/host/run-all.sh </dev/null 2>&1; echo "rc=$?" ) | normalise >>"$outFile"
  }

  run_all healthy
  run_all badid FAKE_ID="uid=0(root) gid=0(root)"
  run_all nosync FAKE_NO_SYNC=1
  run_all buildfail FAKE_BUILD_FAIL=sbx-claude:local
  run_all upfail FAKE_UP_RC=1
  run_all compose1 FAKE_COMPOSE_VERSION=1.29.2
  run_all composebroken FAKE_COMPOSE_FAIL=1
  run_all composev FAKE_COMPOSE_VERSION=garbage
  run_all layers FAKE_CLAUDE_LAYERS="sha256:x1 sha256:c1"
  run_all h10ign FAKE_H10=ignored
  run_all h10start FAKE_H10=started
  run_all downkeeps FAKE_DOWN_KEEPS=1
  run_all deny FAKE_DENY_BROKEN=1
  run_all nocache SBXTEST_NO_CACHE=1
  run_all arch FAKE_CLAUDE_ARCH=amd64
  run_all uname FAKE_UNAME=x86_64
  run_all archunknown FAKE_ARCH=riscv64
  run_all notouch FAKE_NO_TOUCH=1
  run_all owner FAKE_STAT_OWNER=root
  run_all envmissing FAKE_ENV_MISSING=HISTFILE
  run_all update FAKE_UPDATE_ON=1
  run_all share FAKE_SHARE_EXISTS=1
  run_all dubious FAKE_GIT_DUBIOUS=1
  run_all safedir FAKE_SAFE_DIR=/x
  run_all nogit FAKE_NO_GIT_WRITE=1
  run_all nohist FAKE_NO_HISTORY=1
  run_all loseshist FAKE_DOWN_LOSES_HISTORY=1
  run_all extramount FAKE_EXTRA_MOUNT=1
  run_all vols FAKE_VOLUMES=a FAKE_VOLUMES_AFTER_BUILD="a b"
  run_all clobber FAKE_SYNC_CLOBBERS=1
  run_all drift FAKE_BUNDLE_DRIFT=1
  run_all bowner FAKE_BUNDLE_OWNER=sandbox
  run_all bwritable FAKE_BUNDLE_WRITABLE=1
  run_all bmount FAKE_BUNDLE_MOUNT=1
  run_all managedbad FAKE_MANAGED_BAD=1
  run_all ctxscoped FAKE_CONTEXT_SCOPED=1
  run_all ctxnoskills FAKE_CONTEXT_NO_SKILLS=1
  run_all offline FAKE_OFFLINE_FAIL=1
  run_all hookignored FAKE_HOOK_IGNORED=1
  run_all hookdirignored FAKE_HOOK_DIR_IGNORED=1
  run_all scopeeager FAKE_SCOPE_EAGER=1
  run_all toolsoff FAKE_H18_TOOLS_OFF=1
  run_all cfgname FAKE_CONFIG_NAME=sbx-other
  run_all cfglax FAKE_CONFIG_LAX=1
  run_all plainok FAKE_PLAIN_OK=1
  run_all pin FAKE_CLAUDE_VERSION=0.0.1
  run_all ps FAKE_PS="deadbeef0001 cc_oldbox exited"
  run_all label FAKE_LABEL=other

  # A leftover foreign container
  reset
  section "run-all leftover foreign container"
  : >"$FAKE_STATE/container"
  printf '%s\n' /old/sbx-hosttest-leftover >"$FAKE_STATE/container.dir"
  ( cd "$codeTree" && env FAKE_LABEL=other bash tests/host/run-all.sh </dev/null 2>&1; echo "rc=$?" ) | normalise >>"$outFile"

  # Every check on its own, no sandbox and no run folder
  for check in "$codeTree"/tests/host/h[0-9][0-9]-*.sh "$codeTree"/tests/host/coexistence.sh; do
    reset
    section "standalone no sandbox: $(basename "$check")"
    ( cd "$codeTree" && env SBXTEST_DIR= bash "$check" </dev/null 2>&1; echo "rc=$?" ) | normalise >>"$outFile"
  done

  # Every check on its own against a fixture run folder with a running fake container
  for check in "$codeTree"/tests/host/h[0-9][0-9]-*.sh "$codeTree"/tests/host/coexistence.sh; do
    reset
    fixture=$(cd "$codeTree" && bash -c '. tests/host/lib.sh; host_init; make_run_dir; printf "%s" "$RUN"')
    : >"$FAKE_STATE/container"
    printf '%s\n' "$fixture" >"$FAKE_STATE/container.dir"
    mkdir -p "$fixture/state/claude"
    SBX_BUNDLE_DIR="$codeTree/best-practices" CLAUDE_CONFIG_DIR="$fixture/state/claude" bash "$codeTree/claude/start.d/10-best-practices"
    section "standalone with sandbox: $(basename "$check")"
    ( cd "$codeTree" && env SBXTEST_DIR="$fixture" bash "$check" </dev/null 2>&1; echo "rc=$?" ) | normalise >>"$outFile"
  done

  # The coexistence check with a changed baseline
  reset
  fixture=$(cd "$codeTree" && bash -c '. tests/host/lib.sh; host_init; make_run_dir; printf "%s" "$RUN"')
  : >"$FAKE_STATE/container"
  printf '%s\n' "$fixture" >"$FAKE_STATE/container.dir"
  printf 'deadbeef0001 cc_oldbox running\n' >"$fixture/logs/old-containers.before"
  section "coexistence changed baseline"
  ( cd "$codeTree" && env SBXTEST_DIR="$fixture" FAKE_PS="deadbeef0001 cc_oldbox exited" bash tests/host/coexistence.sh </dev/null 2>&1; echo "rc=$?" ) | normalise >>"$outFile"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
if [ ! -f "$newFake" ]; then
  echo "fake-transcript: no new fake at $newFake"
  exit 1
fi

scratch=$(mktemp -d "${TMPDIR:-/tmp}/sbx-fake14.XXXXXX") || exit 1
mkdir -p "$scratch/old" "$scratch/new" || exit 1

# The old fake: the heredoc body of the baseline tests/host-selftest.sh, without the cat line and the closing marker.
git -C "$codeTree" show "$baseCommit:tests/host-selftest.sh" \
  | sed -n "/^cat >\"\$WORK\/bin\/docker\" <<'SHIM'\$/,/^SHIM\$/p" | sed '1d;$d' >"$scratch/old-fake"

if [ ! -s "$scratch/old-fake" ]; then
  echo "fake-transcript: could not extract the old fake from $baseCommit (scratch folder kept: $scratch)"
  exit 1
fi

echo "fake-transcript: building both transcripts (a few minutes)"
build_transcript "$scratch/old-fake" "$scratch/old" &
oldPid=$!
build_transcript "$newFake" "$scratch/new" &
newPid=$!
wait "$oldPid"
wait "$newPid"

if diff -u "$scratch/old/transcript" "$scratch/new/transcript" >"$scratch/transcript.diff"; then
  echo "transcript lines: $(wc -l <"$scratch/new/transcript")"
  case "$scratch" in */sbx-fake14.*) rm -rf "$scratch" ;; esac
  echo "fake-transcript: identical"
  exit 0
fi

head -n 60 "$scratch/transcript.diff"
echo "scratch folder kept: $scratch"
echo "fake-transcript: differ"
exit 1
