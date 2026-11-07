#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Self-test of sbx-start past the folder checks, against a scripted docker
# ------------------------------------------------------------------------------
# Usage: bash tests/selftest/sbx/start.sh (exit 0 = all pass)
# Run by run-all.sh; its one work folder under TMPDIR is removed at exit.
# The refusing stand-in stays first on PATH except inside run_sbx_scripted.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# Case: a container that is gone during the start wait is reported, not silent
# ------------------------------------------------------------------------------
case_container_gone() {
  SBX_CONFIG_DIR=$WORK/cfg-start
  export SBX_CONFIG_DIR

  echo '--- sbx-start when the container disappears'

  run_sbx gone sbx-add gone "$WORK/start dir/gone"
  set_standin_state sha256:new "" "" no
  run_sbx_scripted gonestart sbx-start gone
  expect "sbx-start: a container that is gone is reported as stopped during its start" refused_cleanly gonestart "sbx-gone stopped during its start" "" ""
  expect "sbx-start: the compose up ran before the wait" has_text "$WORK/gonestart.out" "standin: compose"
}

# ------------------------------------------------------------------------------
# Case: a running sandbox on an older image gets a warning before the recreate
# ------------------------------------------------------------------------------
case_older_image() {
  local warnText='sbx-older runs on an older image; recreating it on the new one will close its open shells and Claude sessions'

  SBX_CONFIG_DIR=$WORK/cfg-older
  export SBX_CONFIG_DIR

  echo '--- sbx-start on a running sandbox'

  run_sbx older sbx-add older "$WORK/older dir"

  set_standin_state sha256:new sha256:old true yes
  run_sbx_scripted olderstart sbx-start older
  expect "sbx-start: a running sandbox on an older image is warned" has_text "$WORK/olderstart.out" "$warnText"
  expect "sbx-start: the warning comes before the recreate" appears_before "$WORK/olderstart.out" "will close its open shells" "standin: compose"
  expect "sbx-start: it still starts the sandbox after the warning" equals "$SBX_RC" 0

  set_standin_state sha256:new sha256:new true yes
  run_sbx_scripted currentstart sbx-start older
  expect "sbx-start: the closing hint names sbx-shell" has_text "$WORK/currentstart.out" "sbx-start: open a shell with: sbx-shell older"
  expect "sbx-start: a running sandbox on the current image is not warned" lacks_text "$WORK/currentstart.out" "older image"
  expect "sbx-start: a running sandbox on the current image still starts" equals "$SBX_RC" 0

  set_standin_state sha256:new sha256:old false yes
  run_sbx_scripted stoppedstart sbx-start older
  expect "sbx-start: a stopped sandbox on an older image is not warned" lacks_text "$WORK/stoppedstart.out" "older image"

  set_standin_state sha256:new "" "" yes
  run_sbx_scripted newstart sbx-start older
  expect "sbx-start: a sandbox without a container is not warned" lacks_text "$WORK/newstart.out" "older image"
}

# ------------------------------------------------------------------------------
# refused_before_up LABEL TEXT: exit 1, TEXT in the error, no compose call
# ------------------------------------------------------------------------------
refused_before_up() {
  refused_cleanly "$1" "$2" "" "" && ! grep -Fq -- 'docker compose' "$WORK/standin-calls"
}

# ------------------------------------------------------------------------------
# Case: Docker not answering and a missing image get their own message each
# ------------------------------------------------------------------------------
case_docker_down_or_image_missing() {
  SBX_CONFIG_DIR=$WORK/cfg-start-docker
  export SBX_CONFIG_DIR

  echo '--- sbx-start with Docker stopped or the image missing'

  run_sbx downadd sbx-add down "$WORK/start dir/down"

  set_standin_state sha256:new "" "" yes
  set_standin_knob docker-down
  reset_standin_calls
  run_sbx_scripted downstart sbx-start down
  expect "sbx-start: Docker not answering is refused before compose up" refused_before_up downstart "cannot reach Docker; is Docker running?"
  expect "sbx-start: Docker not answering does not advise sbx-upgrade" lacks_text "$WORK/downstart.err" "sbx-upgrade"

  set_standin_state sha256:new "" "" yes
  set_standin_knob image-missing
  reset_standin_calls
  run_sbx_scripted noimagestart sbx-start down
  expect "sbx-start: a missing image is refused before compose up with the sbx-upgrade advice" refused_before_up noimagestart "sbx-claude:local is not built; run: sbx-upgrade down"
  expect "sbx-start: a missing image does not blame Docker" lacks_text "$WORK/noimagestart.err" "is Docker running?"
}

# ------------------------------------------------------------------------------
# Case: sbx-upgrade and sbx-start share one warning wording
# ------------------------------------------------------------------------------
case_shared_wording() {
  local upgradeLine

  echo '--- the shared warning'

  upgradeLine=$(lib_eval 'scriptName=sbx-upgrade; warn_sessions_close demo "is running; after the build, recreating it"' 2>&1)
  expect "sbx-upgrade: the warning keeps its wording" equals "$upgradeLine" "sbx-upgrade: sbx-demo is running; after the build, recreating it will close its open shells and Claude sessions"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
make_scripted_docker
case_container_gone
case_older_image
case_docker_down_or_image_missing
case_shared_wording
expect "sbx-start: no case reached the refusing docker" no_docker_call
finish_cases
