#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Running sbx-* scripts from the host tests: own registry, /bin/bash, sandbox
# ------------------------------------------------------------------------------
# Sourced after lib.sh by the checks that use bin/; functions only.
# Each registry is in the run folder, so ~/.config/sbx is never touched.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# sbx_test_setup ID PREFIX: sets the registry, the sandbox folder and the PATH
# ------------------------------------------------------------------------------
# Sets and exports SBX_CONFIG_DIR; sets sbxDir (with a space on purpose),
# sbxBinDir (a bash link to /bin/bash) and sbxPath. Fails for ID without RUN.
# ------------------------------------------------------------------------------
sbx_test_setup() {
  local checkId=$1
  local bashVersion

  if [ -z "${RUN:-}" ]; then
    fail "$checkId" "no run folder" "run: bash tests/host/run-all.sh first"
    return 1
  fi

  SBX_CONFIG_DIR=$RUN/$2-sbxcfg-$$
  export SBX_CONFIG_DIR
  sbxDir="$RUN/$2-$$ spaced dir"
  sbxBinDir=$RUN/$2-bash-$$
  sbxPath=$sbxBinDir:$REPO_DIR/bin:$PATH

  case "$SBX_CONFIG_DIR" in
    "$RUN"/*)
      ;;
    *)
      fail "$checkId" "the registry is not inside the run folder: $SBX_CONFIG_DIR"
      return 1
      ;;
  esac

  mkdir -p "$sbxBinDir" || return 1
  ln -s /bin/bash "$sbxBinDir/bash" || return 1

  bashVersion=$(/bin/bash -c 'printf %s "$BASH_VERSION"')
  info "$checkId runs bin/ through PATH with /bin/bash $bashVersion; registry $SBX_CONFIG_DIR"
}

# ------------------------------------------------------------------------------
# run_sbx LOG_NAME SCRIPT ARG...: runs a bin/ script by name, sets sbxStatus
# ------------------------------------------------------------------------------
# The bogus exported values prove the scripts take everything from the registry.
# Output goes to RUN/logs/LOG_NAME.out and .err; stdin is closed.
# ------------------------------------------------------------------------------
run_sbx() {
  local logName=$1

  shift

  run_timeout 900 env PATH="$sbxPath" SBX_DIR=/nonexistent-ambient SBX_NAME=ambient COMPOSE_PROJECT_NAME=sbx-ambient "$@" >"$RUN/logs/$logName.out" 2>"$RUN/logs/$logName.err" </dev/null
  sbxStatus=$?
}

# ------------------------------------------------------------------------------
# restore_test_sandbox LOG_PREFIX: puts the test sandbox back on the run folder
# ------------------------------------------------------------------------------
# The later checks need the test sandbox on the run folder again.
# ------------------------------------------------------------------------------
restore_test_sandbox() {
  if ! compose_down >"$RUN/logs/$1-restore-down.log" 2>&1; then
    add_problem "restoring the test sandbox: compose down failed; log: $RUN/logs/$1-restore-down.log"
  fi

  if ! compose_up >"$RUN/logs/$1-restore-up.log" 2>&1; then
    add_problem "restoring the test sandbox: compose up failed; log: $RUN/logs/$1-restore-up.log"
  fi
}

# ------------------------------------------------------------------------------
# sandbox_field FORMAT: prints a docker inspect field of the test container
# ------------------------------------------------------------------------------
sandbox_field() {
  docker container inspect --format "$1" "$CONTAINER" 2>/dev/null </dev/null
}
