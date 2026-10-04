#!/usr/bin/env bash
# Self-test for the host tests: runs them on Linux against a fake docker.
# - Proves the parsing, the PASS/FAIL lines, the run order, the exit codes and the printed
#   text of tests/host/lib.sh, tests/host/run-all.sh and every check.
# - Cannot prove Docker behavior. The real proof is: bash tests/host/run-all.sh on the Mac.
# - A fake docker is first on PATH. It answers from FAKE_* variables and logs every call;
#   the cases read that log to prove no real sandbox name and nothing destructive reaches Docker.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/host-selftest.sh   (exit 0 = every case passes)
set -u
cd "$(dirname "$0")/.." || exit 1
REPO=$(pwd -P)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/sbx-selftest.XXXXXX") || exit 1

# cleanup_work: removes the work folder made above, and only that.
cleanup_work() {
  case "$WORK" in
    */sbx-selftest.*) rm -rf "$WORK" ;;
  esac
}
trap cleanup_work EXIT
trap 'exit 130' INT TERM

mkdir -p "$WORK/bin" "$WORK/state" "$WORK/tmp"

# --- the fake docker ---

cat >"$WORK/bin/docker" <<'SHIM'
#!/usr/bin/env bash
# Fake docker. Knobs: FAKE_INFO_FAIL, FAKE_ARCH, FAKE_BUILD_FAIL, FAKE_UP_RC, FAKE_LABEL,
# FAKE_PS, FAKE_ID. State lives in FAKE_STATE; every call is logged to FAKE_LOG.
printf 'ENV SBX_NAME=%s SBX_DIR=%s COMPOSE_PROJECT_NAME=%s ARGS: %s\n' \
  "${SBX_NAME-unset}" "${SBX_DIR-unset}" "${COMPOSE_PROJECT_NAME-unset}" "$*" >>"$FAKE_LOG"

unhandled() {
  echo "fake docker: unhandled: $*" >&2
  exit 99
}

has_container() {
  [ -f "$FAKE_STATE/container" ]
}

case "${1:-}" in
  info)
    if [ "${FAKE_INFO_FAIL:-0}" = 1 ]; then
      echo "Cannot connect to the Docker daemon" >&2
      exit 1
    fi
    if [ "${2:-}" = "--format" ]; then
      printf '%s\n' "${FAKE_ARCH:-aarch64}"
    fi
    exit 0
    ;;
  compose)
    shift
    if [ "${1:-}" = "-f" ]; then
      shift 2
    fi
    composeSub=${1:-}
    shift
    case "$composeSub" in
      up)
        if [ -z "${SBX_DIR:-}" ]; then
          echo "required variable SBX_DIR is missing a value: SBX_DIR is required" >&2
          exit 15
        fi
        if [ "${FAKE_UP_RC:-0}" != 0 ]; then
          echo "fake compose: up failed" >&2
          exit "$FAKE_UP_RC"
        fi
        : >"$FAKE_STATE/container"
        printf '%s\n' "$SBX_DIR" >"$FAKE_STATE/container.dir"
        exit 0
        ;;
      down)
        rm -f "$FAKE_STATE/container" "$FAKE_STATE/container.dir"
        exit 0
        ;;
      *) unhandled "compose $composeSub $*" ;;
    esac
    ;;
  container)
    shift
    if [ "${1:-}" != "inspect" ]; then
      unhandled "container $*"
    fi
    shift
    template=""
    if [ "${1:-}" = "--format" ]; then
      template=$2
      shift 2
    fi
    containerName=${1:-}
    if [ "$containerName" != "sbx-hosttest" ] || ! has_container; then
      echo "Error: No such container: $containerName" >&2
      exit 1
    fi
    case "$template" in
      '') exit 0 ;;
      *sbx.name*) printf '%s\n' "${FAKE_LABEL:-hosttest}" ;;
      *Mounts*) cat "$FAKE_STATE/container.dir" ;;
      *State.Running*) printf 'true\n' ;;
      *) unhandled "container inspect $template" ;;
    esac
    exit 0
    ;;
  build)
    shift
    imageTag=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -t) imageTag=$2; shift 2 ;;
        *) shift ;;
      esac
    done
    if [ -n "$imageTag" ] && [ "$imageTag" = "${FAKE_BUILD_FAIL:-}" ]; then
      echo "ERROR: failed to solve: fake build failure for $imageTag" >&2
      exit 1
    fi
    echo "built $imageTag"
    exit 0
    ;;
  ps)
    printf '%s\n' "${FAKE_PS-deadbeef0001 cc_oldbox running}"
    exit 0
    ;;
  exec)
    shift
    while [ "$#" -gt 0 ] && [ "${1#-}" != "$1" ]; do
      shift
    done
    execName=${1:-}
    shift
    if [ "$execName" != "sbx-hosttest" ] || ! has_container; then
      echo "Error: No such container: $execName" >&2
      exit 1
    fi
    case "$*" in
      id) printf '%s\n' "${FAKE_ID:-uid=1000(sandbox) gid=1000(sandbox) groups=1000(sandbox)}" ;;
      *) unhandled "exec $execName $*" ;;
    esac
    exit 0
    ;;
  *) unhandled "$*" ;;
esac
SHIM
chmod +x "$WORK/bin/docker"

export FAKE_STATE="$WORK/state"
export FAKE_LOG="$WORK/docker.log"
export FAKE_REPO="$REPO"
export PATH="$WORK/bin:$PATH"
export TMPDIR="$WORK/tmp"

# --- helpers ---

FAILS=0

# expect NAME COMMAND...: PASS when the command succeeds.
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

# equals A B: true if the two strings are equal.
equals() { [ "$1" = "$2" ]; }

# has_text FILE TEXT: true if FILE contains TEXT.
has_text() { grep -Fq -- "$2" "$1"; }

# lacks_text FILE TEXT: true if FILE does not contain TEXT.
lacks_text() { ! grep -Fq -- "$2" "$1"; }

# has_match FILE REGEX: true if a line of FILE matches REGEX.
has_match() { grep -Eq -- "$2" "$1"; }

# lacks_match FILE REGEX: true if no line of FILE matches REGEX.
lacks_match() { ! grep -Eq -- "$2" "$1"; }

# string_matches REGEX STRING: true if STRING matches REGEX.
string_matches() { printf '%s\n' "$2" | grep -Eq -- "$1"; }

# reset_state: empty fake container state, log and run folders.
reset_state() {
  rm -rf "$WORK/state" "$WORK/tmp"
  mkdir -p "$WORK/state" "$WORK/tmp"
  : >"$FAKE_LOG"
}

# pre_create_container DIR: the fake docker starts with a sbx-hosttest container mounting DIR.
pre_create_container() {
  : >"$WORK/state/container"
  printf '%s\n' "$1" >"$WORK/state/container.dir"
}

# lib_eval SNIPPET: runs SNIPPET in a subshell after sourcing lib.sh and calling host_init.
lib_eval() {
  ( . tests/host/lib.sh; host_init; eval "$1" )
}

# run_runner OUTFILE [VAR=VALUE...]: runs run-all.sh with decoy sandbox variables exported.
run_runner() {
  local outFile=$1

  shift
  RUNNER_RC=0
  env SBX_NAME=demo SBX_DIR=/elsewhere COMPOSE_PROJECT_NAME=evil "$@" \
    bash tests/host/run-all.sh >"$outFile" 2>&1 </dev/null || RUNNER_RC=$?
}

# last_run_dir: the run folder the latest runner made.
last_run_dir() {
  ls -d "$WORK"/tmp/sbx-hosttest-* 2>/dev/null | tail -n 1
}

# --- cases ---

echo "--- lib units"
reset_state

pinFromLib=$(lib_eval 'claude_pin')
pinFromFile=$(grep '^ARG CLAUDE_CODE_VERSION=' claude/Dockerfile | cut -d= -f2)
expect "lib: claude_pin equals the ARG in claude/Dockerfile" equals "$pinFromLib" "$pinFromFile"
expect "lib: claude_pin is not empty" string_matches '^[0-9]+\.[0-9]+\.[0-9]+$' "$pinFromLib"

archAarch=$( export FAKE_ARCH=aarch64; lib_eval 'expected_arch' )
archIntel=$( export FAKE_ARCH=x86_64; lib_eval 'expected_arch' )
archOther=$( export FAKE_ARCH=riscv64; lib_eval 'expected_arch' )
expect "lib: expected_arch maps aarch64 to arm64" equals "$archAarch" "arm64"
expect "lib: expected_arch maps x86_64 to amd64" equals "$archIntel" "amd64"
expect "lib: expected_arch maps anything else to unknown" equals "$archOther" "unknown"

madeRunDir=$(lib_eval 'make_run_dir; printf "%s" "$RUN"')
madeBaseName=$(basename "$madeRunDir")
expect "lib: make_run_dir name has the timestamp and random tail" \
  string_matches '^sbx-hosttest-[0-9]{8}-[0-9]{6}\.[A-Za-z0-9]{6}$' "$madeBaseName"
expect "lib: make_run_dir creates hosttest, state and logs" \
  test -d "$madeRunDir/hosttest" -a -d "$madeRunDir/state" -a -d "$madeRunDir/logs"
expect "lib: make_run_dir keeps the 0700 mode" \
  test -n "$(find "$madeRunDir" -maxdepth 0 -perm 0700)"

scrubbed=$( export SBX_NAME=demo SBX_DIR=/elsewhere COMPOSE_PROJECT_NAME=evil
  lib_eval 'printf "SBX_NAME=%s SBX_DIR=%s COMPOSE_PROJECT_NAME=%s" "$SBX_NAME" "${SBX_DIR-unset}" "${COMPOSE_PROJECT_NAME-unset}"' )
expect "lib: host_init ignores the caller's SBX_NAME, SBX_DIR and COMPOSE_PROJECT_NAME" \
  equals "$scrubbed" "SBX_NAME=hosttest SBX_DIR=unset COMPOSE_PROJECT_NAME=unset"

echo "--- healthy run"
reset_state
run_runner "$WORK/out.healthy"
healthyRunDir=$(last_run_dir)
sed 's/^.*ARGS: //' "$FAKE_LOG" >"$WORK/args.healthy"

expect "runner: healthy run exits 0" equals "$RUNNER_RC" "0"
expect "runner: healthy run prints PASS: H-04" has_text "$WORK/out.healthy" "PASS: H-04"
expect "runner: healthy run prints the summary" has_text "$WORK/out.healthy" "Summary: 1 passed, 0 failed, 0 not run"
expect "runner: healthy run prints the manual pass commands" has_text "$WORK/out.healthy" "manual/h07-login.sh"
expect "runner: the cleanup line has docker compose down and the run folder" \
  has_text "$WORK/out.healthy" "SBX_DIR=$healthyRunDir docker compose down && rm -rf $healthyRunDir"
expect "runner: the run folder is still there afterwards" test -d "$healthyRunDir"
expect "runner: the old container snapshot was written" has_text "$healthyRunDir/logs/old-containers.before" "cc_oldbox"
expect "docker log: nothing is removed or pruned" \
  lacks_match "$WORK/args.healthy" '^(rm|rmi|system|container rm|image rm|volume rm|network rm)( |$)|prune'
expect "docker log: no down with a volume flag" lacks_match "$WORK/args.healthy" 'down.*(-v|--volumes)'
expect "docker log: the caller's decoy values never reach docker" lacks_match "$FAKE_LOG" 'demo|evil|/elsewhere'
expect "docker log: every exec and inspect names sbx-hosttest" \
  equals "$(grep -E '^(exec|container inspect) ' "$WORK/args.healthy" | grep -vc 'sbx-hosttest')" "0"
expect "docker log: every compose call carries the test name and the run folder" \
  equals "$(grep 'ARGS: compose' "$FAKE_LOG" | grep -vc "SBX_NAME=hosttest SBX_DIR=$healthyRunDir ")" "0"

echo "--- failing check"
reset_state
run_runner "$WORK/out.badid" FAKE_ID="uid=0(root) gid=0(root)"
expect "runner: a wrong id exits 1" equals "$RUNNER_RC" "1"
expect "runner: a wrong id prints FAIL: H-04" has_text "$WORK/out.badid" "FAIL: H-04"
expect "runner: a wrong id still prints the summary" has_text "$WORK/out.badid" "Summary: 0 passed, 1 failed, 0 not run"
expect "runner: a wrong id still prints the Next block" has_text "$WORK/out.badid" "manual/h13-doctor.sh"

echo "--- failed build"
reset_state
run_runner "$WORK/out.build" FAKE_BUILD_FAIL=sbx-claude:local
expect "runner: a failed build exits 1" equals "$RUNNER_RC" "1"
expect "runner: a failed build runs no check" lacks_match "$WORK/out.build" '^(PASS|FAIL): H-04'
expect "runner: a failed build prints the log path" has_text "$WORK/out.build" "logs/build-claude.log"
expect "runner: a failed build still prints the Next block" has_text "$WORK/out.build" "manual/h07-login.sh"

echo "--- leftover container that is not the test sandbox"
reset_state
pre_create_container "/old/sbx-hosttest-leftover"
run_runner "$WORK/out.leftover" FAKE_LABEL=other
expect "runner: a foreign sbx-hosttest container exits 1" equals "$RUNNER_RC" "1"
expect "runner: a foreign sbx-hosttest container is reported" has_text "$WORK/out.leftover" "FAIL: SETUP"
expect "runner: a foreign sbx-hosttest container is never taken down" lacks_match "$FAKE_LOG" 'ARGS: compose .*down'

echo "--- sandbox does not start"
reset_state
run_runner "$WORK/out.up" FAKE_UP_RC=1
expect "runner: a failed up exits 1" equals "$RUNNER_RC" "1"
expect "runner: a failed up prints FAIL: SETUP" has_text "$WORK/out.up" "FAIL: SETUP"
expect "runner: a failed up marks the sandbox checks not run" has_text "$WORK/out.up" "NOT RUN: h04-nonroot-user.sh"

if [ "$FAILS" -eq 0 ]; then
  echo "All cases pass."
  exit 0
fi
echo "$FAILS case(s) failed."
exit 1
