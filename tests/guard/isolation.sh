#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Guard rules on isolation: no socket, no privileges, data kept, old layout kept
# ------------------------------------------------------------------------------
# Usage: bash tests/guard/isolation.sh (exit 0 = every rule holds)
# Mounts and effective privileges are checked on the running sandbox by H-26.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# Constants: the commit the old layout is compared with
# ------------------------------------------------------------------------------
# Used by old_layout_untouched: the old ClaudeCode/ layout as it is on main.
# Remove both when the old layout is retired.
# ------------------------------------------------------------------------------
OLD_LAYOUT_COMMIT=304f80d1a0705d9ab668ef2ed4acd9fcf65060ac

# ------------------------------------------------------------------------------
# no_docker_socket_or_privileges: no Docker socket, no sudo, no extra privilege
# ------------------------------------------------------------------------------
# Compose refuses privileged, cap_add, devices, host namespaces, group_add and
# unconfined profiles. Host check H-26 reads the running container.
# ------------------------------------------------------------------------------
no_docker_socket_or_privileges() {
  local fieldRegex='^[[:space:]]*(privileged|cap_add|devices|device_cgroup_rules|pid|ipc|uts|userns_mode|network_mode|cgroup_parent|group_add|sysctls)[[:space:]]*:'
  local unconfinedRegex='(seccomp|apparmor)[=:][[:space:]]*unconfined'

  nowhere_matches "docker\\.sock|$fieldRegex|$unconfinedRegex" $COMPOSE && nowhere_matches '\bsudo\b' $DOCKERFILES
}

# ------------------------------------------------------------------------------
# host_scripts_keep_sandbox_data: only sbx-rm takes a sandbox down; data stays
# ------------------------------------------------------------------------------
# sbx-rm runs a plain compose down and deletes only its registry entry; volumes
# stay, because removing them is how the old layout lost data.
# ------------------------------------------------------------------------------
host_scripts_keep_sandbox_data() {
  local hostFile
  local otherFileList=""

  if [ ! -f bin/sbx-rm ]; then
    echo "    bin/sbx-rm is missing"
    return 1
  fi

  for hostFile in bin/*; do
    if [ "$hostFile" != bin/sbx-rm ]; then
      otherFileList="$otherFileList $hostFile"
    fi
  done

  # No bin/ file name holds a space, so the list is split on purpose.
  nowhere_matches '\b(rm|rmdir|prune|kill|down)\b|--volumes' $otherFileList || return 1

  {
    grep -nE '\b(rmdir|prune|kill)\b|--(volumes|rmi|remove-orphans)|[[:space:]]-v([^A-Za-z0-9-]|$)|\bdown[[:space:]]+-' bin/sbx-rm
    grep -nE '(^|[^A-Za-z-])rm([[:space:]]|$)' bin/sbx-rm | grep -vE '^[0-9]+:  if ! rm -- "\$entryFile"; then$'
  } | report_lines 'bin/sbx-rm:'
}

# ------------------------------------------------------------------------------
# old_layout_untouched: no change to the old layout until it is retired
# ------------------------------------------------------------------------------
old_layout_untouched() {
  git diff --quiet "$OLD_LAYOUT_COMMIT" -- ClaudeCode OpenCode README.md \
    && [ -z "$(git ls-files --others --exclude-standard -- ClaudeCode OpenCode)" ]
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  no_docker_socket_or_privileges \
  host_scripts_keep_sandbox_data \
  old_layout_untouched || exit 1
