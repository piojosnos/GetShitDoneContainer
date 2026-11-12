#!/usr/bin/env bash
# Usage: bash manual.sh TREE OUTFILE
# Runs the four manual helpers under a pty against the fake docker plus a fake interactive claude.
set -u
TREE=$(cd "$1" && pwd -P)
OUT=$2
WORK=$(mktemp -d "${TMPDIR:-/tmp}/sbx-manual.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/shimbin"
sed -n "/^cat >\"\$WORK\/bin\/docker\" <<'SHIM'\$/,/^SHIM\$/p" "$TREE/tests/host-selftest.sh" | sed '1d;$d' >"$WORK/shimbin/docker"
chmod +x "$WORK/shimbin/docker"
cat >"$WORK/bin/docker" <<'WRAP'
#!/usr/bin/env bash
case "$*" in
  "exec -it -w "*" claude")
    echo "[fake claude: interactive]"
    if [ "${FAKE_LOGIN:-1}" = 1 ]; then
      d=$(cat "$FAKE_STATE/container.dir")/state/claude
      mkdir -p "$d/projects"; : >"$d/.claude.json"; : >"$d/.credentials.json"
    fi
    exit 0 ;;
  "exec -it -w "*" claude --continue"|"exec -it -w "*" claude doctor")
    echo "[fake claude: $*]"; exit 0 ;;
  "exec sbx-hosttest claude auth status")
    if [ "${FAKE_AUTH:-1}" = 1 ]; then echo '{"loggedIn": true}'; else echo '{"loggedIn": false}'; fi
    exit 0 ;;
  "exec sbx-hosttest sh -c ls -a \"\$HOME\" | grep -c \"^\\.claude\\.json\$\"")
    echo "${FAKE_HOME_JSON:-0}"; exit 0 ;;
esac
exec "$WORK_SHIM/docker" "$@"
WRAP
sed -i.bak "s#\"\$WORK_SHIM/docker\"#\"$WORK/shimbin/docker\"#" "$WORK/bin/docker"; rm -f "$WORK/bin/docker.bak"
chmod +x "$WORK/bin/docker"
export FAKE_STATE="$WORK/state" FAKE_LOG="$WORK/docker.log" FAKE_REPO="$TREE" PATH="$WORK/bin:$PATH" TMPDIR="$WORK/tmp"
: >"$OUT"
normalise() {
  tr -d '\r' | sed -E -e "s#$TREE#TREE#g" -e "s#$WORK#WORK#g" -e 's#sbx-hosttest-[0-9]{8}-[0-9]{6}\.[A-Za-z0-9]{6}#sbx-hosttest-RUN#g'
}
fixture_up() {
  rm -rf "$WORK/state" "$WORK/tmp"; mkdir -p "$WORK/state" "$WORK/tmp"; : >"$FAKE_LOG"
  fixture=$(cd "$TREE" && bash -c '. tests/host/lib.sh; host_init; make_run_dir; printf "%s" "$RUN"')
  : >"$WORK/state/container"; printf '%s\n' "$fixture" >"$WORK/state/container.dir"
  mkdir -p "$fixture/state/claude"
  SBX_BUNDLE_DIR="$TREE/best-practices" CLAUDE_CONFIG_DIR="$fixture/state/claude" bash "$TREE/claude/start.d/10-best-practices"
}
run_helper() {
  local label=$1 answer=$2 helper=$3; shift 3
  fixture_up
  printf '\n##### %s\n' "$label" >>"$OUT"
  ( cd "$TREE" && printf '%s' "$answer" | env SBXTEST_DIR="$fixture" "$@" script -qec "bash tests/host/manual/$helper" /dev/null 2>&1; echo "rc=$?" ) | normalise >>"$OUT"
}
for variant in "login-ok:1:1:0" "no-login:0:0:0" "home-json:1:1:2"; do
  IFS=: read -r name login auth homejson <<<"$variant"
  run_helper "h07 $name" "" h07-login.sh FAKE_LOGIN=$login FAKE_AUTH=$auth FAKE_HOME_JSON=$homejson
done
run_helper "h09 yes" $'y\n' h09-rebuild-resume.sh
run_helper "h09 no" $'n\n' h09-rebuild-resume.sh
run_helper "h09 empty" $'\n' h09-rebuild-resume.sh
run_helper "h09 nocache arg" $'y\n' h09-rebuild-resume.sh --no-cache
run_helper "h09 no login" $'y\n' h09-rebuild-resume.sh FAKE_AUTH=0
run_helper "h09 buildfail" $'y\n' h09-rebuild-resume.sh FAKE_BUILD_FAIL=sbx-base:local
run_helper "h13 yes" $'y\n' h13-doctor.sh
run_helper "h13 no" $'n\n' h13-doctor.sh
run_helper "h19 all yes" $'y\ny\ny\ny\ny\n' h19-bundle-behaviour.sh
run_helper "h19 mixed" $'y\nn\ny\nx\ny\n' h19-bundle-behaviour.sh
# not a terminal
fixture_up
printf '\n##### not a terminal\n' >>"$OUT"
for helper in h07-login.sh h09-rebuild-resume.sh h13-doctor.sh h19-bundle-behaviour.sh; do
  ( cd "$TREE" && env SBXTEST_DIR="$fixture" bash "tests/host/manual/$helper" </dev/null 2>&1; echo "rc=$?" ) | normalise >>"$OUT"
done
echo "wrote $OUT: $(wc -l <"$OUT") lines"
