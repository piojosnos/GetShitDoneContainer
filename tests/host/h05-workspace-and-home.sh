#!/usr/bin/env bash
# H-05: the project folder is the container's working directory and shows up on the host;
# the home layout is there and owned by sandbox. The container side uses GNU stat, which is fine.
# Depends on: nothing
# Needs: test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
host_init

fileName=x-$$-$(date +%s).txt

# --------------------------------------------------------------------------------
# Creates a file with a name unique to this run in the container and reads the home listing and the owners
# --------------------------------------------------------------------------------
read_container_home() {
  listing=$(in_project sh -c "touch $fileName; ls -a /home/sandbox")
  owners=$(in_container stat -c '%U %n' /home/sandbox/.local /home/sandbox/.local/state)
}

# --------------------------------------------------------------------------------
# Checks the file made in the container reached the project folder on the host
# --------------------------------------------------------------------------------
check_file_reached_host() {
  if [ ! -f "$RUN/hosttest/$fileName" ]; then
    add_problem "$fileName created in the container did not appear in $RUN/hosttest"
  fi
}

# --------------------------------------------------------------------------------
# Checks the home entries the image provides are listed
# --------------------------------------------------------------------------------
check_home_entries() {
  local wanted

  for wanted in .bashrc .local; do
    if ! printf '%s\n' "$listing" | grep -Fxq "$wanted"; then
      add_problem "ls -a /home/sandbox does not list $wanted"
    fi
  done
}

# --------------------------------------------------------------------------------
# Checks the sandbox user owns ~/.local and ~/.local/state
# --------------------------------------------------------------------------------
check_home_owners() {
  local ownedPath

  for ownedPath in /home/sandbox/.local /home/sandbox/.local/state; do
    if ! printf '%s\n' "$owners" | grep -Fxq "sandbox $ownedPath"; then
      add_problem "owner of $ownedPath is not sandbox; stat said: $(join_lines "$owners")"
    fi
  done
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-05 || exit 1
read_container_home
check_file_reached_host
check_home_entries
check_home_owners
report_check H-05 "the workspace or home layout is wrong" \
  "a run-unique file reached the host, .bashrc and .local exist, owners are sandbox"
