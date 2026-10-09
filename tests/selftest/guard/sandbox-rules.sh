#!/usr/bin/env bash
# Self-test of the sandbox rules: the supply chain and bundle wiring rules pass on a clean copy and name each planted pin or COPY problem; the start rules pass on a clean copy and fail, naming the line, when working_dir is put back under the project folder, and fail when the name-check service is gone or can run a container; the state folder rule fails when the Claude image replaces SBX_STATE_DIRS, and the npm cache rule fails, naming the line, on an npm install without the throwaway cache; the docs rule passes on a clean copy and fails, naming the line, when an image comment promises that nothing is created or SANDBOX.md promises a good build, and fails when a doc's name pattern differs from the code, a doc states the old name rule or the fake docker invents a Compose refusal.
# - Run by run-all.sh; runs alone too.
# - Runs the real tests/guard/start.sh and tests/guard/docs.sh inside a scratch copy of the tree, so a planted problem never touches the real files.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/guard/sandbox-rules.sh   (exit 0 = every case passes)
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
  expect "supply chain: a pin default in a Dockerfile fails" has_text "$WORK/supply-default.out" "FAIL: versions_are_pinned"
  expect "supply chain: the pin default line is named" has_text "$WORK/supply-default.out" "ARG NODE_VERSION=1.2.3"

  make_scratch_repo || return 1
  printf 'DEAD_VERSION=1.0.0\n' >>"$WORK/repo/versions.env"
  run_scratch_guard "$WORK/supply-dead.out" supply-chain.sh
  expect "supply chain: a pin no Dockerfile declares fails" has_text "$WORK/supply-dead.out" "FAIL: versions_are_pinned"
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

# --------------------------------------------------------------------------------
# Cases of the state folder and npm cache rules (the scratch copy has no .git, so only the named rule line is read from the isolation output): a clean copy, a Claude image that replaces SBX_STATE_DIRS and an npm install without the throwaway cache
# --------------------------------------------------------------------------------
case_state_and_cache_rules() {
  echo "--- state folder and npm cache rules"

  make_scratch_repo || return 1
  run_scratch_guard "$WORK/state-clean.out" start.sh
  expect "state folders: a clean copy passes the start rules" equals "$GUARD_RC" 0
  run_scratch_guard "$WORK/cache-clean.out" isolation.sh
  expect "npm cache: a clean copy passes the npm cache rule" has_text "$WORK/cache-clean.out" "PASS: npm_builds_keep_their_cache_out_of_the_mount"

  make_scratch_repo || return 1
  edit_scratch_file claude/Dockerfile 's|^\( *SBX_STATE_DIRS=\).*$|\1claude \\|' || return 1
  run_scratch_guard "$WORK/state-replace.out" start.sh
  expect "state folders: a Claude image that replaces SBX_STATE_DIRS fails" has_text "$WORK/state-replace.out" "FAIL: agent_image_keeps_base_state_folders"
  expect "state folders: the replacing line is named" has_text "$WORK/state-replace.out" "replaces SBX_STATE_DIRS"

  make_scratch_repo || return 1
  printf 'RUN npm install -g planted-package\n' >>"$WORK/repo/claude/Dockerfile"
  run_scratch_guard "$WORK/cache-planted.out" isolation.sh
  expect "npm cache: an npm install without the throwaway cache fails" has_text "$WORK/cache-planted.out" "FAIL: npm_builds_keep_their_cache_out_of_the_mount"
  expect "npm cache: the planted install line is named" has_text "$WORK/cache-planted.out" "npm install -g planted-package"
}

# --------------------------------------------------------------------------------
# Cases of the docs rules: a clean copy, an image comment that promises nothing is created, a doc that promises a good build, a drifted name pattern, the old name rule and an invented Compose refusal in the fake docker
# --------------------------------------------------------------------------------
case_docs_rule() {
  echo "--- docs rule"

  make_scratch_repo || return 1
  edit_scratch_file base/Dockerfile 's/never creates anything on the Mac/may be asked not to create a folder on the Mac/' || return 1
  run_scratch_guard "$WORK/docs-clean.out" docs.sh
  expect "sandbox rules: an image comment without the promise passes the docs rule" equals "$GUARD_RC" 0

  make_scratch_repo || return 1
  printf '# - It never creates anything on the Mac.\n' >>"$WORK/repo/base/Dockerfile"
  run_scratch_guard "$WORK/docs-promise.out" docs.sh
  expect "sandbox rules: a promise that nothing is created fails" has_text "$WORK/docs-promise.out" "FAIL: docs_promise_only_what_happens"
  expect "sandbox rules: the promising line is named" has_text "$WORK/docs-promise.out" "never creates anything on the Mac"

  make_scratch_repo || return 1
  printf 'When it passes, the build is good.\n' >>"$WORK/repo/SANDBOX.md"
  run_scratch_guard "$WORK/docs-good-build.out" docs.sh
  expect "sandbox rules: a doc that promises a good build fails" has_text "$WORK/docs-good-build.out" "FAIL: docs_promise_only_what_happens"
  expect "sandbox rules: the good-build line is named" has_text "$WORK/docs-good-build.out" "When it passes, the build is good."
  expect "sandbox rules: a doc that promises a good build exits non-zero" test "$GUARD_RC" -ne 0

  make_scratch_repo || return 1
  edit_scratch_file SANDBOX.md 's/{0,30}/{0,40}/' || return 1
  run_scratch_guard "$WORK/docs-pattern.out" docs.sh
  expect "sandbox rules: a doc whose name pattern differs from the code fails" has_text "$WORK/docs-pattern.out" "FAIL: docs_state_the_sandbox_name_rule"
  expect "sandbox rules: the differing pattern is reported" has_text "$WORK/docs-pattern.out" "SANDBOX.md does not state the name pattern"

  make_scratch_repo || return 1
  printf 'SBX_NAME: lowercase letters, digits, - and _.\n' >>"$WORK/repo/SANDBOX.md"
  run_scratch_guard "$WORK/docs-old-rule.out" docs.sh
  expect "sandbox rules: the old name rule in a doc fails" has_text "$WORK/docs-old-rule.out" "FAIL: docs_state_the_sandbox_name_rule"
  expect "sandbox rules: the old rule line is named" has_text "$WORK/docs-old-rule.out" "SBX_NAME: lowercase letters, digits, - and _."

  make_scratch_repo || return 1
  printf '# fake note: "sbx-X" is not a valid project name\n' >>"$WORK/repo/tests/selftest/host/support/fake-docker"
  run_scratch_guard "$WORK/docs-fake-refusal.out" docs.sh
  expect "sandbox rules: an invented Compose refusal in the fake docker fails" has_text "$WORK/docs-fake-refusal.out" "FAIL: fake_docker_claims_only_real_compose"
  expect "sandbox rules: the invented refusal line is named" has_text "$WORK/docs-fake-refusal.out" 'fake note: "sbx-X" is not a valid project name'
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_supply_chain_rules
case_start_rules
case_state_and_cache_rules
case_docs_rule
finish_cases
