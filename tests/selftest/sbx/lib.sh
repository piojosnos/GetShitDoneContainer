#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Shared by the sbx self-test groups: work folder, Docker at nothing, runners
# ------------------------------------------------------------------------------
# Sourced by the groups, never run directly (functions only).
# ------------------------------------------------------------------------------

. "$(dirname "${BASH_SOURCE[0]}")/../lib-expect.sh"

# ------------------------------------------------------------------------------
# start_group: enters the repo root, makes WORK and the registry, points Docker
# at a socket that does not exist
# ------------------------------------------------------------------------------
# No case can reach a Docker daemon. DOCKER_CONTEXT is unset because the Docker
# CLI lets it override DOCKER_HOST. SBX_CONFIG_DIR keeps the user's registry
# out.
# ------------------------------------------------------------------------------
start_group() {
  enter_repo_root || return 1

  BIN=$REPO/bin

  make_work_folder sbxtest || return 1

  SBX_CONFIG_DIR=$WORK/cfg
  export SBX_CONFIG_DIR
  unset SBX_DIR SBX_NAME DOCKER_CONTEXT

  DOCKER_HOST=unix:///nonexistent
  export DOCKER_HOST
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
