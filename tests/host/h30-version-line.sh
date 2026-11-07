#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-30: the versions line matches versions.env; only interactive shells print it
# ------------------------------------------------------------------------------
# Needs: test sandbox running (read only)
# The jdk field comes from the TEMURIN_IMAGE tag and the python field from the
# container, because neither has a pin of its own.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init

expectedLine=""

# ------------------------------------------------------------------------------
# expected_line: the line the pins and the container say the image must hold
# ------------------------------------------------------------------------------
expected_line() {
  local temurinTag jdkVersion pythonVersion

  temurinTag=$(pin_of TEMURIN_IMAGE)
  temurinTag=${temurinTag#*:}
  jdkVersion=${temurinTag%%_*}
  pythonVersion=$(in_container python3 --version | sed 's/^Python //')

  expectedLine="claude $(pin_of CLAUDE_CODE_VERSION) | gsd $(pin_of GSD_CORE_VERSION) | ccusage $(pin_of CCUSAGE_VERSION) | node $(pin_of NODE_VERSION) | jdk $jdkVersion | mvn $(pin_of MAVEN_VERSION) | python $pythonVersion"
}

# ------------------------------------------------------------------------------
# Checks the file in the Claude image is exactly the expected line
# ------------------------------------------------------------------------------
check_image_line() {
  local imageLine

  imageLine=$(run_timeout 60 docker run --rm --entrypoint cat sbx-claude:local /etc/sbx/tool-versions </dev/null 2>&1)

  if [ "$imageLine" != "$expectedLine" ]; then
    add_problem "/etc/sbx/tool-versions in sbx-claude:local is '$(first_lines "$imageLine")'; expected '$expectedLine'"
  fi
}

# ------------------------------------------------------------------------------
# Checks an interactive shell prints the expected line once, and nothing else
# ------------------------------------------------------------------------------
# Without a terminal bash writes a job-control note on stderr, so it is dropped.
# ------------------------------------------------------------------------------
check_interactive_shell() {
  local shellOutput

  shellOutput=$(run_timeout 60 docker exec -i "$CONTAINER" bash -i </dev/null 2>/dev/null)

  if [ "$shellOutput" != "$expectedLine" ]; then
    add_problem "an interactive shell in $CONTAINER printed '$(first_lines "$shellOutput")'; expected the versions line once"
  fi
}

# ------------------------------------------------------------------------------
# Checks bash -c and bash -lc print nothing
# ------------------------------------------------------------------------------
check_quiet_shells() {
  local shellFlag quietOutput

  for shellFlag in -c -lc; do
    quietOutput=$(run_timeout 60 docker exec "$CONTAINER" bash "$shellFlag" true </dev/null 2>&1)

    if [ -n "$quietOutput" ]; then
      add_problem "bash $shellFlag true in $CONTAINER printed '$(first_lines "$quietOutput")'; a script shell must stay quiet"
    fi
  done
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-30 || exit 1
expected_line
check_image_line
check_interactive_shell
check_quiet_shells
report_check H-30 "the tool versions line is wrong or shows in the wrong shells" \
  "the line matches versions.env, an interactive shell prints it once, bash -c and bash -lc print nothing"
