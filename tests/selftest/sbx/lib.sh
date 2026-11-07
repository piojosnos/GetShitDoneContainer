#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Shared by the sbx self-test groups: work folder, docker stand-in, runners
# ------------------------------------------------------------------------------
# Sourced by the groups, never run directly (functions only).
# ------------------------------------------------------------------------------

. "$(dirname "${BASH_SOURCE[0]}")/../lib-expect.sh"

# ------------------------------------------------------------------------------
# start_group: enters the repo root, makes WORK, the registry and the stand-in
# ------------------------------------------------------------------------------
# The stand-in docker refuses every call, so no case can reach the Mac's Docker;
# SBX_CONFIG_DIR keeps the user's registry out.
# ------------------------------------------------------------------------------
start_group() {
  enter_repo_root || return 1

  BIN=$REPO/bin

  make_work_folder sbxtest || return 1

  SBX_CONFIG_DIR=$WORK/cfg
  export SBX_CONFIG_DIR
  unset SBX_DIR SBX_NAME

  mkdir -p "$WORK/fence"
  {
    printf '%s\n' '#!/bin/sh'
    printf '%s\n' "echo \"docker \$*\" >>\"$WORK/docker-calls\""
    printf '%s\n' 'exit 99'
  } >"$WORK/fence/docker"
  chmod 755 "$WORK/fence/docker"

  PATH=$WORK/fence:$PATH
  export PATH
}

# ------------------------------------------------------------------------------
# make_scripted_docker: makes WORK/scripted/docker, a stand-in that follows files
# ------------------------------------------------------------------------------
# For the cases that must get past the pre-Docker checks. It answers from the
# files in WORK/standin-state and logs to WORK/standin-calls, so the refusing
# stand-in still sees no call. compose succeeds and prints a line.
#   container-image    set: the container exists and this is its image id
#   container-running  true or false, what container inspect prints for State
#   image-id           the id of the current image
#   exec-ok            set: docker exec succeeds
# Without container-image, every container inspect fails and the id is gone.
# ------------------------------------------------------------------------------
make_scripted_docker() {
  mkdir -p "$WORK/scripted" "$WORK/standin-state"
  {
    printf '%s\n' '#!/bin/sh'
    printf '%s\n' "state=\"$WORK/standin-state\""
    printf '%s\n' "echo \"docker \$*\" >>\"$WORK/standin-calls\""
    printf '%s\n' 'case "$1" in'
    printf '%s\n' '  compose) echo "standin: compose $*"; exit 0 ;;'
    printf '%s\n' '  exec) [ -f "$state/exec-ok" ]; exit $? ;;'
    printf '%s\n' '  image)'
    printf '%s\n' '    case "$*" in'
    printf '%s\n' "      *'{{.Id}}'*) cat \"\$state/image-id\" ;;"
    printf '%s\n' '    esac'
    printf '%s\n' '    exit 0 ;;'
    printf '%s\n' '  container)'
    printf '%s\n' '    [ -f "$state/container-image" ] || exit 1'
    printf '%s\n' '    case "$*" in'
    printf '%s\n' "      *'{{.State.Running}}'*) cat \"\$state/container-running\" ;;"
    printf '%s\n' "      *'{{.Image}}'*) cat \"\$state/container-image\" ;;"
    printf '%s\n' '    esac'
    printf '%s\n' '    exit 0 ;;'
    printf '%s\n' 'esac'
    printf '%s\n' 'exit 99'
  } >"$WORK/scripted/docker"
  chmod 755 "$WORK/scripted/docker"
}

# ------------------------------------------------------------------------------
# set_standin_state IMAGE_ID CONTAINER_IMAGE RUNNING EXEC_OK
# ------------------------------------------------------------------------------
# An empty CONTAINER_IMAGE means no container. EXEC_OK is yes or no.
# ------------------------------------------------------------------------------
set_standin_state() {
  rm -f "$WORK/standin-state"/*
  printf '%s\n' "$1" >"$WORK/standin-state/image-id"

  if [ -n "$2" ]; then
    printf '%s\n' "$2" >"$WORK/standin-state/container-image"
    printf '%s\n' "$3" >"$WORK/standin-state/container-running"
  fi

  if [ "$4" = "yes" ]; then
    : >"$WORK/standin-state/exec-ok"
  fi
}

# ------------------------------------------------------------------------------
# run_sbx_scripted LABEL SCRIPT ARG...: run_sbx with the scripted docker first
# ------------------------------------------------------------------------------
run_sbx_scripted() {
  local savedPath=$PATH

  PATH=$WORK/scripted:$PATH
  run_sbx "$@"
  PATH=$savedPath
}

# ------------------------------------------------------------------------------
# run_sbx LABEL SCRIPT ARG...: runs bin/SCRIPT, sets SBX_RC
# ------------------------------------------------------------------------------
# Output goes to WORK/LABEL.out and WORK/LABEL.err; stdin is closed.
# ------------------------------------------------------------------------------
run_sbx() {
  local label=$1
  local scriptFile=$2

  shift 2

  bash "$BIN/$scriptFile" "$@" >"$WORK/$label.out" 2>"$WORK/$label.err" </dev/null
  SBX_RC=$?
}

# ------------------------------------------------------------------------------
# refused_cleanly LABEL TEXT NAME PATH: refused with exit 1 and nothing made
# ------------------------------------------------------------------------------
# NAME has no entry and PATH does not exist; an empty NAME or PATH, or /, is
# not looked at.
# ------------------------------------------------------------------------------
refused_cleanly() {
  [ "$SBX_RC" -eq 1 ] || return 1
  has_text "$WORK/$1.err" "$2" || return 1

  if [ -n "$3" ] && [ -e "$SBX_CONFIG_DIR/sandboxes/$3" ]; then
    return 1
  fi

  if [ -n "$4" ] && [ "$4" != "/" ] && [ -e "$4" ]; then
    return 1
  fi

  return 0
}

# ------------------------------------------------------------------------------
# usage_printed LABEL TEXT: true on exit 2 with the usage line in the error
# ------------------------------------------------------------------------------
usage_printed() {
  [ "$SBX_RC" -eq 2 ] && has_text "$WORK/$1.err" "$2"
}

# ------------------------------------------------------------------------------
# no_docker_call: true when the docker stand-in was never called
# ------------------------------------------------------------------------------
no_docker_call() {
  [ ! -e "$WORK/docker-calls" ]
}

# ------------------------------------------------------------------------------
# plant_entry NAME LINE...: writes the lines to registry file NAME (none: empty)
# ------------------------------------------------------------------------------
plant_entry() {
  local entryName=$1

  shift

  mkdir -p "$SBX_CONFIG_DIR/sandboxes"
  : >"$SBX_CONFIG_DIR/sandboxes/$entryName"

  if [ "$#" -gt 0 ]; then
    printf '%s\n' "$@" >"$SBX_CONFIG_DIR/sandboxes/$entryName"
  fi
}

# ------------------------------------------------------------------------------
# lib_eval SNIPPET: runs SNIPPET after sourcing the real library and sbx_init
# ------------------------------------------------------------------------------
lib_eval() {
  ( . "$BIN/sbx-lib.sh"; sbx_init || exit 1; eval "$1" )
}
