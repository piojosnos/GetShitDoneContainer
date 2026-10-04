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
# FAKE_PS, FAKE_ID, FAKE_COMPOSE_VERSION, FAKE_COMPOSE_FAIL, FAKE_BASE_LAYERS,
# FAKE_CLAUDE_LAYERS, FAKE_CONFIG_NAME, FAKE_CONFIG_LAX, FAKE_CLAUDE_VERSION, FAKE_PLAIN_OK.
# State lives in FAKE_STATE; every call is logged to FAKE_LOG.
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
  version)
    printf 'Docker Desktop 4.99.0 (fake)\n'
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
      version)
        if [ "${FAKE_COMPOSE_FAIL:-0}" = 1 ]; then
          echo "docker: 'compose' is not a docker command." >&2
          exit 1
        fi
        printf '%s\n' "${FAKE_COMPOSE_VERSION:-2.39.1}"
        exit 0
        ;;
      config)
        if [ -z "${SBX_DIR:-}" ] && [ "${FAKE_CONFIG_LAX:-0}" != 1 ]; then
          echo "required variable SBX_DIR is missing a value: SBX_DIR is required (absolute host path of the sandbox folder)" >&2
          exit 15
        fi
        printf 'name: %s\nservices:\n  sandbox: {}\n' "${FAKE_CONFIG_NAME:-sbx-${SBX_NAME:-unset}}"
        exit 0
        ;;
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
  image)
    shift
    if [ "${1:-}" != "inspect" ]; then
      unhandled "image $*"
    fi
    shift
    if [ "${1:-}" = "--format" ]; then
      shift 2
    fi
    imageRef=${1:-}
    baseLayers=${FAKE_BASE_LAYERS:-sha256:b1 sha256:b2}
    case "$imageRef" in
      sbx-base:local) layerList=$baseLayers ;;
      sbx-claude:local) layerList=${FAKE_CLAUDE_LAYERS:-$baseLayers sha256:c1 sha256:c2} ;;
      *)
        echo "Error: No such image: $imageRef" >&2
        exit 1
        ;;
    esac
    for layer in $layerList; do
      printf '%s\n' "$layer"
    done
    exit 0
    ;;
  run)
    case "$*" in
      *"--entrypoint claude"*)
        fakePin=$(sed -n 's/^ARG CLAUDE_CODE_VERSION=//p' "$FAKE_REPO/claude/Dockerfile")
        printf '%s (Claude Code)\n' "${FAKE_CLAUDE_VERSION:-$fakePin}"
        exit 0
        ;;
      *)
        if [ "${FAKE_PLAIN_OK:-0}" = 1 ]; then
          echo "started without a mount"
          exit 0
        fi
        echo "[sbx] ERROR: /home/sandbox/workspace is not a bind mount; its data would be lost on recreate." >&2
        echo "[sbx]        Start the sandbox with 'docker compose up' (see SANDBOX.md)." >&2
        exit 1
        ;;
    esac
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

# make_fixture_run: makes a run folder and a running fake test container that mounts it; sets FIXTURE.
make_fixture_run() {
  FIXTURE=$(lib_eval 'make_run_dir; printf "%s" "$RUN"')
  pre_create_container "$FIXTURE"
}

# run_standalone OUTFILE SCRIPT [VAR=VALUE...]: runs one check alone, with the decoys exported
# and SBXTEST_DIR pointing at FIXTURE (when set); sets CHECK_RC.
run_standalone() {
  local outFile=$1
  local script=$2

  shift 2
  CHECK_RC=0
  env SBX_NAME=demo SBX_DIR=/elsewhere COMPOSE_PROJECT_NAME=evil SBXTEST_DIR="${FIXTURE:-}" "$@" \
    bash "tests/host/$script" >"$outFile" 2>&1 </dev/null || CHECK_RC=$?
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
expect "runner: healthy run prints PASS: H-00" has_text "$WORK/out.healthy" "PASS: H-00"
expect "runner: healthy run prints PASS: H-02" has_text "$WORK/out.healthy" "PASS: H-02"
expect "runner: healthy run prints PASS: H-03" has_text "$WORK/out.healthy" "PASS: H-03"
expect "runner: healthy run prints PASS: H-04" has_text "$WORK/out.healthy" "PASS: H-04"
expect "runner: healthy run prints PASS: H-12" has_text "$WORK/out.healthy" "PASS: H-12"
expect "runner: healthy run prints the summary" has_text "$WORK/out.healthy" "Summary: 5 passed, 0 failed, 0 not run"
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
expect "docker log: every compose call but the SBX_DIR probe carries the test name and the run folder" \
  equals "$(grep 'ARGS: compose' "$FAKE_LOG" | grep -v ' config' | grep -vc "SBX_NAME=hosttest SBX_DIR=$healthyRunDir ")" "0"
expect "docker log: the SBX_DIR probe runs without SBX_DIR and with the test name" \
  has_match "$FAKE_LOG" 'SBX_NAME=hosttest SBX_DIR=unset COMPOSE_PROJECT_NAME=unset ARGS: compose .* config'
expect "docker log: the plain docker run uses the real image tag" has_match "$WORK/args.healthy" '^run --rm sbx-claude:local claude --version'
expect "docker log: the builds use the real tags" \
  has_match "$WORK/args.healthy" '^build -t sbx-base:local .*/base$'
expect "docker log: the claude image is built after the base image" \
  has_match "$WORK/args.healthy" '^build -t sbx-claude:local .*/claude$'

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

echo "--- H-00 on its own"
reset_state
FIXTURE=""
run_standalone "$WORK/out.h00" h00-compose-v2.sh
expect "H-00: Compose 2.x passes" equals "$CHECK_RC" "0"
expect "H-00: prints PASS: H-00" has_text "$WORK/out.h00" "PASS: H-00"
expect "H-00: prints the Compose version" has_text "$WORK/out.h00" "INFO: Compose version 2.39.1"
expect "H-00: prints the Docker Desktop version" has_text "$WORK/out.h00" "Docker Desktop 4.99.0"
run_standalone "$WORK/out.h00.five" h00-compose-v2.sh FAKE_COMPOSE_VERSION=v5.0.2
expect "H-00: Compose 5.x with a leading v passes" equals "$CHECK_RC" "0"
run_standalone "$WORK/out.h00.one" h00-compose-v2.sh FAKE_COMPOSE_VERSION=1.29.2
expect "H-00: Compose 1.x fails" equals "$CHECK_RC" "1"
expect "H-00: Compose 1.x prints FAIL: H-00" has_text "$WORK/out.h00.one" "FAIL: H-00"
run_standalone "$WORK/out.h00.broken" h00-compose-v2.sh FAKE_COMPOSE_FAIL=1
expect "H-00: a failing docker compose version fails" equals "$CHECK_RC" "1"
expect "H-00: a failing docker compose version prints FAIL: H-00" has_text "$WORK/out.h00.broken" "FAIL: H-00"

echo "--- H-02 on its own"
run_standalone "$WORK/out.h02" h02-claude-on-base.sh
expect "H-02: base layers under the Claude layers pass" equals "$CHECK_RC" "0"
expect "H-02: prints PASS: H-02" has_text "$WORK/out.h02" "PASS: H-02"
run_standalone "$WORK/out.h02.bad" h02-claude-on-base.sh FAKE_CLAUDE_LAYERS="sha256:b1 sha256:x9 sha256:c1"
expect "H-02: a differing layer fails" equals "$CHECK_RC" "1"
expect "H-02: a differing layer prints FAIL: H-02" has_text "$WORK/out.h02.bad" "FAIL: H-02"
expect "H-02: a differing layer shows both layers" \
  has_text "$WORK/out.h02.bad" "sha256:b2"
expect "H-02: a differing layer shows the Claude side too" \
  has_text "$WORK/out.h02.bad" "sha256:x9"

echo "--- H-03 on its own"
reset_state
make_fixture_run
run_standalone "$WORK/out.h03" h03-variable-interpolation.sh
expect "H-03: both halves right pass" equals "$CHECK_RC" "0"
expect "H-03: prints PASS: H-03" has_text "$WORK/out.h03" "PASS: H-03"
FIXTURE=""
reset_state
run_standalone "$WORK/out.h03.norun" h03-variable-interpolation.sh
expect "H-03: passes without a running sandbox" equals "$CHECK_RC" "0"
run_standalone "$WORK/out.h03.name" h03-variable-interpolation.sh FAKE_CONFIG_NAME=sbx-other
expect "H-03: a wrong project name fails" equals "$CHECK_RC" "1"
expect "H-03: a wrong project name names that half" has_text "$WORK/out.h03.name" "name: sbx-hosttest"
run_standalone "$WORK/out.h03.lax" h03-variable-interpolation.sh FAKE_CONFIG_LAX=1
expect "H-03: a config that works without SBX_DIR fails" equals "$CHECK_RC" "1"
expect "H-03: a config that works without SBX_DIR names that half" has_text "$WORK/out.h03.lax" "SBX_DIR is required"

echo "--- H-04 on its own"
reset_state
FIXTURE=""
run_standalone "$WORK/out.h04.none" h04-nonroot-user.sh
expect "H-04: no test sandbox fails" equals "$CHECK_RC" "1"
expect "H-04: no test sandbox says to run run-all.sh" has_text "$WORK/out.h04.none" "run-all.sh"
make_fixture_run
run_standalone "$WORK/out.h04.ok" h04-nonroot-user.sh
expect "H-04: the test sandbox passes" equals "$CHECK_RC" "0"
run_standalone "$WORK/out.h04.foreign" h04-nonroot-user.sh FAKE_LABEL=other
expect "H-04: a container with another label is refused" equals "$CHECK_RC" "1"

echo "--- H-12 on its own"
reset_state
FIXTURE=""
run_standalone "$WORK/out.h12" h12-plain-run-refused-pin-installed.sh
expect "H-12: refused plain run and the pinned version pass" equals "$CHECK_RC" "0"
expect "H-12: prints PASS: H-12" has_text "$WORK/out.h12" "PASS: H-12"
run_standalone "$WORK/out.h12.pin" h12-plain-run-refused-pin-installed.sh FAKE_CLAUDE_VERSION=0.0.1
expect "H-12: a different installed version fails" equals "$CHECK_RC" "1"
expect "H-12: a different installed version prints FAIL: H-12" has_text "$WORK/out.h12.pin" "FAIL: H-12"
run_standalone "$WORK/out.h12.plain" h12-plain-run-refused-pin-installed.sh FAKE_PLAIN_OK=1
expect "H-12: a plain run that starts fails" equals "$CHECK_RC" "1"

echo "--- fatal H-00 in the runner"
reset_state
run_runner "$WORK/out.h00fatal" FAKE_COMPOSE_VERSION=1.29.2
expect "runner: Compose 1.x exits 1" equals "$RUNNER_RC" "1"
expect "runner: Compose 1.x prints FAIL: H-00" has_text "$WORK/out.h00fatal" "FAIL: H-00"
expect "runner: Compose 1.x builds nothing" lacks_text "$FAKE_LOG" "ARGS: build"
expect "runner: Compose 1.x still prints the Next block" has_text "$WORK/out.h00fatal" "manual/h07-login.sh"

echo "--- H-02 failure does not stop the runner"
reset_state
run_runner "$WORK/out.h02keep" FAKE_CLAUDE_LAYERS="sha256:x1 sha256:c1"
expect "runner: an H-02 failure exits 1" equals "$RUNNER_RC" "1"
expect "runner: an H-02 failure prints FAIL: H-02" has_text "$WORK/out.h02keep" "FAIL: H-02"
expect "runner: an H-02 failure still runs H-04" has_text "$WORK/out.h02keep" "PASS: H-04"
expect "runner: an H-02 failure still runs H-12" has_text "$WORK/out.h02keep" "PASS: H-12"
expect "runner: an H-02 failure is in the summary" has_text "$WORK/out.h02keep" "Failed: h02-claude-on-base.sh"

if [ "$FAILS" -eq 0 ]; then
  echo "All cases pass."
  exit 0
fi
echo "$FAILS case(s) failed."
exit 1
