#!/usr/bin/env bash
# H-03: variables reach compose.yml. The project name is sbx-hosttest, and a missing
# SBX_DIR is refused with a message that names it.
# Depends on: nothing
# Needs: nothing
set -u
. "$(dirname "$0")/lib.sh"
host_init

# --------------------------------------------------------------------------------
# Renders the compose config with and without SBX_DIR
# --------------------------------------------------------------------------------
read_configs() {
  if [ -n "$RUN" ]; then
    nameOutput=$(compose_cmd config 2>&1)
  else
    nameOutput=$(SBX_NAME=hosttest SBX_DIR=/sbx-hosttest-config-only docker compose --env-file /dev/null -f "$REPO_DIR/compose.yml" config </dev/null 2>&1)
  fi

  missingOutput=$(env -u SBX_DIR SBX_NAME=hosttest docker compose --env-file /dev/null -f "$REPO_DIR/compose.yml" config </dev/null 2>&1)
  missingStatus=$?
}

# --------------------------------------------------------------------------------
# Checks the project name is sbx-hosttest
# --------------------------------------------------------------------------------
check_project_name() {
  if ! printf '%s\n' "$nameOutput" | grep -Fxq 'name: sbx-hosttest'; then
    add_problem "expected the line 'name: sbx-hosttest' in the config; got: $(first_lines "$nameOutput")"
  fi
}

# --------------------------------------------------------------------------------
# Checks a missing SBX_DIR is refused by name
# --------------------------------------------------------------------------------
check_missing_dir_refused() {
  if [ "$missingStatus" -eq 0 ] || [[ "$missingOutput" != *"SBX_DIR is required"* ]]; then
    add_problem "expected 'SBX_DIR is required' and a non-zero exit without SBX_DIR; got exit $missingStatus: $(first_lines "$missingOutput")"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
read_configs
check_project_name
check_missing_dir_refused
report_check H-03 "variable interpolation is wrong" \
  "the project name is sbx-hosttest and a missing SBX_DIR is refused by name"
