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
# refuse_host_mode NAME VALUE: adds a problem if VALUE is host (returns 1)
# ------------------------------------------------------------------------------
refuse_host_mode() {
  if [ "$2" = "host" ]; then
    add_problem "$1 is host"
    return 1
  fi

  return 0
}

# ------------------------------------------------------------------------------
# check_privileges: no privilege, host namespace, device, extra group or profile
# ------------------------------------------------------------------------------
# A normal compose container reports NetworkMode <project>_default, IpcMode
# private (or shareable), PidMode, UTSMode and UsernsMode empty, Devices and
# GroupAdd null. Compose may write CapDrop and SecurityOpt in its own form, so
# the check looks for substrings and prints the raw line.
# ------------------------------------------------------------------------------
check_privileges() {
  local inspectLine privileged capDrop capAdd securityOpt
  local networkMode pidMode ipcMode utsMode usernsMode devices groupAdd
  local problemFound=0

  inspectLine=$(docker container inspect \
    --format '{{.HostConfig.Privileged}}|{{json .HostConfig.CapDrop}}|{{json .HostConfig.CapAdd}}|{{json .HostConfig.SecurityOpt}}|{{.HostConfig.NetworkMode}}|{{.HostConfig.PidMode}}|{{.HostConfig.IpcMode}}|{{.HostConfig.UTSMode}}|{{.HostConfig.UsernsMode}}|{{json .HostConfig.Devices}}|{{json .HostConfig.GroupAdd}}' \
    "$CONTAINER" </dev/null 2>&1)
  IFS='|' read -r privileged capDrop capAdd securityOpt networkMode pidMode ipcMode utsMode usernsMode devices groupAdd <<<"$inspectLine"

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

  case "$securityOpt" in
    *unconfined*)
      add_problem "SecurityOpt holds an unconfined profile"
      problemFound=1
      ;;
  esac

  refuse_host_mode NetworkMode "$networkMode" || problemFound=1
  refuse_host_mode PidMode "$pidMode" || problemFound=1
  refuse_host_mode IpcMode "$ipcMode" || problemFound=1
  refuse_host_mode UTSMode "$utsMode" || problemFound=1
  refuse_host_mode UsernsMode "$usernsMode" || problemFound=1

  case "$networkMode" in
    container:*)
      add_problem "NetworkMode joins another container"
      problemFound=1
      ;;
  esac

  if [ "$devices" != "null" ] && [ "$devices" != "[]" ]; then
    add_problem "Devices is not null or empty"
    problemFound=1
  fi

  if [ "$groupAdd" != "null" ] && [ "$groupAdd" != "[]" ]; then
    add_problem "GroupAdd is not null or empty"
    problemFound=1
  fi

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
  "one bind mount at /home/sandbox/workspace; not privileged; all capabilities dropped, none added; no-new-privileges; no unconfined profile, host namespace, device or extra group"
