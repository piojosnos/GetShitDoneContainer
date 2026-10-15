#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-26: the test sandbox has one bind mount and no privileges (docker inspect)
# ------------------------------------------------------------------------------
# Needs: test sandbox running
# H-04 proves the uid; H-09 checks the mount again after a rebuild.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init

# ------------------------------------------------------------------------------
# check_privileges: not privileged, all capabilities dropped, none added
# ------------------------------------------------------------------------------
# Compose may write CapDrop and SecurityOpt in its own form, so the check looks
# for substrings and prints the raw line.
# ------------------------------------------------------------------------------
check_privileges() {
  local inspectLine privileged capDrop capAdd securityOpt
  local problemFound=0

  inspectLine=$(docker container inspect \
    --format '{{.HostConfig.Privileged}}|{{json .HostConfig.CapDrop}}|{{json .HostConfig.CapAdd}}|{{json .HostConfig.SecurityOpt}}' \
    "$CONTAINER" </dev/null 2>&1)
  privileged=$(printf '%s\n' "$inspectLine" | cut -d'|' -f1)
  capDrop=$(printf '%s\n' "$inspectLine" | cut -d'|' -f2)
  capAdd=$(printf '%s\n' "$inspectLine" | cut -d'|' -f3)
  securityOpt=$(printf '%s\n' "$inspectLine" | cut -d'|' -f4)

  if [ "$privileged" != "false" ]; then
    add_problem "Privileged is not false"
    problemFound=1
  fi

  case "$capDrop" in
    *'"ALL"'*) ;;
    *)
      add_problem "CapDrop does not hold ALL"
      problemFound=1
      ;;
  esac

  if [ "$capAdd" != "null" ] && [ "$capAdd" != "[]" ]; then
    add_problem "CapAdd is not null or empty"
    problemFound=1
  fi

  case "$securityOpt" in
    *no-new-privileges*) ;;
    *)
      add_problem "SecurityOpt does not hold no-new-privileges"
      problemFound=1
      ;;
  esac

  if [ "$problemFound" -eq 1 ]; then
    add_problem "docker inspect gave: $inspectLine"
  fi
}

# ------------------------------------------------------------------------------
# check_mounts: the one mount is a bind at /home/sandbox/workspace
# ------------------------------------------------------------------------------
check_mounts() {
  local mountLines

  mountLines=$(docker container inspect \
    --format '{{range .Mounts}}{{.Type}} {{.Destination}}{{println}}{{end}}' \
    "$CONTAINER" </dev/null 2>&1 | grep .)

  if [ "$mountLines" != "bind /home/sandbox/workspace" ]; then
    add_problem "expected one bind mount at /home/sandbox/workspace; got: $(join_lines "$mountLines" '; ')"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-26 || exit 1
check_privileges
check_mounts
report_check H-26 "the test sandbox has an extra mount or a privilege" \
  "one bind mount at /home/sandbox/workspace; not privileged; all capabilities dropped, none added; no-new-privileges"
