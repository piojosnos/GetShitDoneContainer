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
# FAKE_CLAUDE_LAYERS, FAKE_CONFIG_NAME, FAKE_CONFIG_LAX, FAKE_CLAUDE_VERSION, FAKE_PLAIN_OK,
# FAKE_IMAGE_ARCH, FAKE_CLAUDE_ARCH, FAKE_UNAME, FAKE_NO_TOUCH, FAKE_STAT_OWNER, FAKE_ENV_MISSING,
# FAKE_UPDATE_ON, FAKE_SHARE_EXISTS, FAKE_GIT_DUBIOUS, FAKE_SAFE_DIR, FAKE_NO_GIT_WRITE,
# FAKE_NO_HISTORY, FAKE_DOWN_LOSES_HISTORY, FAKE_VOLUMES, FAKE_VOLUMES_AFTER_BUILD,
# FAKE_EXTRA_MOUNT, FAKE_DOWN_KEEPS, FAKE_H10 (honored, ignored or started).
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
        if [ ! -d "$SBX_DIR" ]; then
          case "${FAKE_H10:-honored}" in
            ignored)
              mkdir -p "$SBX_DIR"
              : >"$FAKE_STATE/container"
              printf '%s\n' "$SBX_DIR" >"$FAKE_STATE/container.dir"
              echo "[sbx] ERROR: the project folder is missing." >&2
              exit 1
              ;;
            started)
              : >"$FAKE_STATE/container"
              printf '%s\n' "$SBX_DIR" >"$FAKE_STATE/container.dir"
              exit 0
              ;;
            *)
              echo "fake compose: bind source path does not exist: $SBX_DIR" >&2
              exit 1
              ;;
          esac
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
        if [ "${FAKE_DOWN_LOSES_HISTORY:-0}" = 1 ] && [ -f "$FAKE_STATE/container.dir" ]; then
          rm -f "$(cat "$FAKE_STATE/container.dir")/state/shell/bash_history"
        fi
        if [ "${FAKE_DOWN_KEEPS:-0}" != 1 ]; then
          rm -f "$FAKE_STATE/container" "$FAKE_STATE/container.dir"
        fi
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
      *.Type*)
        printf 'bind /home/sandbox/workspace %s\n' "$(cat "$FAKE_STATE/container.dir")"
        if [ "${FAKE_EXTRA_MOUNT:-0}" = 1 ]; then
          printf 'volume /home/sandbox/extra /var/lib/docker/volumes/extra\n'
        fi
        ;;
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
    imageTemplate=""
    if [ "${1:-}" = "--format" ]; then
      imageTemplate=$2
      shift 2
    fi
    case "$imageTemplate" in
      *Architecture*)
        for imageRef in "$@"; do
          case "$imageRef" in
            sbx-claude:local) printf '%s\n' "${FAKE_CLAUDE_ARCH:-${FAKE_IMAGE_ARCH:-arm64}}" ;;
            sbx-base:local) printf '%s\n' "${FAKE_IMAGE_ARCH:-arm64}" ;;
            *)
              echo "Error: No such image: $imageRef" >&2
              exit 1
              ;;
          esac
        done
        exit 0
        ;;
    esac
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
    : >"$FAKE_STATE/built"
    echo "built $imageTag"
    exit 0
    ;;
  volume)
    if [ "${2:-}" != "ls" ]; then
      unhandled "volume $*"
    fi
    volumeList=${FAKE_VOLUMES:-}
    if [ -f "$FAKE_STATE/built" ] && [ -n "${FAKE_VOLUMES_AFTER_BUILD:-}" ]; then
      volumeList=$FAKE_VOLUMES_AFTER_BUILD
    fi
    for volumeName in $volumeList; do
      printf '%s\n' "$volumeName"
    done
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
      "uname -m") printf '%s\n' "${FAKE_UNAME:-aarch64}" ;;
      "sh -c touch"*)
        if [ "${FAKE_NO_TOUCH:-0}" != 1 ]; then
          mkdir -p "$(cat "$FAKE_STATE/container.dir")/hosttest"
          : >"$(cat "$FAKE_STATE/container.dir")/hosttest/x.txt"
        fi
        printf '.\n..\n.bashrc\n.local\nworkspace\n'
        ;;
      "stat -c"*)
        shift 3
        for statPath in "$@"; do
          printf '%s %s\n' "${FAKE_STAT_OWNER:-sandbox}" "$statPath"
        done
        ;;
      env)
        for envName in CLAUDE_CONFIG_DIR DISABLE_UPDATES HISTFILE GH_CONFIG_DIR GIT_CONFIG_GLOBAL; do
          if [ "$envName" != "${FAKE_ENV_MISSING:-}" ]; then
            printf '%s=/fake/%s\n' "$envName" "$envName"
          fi
        done
        printf 'HOME=/home/sandbox\n'
        ;;
      "claude update")
        if [ "${FAKE_UPDATE_ON:-0}" = 1 ]; then
          echo "Checking for updates... installed 9.9.9"
        else
          echo "Updates are disabled by your administrator"
        fi
        ;;
      "git status")
        if [ "${FAKE_GIT_DUBIOUS:-0}" = 1 ]; then
          echo "fatal: detected dubious ownership in repository at '/home/sandbox/workspace/hosttest'" >&2
          exit 128
        fi
        echo "On branch main"
        ;;
      "git config --system --get-all safe.directory") printf '%s\n' "${FAKE_SAFE_DIR:-*}" ;;
      "git config --global user.name T")
        if [ "${FAKE_NO_GIT_WRITE:-0}" != 1 ]; then
          mkdir -p "$(cat "$FAKE_STATE/container.dir")/state/git"
          printf '[user]\n\tname = T\n' >"$(cat "$FAKE_STATE/container.dir")/state/git/config"
        fi
        ;;
      "bash -i")
        historyPath="$(cat "$FAKE_STATE/container.dir")/state/shell/bash_history"
        while IFS= read -r shellLine; do
          case "$shellLine" in
            echo*)
              if [ "${FAKE_NO_HISTORY:-0}" != 1 ]; then
                mkdir -p "$(dirname "$historyPath")"
                printf '%s\n' "$shellLine" >>"$historyPath"
              fi
              ;;
            history)
              if [ -f "$historyPath" ]; then
                nl -ba "$historyPath"
              fi
              ;;
            exit) exit 0 ;;
          esac
        done
        ;;
      "sh -c test ! -e"*)
        if [ "${FAKE_SHARE_EXISTS:-0}" = 1 ]; then
          exit 1
        fi
        ;;
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
expect "runner: healthy run prints PASS: H-01" has_text "$WORK/out.healthy" "PASS: H-01"
expect "runner: healthy run prints PASS: H-02" has_text "$WORK/out.healthy" "PASS: H-02"
expect "runner: healthy run prints PASS: H-03" has_text "$WORK/out.healthy" "PASS: H-03"
expect "runner: healthy run prints PASS: H-04" has_text "$WORK/out.healthy" "PASS: H-04"
expect "runner: healthy run prints PASS: H-05" has_text "$WORK/out.healthy" "PASS: H-05"
expect "runner: healthy run prints PASS: H-06" has_text "$WORK/out.healthy" "PASS: H-06"
expect "runner: healthy run prints PASS: H-08" has_text "$WORK/out.healthy" "PASS: H-08"
expect "runner: healthy run prints PASS: H-09" has_text "$WORK/out.healthy" "PASS: H-09"
expect "runner: healthy run prints PASS: H-10" has_text "$WORK/out.healthy" "PASS: H-10"
expect "runner: healthy run prints PASS: H-11" has_text "$WORK/out.healthy" "PASS: H-11"
expect "runner: healthy run prints PASS: H-12" has_text "$WORK/out.healthy" "PASS: H-12"
expect "runner: healthy run has 14 PASS lines" equals "$(grep -c '^PASS:' "$WORK/out.healthy")" "14"
expect "runner: healthy run prints PASS: Coexistence" has_text "$WORK/out.healthy" "PASS: Coexistence"
expect "runner: healthy run prints PASS: H-13" has_text "$WORK/out.healthy" "PASS: H-13"
expect "runner: healthy run prints the summary" has_text "$WORK/out.healthy" "Summary: 14 passed, 0 failed, 0 not run"
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
expect "docker log: every compose up and down carries the test name and the run folder" \
  equals "$(grep -E 'ARGS: compose .* (up|down)( |$)' "$FAKE_LOG" | grep -vcE "SBX_NAME=hosttest SBX_DIR=$healthyRunDir(/does-not-exist)? ")" "0"
expect "docker log: the sandbox was started" has_match "$FAKE_LOG" 'ARGS: compose .* up -d --wait'
expect "docker log: every compose call names the test name" \
  equals "$(grep 'ARGS: compose' "$FAKE_LOG" | grep -vc 'SBX_NAME=hosttest ')" "0"
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
expect "runner: a wrong id still prints the summary" has_text "$WORK/out.badid" "Summary: 13 passed, 1 failed, 0 not run"
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

echo "--- H-01 on its own"
reset_state
make_fixture_run
run_standalone "$WORK/out.h01" h01-native-arch.sh
expect "H-01: matching image and container architectures pass" equals "$CHECK_RC" "0"
expect "H-01: prints PASS: H-01" has_text "$WORK/out.h01" "PASS: H-01"
run_standalone "$WORK/out.h01.amd" h01-native-arch.sh FAKE_CLAUDE_ARCH=amd64
expect "H-01: an amd64 image on an aarch64 daemon fails" equals "$CHECK_RC" "1"
expect "H-01: the wrong image is named" has_text "$WORK/out.h01.amd" "sbx-claude:local"
run_standalone "$WORK/out.h01.uname" h01-native-arch.sh FAKE_UNAME=x86_64
expect "H-01: a container uname that differs from the daemon fails" equals "$CHECK_RC" "1"
run_standalone "$WORK/out.h01.unknown" h01-native-arch.sh FAKE_ARCH=riscv64
expect "H-01: an unknown daemon architecture fails" equals "$CHECK_RC" "1"
printf 'WARNING: requested image platform does not match the detected host platform\n' >"$FIXTURE/logs/build-base.log"
run_standalone "$WORK/out.h01.warn" h01-native-arch.sh
expect "H-01: a platform mismatch warning in a build log fails" equals "$CHECK_RC" "1"
expect "H-01: the warning log is named" has_text "$WORK/out.h01.warn" "build-base.log"

echo "--- H-05 on its own"
reset_state
make_fixture_run
run_standalone "$WORK/out.h05" h05-workspace-and-home.sh
expect "H-05: x.txt on the host, .bashrc and .local listed, sandbox owners pass" equals "$CHECK_RC" "0"
expect "H-05: prints PASS: H-05" has_text "$WORK/out.h05" "PASS: H-05"
expect "H-05: x.txt exists in the run folder" test -f "$FIXTURE/hosttest/x.txt"
reset_state
make_fixture_run
run_standalone "$WORK/out.h05.notouch" h05-workspace-and-home.sh FAKE_NO_TOUCH=1
expect "H-05: a file that never reaches the host fails" equals "$CHECK_RC" "1"
expect "H-05: the missing file is named" has_text "$WORK/out.h05.notouch" "x.txt"
reset_state
make_fixture_run
run_standalone "$WORK/out.h05.root" h05-workspace-and-home.sh FAKE_STAT_OWNER=root
expect "H-05: a root owner fails" equals "$CHECK_RC" "1"
expect "H-05: the root owner is shown" has_text "$WORK/out.h05.root" "root /home/sandbox/.local"

echo "--- H-13 on its own"
reset_state
make_fixture_run
run_standalone "$WORK/out.h13" h13-env-and-no-self-update.sh
expect "H-13: five variables, updates disabled and no share folder pass" equals "$CHECK_RC" "0"
expect "H-13: prints PASS: H-13" has_text "$WORK/out.h13" "PASS: H-13"
run_standalone "$WORK/out.h13.env" h13-env-and-no-self-update.sh FAKE_ENV_MISSING=HISTFILE
expect "H-13: a missing variable fails" equals "$CHECK_RC" "1"
expect "H-13: the missing variable is named" has_text "$WORK/out.h13.env" "HISTFILE"
run_standalone "$WORK/out.h13.update" h13-env-and-no-self-update.sh FAKE_UPDATE_ON=1
expect "H-13: an update that runs fails" equals "$CHECK_RC" "1"
run_standalone "$WORK/out.h13.share" h13-env-and-no-self-update.sh FAKE_SHARE_EXISTS=1
expect "H-13: an existing share folder fails" equals "$CHECK_RC" "1"

echo "--- H-06 on its own"
reset_state
make_fixture_run
mkdir -p "$WORK/fakehome/tpl"
printf 'template marker\n' >"$WORK/fakehome/tpl/MARK"
printf '[init]\n\ttemplateDir = %s\n[user]\n\tname = Real Person\n' "$WORK/fakehome/tpl" >"$WORK/fakehome/.gitconfig"
cp "$WORK/fakehome/.gitconfig" "$WORK/gitconfig.before"
run_standalone "$WORK/out.h06" h06-git-and-identity.sh HOME="$WORK/fakehome"
expect "H-06: no dubious ownership, safe.directory * and the identity file pass" equals "$CHECK_RC" "0"
expect "H-06: prints PASS: H-06" has_text "$WORK/out.h06" "PASS: H-06"
expect "H-06: the host-side git init made a repository" test -d "$FIXTURE/hosttest/.git"
expect "H-06: the identity file is in the run folder" has_text "$FIXTURE/state/git/config" "name = T"
expect "H-06: the host git config is not read (its template folder was not used)" test ! -e "$FIXTURE/hosttest/.git/MARK"
expect "H-06: the host git config file is untouched" cmp -s "$WORK/fakehome/.gitconfig" "$WORK/gitconfig.before"
reset_state
make_fixture_run
run_standalone "$WORK/out.h06.dubious" h06-git-and-identity.sh FAKE_GIT_DUBIOUS=1
expect "H-06: a dubious ownership message fails" equals "$CHECK_RC" "1"
expect "H-06: the dubious ownership message is shown" has_text "$WORK/out.h06.dubious" "dubious ownership"
reset_state
make_fixture_run
run_standalone "$WORK/out.h06.nowrite" h06-git-and-identity.sh FAKE_NO_GIT_WRITE=1
expect "H-06: a missing identity file fails" equals "$CHECK_RC" "1"
expect "H-06: the missing identity file is named" has_text "$WORK/out.h06.nowrite" "state/git/config"
run_standalone "$WORK/out.h06.safe" h06-git-and-identity.sh FAKE_SAFE_DIR=/home/sandbox/workspace
expect "H-06: a safe.directory value that is not * fails" equals "$CHECK_RC" "1"

echo "--- H-08 on its own"
reset_state
make_fixture_run
run_standalone "$WORK/out.h08" h08-history-survives-recreate.sh
expect "H-08: a marker written while a shell is open survives the recreate" equals "$CHECK_RC" "0"
expect "H-08: prints PASS: H-08" has_text "$WORK/out.h08" "PASS: H-08"
expect "H-08: the history file is in the run folder" has_text "$FIXTURE/state/shell/bash_history" "echo marker-"
expect "H-08: the sandbox is down and up once" equals "$(grep -c 'ARGS: compose .* \(up\|down\)' "$FAKE_LOG")" "2"
reset_state
make_fixture_run
run_standalone "$WORK/out.h08.nohist" h08-history-survives-recreate.sh FAKE_NO_HISTORY=1
expect "H-08: a marker that never reaches the history file fails" equals "$CHECK_RC" "1"
expect "H-08: the failing half is the first one" has_text "$WORK/out.h08.nohist" "before the recreate"
reset_state
make_fixture_run
run_standalone "$WORK/out.h08.lost" h08-history-survives-recreate.sh FAKE_DOWN_LOSES_HISTORY=1
expect "H-08: history lost by the recreate fails" equals "$CHECK_RC" "1"
expect "H-08: the failing half is the second one" has_text "$WORK/out.h08.lost" "after the recreate"

echo "--- Coexistence on its own"
reset_state
make_fixture_run
printf 'deadbeef0001 cc_oldbox running\n' >"$FIXTURE/logs/old-containers.before"
run_standalone "$WORK/out.co" coexistence.sh
expect "Coexistence: equal snapshots and clean old folders pass" equals "$CHECK_RC" "0"
expect "Coexistence: prints PASS: Coexistence" has_text "$WORK/out.co" "PASS: Coexistence"
run_standalone "$WORK/out.co.changed" coexistence.sh FAKE_PS="deadbeef0001 cc_oldbox exited"
expect "Coexistence: a changed snapshot fails" equals "$CHECK_RC" "1"
expect "Coexistence: a changed snapshot shows the before side" has_text "$WORK/out.co.changed" "cc_oldbox running"
expect "Coexistence: a changed snapshot shows the after side" has_text "$WORK/out.co.changed" "cc_oldbox exited"
expect "Coexistence: a changed snapshot says to re-run" has_text "$WORK/out.co.changed" "re-run"
expect "Coexistence: the baseline is left as it was" \
  equals "$(cat "$FIXTURE/logs/old-containers.before")" "deadbeef0001 cc_oldbox running"
reset_state
FIXTURE=""
run_standalone "$WORK/out.co.nobase" coexistence.sh
expect "Coexistence: no baseline passes on git alone" equals "$CHECK_RC" "0"
expect "Coexistence: no baseline says so" has_text "$WORK/out.co.nobase" "git only; no baseline"
mkdir -p "$WORK/scratchrepo/tests/host" "$WORK/scratchrepo/ClaudeCode"
cp tests/host/*.sh "$WORK/scratchrepo/tests/host/"
git -C "$WORK/scratchrepo" init -q
: >"$WORK/scratchrepo/ClaudeCode/stray.txt"
CHECK_RC=0
env SBXTEST_DIR="" bash "$WORK/scratchrepo/tests/host/coexistence.sh" >"$WORK/out.co.git" 2>&1 </dev/null || CHECK_RC=$?
expect "Coexistence: a change under ClaudeCode/ fails" equals "$CHECK_RC" "1"
expect "Coexistence: the changed path is shown" has_text "$WORK/out.co.git" "stray.txt"

echo "--- H-11 on its own"
reset_state
make_fixture_run
run_standalone "$WORK/out.h11" h11-stop-is-quick-and-safe.sh
expect "H-11: a quick stop that keeps the folders passes" equals "$CHECK_RC" "0"
expect "H-11: prints PASS: H-11" has_text "$WORK/out.h11" "PASS: H-11"
expect "H-11: the sentinel in the project folder is intact" test -f "$FIXTURE/hosttest/h11-sentinel.txt"
expect "H-11: the sentinel in the state folder is intact" test -f "$FIXTURE/state/h11-sentinel.txt"
expect "H-11: the sandbox is up again" test -f "$WORK/state/container"
reset_state
make_fixture_run
run_standalone "$WORK/out.h11.kept" h11-stop-is-quick-and-safe.sh FAKE_DOWN_KEEPS=1
expect "H-11: a container still present after down fails" equals "$CHECK_RC" "1"
expect "H-11: the kept container is the reason" has_text "$WORK/out.h11.kept" "still exists"

echo "--- H-09 on its own"
reset_state
make_fixture_run
run_standalone "$WORK/out.h09" h09-rebuild-keeps-files-no-volumes.sh FAKE_VOLUMES="olddata"
expect "H-09: sentinels, volumes and the one bind mount pass" equals "$CHECK_RC" "0"
expect "H-09: prints PASS: H-09" has_text "$WORK/out.h09" "PASS: H-09"
sed 's/^.*ARGS: //' "$FAKE_LOG" >"$WORK/args.h09"
expect "H-09: both images are rebuilt" equals "$(grep -c '^build ' "$WORK/args.h09")" "2"
expect "H-09: the rebuild uses the cache by default" lacks_text "$WORK/args.h09" "--no-cache"
expect "H-09: the sandbox is up again" test -f "$WORK/state/container"
reset_state
make_fixture_run
run_standalone "$WORK/out.h09.mount" h09-rebuild-keeps-files-no-volumes.sh FAKE_EXTRA_MOUNT=1
expect "H-09: a second mount fails" equals "$CHECK_RC" "1"
expect "H-09: the second mount is shown" has_text "$WORK/out.h09.mount" "/home/sandbox/extra"
reset_state
make_fixture_run
run_standalone "$WORK/out.h09.vol" h09-rebuild-keeps-files-no-volumes.sh FAKE_VOLUMES="a" FAKE_VOLUMES_AFTER_BUILD="a b"
expect "H-09: a changed volume list fails" equals "$CHECK_RC" "1"
expect "H-09: the volume change is reported" has_text "$WORK/out.h09.vol" "volume"
reset_state
make_fixture_run
run_standalone "$WORK/out.h09.nocache" h09-rebuild-keeps-files-no-volumes.sh SBXTEST_NO_CACHE=1
sed 's/^.*ARGS: //' "$FAKE_LOG" >"$WORK/args.h09.nocache"
expect "H-09: SBXTEST_NO_CACHE=1 still passes" equals "$CHECK_RC" "0"
expect "H-09: SBXTEST_NO_CACHE=1 adds --no-cache to both builds" \
  equals "$(grep -c '^build --no-cache ' "$WORK/args.h09.nocache")" "2"

echo "--- H-10 on its own"
reset_state
make_fixture_run
run_standalone "$WORK/out.h10.ok" h10-missing-folder-refused.sh
expect "H-10: a refused missing folder with the path absent passes" equals "$CHECK_RC" "0"
expect "H-10: prints PASS: H-10" has_text "$WORK/out.h10.ok" "PASS: H-10"
expect "H-10: the bad path was not created" test ! -e "$FIXTURE/does-not-exist"
expect "H-10: the real sandbox is up at the end" test -f "$WORK/state/container"
lastComposeCall=$(grep 'ARGS: compose' "$FAKE_LOG" | tail -n 1)
expect "H-10: the last compose call is an up with the real run folder" \
  string_matches "SBX_DIR=$FIXTURE COMPOSE_PROJECT_NAME=unset ARGS: compose .* up -d --wait$" "$lastComposeCall"
reset_state
make_fixture_run
run_standalone "$WORK/out.h10.ign" h10-missing-folder-refused.sh FAKE_H10=ignored
expect "H-10: a path that Docker created fails" equals "$CHECK_RC" "1"
expect "H-10: the created path is reported as create_host_path ignored" has_text "$WORK/out.h10.ign" "create_host_path ignored"
expect "H-10: the report carries the Compose version" has_text "$WORK/out.h10.ign" "Compose 2.39.1"
expect "H-10: the created path is left for the printed cleanup" test -d "$FIXTURE/does-not-exist"
expect "H-10: the real sandbox is up at the end after a created path" test -f "$WORK/state/container"
expect "H-10: the real sandbox mounts the real run folder" equals "$(cat "$WORK/state/container.dir")" "$FIXTURE"
reset_state
make_fixture_run
run_standalone "$WORK/out.h10.start" h10-missing-folder-refused.sh FAKE_H10=started
expect "H-10: a start on a missing folder fails" equals "$CHECK_RC" "1"
expect "H-10: a start on a missing folder says so" has_text "$WORK/out.h10.start" "started on a missing folder"
expect "H-10: the real sandbox is up at the end after a start" test -f "$WORK/state/container"
expect "H-10: the real sandbox mounts the real run folder after a start" equals "$(cat "$WORK/state/container.dir")" "$FIXTURE"

echo "--- full chain in the runner"
reset_state
run_runner "$WORK/out.chain.ign" FAKE_H10=ignored
expect "runner: a created missing folder exits 1" equals "$RUNNER_RC" "1"
expect "runner: a created missing folder prints FAIL: H-10" has_text "$WORK/out.chain.ign" "FAIL: H-10"
expect "runner: a created missing folder still runs Coexistence" has_text "$WORK/out.chain.ign" "PASS: Coexistence"
expect "runner: a created missing folder still prints the Next block" has_text "$WORK/out.chain.ign" "manual/h13-doctor.sh"
reset_state
run_runner "$WORK/out.chain.keep" FAKE_DOWN_KEEPS=1
expect "runner: a kept container exits 1" equals "$RUNNER_RC" "1"
expect "runner: a kept container prints FAIL: H-11" has_text "$WORK/out.chain.keep" "FAIL: H-11"
expect "runner: the chain stops, so H-09 is not run" has_text "$WORK/out.chain.keep" "NOT RUN: h09-rebuild-keeps-files-no-volumes.sh"
expect "runner: the chain stops, so H-10 is not run" has_text "$WORK/out.chain.keep" "NOT RUN: h10-missing-folder-refused.sh"
expect "runner: H-09 prints no result after the chain stopped" lacks_match "$WORK/out.chain.keep" '^(PASS|FAIL): H-(09|10)'
expect "runner: Coexistence still runs after the chain stopped" has_text "$WORK/out.chain.keep" "PASS: Coexistence"
reset_state
run_runner "$WORK/out.nocache" SBXTEST_NO_CACHE=1
sed 's/^.*ARGS: //' "$FAKE_LOG" >"$WORK/args.nocache"
expect "runner: SBXTEST_NO_CACHE=1 run exits 0" equals "$RUNNER_RC" "0"
expect "runner: the first builds use the cache" equals "$(grep -c '^build -t ' "$WORK/args.nocache")" "2"
expect "runner: only the rebuild uses --no-cache" equals "$(grep -c '^build --no-cache ' "$WORK/args.nocache")" "2"

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
