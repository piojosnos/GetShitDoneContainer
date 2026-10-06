#!/usr/bin/env bash
# H-04: the container runs as the non-root sandbox user (uid 1000).
# Depends on: nothing
# Needs: test sandbox running
set -u
. "$(dirname "$0")/lib.sh"
host_init

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-04 || exit 1
output=$(in_container id)

if [[ "$output" != "uid=1000(sandbox) gid=1000(sandbox)"* ]]; then
  add_problem "got: $output"
fi

report_check H-04 "expected uid=1000(sandbox) gid=1000(sandbox)" \
  "container user is uid=1000(sandbox)"
