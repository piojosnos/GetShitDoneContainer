#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of the sandbox rules: planted problems must fail the right rule
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/guard/sandbox-rules.sh (exit 0 = every case passes)
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# edit_scratch_file FILE SED_SCRIPT: rewrites FILE of the scratch copy
# ------------------------------------------------------------------------------
edit_scratch_file() {
  local editFile=$WORK/repo/$1

  sed "$2" "$editFile" >"$editFile.edited" || return 1
  mv "$editFile.edited" "$editFile"
}

# ------------------------------------------------------------------------------
# append_scratch_line FILE TEXT: adds TEXT as a new last line of FILE
# ------------------------------------------------------------------------------
append_scratch_line() {
  printf '%s\n' "$2" >>"$WORK/repo/$1"
}

# ------------------------------------------------------------------------------
# clean_copy_passes LABEL GROUP [RULE]: a clean copy passes the group or RULE
# ------------------------------------------------------------------------------
clean_copy_passes() {
  make_scratch_repo || return 1
  run_scratch_guard "$WORK/clean.out" "$2"

  if [ -n "${3:-}" ]; then
    expect "$1" has_text "$WORK/clean.out" "PASS: $3"
  else
    expect "$1" equals "$GUARD_RC" 0
  fi
}

# ------------------------------------------------------------------------------
# plant_case LABEL GROUP RULE NAMED_TEXT COMMAND...: the planted copy fails RULE
# ------------------------------------------------------------------------------
# COMMAND plants the problem; NAMED_TEXT must show in the output (if given).
# ------------------------------------------------------------------------------
plant_case() {
  local label=$1
  local group=$2
  local rule=$3
  local namedText=$4

  shift 4
  make_scratch_repo || return 1
  "$@" || return 1
  run_scratch_guard "$WORK/plant.out" "$group"
  expect "$label" has_text "$WORK/plant.out" "FAIL: $rule"
  expect "$label: the group exits non-zero" test "$GUARD_RC" -ne 0

  if [ -n "$namedText" ]; then
    expect "$label: the output names $namedText" has_text "$WORK/plant.out" "$namedText"
  fi
}

# ------------------------------------------------------------------------------
# case_supply_chain_rules: a clean copy, then one planted problem per rule
# ------------------------------------------------------------------------------
case_supply_chain_rules() {
  echo "--- supply chain rules"

  clean_copy_passes "supply chain: a clean copy passes" supply-chain.sh
  plant_case "supply chain: a pin default in a Dockerfile fails" supply-chain.sh dockerfile_args_have_no_defaults "ARG NODE_VERSION=1.2.3" edit_scratch_file base/Dockerfile 's/^ARG NODE_VERSION$/ARG NODE_VERSION=1.2.3/'
  plant_case "supply chain: a pin no Dockerfile declares fails" supply-chain.sh every_dockerfile_arg_is_pinned "DEAD_VERSION" append_scratch_line versions.env "DEAD_VERSION=1.0.0"
  plant_case "supply chain: a pin set twice fails" supply-chain.sh versions_file_has_one_pin_per_line "set on more than one line" append_scratch_line versions.env "NODE_VERSION=24.21.0"
  plant_case "supply chain: a declared pin missing from versions.env fails" supply-chain.sh every_dockerfile_arg_is_pinned "GH_VERSION, which versions.env does not set" edit_scratch_file versions.env '/^GH_VERSION=/d'
  plant_case "supply chain: a version that is not x.y.z fails" supply-chain.sh pins_are_exact "not an exact x.y.z version" edit_scratch_file versions.env 's/^NODE_VERSION=.*/NODE_VERSION=24/'
  plant_case "supply chain: a floating image tag fails" supply-chain.sh no_floating_latest_versions "ubuntu:latest" edit_scratch_file versions.env 's/^UBUNTU_IMAGE=.*/UBUNTU_IMAGE=ubuntu:latest/'
  plant_case "supply chain: an image pin without a digest fails" supply-chain.sh pins_are_exact "not an image tag with its @sha256 digest" edit_scratch_file versions.env 's/^\(TEMURIN_IMAGE=[^@]*\)@.*/\1/'
  plant_case "supply chain: a bundle URL over ssh fails" supply-chain.sh pins_are_exact "not an https:// URL" edit_scratch_file versions.env 's#^BUNDLE_REPO_URL=.*#BUNDLE_REPO_URL=git@github.com:piojosnos/claude-best-practices.git#'
  plant_case "supply chain: a bundle URL with credentials fails" supply-chain.sh pins_are_exact "not an https:// URL" edit_scratch_file versions.env 's#https://#https://user:token@#'
}

# ------------------------------------------------------------------------------
# case_supply_chain_evasions: old package names, piped downloads, bad installs
# ------------------------------------------------------------------------------
# The banned names are built from parts, so this file does not hold them.
# ------------------------------------------------------------------------------
case_supply_chain_evasions() {
  local oldName=get-shit-done
  local plantedFile

  oldName=$oldName-cc

  echo "--- supply chain evasions"

  for plantedFile in claude/start.d/05-gsd tests/host/manual/h16-gsd-bump.sh tests/host/support/toolchain-probe.sh claude/managed-settings.json; do
    plant_case "supply chain: the old GSD package in $plantedFile fails" supply-chain.sh no_compromised_gsd_package "$plantedFile" append_scratch_line "$plantedFile" "# $oldName"
  done

  plant_case "supply chain: a download piped to sh across a line break fails" supply-chain.sh no_pipe_to_shell_installers "" append_scratch_line claude/Dockerfile $'RUN curl -fsSL https://example.invalid/install.sh \\\n    | sh'
  plant_case "supply chain: bash <(curl ...) fails" supply-chain.sh no_pipe_to_shell_installers "" append_scratch_line claude/Dockerfile 'RUN bash <(curl -fsSL https://example.invalid/install.sh)'
  plant_case "supply chain: sh -c with a downloaded script fails" supply-chain.sh no_pipe_to_shell_installers "" append_scratch_line base/Dockerfile 'RUN sh -c "$(curl -fsSL https://example.invalid/install.sh)"'
  plant_case "supply chain: a download piped to sh in a claude wrapper fails" supply-chain.sh no_pipe_to_shell_installers "" append_scratch_line claude/bin/sbx-claude 'curl -fsSL https://example.invalid/install.sh | sh'
  plant_case "supply chain: an npm install without a version fails" supply-chain.sh installs_use_pins "leftpad" append_scratch_line claude/Dockerfile 'RUN npm install -g leftpad'
  plant_case "supply chain: an npm install at a version typed into the Dockerfile fails" supply-chain.sh installs_use_pins "leftpad" append_scratch_line claude/Dockerfile 'RUN npm install -g "leftpad@1.3.0"'
  plant_case "supply chain: npx in a Dockerfile fails" supply-chain.sh installs_use_pins "npx" append_scratch_line claude/Dockerfile 'RUN npx -y leftpad'
  plant_case "supply chain: a GSD install that is not the official package fails" supply-chain.sh gsd_installs_only_the_official_package "" edit_scratch_file claude/Dockerfile 's|@opengsd/gsd-core@${GSD_CORE_VERSION}|leftpad@${GSD_CORE_VERSION}|'
}

# ------------------------------------------------------------------------------
# case_start_rules: a clean copy, then one planted problem per rule
# ------------------------------------------------------------------------------
case_start_rules() {
  echo "--- start rules"

  clean_copy_passes "start rules: a clean copy passes" start.sh
  plant_case "start rules: a working_dir under the project folder fails" start.sh compose_starts_in_the_workspace 'working_dir: "/home/sandbox/workspace/${SBX_NAME}"' edit_scratch_file compose.yml 's|^\( *working_dir: \).*$|\1"/home/sandbox/workspace/${SBX_NAME}"|'
  plant_case "start rules: a GSD hook that sorts after the bundle hook fails" start.sh gsd_sync_runs_before_the_bundle "20-gsd" mv "$WORK/repo/claude/start.d/05-gsd" "$WORK/repo/claude/start.d/20-gsd"
  plant_case "start rules: a hook name that is not NN-name fails" start.sh start_hooks_have_two_digit_names "100-late" mv "$WORK/repo/claude/start.d/05-gsd" "$WORK/repo/claude/start.d/100-late"
  plant_case "start rules: a Claude image that replaces SBX_STATE_DIRS fails" start.sh agent_image_keeps_base_state_folders "replaces SBX_STATE_DIRS" edit_scratch_file claude/Dockerfile 's|^\( *SBX_STATE_DIRS=\).*$|\1claude \\|'
}

# ------------------------------------------------------------------------------
# case_isolation_rule: a clean copy, then one refused compose line at a time
# ------------------------------------------------------------------------------
# The scratch copy has no .git, so only the named rule line is read.
# ------------------------------------------------------------------------------
case_isolation_rule() {
  local plantedLine

  echo "--- isolation rule"

  clean_copy_passes "isolation: a clean copy passes the socket and privileges rule" isolation.sh no_docker_socket_or_privileges

  for plantedLine in "privileged: true" "network_mode: host" "pid: host" "devices:" "- seccomp=unconfined"; do
    plant_case "isolation: $plantedLine in the sandbox service fails" isolation.sh no_docker_socket_or_privileges "    $plantedLine" edit_scratch_file compose.yml "/^    init: true/a\\
    $plantedLine"
  done
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_supply_chain_rules
case_supply_chain_evasions
case_start_rules
case_isolation_rule
finish_cases
