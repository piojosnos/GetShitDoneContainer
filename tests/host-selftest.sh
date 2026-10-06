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

# --- cases ---

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

if [ "$FAILS" -eq 0 ]; then
  echo "All cases pass."
  exit 0
fi
echo "$FAILS case(s) failed."
exit 1
