#!/usr/bin/env bash
# Shared helpers for the host tests: setup, the test sandbox safety checks, PASS/FAIL printing.
# - Sourced by run-all.sh and by every check; never run directly.
# - Sets no shell options and does not cd, so the caller keeps control of both.
# - Every Docker call is aimed at the throwaway sandbox: project hosttest, container
#   sbx-hosttest. The caller's SBX_NAME, SBX_DIR and COMPOSE_* values are never used.
# - Deletes nothing. The cleanup is only printed (print_next_block).
# - Host side code is stock bash 3.2 with BSD tools (macOS); GNU tools only inside docker exec.

# host_init: sets REPO_DIR, HOST_DIR, SBX_NAME, CONTAINER and RUN; scrubs the environment.
host_init() {
  local libDir

  libDir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
  HOST_DIR=$libDir
  REPO_DIR=$(cd "$libDir/../.." && pwd -P)

  unset COMPOSE_PROJECT_NAME COMPOSE_FILE COMPOSE_PROFILES COMPOSE_PATH_SEPARATOR SBX_DIR
  SBX_NAME=hosttest
  export SBX_NAME
  CONTAINER=sbx-hosttest

  resolve_run_dir
}

# run_dir_name_ok PATH: true if the last path component starts with sbx-hosttest-.
run_dir_name_ok() {
  local folderName

  folderName=$(basename "$1")
  case "$folderName" in
    sbx-hosttest-*) return 0 ;;
  esac

  return 1
}

# resolve_run_dir: sets RUN from SBXTEST_DIR, else from the test container's mount; else empty.
resolve_run_dir() {
  local mountSource

  RUN=""

  if [ -n "${SBXTEST_DIR:-}" ]; then
    if [ -d "$SBXTEST_DIR" ] && run_dir_name_ok "$SBXTEST_DIR"; then
      RUN=$(cd "$SBXTEST_DIR" && pwd -P)
    else
      printf 'SBXTEST_DIR is not an existing folder named sbx-hosttest-*: %s\n' "$SBXTEST_DIR" >&2
    fi

    return 0
  fi

  mountSource=$(docker container inspect \
    --format '{{range .Mounts}}{{if eq .Destination "/home/sandbox/workspace"}}{{.Source}}{{end}}{{end}}' \
    "$CONTAINER" 2>/dev/null </dev/null) || return 0

  if [ -z "$mountSource" ]; then
    return 0
  fi

  if [ -d "$mountSource" ] && run_dir_name_ok "$mountSource"; then
    RUN=$(cd "$mountSource" && pwd -P)
  else
    printf 'The %s mount is not a folder visible on this machine: %s\n' "$CONTAINER" "$mountSource" >&2
  fi

  return 0
}

# make_run_dir: creates a fresh run folder (hosttest, state, logs inside); sets RUN, exports SBXTEST_DIR.
make_run_dir() {
  local baseDir created

  baseDir=${TMPDIR:-/tmp}
  baseDir=${baseDir%/}
  if [ -z "$baseDir" ]; then
    baseDir=/tmp
  fi

  if ! created=$(mktemp -d "$baseDir/sbx-hosttest-$(date +%Y%m%d-%H%M%S).XXXXXX"); then
    printf 'Could not create a run folder under %s\n' "$baseDir" >&2
    return 1
  fi

  RUN=$(cd "$created" && pwd -P) || return 1
  mkdir -p "$RUN/hosttest" "$RUN/state" "$RUN/logs" || return 1
  SBXTEST_DIR=$RUN
  export SBXTEST_DIR

  return 0
}

# pass ID TEXT: prints one PASS line.
pass() {
  printf 'PASS: %s %s\n' "$1" "$2"
}

# fail ID TEXT [DETAIL...]: prints one FAIL line, then each detail indented.
fail() {
  local checkId=$1
  local text=$2

  printf 'FAIL: %s %s\n' "$checkId" "$text"
  shift 2
  while [ "$#" -gt 0 ]; do
    printf '      %s\n' "$1"
    shift
  done
}

# info TEXT: prints one INFO line.
info() {
  printf 'INFO: %s\n' "$1"
}

# in_container CMD...: runs CMD in the test container; stdin closed, stderr merged, never a tty.
in_container() {
  docker exec "$CONTAINER" "$@" </dev/null 2>&1
}

# compose_cmd ARGS...: runs docker compose against compose.yml for the test sandbox only.
compose_cmd() {
  if [ -z "${RUN:-}" ]; then
    printf 'No run folder, so no compose command is run.\n' >&2
    return 1
  fi

  SBX_NAME=hosttest SBX_DIR="$RUN" docker compose -f "$REPO_DIR/compose.yml" "$@" </dev/null
}

# run_timeout SECONDS CMD...: runs CMD; kills it after SECONDS; returns 143 on timeout.
run_timeout() {
  local seconds=$1
  local commandPid watcherPid exitCode

  shift
  "$@" &
  commandPid=$!
  (
    elapsedSeconds=0
    while [ "$elapsedSeconds" -lt "$seconds" ]; do
      sleep 1
      if ! kill -0 "$commandPid" 2>/dev/null; then
        exit 0
      fi
      elapsedSeconds=$((elapsedSeconds + 1))
    done
    kill "$commandPid" 2>/dev/null
  ) >/dev/null 2>&1 &
  watcherPid=$!
  wait "$commandPid"
  exitCode=$?
  kill "$watcherPid" 2>/dev/null
  wait "$watcherPid" 2>/dev/null

  return "$exitCode"
}

# compose_up: starts the test sandbox and waits; log in the run folder; returns the exit code.
compose_up() {
  local logFile exitCode

  logFile="$RUN/logs/compose-up.log"
  run_timeout 120 compose_cmd up -d --wait >"$logFile" 2>&1
  exitCode=$?

  if [ "$exitCode" -ne 0 ]; then
    printf 'compose up failed (exit %s); last lines of %s:\n' "$exitCode" "$logFile"
    tail -n 20 "$logFile" | sed 's/^/    /'
    printf 'If the log says the mount was denied, the run folder is not under a folder shared with Docker Desktop (Settings, Resources, File sharing).\n'
  fi

  return "$exitCode"
}

# assert_test_sandbox: true only if sbx-hosttest exists, is labelled sbx.name=hosttest and mounts a sbx-hosttest-* folder.
assert_test_sandbox() {
  local label mountSource

  label=$(docker container inspect --format '{{index .Config.Labels "sbx.name"}}' "$CONTAINER" 2>/dev/null </dev/null) || return 1
  if [ "$label" != "hosttest" ]; then
    return 1
  fi

  mountSource=$(docker container inspect \
    --format '{{range .Mounts}}{{if eq .Destination "/home/sandbox/workspace"}}{{.Source}}{{end}}{{end}}' \
    "$CONTAINER" 2>/dev/null </dev/null) || return 1
  case "$mountSource" in
    *sbx-hosttest-*) return 0 ;;
  esac

  return 1
}

# require_test_sandbox ID: true when the test sandbox is running; else prints a FAIL line for ID, returns 1.
require_test_sandbox() {
  local checkId=$1
  local running

  if [ -n "${RUN:-}" ]; then
    running=$(docker container inspect --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null </dev/null)
    if [ "$running" = "true" ] && assert_test_sandbox; then
      return 0
    fi
  fi

  fail "$checkId" "the test sandbox is not running" "run: bash tests/host/run-all.sh first"

  return 1
}

# compose_down: takes the test sandbox down (never removes volumes); refuses if sbx-hosttest is not the test sandbox.
compose_down() {
  if docker container inspect "$CONTAINER" >/dev/null 2>&1 </dev/null; then
    if ! assert_test_sandbox; then
      printf 'Refusing compose down: %s is not the test sandbox.\n' "$CONTAINER" >&2
      return 1
    fi
  fi

  compose_cmd down
}

# remove_leftover_test_container: 0 if none or taken down; 1 if the name is taken by something else or down failed.
remove_leftover_test_container() {
  local label

  if ! docker container inspect "$CONTAINER" >/dev/null 2>&1 </dev/null; then
    return 0
  fi

  label=$(docker container inspect --format '{{index .Config.Labels "sbx.name"}}' "$CONTAINER" 2>/dev/null </dev/null)
  if [ "$label" != "hosttest" ]; then
    printf 'A container named %s exists but is not labelled sbx.name=hosttest. It was left alone.\n' "$CONTAINER" >&2
    return 1
  fi

  compose_down >"$RUN/logs/leftover-down.log" 2>&1
}

# build_images LOG_PREFIX [--no-cache]: builds sbx-base:local, then sbx-claude:local; logs in the run folder.
build_images() {
  local logPrefix=$1
  local cacheFlag=${2:-}
  local imageName logFile buildStatus

  for imageName in base claude; do
    logFile="$RUN/logs/$logPrefix-$imageName.log"
    if [ "$cacheFlag" = "--no-cache" ]; then
      docker build --no-cache -t "sbx-$imageName:local" "$REPO_DIR/$imageName" >"$logFile" 2>&1 </dev/null
      buildStatus=$?
    else
      docker build -t "sbx-$imageName:local" "$REPO_DIR/$imageName" >"$logFile" 2>&1 </dev/null
      buildStatus=$?
    fi

    if [ "$buildStatus" -ne 0 ]; then
      printf 'Build of sbx-%s:local failed. Log: %s\n' "$imageName" "$logFile"
      tail -n 20 "$logFile" | sed 's/^/    /'
      return 1
    fi
  done

  return 0
}

# expected_arch: the image architecture the daemon should produce (arm64, amd64 or unknown).
expected_arch() {
  case "$(docker info --format '{{.Architecture}}' </dev/null)" in
    aarch64) printf 'arm64\n' ;;
    x86_64) printf 'amd64\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

# claude_pin: the pinned Claude Code version, read from claude/Dockerfile.
claude_pin() {
  sed -n 's/^ARG CLAUDE_CODE_VERSION=//p' "$REPO_DIR/claude/Dockerfile"
}

# snapshot_old_containers: one sorted line per old-layout container: ID, name, state.
snapshot_old_containers() {
  docker ps -a --format '{{.ID}} {{.Names}} {{.State}}' </dev/null 2>/dev/null | grep -E '^[0-9a-f]+ cc_' | sort
}

# print_next_block: prints the manual pass commands and the cleanup command. Only prints.
print_next_block() {
  printf '\nNext\n'
  printf '  Manual pass (needs a terminal), in this order:\n'
  printf '    bash %q\n' "${HOST_DIR:-}/manual/h07-login.sh"
  printf '    bash %q\n' "${HOST_DIR:-}/manual/h09-rebuild-resume.sh"
  printf '    bash %q\n' "${HOST_DIR:-}/manual/h13-doctor.sh"

  if [ -n "${RUN:-}" ]; then
    printf '  Cleanup when you are done. The run folder holds the Claude login after the manual pass:\n'
    printf '    cd %q && SBX_NAME=hosttest SBX_DIR=%q docker compose down && rm -rf %q\n' "${REPO_DIR:-}" "$RUN" "$RUN"
  else
    printf '  No run folder was created, so there is nothing to clean up.\n'
  fi
}
