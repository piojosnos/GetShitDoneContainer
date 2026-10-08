#!/usr/bin/env bash
# H-06: git works in the container on a repository made on the host, and a git identity set
# in the container is stored in the mounted state folder.
# - The only host-side git call is the init below. It ignores your own git configuration
#   (GIT_CONFIG_GLOBAL=/dev/null, GIT_CONFIG_NOSYSTEM=1), so your identity is never read or written.
# - The identity is set inside the container, where GIT_CONFIG_GLOBAL points into the run folder.
# Depends on: nothing
# Needs: test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
host_init

identityName=hosttest-$$-$(date +%s)

# --------------------------------------------------------------------------------
# Makes the project folder a git repository from the host, ignoring your own git configuration
# --------------------------------------------------------------------------------
init_host_repo() {
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git init -q "$RUN/hosttest"
  initStatus=$?

  if [ "$initStatus" -ne 0 ]; then
    add_problem "git init of $RUN/hosttest on the host failed"
  fi
}

# --------------------------------------------------------------------------------
# Runs git in the container: status, the system safe.directory value, and setting the identity
# --------------------------------------------------------------------------------
read_git_state() {
  statusOutput=$(in_project git status)
  statusCode=$?
  safeOutput=$(in_container git config --system --get-all safe.directory)
  identityOutput=$(in_container git config --global user.name "$identityName")
  identityCode=$?
}

# --------------------------------------------------------------------------------
# Checks git status ran in the container without an ownership error
# --------------------------------------------------------------------------------
check_git_status() {
  if [ "$statusCode" -ne 0 ] || [[ "$statusOutput" == *"dubious ownership"* ]]; then
    add_problem "git status in the container exited $statusCode: $(first_lines "$statusOutput" 2)"
  fi
}

# --------------------------------------------------------------------------------
# Checks the system safe.directory value is *
# --------------------------------------------------------------------------------
check_safe_directory() {
  if ! printf '%s\n' "$safeOutput" | grep -Fxq '*'; then
    add_problem "the system safe.directory value must be *; got: $(join_lines "$safeOutput")"
  fi
}

# --------------------------------------------------------------------------------
# Checks the identity set in the container reached the mounted state folder
# --------------------------------------------------------------------------------
check_identity_stored() {
  if [ "$identityCode" -ne 0 ]; then
    add_problem "git config --global user.name $identityName failed in the container: $identityOutput"
  fi

  if ! grep -Eq "^[[:space:]]*name = $identityName\$" "$RUN/state/git/config" 2>/dev/null; then
    add_problem "$RUN/state/git/config does not contain the line 'name = $identityName'"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-06 || exit 1
init_host_repo
read_git_state
check_git_status
check_safe_directory
check_identity_stored
report_check H-06 "git or the stored identity is wrong" \
  "git status is clean of ownership errors, safe.directory is *, the run's identity is in state/git/config"
