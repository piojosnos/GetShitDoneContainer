#!/usr/bin/env bash
# Guard rules on the supply chain: GSD comes from one package, and every tool is pinned and never piped into a shell.
# - Run by tests/guard/run-all.sh; runs alone too.
# - Usage, from anywhere: bash tests/guard/supply-chain.sh   (exit 0 = every rule holds)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# no_compromised_gsd_package: GSD must come only from @opengsd/gsd-core: the old package was compromised.
# --------------------------------------------------------------------------------
no_compromised_gsd_package() {
  nowhere_matches 'get-shit-done-cc|gsd-build' $SANDBOX_FILES SANDBOX.md tests/host-checklist.md tests/host/*.sh tests/selftest/*.sh tests/selftest/*/*.sh tests/selftest/*/support/*
}

# --------------------------------------------------------------------------------
# no_pipe_to_shell_installers: Nothing is installed by piping a download into a shell (unverified code).
# --------------------------------------------------------------------------------
no_pipe_to_shell_installers() {
  nowhere_matches '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh([[:space:]]|$)' $DOCKERFILES
}

# --------------------------------------------------------------------------------
# no_floating_latest_versions: No floating versions: what is in the image changes only when a pin changes.
# --------------------------------------------------------------------------------
no_floating_latest_versions() {
  nowhere_matches ':latest|@latest' $SANDBOX_FILES
}

# --------------------------------------------------------------------------------
# versions_are_pinned: Every tool version is an exact pin.
# --------------------------------------------------------------------------------
versions_are_pinned() {
  has_line $BASE 'FROM ubuntu:24.04' \
    && grep -Eq '^ARG NODE_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' $BASE \
    && grep -Eq '^ARG GH_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' $BASE \
    && grep -Eq '^ARG CLAUDE_CODE_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' $CLAUDE
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  no_compromised_gsd_package \
  no_pipe_to_shell_installers \
  no_floating_latest_versions \
  versions_are_pinned || exit 1
