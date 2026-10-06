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
# FAKE_EXTRA_MOUNT, FAKE_DOWN_KEEPS, FAKE_H10 (honored, ignored or started),
# FAKE_NO_SYNC (compose up skips the start hook), FAKE_CONTEXT_SCOPED (the fake /context also lists
# path-scoped rules), FAKE_CONTEXT_NO_SKILLS (the fake /context lists no skills), FAKE_OFFLINE_FAIL
# (a run with --network none fails to start), FAKE_HOOK_IGNORED (a run whose hook fails still runs
# its command), FAKE_SYNC_CLOBBERS (compose up deletes state/claude/skills and projects before the
# hook, as a broken sync would), FAKE_BUNDLE_DRIFT (the bundle copied out of the image has an extra
# file), FAKE_BUNDLE_OWNER (the owner of /opt/sbx/best-practices), FAKE_BUNDLE_WRITABLE (the sandbox
# user can write in the bundle), FAKE_BUNDLE_MOUNT (a mount sits under /opt/sbx), FAKE_MANAGED_BAD
# (the managed settings do not parse), FAKE_SCOPE_EAGER (the fake H-18 scope run shows the path-scoped
# rule in the first request), FAKE_DENY_BROKEN (the fake H-18 deny run changes the first always-on
# rule and plants a file), FAKE_H18_TOOLS_OFF (the fake H-18 deny run never edits the project file),
# FAKE_HOOK_DIR_IGNORED (a run with its own folder over /etc/sbx/start.d skips the hook step).
# Compose up and a run with --network none execute the real start hook, as the real entrypoint does.
# A run that mounts its own folder over /etc/sbx/start.d runs the real entrypoint hook step on that
# folder instead of the bundle sync.
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
        mkdir -p "$SBX_DIR/state/claude"
        if [ "${FAKE_SYNC_CLOBBERS:-0}" = 1 ]; then
          rm -rf "$SBX_DIR/state/claude/skills" "$SBX_DIR/state/claude/projects"
        fi
        if [ "${FAKE_NO_SYNC:-0}" != 1 ]; then
          if ! SBX_BUNDLE_DIR="$FAKE_REPO/best-practices" CLAUDE_CONFIG_DIR="$SBX_DIR/state/claude" \
            bash "$FAKE_REPO/claude/start.d/10-best-practices"; then
            echo "[sbx] ERROR: start hook /etc/sbx/start.d/10-best-practices failed; the container was not started." >&2
            exit 1
          fi
        fi
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
      *"--network none"*)
        hookBroken=0
        case "$*" in
          *"CLAUDE_CONFIG_DIR=/proc/"*) hookBroken=1 ;;
        esac
        if [ "$hookBroken" = 1 ] && [ "${FAKE_HOOK_IGNORED:-0}" != 1 ]; then
          echo "[sbx] ERROR: start hook /etc/sbx/start.d/10-best-practices failed; the container was not started." >&2
          exit 1
        fi
        if [ "$hookBroken" = 0 ] && [ "${FAKE_OFFLINE_FAIL:-0}" = 1 ]; then
          echo "fake docker: the container could not start with networking disabled" >&2
          exit 1
        fi
        mountSource=""
        hookSource=""
        lastArg=""
        for runArg in "$@"; do
          case "$runArg" in
            type=bind,source=*)
              mountTarget=${runArg#*,target=}
              mountTarget=${mountTarget%,readonly}
              mountPath=${runArg#type=bind,source=}
              mountPath=${mountPath%%,target=*}
              if [ "$mountTarget" = /etc/sbx/start.d ]; then
                hookSource=$mountPath
              else
                mountSource=$mountPath
              fi
              ;;
          esac
          lastArg=$runArg
        done
        if [ -n "$hookSource" ]; then
          if [ "${FAKE_HOOK_DIR_IGNORED:-0}" != 1 ]; then
            hookOutput=$( ( . "$FAKE_REPO/base/sbx-start-lib.sh"; hookDir=$hookSource; run_start_hooks ) 2>&1 </dev/null )
            hookStatus=$?
            if [ "$hookStatus" -ne 0 ]; then
              printf '%s\n' "${hookOutput//"$hookSource"//etc/sbx/start.d}" >&2
              exit 1
            fi
          fi
        elif [ "$hookBroken" = 0 ]; then
          mkdir -p "$mountSource/state/claude"
          if ! SBX_BUNDLE_DIR="$FAKE_REPO/best-practices" CLAUDE_CONFIG_DIR="$mountSource/state/claude" \
            bash "$FAKE_REPO/claude/start.d/10-best-practices"; then
            echo "[sbx] ERROR: start hook /etc/sbx/start.d/10-best-practices failed; the container was not started." >&2
            exit 1
          fi
        fi
        sh -c "$lastArg"
        exit $?
        ;;
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
        -f) shift 2 ;;
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
  cp)
    shift
    if ! has_container || [ "$#" -ne 2 ] || [ "$1" != "sbx-hosttest:/opt/sbx/best-practices" ]; then
      unhandled "cp $*"
    fi
    cp -R "$FAKE_REPO/best-practices" "$2"
    if [ "${FAKE_BUNDLE_DRIFT:-0}" = 1 ]; then
      printf 'drift\n' >"$2/rules/h14-drift.md"
    fi
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
      "env H18_SCRIPT="*)
        h18Log=""
        for h18Arg in "$@"; do
          case "$h18Arg" in
            H18_LOG=*) h18Log=${h18Arg#H18_LOG=} ;;
          esac
        done
        h18Root=$(cat "$FAKE_STATE/container.dir")
        h18Log="$h18Root/${h18Log#/home/sandbox/workspace/}"
        case "$h18Log" in
          *scope*)
            if [ "${FAKE_SCOPE_EAGER:-0}" = 1 ]; then
              printf 'step=0 always=yes scoped=yes\n' >"$h18Log"
            else
              printf 'step=0 always=yes scoped=no\n' >"$h18Log"
            fi
            printf 'step=1 always=yes scoped=yes\n' >>"$h18Log"
            ;;
          *deny*)
            if [ "${FAKE_H18_TOOLS_OFF:-0}" != 1 ]; then
              sed 's/before/after/' "$h18Root/hosttest/h18/control.txt" >"$h18Root/hosttest/h18/control.tmp"
              mv "$h18Root/hosttest/h18/control.tmp" "$h18Root/hosttest/h18/control.txt"
              if [ "${FAKE_DENY_BROKEN:-0}" = 1 ]; then
                for h18Rule in $(cd "$h18Root/state/claude/rules" && find . -type f -name '*.md' | sed 's|^\./||' | sort); do
                  if [ "$(sed -n 1p "$h18Root/state/claude/rules/$h18Rule")" != "---" ]; then
                    printf 'scribble\n' >>"$h18Root/state/claude/rules/$h18Rule"
                    break
                  fi
                done
                printf 'planted\n' >"$h18Root/state/claude/rules/h18-planted.md"
              fi
            fi
            ;;
        esac
        ;;
      "sh -c : h14-probe"*)
        printf 'OWNER /opt/sbx/best-practices %s:%s 755\n' "${FAKE_BUNDLE_OWNER:-root}" "${FAKE_BUNDLE_OWNER:-root}"
        printf 'OWNER /etc/sbx/start.d root:root 755\n'
        printf 'OWNER /etc/sbx/start.d/10-best-practices root:root 755\n'
        printf 'OWNER /etc/claude-code/managed-settings.json root:root 644\n'
        if [ "${FAKE_BUNDLE_WRITABLE:-0}" = 1 ]; then
          printf 'WRITABLE /opt/sbx/best-practices/rules/communication.md\n'
        fi
        if [ "${FAKE_BUNDLE_MOUNT:-0}" = 1 ]; then
          printf 'MOUNT /opt/sbx/best-practices\n'
        fi
        if [ "${FAKE_MANAGED_BAD:-0}" = 1 ]; then
          printf 'JSON bad\n'
        else
          printf 'JSON ok\n'
        fi
        ;;
      "sh -c test ! -e"*)
        if [ "${FAKE_SHARE_EXISTS:-0}" = 1 ]; then
          exit 1
        fi
        ;;
      *"claude -p /context")
        contextRules=$FAKE_REPO/best-practices/rules
        echo "### Memory Files"
        echo "| Type | Path | Tokens |"
        echo "|------|------|--------|"
        for contextRel in $(cd "$contextRules" && find . -type f | sed 's|^\./||' | sort); do
          if [ "$(sed -n 1p "$contextRules/$contextRel")" != "---" ] || [ "${FAKE_CONTEXT_SCOPED:-0}" = 1 ]; then
            printf '| User | /home/sandbox/workspace/state/claude/rules/%s | 10 |\n' "$contextRel"
          fi
        done
        echo
        echo "### Skills"
        echo "| Skill | Source | Tokens |"
        echo "|-------|--------|--------|"
        if [ "${FAKE_CONTEXT_NO_SKILLS:-0}" != 1 ]; then
          for contextSkill in "$FAKE_REPO"/best-practices/skills/*/; do
            printf '| %s | User | < 20 |\n' "$(basename "$contextSkill")"
          done
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

# fake_start_sync DIR: runs the real start hook into DIR/state/claude, as a container start would.
fake_start_sync() {
  mkdir -p "$1/state/claude"
  SBX_BUNDLE_DIR="$REPO/best-practices" CLAUDE_CONFIG_DIR="$1/state/claude" \
    bash "$REPO/claude/start.d/10-best-practices"
}

# last_run_dir: the run folder the latest runner made.
last_run_dir() {
  ls -d "$WORK"/tmp/sbx-hosttest-* 2>/dev/null | tail -n 1
}

# --- cases ---

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
expect "runner: healthy run prints PASS: H-16" has_text "$WORK/out.healthy" "PASS: H-16"
expect "runner: healthy run prints PASS: H-10" has_text "$WORK/out.healthy" "PASS: H-10"
expect "runner: healthy run prints PASS: H-11" has_text "$WORK/out.healthy" "PASS: H-11"
expect "runner: healthy run prints PASS: H-12" has_text "$WORK/out.healthy" "PASS: H-12"
expect "runner: healthy run has 19 PASS lines" equals "$(grep -c '^PASS:' "$WORK/out.healthy")" "19"
expect "runner: healthy run prints PASS: Coexistence" has_text "$WORK/out.healthy" "PASS: Coexistence"
expect "runner: healthy run prints PASS: H-13" has_text "$WORK/out.healthy" "PASS: H-13"
expect "runner: healthy run prints PASS: H-14" has_text "$WORK/out.healthy" "PASS: H-14"
expect "runner: healthy run prints PASS: H-15" has_text "$WORK/out.healthy" "PASS: H-15"
expect "runner: healthy run prints PASS: H-17" has_text "$WORK/out.healthy" "PASS: H-17"
expect "runner: healthy run prints PASS: H-18" has_text "$WORK/out.healthy" "PASS: H-18"
expect "runner: healthy run prints the summary" has_text "$WORK/out.healthy" "Summary: 19 passed, 0 failed, 0 not run"
expect "runner: healthy run prints the manual pass commands" has_text "$WORK/out.healthy" "manual/h07-login.sh"
expect "runner: healthy run prints the bundle behaviour helper" has_text "$WORK/out.healthy" "manual/h19-bundle-behaviour.sh"
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
  has_match "$WORK/args.healthy" '^build -f .*/base/Dockerfile -t sbx-base:local /'
expect "docker log: the claude image is built after the base image" \
  has_match "$WORK/args.healthy" '^build -f .*/claude/Dockerfile -t sbx-claude:local /'

echo "--- failing check"
reset_state
run_runner "$WORK/out.badid" FAKE_ID="uid=0(root) gid=0(root)"
expect "runner: a wrong id exits 1" equals "$RUNNER_RC" "1"
expect "runner: a wrong id prints FAIL: H-04" has_text "$WORK/out.badid" "FAIL: H-04"
expect "runner: a wrong id still prints the summary" has_text "$WORK/out.badid" "Summary: 18 passed, 1 failed, 0 not run"
expect "runner: a wrong id still prints the Next block" has_text "$WORK/out.badid" "manual/h13-doctor.sh"

echo "--- sandbox started without the bundle sync"
reset_state
run_runner "$WORK/out.nosync" FAKE_NO_SYNC=1
expect "runner: a start that never synced exits 1" equals "$RUNNER_RC" "1"
expect "runner: a start that never synced prints FAIL: H-15" has_text "$WORK/out.nosync" "FAIL: H-15"

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

echo "--- H-14 on its own"
reset_state
make_fixture_run
run_standalone "$WORK/out.h14" h14-bundle-in-image.sh
expect "H-14: a bundle equal to the repo with root owners and no mount passes" equals "$CHECK_RC" "0"
expect "H-14: prints PASS: H-14" has_text "$WORK/out.h14" "PASS: H-14"
expect "H-14: the copy from the image is in the run folder's logs" \
  diff -r -q "$REPO/best-practices" "$(ls -d "$FIXTURE"/logs/h14-bundle-* | head -n 1)"
expect "H-14: docker cp reads /opt/sbx/best-practices from the test container" \
  has_match "$FAKE_LOG" 'ARGS: cp sbx-hosttest:/opt/sbx/best-practices .*/logs/h14-bundle-'
run_standalone "$WORK/out.h14.drift" h14-bundle-in-image.sh FAKE_BUNDLE_DRIFT=1
expect "H-14: an image copy with an extra file fails" equals "$CHECK_RC" "1"
expect "H-14: the extra file is named" has_text "$WORK/out.h14.drift" "h14-drift.md"
run_standalone "$WORK/out.h14.owner" h14-bundle-in-image.sh FAKE_BUNDLE_OWNER=sandbox
expect "H-14: a bundle owned by sandbox fails" equals "$CHECK_RC" "1"
expect "H-14: the bundle path is named" has_text "$WORK/out.h14.owner" "/opt/sbx/best-practices is"
expect "H-14: the wrong owner is shown" has_text "$WORK/out.h14.owner" "sandbox:sandbox 755"
run_standalone "$WORK/out.h14.writable" h14-bundle-in-image.sh FAKE_BUNDLE_WRITABLE=1
expect "H-14: a path the sandbox user can write fails" equals "$CHECK_RC" "1"
expect "H-14: the writable path is named" has_text "$WORK/out.h14.writable" "/opt/sbx/best-practices/rules/communication.md"
run_standalone "$WORK/out.h14.mount" h14-bundle-in-image.sh FAKE_BUNDLE_MOUNT=1
expect "H-14: a mount under /opt/sbx fails" equals "$CHECK_RC" "1"
expect "H-14: the mount point is named" has_text "$WORK/out.h14.mount" "a mount sits under"
run_standalone "$WORK/out.h14.json" h14-bundle-in-image.sh FAKE_MANAGED_BAD=1
expect "H-14: managed settings that do not parse fail" equals "$CHECK_RC" "1"
expect "H-14: the parse failure is named" has_text "$WORK/out.h14.json" "do not parse"
reset_state
FIXTURE=""
run_standalone "$WORK/out.h14.none" h14-bundle-in-image.sh
expect "H-14: no test sandbox fails" equals "$CHECK_RC" "1"
expect "H-14: no test sandbox says to run run-all.sh first" has_text "$WORK/out.h14.none" "run-all.sh first"

echo "--- H-15 on its own"
reset_state
make_fixture_run
fake_start_sync "$FIXTURE"
run_standalone "$WORK/out.h15" h15-bundle-synced-and-visible.sh
expect "H-15: a synced bundle that Claude lists passes" equals "$CHECK_RC" "0"
expect "H-15: prints PASS: H-15" has_text "$WORK/out.h15" "PASS: H-15"
expect "H-15: the probe runs claude -p /context with a dummy key and no network" \
  has_match "$FAKE_LOG" 'ARGS: exec sbx-hosttest env ANTHROPIC_API_KEY=sk-ant-dummy ANTHROPIC_BASE_URL=http://127.0.0.1:1 claude -p /context$'
run_standalone "$WORK/out.h15.scoped" h15-bundle-synced-and-visible.sh FAKE_CONTEXT_SCOPED=1
expect "H-15: a path-scoped rule loaded at start fails" equals "$CHECK_RC" "1"
expect "H-15: the loaded path-scoped rule is named" has_text "$WORK/out.h15.scoped" "shell.md"
run_standalone "$WORK/out.h15.noskills" h15-bundle-synced-and-visible.sh FAKE_CONTEXT_NO_SKILLS=1
expect "H-15: skills that Claude does not list fail" equals "$CHECK_RC" "1"
expect "H-15: the missing skill is named" has_text "$WORK/out.h15.noskills" "merged"
printf 'tampered\n' >>"$FIXTURE/state/claude/rules/communication.md"
run_standalone "$WORK/out.h15.tamper" h15-bundle-synced-and-visible.sh
expect "H-15: a synced rule that differs from the repo fails" equals "$CHECK_RC" "1"
expect "H-15: the differing rule is named" has_text "$WORK/out.h15.tamper" "communication.md"
reset_state
make_fixture_run
run_standalone "$WORK/out.h15.nosync" h15-bundle-synced-and-visible.sh
expect "H-15: a start where the hook never ran fails" equals "$CHECK_RC" "1"
expect "H-15: the missing rules folder is named" has_text "$WORK/out.h15.nosync" "state/claude/rules"
reset_state
FIXTURE=""
run_standalone "$WORK/out.h15.none" h15-bundle-synced-and-visible.sh
expect "H-15: no test sandbox fails" equals "$CHECK_RC" "1"
expect "H-15: no test sandbox says to run run-all.sh first" has_text "$WORK/out.h15.none" "run-all.sh first"

echo "--- H-17 on its own"
reset_state
make_fixture_run
run_standalone "$WORK/out.h17" h17-start-offline-and-failing-hook.sh
expect "H-17: an offline start that syncs and a failing hook that stops pass" equals "$CHECK_RC" "0"
expect "H-17: prints PASS: H-17" has_text "$WORK/out.h17" "PASS: H-17"
expect "H-17: the offline start synced the rules into its own folder"   diff -r -q "$REPO/best-practices/rules" "$FIXTURE/h17/state/claude/rules"
expect "H-17: the test sandbox state was not touched" test ! -e "$FIXTURE/state/claude"
sed 's/^.*ARGS: //' "$FAKE_LOG" >"$WORK/args.h17"
expect "H-17: all four containers run with --rm, no network, no capabilities, no new privileges"   equals "$(grep -c '^run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true ' "$WORK/args.h17")" "4"
expect "H-17: all four containers mount the run folder as the workspace"   equals "$(grep -F -c "type=bind,source=$FIXTURE/h17,target=/home/sandbox/workspace" "$WORK/args.h17")" "4"
expect "H-17: two containers mount their own hook folder read-only over the image hooks"   equals "$(grep -F -c ",target=/etc/sbx/start.d,readonly" "$WORK/args.h17")" "2"
expect "H-17: the hook folders sit under the run folder"   equals "$(grep -F -c "source=$FIXTURE/h17/hooks-" "$WORK/args.h17")" "2"
expect "H-17: the not-executable hook is a file without the execute bit" test -f "$FIXTURE/h17/hooks-not-executable/10-not-executable"
expect "H-17: the not-executable hook has no execute bit" test ! -x "$FIXTURE/h17/hooks-not-executable/10-not-executable"
expect "H-17: the dangling hook is a link" test -L "$FIXTURE/h17/hooks-dangling/10-dangling"
expect "H-17: the dangling hook link points nowhere" test ! -e "$FIXTURE/h17/hooks-dangling/10-dangling"
expect "H-17: only the failing container gets a broken config folder"   equals "$(grep -c 'CLAUDE_CONFIG_DIR=/proc/no-such-dir' "$WORK/args.h17")" "1"
run_standalone "$WORK/out.h17.offline" h17-start-offline-and-failing-hook.sh FAKE_OFFLINE_FAIL=1
expect "H-17: an offline start that fails fails the check" equals "$CHECK_RC" "1"
expect "H-17: the offline start is named" has_text "$WORK/out.h17.offline" "offline start"
run_standalone "$WORK/out.h17.ignored" h17-start-offline-and-failing-hook.sh FAKE_HOOK_IGNORED=1
expect "H-17: a failing hook that does not stop the start fails the check" equals "$CHECK_RC" "1"
expect "H-17: the command that ran is reported" has_text "$WORK/out.h17.ignored" "command ran"
run_standalone "$WORK/out.h17.hookdir" h17-start-offline-and-failing-hook.sh FAKE_HOOK_DIR_IGNORED=1
expect "H-17: hook folders that do not stop the start fail the check" equals "$CHECK_RC" "1"
expect "H-17: the not-executable hook is named" has_text "$WORK/out.h17.hookdir" "is not executable"
expect "H-17: the dangling hook is named" has_text "$WORK/out.h17.hookdir" "is not a regular file"
reset_state
FIXTURE=""
run_standalone "$WORK/out.h17.none" h17-start-offline-and-failing-hook.sh
expect "H-17: no run folder fails" equals "$CHECK_RC" "1"
expect "H-17: no run folder says so" has_text "$WORK/out.h17.none" "no run folder"

echo "--- H-18 on its own"
reset_state
make_fixture_run
fake_start_sync "$FIXTURE"
run_standalone "$WORK/out.h18" h18-scope-and-deny.sh
expect "H-18: a scoped rule that loads late and a deny that holds pass" equals "$CHECK_RC" "0"
expect "H-18: prints PASS: H-18" has_text "$WORK/out.h18" "PASS: H-18"
expect "H-18: the fake API server is copied into the run folder's logs" test -f "$FIXTURE/logs/fake-claude-api.js"
expect "H-18: the probe file is under the project folder" test -f "$FIXTURE/hosttest/h18/deep/probe.sh"
expect "H-18: the project file was edited" equals "$(cat "$FIXTURE/hosttest/h18/control.txt")" "h18 control after"
expect "H-18: both scenario scripts name container paths" has_text "$FIXTURE/logs/h18-deny.json" "/home/sandbox/workspace/state/claude/rules/"
expect "H-18: the exec runs with the fake API script and log in the environment" \
  has_match "$FAKE_LOG" 'ARGS: exec sbx-hosttest env H18_SCRIPT=/home/sandbox/workspace/logs/h18-scope.json H18_LOG=/home/sandbox/workspace/logs/h18-scope.log '
run_standalone "$WORK/out.h18.eager" h18-scope-and-deny.sh FAKE_SCOPE_EAGER=1
expect "H-18: a path-scoped rule loaded at the first request fails" equals "$CHECK_RC" "1"
expect "H-18: the eager load is named" has_text "$WORK/out.h18.eager" "loaded before any matching file was touched"
fake_start_sync "$FIXTURE"
run_standalone "$WORK/out.h18.broken" h18-scope-and-deny.sh FAKE_DENY_BROKEN=1
expect "H-18: a broken deny fails" equals "$CHECK_RC" "1"
expect "H-18: the changed rule is named" has_text "$WORK/out.h18.broken" "state/claude/rules/coding-general.md was changed"
expect "H-18: the planted file is named" has_text "$WORK/out.h18.broken" "h18-planted.md"
fake_start_sync "$FIXTURE"
run_standalone "$WORK/out.h18.off" h18-scope-and-deny.sh FAKE_H18_TOOLS_OFF=1
expect "H-18: tools that never ran fail" equals "$CHECK_RC" "1"
expect "H-18: tools that never ran say the deny result proves nothing" has_text "$WORK/out.h18.off" "the edit tool never ran, so the deny result proves nothing"
reset_state
FIXTURE=""
run_standalone "$WORK/out.h18.none" h18-scope-and-deny.sh
expect "H-18: no test sandbox fails" equals "$CHECK_RC" "1"
expect "H-18: no test sandbox says to run run-all.sh first" has_text "$WORK/out.h18.none" "run-all.sh first"

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
expect "runner: the first builds use the cache" equals "$(grep -c '^build -f ' "$WORK/args.nocache")" "2"
expect "runner: only the rebuild uses --no-cache" equals "$(grep -c '^build --no-cache ' "$WORK/args.nocache")" "2"

echo "--- H-18 failure does not stop the runner"
reset_state
run_runner "$WORK/out.h18keep" FAKE_DENY_BROKEN=1
expect "runner: an H-18 failure exits 1" equals "$RUNNER_RC" "1"
expect "runner: an H-18 failure prints FAIL: H-18" has_text "$WORK/out.h18keep" "FAIL: H-18"
expect "runner: an H-18 failure marks no check not run" lacks_text "$WORK/out.h18keep" "NOT RUN"
expect "runner: an H-18 failure still runs the chain" has_text "$WORK/out.h18keep" "PASS: H-16"
expect "runner: an H-18 failure is in the summary" has_text "$WORK/out.h18keep" "Summary: 18 passed, 1 failed, 0 not run"
expect "runner: an H-18 failure is listed" has_text "$WORK/out.h18keep" "Failed: h18-scope-and-deny.sh"

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
