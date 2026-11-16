#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Guard rules on isolation: no socket or privilege, data kept, test images
# ------------------------------------------------------------------------------
# Usage: bash tests/guard/isolation.sh (exit 0 = every rule holds)
# Mounts and effective privileges are checked on the running sandbox by H-26.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

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
# Every bin/ script other than sbx-rm is free of rm, rmdir, prune, kill, down and
# --volumes, so no other script deletes data or takes a sandbox down. What sbx-rm
# itself removes is proven on real Docker by host check H-33.
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
  nowhere_matches '\b(rm|rmdir|prune|kill|down)\b|--volumes' $otherFileList
}

# ------------------------------------------------------------------------------
# managed_settings_deny_skill_edits: the managed settings deny Edit on the synced skills
# ------------------------------------------------------------------------------
# sbx-selfcheck reads the same entry in the image (host check H-34).
# ------------------------------------------------------------------------------
managed_settings_deny_skill_edits() {
  local denyEntry='Edit(//home/sandbox/workspace/state/claude/skills/**)'

  if ! grep -Fq "\"$denyEntry\"" claude/managed-settings.json; then
    echo "    claude/managed-settings.json has no deny entry $denyEntry"
    return 1
  fi

  return 0
}

# ------------------------------------------------------------------------------
# host_tests_never_name_the_local_tag: a test run never builds, runs or removes the images your sandboxes use
# ------------------------------------------------------------------------------
# host-test.sh and the host checks take their images from SBX_IMAGE_TAG, which
# they always set to test. A local tag named in one of them, even in a comment,
# is the first step to a run that replaces the images your sandboxes use.
# ------------------------------------------------------------------------------
host_tests_never_name_the_local_tag() {
  nowhere_matches ':local\b' host-test.sh tests/host/*.sh
}

# ------------------------------------------------------------------------------
# owner_fix_hint_matches_container_name: the Mac fix shared by the self-check and sbx-init names the container compose.yml makes
# ------------------------------------------------------------------------------
# The fix runs a throwaway root container with --volumes-from sbx-NAME. If the
# container_name in compose.yml changes, the printed command would name a
# container that does not exist.
# ------------------------------------------------------------------------------
owner_fix_hint_matches_container_name() {
  local hintFile=base/selfcheck/root_owned_scan.py
  local namePrefix

  namePrefix=$(sed -n 's/^ *container_name: "\(.*\)\${SBX_NAME}".*$/\1/p' $COMPOSE | head -n 1)

  if [ -z "$namePrefix" ]; then
    echo "    $COMPOSE has no container_name of the form \"PREFIX\${SBX_NAME}\""
    return 1
  fi

  if ! grep -Fq -- "--volumes-from ${namePrefix}{sandbox_name(" $hintFile; then
    echo "    $hintFile does not name the container as --volumes-from ${namePrefix}{sandbox_name(...)}, the container_name of $COMPOSE"
    return 1
  fi

  return 0
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  no_docker_socket_or_privileges \
  host_scripts_keep_sandbox_data \
  managed_settings_deny_skill_edits \
  host_tests_never_name_the_local_tag \
  owner_fix_hint_matches_container_name || exit 1
