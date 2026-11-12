#!/usr/bin/env bash
# Usage: bash transcript.sh TREE OUTFILE
# Runs run-all.sh and every check of the repo checkout TREE against the fake docker taken from
# TREE/tests/host-selftest.sh, once per failure knob; writes one normalised transcript to OUTFILE.
set -u
TREE=$(cd "$1" && pwd -P)
OUT=$2
WORK=$(mktemp -d "${TMPDIR:-/tmp}/sbx-transcript.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
sed -n "/^cat >\"\$WORK\/bin\/docker\" <<'SHIM'\$/,/^SHIM\$/p" "$TREE/tests/host-selftest.sh" | sed '1d;$d' >"$WORK/bin/docker"
chmod +x "$WORK/bin/docker"
export FAKE_STATE="$WORK/state" FAKE_LOG="$WORK/docker.log" FAKE_REPO="$TREE" PATH="$WORK/bin:$PATH" TMPDIR="$WORK/tmp"
: >"$OUT"

reset() { rm -rf "$WORK/state" "$WORK/tmp"; mkdir -p "$WORK/state" "$WORK/tmp"; : >"$FAKE_LOG"; }

normalise() {
  sed -E \
    -e "s#$TREE#TREE#g" \
    -e "s#$WORK#WORK#g" \
    -e 's#sbx-hosttest-[0-9]{8}-[0-9]{6}\.[A-Za-z0-9]{6}#sbx-hosttest-RUN#g' \
    -e 's#(marker|h09|h11|h16)-[0-9]+-[0-9]{10}#\1-PID-EPOCH#g' \
    -e 's#h14-bundle-[0-9]+-[0-9]{10}#h14-bundle-PID-EPOCH#g' \
    -e 's#took [0-9]+ s#took N s#g' \
    -e 's#(compose down took )[0-9]+( s, the container)#\1N\2#'
}

section() { printf '\n##### %s\n' "$1" >>"$OUT"; }

run_all() {
  local label=$1; shift
  reset
  section "run-all $label"
  ( cd "$TREE" && env SBX_NAME=demo SBX_DIR=/elsewhere COMPOSE_PROJECT_NAME=evil "$@" bash tests/host/run-all.sh </dev/null 2>&1; echo "rc=$?" ) | normalise >>"$OUT"
}

run_all healthy
run_all badid FAKE_ID="uid=0(root) gid=0(root)"
run_all nosync FAKE_NO_SYNC=1
run_all buildfail FAKE_BUILD_FAIL=sbx-claude:local
run_all upfail FAKE_UP_RC=1
run_all compose1 FAKE_COMPOSE_VERSION=1.29.2
run_all composebroken FAKE_COMPOSE_FAIL=1
run_all composev FAKE_COMPOSE_VERSION=garbage
run_all infofail FAKE_INFO_FAIL=1
run_all layers FAKE_CLAUDE_LAYERS="sha256:x1 sha256:c1"
run_all layers2 FAKE_BASE_LAYERS=" "
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
run_all scopeeager FAKE_SCOPE_EAGER=1
run_all toolsoff FAKE_H18_TOOLS_OFF=1
run_all cfgname FAKE_CONFIG_NAME=sbx-other
run_all cfglax FAKE_CONFIG_LAX=1
run_all plainok FAKE_PLAIN_OK=1
run_all pin FAKE_CLAUDE_VERSION=0.0.1
run_all ps FAKE_PS="deadbeef0001 cc_oldbox exited"
run_all label FAKE_LABEL=other

# Leftover foreign container
reset
section "run-all leftover foreign container"
: >"$WORK/state/container"; printf '%s\n' /old/sbx-hosttest-leftover >"$WORK/state/container.dir"
( cd "$TREE" && env FAKE_LABEL=other bash tests/host/run-all.sh </dev/null 2>&1; echo "rc=$?" ) | normalise >>"$OUT"

# Every check on its own, no sandbox and no run folder
for check in "$TREE"/tests/host/h[0-9][0-9]-*.sh "$TREE"/tests/host/coexistence.sh; do
  reset
  section "standalone no sandbox: $(basename "$check")"
  ( cd "$TREE" && env SBXTEST_DIR= bash "$check" </dev/null 2>&1; echo "rc=$?" ) | normalise >>"$OUT"
done

# Every check on its own against a fixture run folder with a running fake container
for check in "$TREE"/tests/host/h[0-9][0-9]-*.sh "$TREE"/tests/host/coexistence.sh; do
  reset
  fixture=$(cd "$TREE" && bash -c '. tests/host/lib.sh; host_init; make_run_dir; printf "%s" "$RUN"')
  : >"$WORK/state/container"; printf '%s\n' "$fixture" >"$WORK/state/container.dir"
  mkdir -p "$fixture/state/claude"
  SBX_BUNDLE_DIR="$TREE/best-practices" CLAUDE_CONFIG_DIR="$fixture/state/claude" bash "$TREE/claude/start.d/10-best-practices"
  section "standalone with sandbox: $(basename "$check")"
  ( cd "$TREE" && env SBXTEST_DIR="$fixture" bash "$check" </dev/null 2>&1; echo "rc=$?" ) | normalise >>"$OUT"
done
# Coexistence with a changed baseline
reset
fixture=$(cd "$TREE" && bash -c '. tests/host/lib.sh; host_init; make_run_dir; printf "%s" "$RUN"')
: >"$WORK/state/container"; printf '%s\n' "$fixture" >"$WORK/state/container.dir"
printf 'deadbeef0001 cc_oldbox running\n' >"$fixture/logs/old-containers.before"
section "coexistence changed baseline"
( cd "$TREE" && env SBXTEST_DIR="$fixture" FAKE_PS="deadbeef0001 cc_oldbox exited" bash tests/host/coexistence.sh </dev/null 2>&1; echo "rc=$?" ) | normalise >>"$OUT"
echo "wrote $OUT: $(wc -l <"$OUT") lines"
