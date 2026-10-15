#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of the sandbox rules: planted problems must fail the right rule
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/guard/sandbox-rules.sh (exit 0 = every case passes)
# Each case plants its problem in a scratch copy of the tree.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# edit_scratch_file FILE SED_SCRIPT: rewrites FILE of the scratch copy with the sed script; returns 1 on failure.
# --------------------------------------------------------------------------------
edit_scratch_file() {
  local editFile=$WORK/repo/$1

  sed "$2" "$editFile" >"$editFile.edited" || return 1
  mv "$editFile.edited" "$editFile"
}

# --------------------------------------------------------------------------------
# Cases of the supply chain and bundle wiring rules: a clean copy and one planted problem each
# --------------------------------------------------------------------------------
case_supply_chain_rules() {
  echo "--- supply chain and bundle wiring rules"

  make_scratch_repo || return 1
  run_scratch_guard "$WORK/supply-clean.out" supply-chain.sh
  expect "supply chain: a clean copy passes" equals "$GUARD_RC" 0

  make_scratch_repo || return 1
  run_scratch_guard "$WORK/bundle-clean.out" bundle-wiring.sh
  expect "bundle wiring: a clean copy passes" equals "$GUARD_RC" 0

  make_scratch_repo || return 1
  edit_scratch_file base/Dockerfile 's/^ARG NODE_VERSION$/ARG NODE_VERSION=1.2.3/' || return 1
  run_scratch_guard "$WORK/supply-default.out" supply-chain.sh
  expect "supply chain: a pin default in a Dockerfile fails" has_text "$WORK/supply-default.out" "FAIL: dockerfile_args_have_no_defaults"
  expect "supply chain: the pin default line is named" has_text "$WORK/supply-default.out" "ARG NODE_VERSION=1.2.3"

  make_scratch_repo || return 1
  printf 'DEAD_VERSION=1.0.0\n' >>"$WORK/repo/versions.env"
  run_scratch_guard "$WORK/supply-dead.out" supply-chain.sh
  expect "supply chain: a pin no Dockerfile declares fails" has_text "$WORK/supply-dead.out" "FAIL: every_dockerfile_arg_is_pinned"
  expect "supply chain: the dead pin is named" has_text "$WORK/supply-dead.out" "DEAD_VERSION"

  make_scratch_repo || return 1
  printf 'NODE_VERSION=24.21.0\n' >>"$WORK/repo/versions.env"
  run_scratch_guard "$WORK/supply-twice.out" supply-chain.sh
  expect "supply chain: a pin set twice fails" has_text "$WORK/supply-twice.out" "is set on more than one line"

  make_scratch_repo || return 1
  edit_scratch_file versions.env '/^GH_VERSION=/d' || return 1
  run_scratch_guard "$WORK/supply-missing.out" supply-chain.sh
  expect "supply chain: a declared pin missing from versions.env fails" has_text "$WORK/supply-missing.out" "GH_VERSION, which versions.env does not set"

  make_scratch_repo || return 1
  edit_scratch_file versions.env 's/^NODE_VERSION=.*/NODE_VERSION=24/' || return 1
  run_scratch_guard "$WORK/supply-short.out" supply-chain.sh
  expect "supply chain: a version that is not x.y.z fails" has_text "$WORK/supply-short.out" "is not an exact x.y.z version"

  make_scratch_repo || return 1
  edit_scratch_file versions.env 's/^UBUNTU_IMAGE=.*/UBUNTU_IMAGE=ubuntu:latest/' || return 1
  run_scratch_guard "$WORK/supply-floating.out" supply-chain.sh
  expect "supply chain: a floating image tag fails" has_text "$WORK/supply-floating.out" "FAIL: no_floating_latest_versions"

  make_scratch_repo || return 1
  edit_scratch_file versions.env 's/^\(TEMURIN_IMAGE=[^@]*\)@.*/\1/' || return 1
  run_scratch_guard "$WORK/supply-nodigest.out" supply-chain.sh
  expect "supply chain: an image pin without a digest fails" has_text "$WORK/supply-nodigest.out" "is not an image tag with its @sha256 digest"

  make_scratch_repo || return 1
  printf 'COPY outside.txt /etc/outside.txt\n' >>"$WORK/repo/claude/Dockerfile"
  : >"$WORK/repo/outside.txt"
  run_scratch_guard "$WORK/bundle-outside.out" bundle-wiring.sh
  expect "bundle wiring: a COPY source outside the allowlist fails" has_text "$WORK/bundle-outside.out" "FAIL: bundle_reaches_build_context"
  expect "bundle wiring: the outside COPY message names the allowlist" has_text "$WORK/bundle-outside.out" "outside base, claude, best-practices and versions.env"

  make_scratch_repo || return 1
  printf 'COPY --from=planted /opt/x /opt/x\n' >>"$WORK/repo/base/Dockerfile"
  run_scratch_guard "$WORK/bundle-from.out" bundle-wiring.sh
  expect "bundle wiring: a COPY from a build stage is not a build-context source" equals "$GUARD_RC" 0
}

# --------------------------------------------------------------------------------
# Cases of the supply chain rules against evasions (the banned names are built from parts, so this file does not hold them): the old GSD package in a hook, a manual helper and a support script, a download piped to a shell across a line break, through process substitution or through sh -c, an install without a pin, with a floating tag, with a literal version or with an undeclared pin, and a GSD install that is not the pinned official package
# --------------------------------------------------------------------------------
case_supply_chain_evasions() {
  local oldName=get-shit-done
  local plantedFile

  oldName=$oldName-cc

  echo "--- supply chain evasions"

  for plantedFile in claude/start.d/05-gsd tests/host/manual/h16-gsd-bump.sh tests/host/support/toolchain-probe.sh claude/managed-settings.json; do
    make_scratch_repo || return 1
    printf '# %s\n' "$oldName" >>"$WORK/repo/$plantedFile"
    run_scratch_guard "$WORK/supply-oldname.out" supply-chain.sh
    expect "supply chain: the old GSD package in $plantedFile fails" has_text "$WORK/supply-oldname.out" "FAIL: no_compromised_gsd_package"
    expect "supply chain: the old GSD package line in $plantedFile is named" has_text "$WORK/supply-oldname.out" "$plantedFile"
  done

  make_scratch_repo || return 1
  printf 'RUN curl -fsSL https://example.invalid/install.sh \\\n    | sh\n' >>"$WORK/repo/claude/Dockerfile"
  run_scratch_guard "$WORK/supply-pipe-break.out" supply-chain.sh
  expect "supply chain: a download piped to sh across a line break fails" has_text "$WORK/supply-pipe-break.out" "FAIL: no_pipe_to_shell_installers"

  make_scratch_repo || return 1
  printf 'RUN bash <(curl -fsSL https://example.invalid/install.sh)\n' >>"$WORK/repo/claude/Dockerfile"
  run_scratch_guard "$WORK/supply-process-subst.out" supply-chain.sh
  expect "supply chain: bash <(curl ...) fails" has_text "$WORK/supply-process-subst.out" "FAIL: no_pipe_to_shell_installers"

  make_scratch_repo || return 1
  printf 'RUN sh -c "$(curl -fsSL https://example.invalid/install.sh)"\n' >>"$WORK/repo/base/Dockerfile"
  run_scratch_guard "$WORK/supply-sh-c.out" supply-chain.sh
  expect "supply chain: sh -c with a downloaded script fails" has_text "$WORK/supply-sh-c.out" "FAIL: no_pipe_to_shell_installers"

  make_scratch_repo || return 1
  printf 'RUN npm install -g leftpad\n' >>"$WORK/repo/claude/Dockerfile"
  run_scratch_guard "$WORK/supply-npm-nopin.out" supply-chain.sh
  expect "supply chain: an npm install without a version fails" has_text "$WORK/supply-npm-nopin.out" "FAIL: installs_use_declared_pins"
  expect "supply chain: the unpinned package is named" has_text "$WORK/supply-npm-nopin.out" "leftpad"

  make_scratch_repo || return 1
  printf 'RUN npm install -g "leftpad@next"\n' >>"$WORK/repo/claude/Dockerfile"
  run_scratch_guard "$WORK/supply-npm-tag.out" supply-chain.sh
  expect "supply chain: an npm install at a floating tag fails" has_text "$WORK/supply-npm-tag.out" "FAIL: installs_use_declared_pins"

  make_scratch_repo || return 1
  printf 'RUN npm install -g "leftpad@1.3.0"\n' >>"$WORK/repo/claude/Dockerfile"
  run_scratch_guard "$WORK/supply-npm-literal.out" supply-chain.sh
  expect "supply chain: an npm install at a version typed into the Dockerfile fails" has_text "$WORK/supply-npm-literal.out" "FAIL: installs_use_declared_pins"

  make_scratch_repo || return 1
  printf 'RUN npm install -g "leftpad@${LEFTPAD_VERSION}"\n' >>"$WORK/repo/claude/Dockerfile"
  run_scratch_guard "$WORK/supply-npm-undeclared.out" supply-chain.sh
  expect "supply chain: an npm install at an undeclared pin fails" has_text "$WORK/supply-npm-undeclared.out" "FAIL: installs_use_declared_pins"
  expect "supply chain: the undeclared pin is named" has_text "$WORK/supply-npm-undeclared.out" "LEFTPAD_VERSION"

  make_scratch_repo || return 1
  printf 'RUN npx -y leftpad\n' >>"$WORK/repo/claude/Dockerfile"
  run_scratch_guard "$WORK/supply-npx.out" supply-chain.sh
  expect "supply chain: npx in a Dockerfile fails" has_text "$WORK/supply-npx.out" "FAIL: installs_use_declared_pins"

  make_scratch_repo || return 1
  edit_scratch_file claude/Dockerfile 's|@opengsd/gsd-core@${GSD_CORE_VERSION}|leftpad@${GSD_CORE_VERSION}|' || return 1
  run_scratch_guard "$WORK/supply-gsd-other.out" supply-chain.sh
  expect "supply chain: a GSD install that is not the official package fails" has_text "$WORK/supply-gsd-other.out" "FAIL: gsd_installs_only_the_official_package"
}

# --------------------------------------------------------------------------------
# Cases of the start rules: a clean copy, a working_dir under the project folder and a GSD hook that sorts after the bundle hook
# --------------------------------------------------------------------------------
case_start_rules() {
  echo "--- start rules"

  make_scratch_repo || return 1
  run_scratch_guard "$WORK/start-clean.out" start.sh
  expect "sandbox rules: a clean copy passes the start rules" equals "$GUARD_RC" 0

  make_scratch_repo || return 1
  edit_scratch_file compose.yml 's|^\( *working_dir: \).*$|\1"/home/sandbox/workspace/${SBX_NAME}"|' || return 1
  run_scratch_guard "$WORK/start-under.out" start.sh
  expect "sandbox rules: a working_dir under the project folder fails" has_text "$WORK/start-under.out" "FAIL: compose_starts_in_the_workspace"
  expect "sandbox rules: that working_dir line is named" has_text "$WORK/start-under.out" 'working_dir: "/home/sandbox/workspace/${SBX_NAME}"'
  expect "sandbox rules: a working_dir under the project folder exits non-zero" test "$GUARD_RC" -ne 0

  make_scratch_repo || return 1
  edit_scratch_file compose.yml 's/^\( *\)scale: 0$/\1scale: 1/' || return 1
  run_scratch_guard "$WORK/start-scaled.out" start.sh
  expect "sandbox rules: a name check that can run a container fails" has_text "$WORK/start-scaled.out" "FAIL: compose_checks_the_name_before_it_acts"

  make_scratch_repo || return 1
  edit_scratch_file compose.yml '/image: "sbx-${SBX_NAME}-name-check"/d' || return 1
  run_scratch_guard "$WORK/start-nocheck.out" start.sh
  expect "sandbox rules: a compose.yml without the name check fails" has_text "$WORK/start-nocheck.out" "FAIL: compose_checks_the_name_before_it_acts"
  expect "sandbox rules: a missing name check exits non-zero" test "$GUARD_RC" -ne 0

  make_scratch_repo || return 1
  mv "$WORK/repo/claude/start.d/05-gsd" "$WORK/repo/claude/start.d/20-gsd" || return 1
  run_scratch_guard "$WORK/start-gsd-late.out" start.sh
  expect "start hooks: a GSD hook that sorts after the bundle hook fails" has_text "$WORK/start-gsd-late.out" "FAIL: gsd_sync_runs_before_the_bundle"
  expect "start hooks: the late GSD hook is named" has_text "$WORK/start-gsd-late.out" "20-gsd"
}

# ------------------------------------------------------------------------------
# case_state_folder_rule: a clean copy, then a Claude image that replaces SBX_STATE_DIRS
# ------------------------------------------------------------------------------
case_state_folder_rule() {
  echo "--- state folder rule"

  make_scratch_repo || return 1
  run_scratch_guard "$WORK/state-clean.out" start.sh
  expect "state folders: a clean copy passes the start rules" equals "$GUARD_RC" 0

  make_scratch_repo || return 1
  edit_scratch_file claude/Dockerfile 's|^\( *SBX_STATE_DIRS=\).*$|\1claude \\|' || return 1
  run_scratch_guard "$WORK/state-replace.out" start.sh
  expect "state folders: a Claude image that replaces SBX_STATE_DIRS fails" has_text "$WORK/state-replace.out" "FAIL: agent_image_keeps_base_state_folders"
  expect "state folders: the replacing line is named" has_text "$WORK/state-replace.out" "replaces SBX_STATE_DIRS"
}

# ------------------------------------------------------------------------------
# case_isolation_rule: a clean copy, then privileged: true in the sandbox service
# ------------------------------------------------------------------------------
# The scratch copy has no .git, so only the named rule line is read from the output.
# ------------------------------------------------------------------------------
case_isolation_rule() {
  echo "--- isolation rule"

  make_scratch_repo || return 1
  run_scratch_guard "$WORK/isolation-clean.out" isolation.sh
  expect "isolation: a clean copy passes the socket and privileges rule" has_text "$WORK/isolation-clean.out" "PASS: no_docker_socket_or_privileges"

  make_scratch_repo || return 1
  edit_scratch_file compose.yml "/^    init: true/a\\
    privileged: true" || return 1
  run_scratch_guard "$WORK/isolation-privileged.out" isolation.sh
  expect "isolation: privileged: true in the sandbox service fails" has_text "$WORK/isolation-privileged.out" "FAIL: no_docker_socket_or_privileges"
  expect "isolation: the privileged line is named" has_text "$WORK/isolation-privileged.out" "    privileged: true"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_supply_chain_rules
case_supply_chain_evasions
case_start_rules
case_state_folder_rule
case_isolation_rule
finish_cases
