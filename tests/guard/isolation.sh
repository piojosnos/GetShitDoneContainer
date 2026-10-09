#!/usr/bin/env bash
# Guard rules on isolation: no Docker socket or sudo, one mount, no privileges, no npm cache and nothing else baked under the mount point, the old layout untouched.
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
# npm_builds_keep_their_cache_out_of_the_mount: A build-time npm call inherits the image's NPM_CONFIG_CACHE, which points under the mount point; the image must hold nothing there.
# --------------------------------------------------------------------------------
# Every RUN step that calls npm must export NPM_CONFIG_CACHE=/tmp/npm-cache, so every npm call in it,
# not only the first, writes its cache and its logs to /tmp.
npm_builds_keep_their_cache_out_of_the_mount() {
  local dockerfile
  local hits=""

  for dockerfile in $DOCKERFILES; do
    hits="$hits$(awk -v file="$dockerfile" '
      function check_step() {
        if (step != "" && step ~ /(^|[^A-Za-z_])npm[[:space:]]/ && index(step, "export NPM_CONFIG_CACHE=/tmp/npm-cache") == 0) {
          print file ":" step_line ": " step
        }
        step = ""
      }
      /^RUN[[:space:]]/ { check_step(); step_line = NR; step = $0; continuing = /\\$/; next }
      continuing { step = step " " $0; continuing = /\\$/; next }
      { check_step() }
      END { check_step() }
    ' "$dockerfile")"
  done

  if [ -n "$hits" ]; then
    echo "$hits" | sed 's/^/    /'
    return 1
  fi

  return 0
}

# --------------------------------------------------------------------------------
# images_leave_the_mount_point_empty: The mount hides whatever an image holds under /home/sandbox/workspace, so each image must hold nothing there.
# --------------------------------------------------------------------------------
# The last RUN of each Dockerfile must end with the emptiness check, so no later step can write there.
images_leave_the_mount_point_empty() {
  local dockerfile
  local last_run_line
  local check_line
  local failed=0

  for dockerfile in $DOCKERFILES; do
    last_run_line=$(grep -n '^RUN' "$dockerfile" | tail -n 1 | cut -d: -f1)
    check_line=$(grep -nF 'test -z "$(ls -A /home/sandbox/workspace)"' "$dockerfile" | tail -n 1 | cut -d: -f1)

    if [ -z "$check_line" ]; then
      echo "    $dockerfile: no emptiness check of /home/sandbox/workspace"
      failed=1
    elif [ -z "$last_run_line" ] || [ "$check_line" -lt "$last_run_line" ]; then
      echo "    $dockerfile: the emptiness check is not in the last RUN"
      failed=1
    elif sed -n "$((last_run_line + 1)),${check_line}p" "$dockerfile" | grep -Eq '^[A-Z]+[[:space:]]'; then
      echo "    $dockerfile: the emptiness check is not in the last RUN"
      failed=1
    fi
  done

  return $failed
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
  npm_builds_keep_their_cache_out_of_the_mount \
  images_leave_the_mount_point_empty \
  old_layout_untouched || exit 1
