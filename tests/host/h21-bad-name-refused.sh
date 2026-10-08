#!/usr/bin/env bash
# H-21: an SBX_NAME that breaks the sandbox name rule is refused at container start; the command never runs and nothing is written.
# - Two plain docker run --rm containers with the compose restrictions mount their own folder
#   $RUN/h21, which holds a project folder for each name and state/, so only the name can stop
#   the start.
# - The names are HostTest (an uppercase letter; Compose would turn it into the project hosttest)
#   and host_test (an underscore).
# - Each must exit non-zero with the [sbx] ERROR that names SBX_NAME and the value and gives the
#   example my-project, must never print the command's marker, and must write no state folder.
# Depends on: nothing
# Needs: images built; the run folder (not the running sandbox)
set -u
. "$(dirname "$0")/lib.sh"
host_init

# --------------------------------------------------------------------------------
# FAIL and return 1 when there is no run folder
# --------------------------------------------------------------------------------
require_run_folder() {
  if [ -z "${RUN:-}" ]; then
    fail H-21 "no run folder" "run: bash tests/host/run-all.sh first"
    return 1
  fi
}

# --------------------------------------------------------------------------------
# Creates a project folder for each name and the state folder; safe to run again on the same run folder
# --------------------------------------------------------------------------------
make_name_folders() {
  mkdir -p "$RUN/h21/HostTest" "$RUN/h21/host_test" "$RUN/h21/state"
}

# --------------------------------------------------------------------------------
# Runs one container with the compose restrictions, the h21 workspace and SBX_NAME=NAME; its status is docker's
# --------------------------------------------------------------------------------
run_named_container() {
  run_timeout 60 docker run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true \
    -e "SBX_NAME=$1" --mount "type=bind,source=$RUN/h21,target=/home/sandbox/workspace" \
    sbx-claude:local sh -c 'echo h21-command-ran' </dev/null 2>&1
}

# --------------------------------------------------------------------------------
# Runs the container with the uppercase name and the one with the underscore
# --------------------------------------------------------------------------------
run_containers() {
  upperOutput=$(run_named_container HostTest)
  upperStatus=$?

  underscoreOutput=$(run_named_container host_test)
  underscoreStatus=$?
}

# --------------------------------------------------------------------------------
# Checks the start was refused by the name rule with the example, and the command never ran
# --------------------------------------------------------------------------------
check_name_refused() {
  local label=$1 status=$2 output=$3 value=$4

  if [ "$status" -eq 0 ]; then
    add_problem "$label started; the container exited 0"
  fi

  if [[ "$output" != *"SBX_NAME \"$value\" breaks the sandbox name rule"* ]]; then
    add_problem "$label was not refused by the name rule; got: $(first_lines "$output")"
  fi

  if [[ "$output" != *"my-project"* ]]; then
    add_problem "the refusal of $label gives no valid example; got: $(first_lines "$output")"
  fi

  if [[ "$output" == *"h21-command-ran"* ]]; then
    add_problem "the command ran despite $label"
  fi
}

# --------------------------------------------------------------------------------
# Checks the refused starts wrote no state folder
# --------------------------------------------------------------------------------
check_no_state_written() {
  if [ -e "$RUN/h21/state/shell" ]; then
    add_problem "the start wrote state folders before it refused the name: $RUN/h21/state/shell exists"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_run_folder || exit 1
make_name_folders
run_containers
check_name_refused "an uppercase SBX_NAME (HostTest)" "$upperStatus" "$upperOutput" "HostTest"
check_name_refused "an underscore in SBX_NAME (host_test)" "$underscoreStatus" "$underscoreOutput" "host_test"
check_no_state_written
report_check H-21 "a name that breaks the rule was not refused at start" \
  "an uppercase SBX_NAME and an underscore are each refused at start with the name rule; the command never ran and nothing was written"
