#!/usr/bin/env bash
# Guard rules on isolation: no Docker socket or sudo, one mount, no privileges, the old layout untouched.
# - Run by tests/guard/run-all.sh; runs alone too.
# - Usage, from anywhere: bash tests/guard/isolation.sh   (exit 0 = every rule holds)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Constants: the commit the old layout is compared with
# --------------------------------------------------------------------------------
# Used by old_layout_untouched: the old ClaudeCode/ layout as it is on main.
# Remove both when the old layout is retired.
OLD_LAYOUT_COMMIT=304f80d1a0705d9ab668ef2ed4acd9fcf65060ac

# --------------------------------------------------------------------------------
# no_docker_socket_or_sudo: The agent must not reach the Docker daemon or become root.
# --------------------------------------------------------------------------------
no_docker_socket_or_sudo() {
  nowhere_matches 'docker\.sock' $COMPOSE && nowhere_matches '\bsudo\b' $DOCKERFILES
}

# --------------------------------------------------------------------------------
# exactly_one_mount_and_not_over_home: Exactly one mount: the sandbox folder, at /home/sandbox/workspace.
# --------------------------------------------------------------------------------
# Never over /home/sandbox itself, and no Docker volumes (they can be deleted with the container).
exactly_one_mount_and_not_over_home() {
  [ "$(grep -Ec '^[[:space:]]*- type: bind$' $COMPOSE)" -eq 1 ] \
    && grep -Eq '^[[:space:]]*target: /home/sandbox/workspace$' $COMPOSE \
    && nowhere_matches 'target:[[:space:]]*"?/home/sandbox"?[[:space:]]*$' $COMPOSE \
    && nowhere_matches '^volumes:|type: volume' $COMPOSE \
    && nowhere_matches '^[[:space:]]*VOLUME([[:space:]]|$)' $DOCKERFILES
}

# --------------------------------------------------------------------------------
# runs_without_privileges: The agent runs as the non-root sandbox user, with no extra privileges.
# --------------------------------------------------------------------------------
runs_without_privileges() {
  [ "$(grep -E '^USER' $BASE | tail -n 1)" = "USER sandbox" ] \
    && [ "$(grep -E '^USER' $CLAUDE | tail -n 1)" = "USER sandbox" ] \
    && grep -Fq 'no-new-privileges:true' $COMPOSE \
    && grep -A1 'cap_drop:' $COMPOSE | grep -Fq -- '- ALL'
}

# --------------------------------------------------------------------------------
# old_layout_untouched: The old layout keeps working until it is retired: no change to its files.
# --------------------------------------------------------------------------------
old_layout_untouched() {
  git diff --quiet "$OLD_LAYOUT_COMMIT" -- ClaudeCode OpenCode README.md \
    && [ -z "$(git ls-files --others --exclude-standard -- ClaudeCode OpenCode)" ]
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  no_docker_socket_or_sudo \
  exactly_one_mount_and_not_over_home \
  runs_without_privileges \
  old_layout_untouched || exit 1
