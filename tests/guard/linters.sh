#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Guard rules: shellcheck passes on every script, hadolint on both Dockerfiles
# ------------------------------------------------------------------------------
# Usage, from anywhere: bash tests/guard/linters.sh (exit 0 = every rule holds)
# A missing linter is a failure, never a skip.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# Rule shellcheck_passes: every script in SHELL_FILES is clean at warning level
# ------------------------------------------------------------------------------
# No -x: following sourced files hangs on this tree, so each file stands alone.
# ------------------------------------------------------------------------------
shellcheck_passes() {
  local findings

  if ! command -v shellcheck >/dev/null 2>&1; then
    echo "    shellcheck is not installed (it ships in sbx-base)"
    return 1
  fi

  if findings=$(shellcheck --rcfile .shellcheckrc -S warning -f gcc $SHELL_FILES 2>&1); then
    return 0
  fi

  printf '%s\n' "$findings" | sed 's/^/    /'
  return 1
}

# ------------------------------------------------------------------------------
# Rule hadolint_passes: both Dockerfiles are clean at warning level
# ------------------------------------------------------------------------------
# --config is explicit, so a stray file in HOME cannot change the result.
# ------------------------------------------------------------------------------
hadolint_passes() {
  local findings

  if ! command -v hadolint >/dev/null 2>&1; then
    echo "    hadolint is not installed (it ships in sbx-base)"
    return 1
  fi

  if findings=$(hadolint --no-color --config .hadolint.yaml $DOCKERFILES 2>&1); then
    return 0
  fi

  printf '%s\n' "$findings" | sed 's/^/    /'
  return 1
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules shellcheck_passes hadolint_passes || exit 1
