#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Host tests: runs every check that needs no human, then prints a summary
# ------------------------------------------------------------------------------
# Usage, from anywhere: bash tests/host/run-all.sh (exit 0 = all checks passed)
# What each suite is for and when to add a check: tests/README.md
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-best-practices.sh"
host_init
RUN=""
unset SBXTEST_DIR

# ------------------------------------------------------------------------------
# Check lists, in run order
# ------------------------------------------------------------------------------
# The chain stops at its first failure. H-10 runs last: it is the likeliest to
# fail for an environmental reason.
# ------------------------------------------------------------------------------
noSandboxCheckList="h03-variable-interpolation.sh h25-images-match-versions.sh h27-best-practices-clone-and-publish.sh"
sandboxCheckList="h06-git-on-mac-repo.sh h26-isolation-by-inspect.sh h34-selfcheck.sh h35-init-owner-and-lock.sh"
chainCheckList="h08-history-survives-recreate.sh h16-live-clone-and-restart.sh h23-caches-survive-recreate.sh h09-rebuild-keeps-files-no-volumes.sh h28-sbx-add-start-stop.sh h29-sbx-upgrade.sh h31-sbx-shell.sh h32-sbx-list.sh h33-sbx-rm.sh h10-missing-folder-refused.sh"

remainingList="$noSandboxCheckList $sandboxCheckList $chainCheckList"
passedCount=0
failedCount=0
notRunCount=0
failedList=""

# ------------------------------------------------------------------------------
# drop_remaining SCRIPT: takes SCRIPT off the list of checks still waiting
# ------------------------------------------------------------------------------
drop_remaining() {
  local script item
  local keptList=""

  script=$1

  for item in $remainingList; do
    if [ "$item" != "$script" ]; then
      keptList="$keptList $item"
    fi
  done
  remainingList=$keptList
}

# ------------------------------------------------------------------------------
# run_check SCRIPT: runs one check in a child process; counts its exit status
# ------------------------------------------------------------------------------
run_check() {
  local script=$1

  drop_remaining "$script"

  if bash "$HOST_DIR/$script" </dev/null; then
    passedCount=$((passedCount + 1))
    return 0
  fi

  failedCount=$((failedCount + 1))
  failedList="$failedList $script"

  return 1
}

# ------------------------------------------------------------------------------
# run_list SCRIPT...: runs every check, even after a failure
# ------------------------------------------------------------------------------
run_list() {
  local script

  for script in $1; do
    run_check "$script"
  done
}

# ------------------------------------------------------------------------------
# mark_not_run SCRIPT... REASON: prints and counts the checks that did not run
# ------------------------------------------------------------------------------
mark_not_run() {
  local script

  for script in $1; do
    printf 'NOT RUN: %s (%s)\n' "$script" "$2"
    notRunCount=$((notRunCount + 1))
    drop_remaining "$script"
  done
}

# ------------------------------------------------------------------------------
# run_chain SCRIPT...: runs in order; after a failure the rest are not run
# ------------------------------------------------------------------------------
run_chain() {
  local script
  local stopped=0

  for script in $1; do
    if [ "$stopped" -eq 1 ]; then
      mark_not_run "$script" "an earlier check in the chain failed"
    elif ! run_check "$script"; then
      stopped=1
    fi
  done
}

# ------------------------------------------------------------------------------
# record_setup_failure TEXT: counts a failure that belongs to no check
# ------------------------------------------------------------------------------
record_setup_failure() {
  printf 'FAIL: SETUP %s\n' "$1"
  failedCount=$((failedCount + 1))
  failedList="$failedList SETUP"
}

# ------------------------------------------------------------------------------
# finish REASON: marks the rest not run, prints the summary, exits 0 or 1
# ------------------------------------------------------------------------------
finish() {
  mark_not_run "$remainingList" "$1"
  printf '\nSummary: %s passed, %s failed, %s not run\n' "$passedCount" "$failedCount" "$notRunCount"

  if [ -n "$failedList" ]; then
    printf 'Failed:%s\n' "$failedList"
  fi

  if [ "$failedCount" -eq 0 ] && [ "$notRunCount" -eq 0 ]; then
    exit 0
  fi
  exit 1
}

# ------------------------------------------------------------------------------
# fatal TEXT: a setup step failed, so nothing else can run
# ------------------------------------------------------------------------------
fatal() {
  record_setup_failure "$1"
  finish "setup failed"
}

# ------------------------------------------------------------------------------
# print_next_block: prints the cleanup command
# ------------------------------------------------------------------------------
print_next_block() {
  printf '\nNext\n'

  if [ -n "${RUN:-}" ]; then
    printf '  Cleanup when you are done:\n'
    printf '    cd %q && SBX_NAME=hosttest SBX_DIR=%q docker compose down && rm -rf %q\n' "${REPO_DIR:-}" "$RUN" "$RUN"
  else
    printf '  No run folder was created, so there is nothing to clean up.\n'
  fi
}

# ------------------------------------------------------------------------------
# install_traps: Ctrl-C exits 130; the Next block prints whenever the run ends
# ------------------------------------------------------------------------------
install_traps() {
  trap 'exit 130' INT TERM
  trap print_next_block EXIT
}

# ------------------------------------------------------------------------------
# print_docker_target: prints the Docker context and DOCKER_HOST in use
# ------------------------------------------------------------------------------
print_docker_target() {
  local contextName

  if ! contextName=$(docker context show 2>/dev/null </dev/null) || [ -z "$contextName" ]; then
    contextName=unknown
  fi

  info "docker context: $contextName, DOCKER_HOST: ${DOCKER_HOST:-not set}"
}

# ------------------------------------------------------------------------------
# check_docker_reachable: stops the run when the Docker daemon does not answer
# ------------------------------------------------------------------------------
check_docker_reachable() {
  if ! docker info >/dev/null 2>&1 </dev/null; then
    fatal "the Docker daemon is not reachable; start Docker Desktop and run again"
  fi
}

# ------------------------------------------------------------------------------
# create_run_folder: makes the run folder and prints its path; stops on failure
# ------------------------------------------------------------------------------
create_run_folder() {
  if ! make_run_dir; then
    fatal "could not create the run folder"
  fi

  info "run folder: $RUN"
}

# ------------------------------------------------------------------------------
# create_best_practices_clone: makes the fixture origin and the sandbox's clone
# ------------------------------------------------------------------------------
# Both sit in the run folder. The run stops when either step fails.
# ------------------------------------------------------------------------------
create_best_practices_clone() {
  local cloneLog=$RUN/logs/best-practices-clone.log

  if ! make_best_practices_origin "$RUN/best-practices-origin.git" >"$cloneLog" 2>&1 ||
    ! make_best_practices_clone "$RUN/best-practices-origin.git" "$RUN/best-practices" >>"$cloneLog" 2>&1; then
    fatal "could not make the fixture best-practices clone (log: $cloneLog)"
  fi

  info "best-practices clone: $RUN/best-practices"
}

# ------------------------------------------------------------------------------
# make_test_root_cert CERT_FILE: makes or reuses the throwaway root certificate
# ------------------------------------------------------------------------------
# The private key is deleted at once; the certificate alone signs nothing. A
# file valid for another day is reused, so the test images keep their cache.
# ------------------------------------------------------------------------------
make_test_root_cert() {
  local certFile=$1
  local certDir keyFile makeStatus

  certDir=$(dirname "$certFile")
  keyFile=$certDir/root-ca.key
  rm -f "$keyFile"

  if openssl x509 -noout -checkend 86400 -in "$certFile" >/dev/null 2>&1 </dev/null; then
    printf 'reusing %s\n' "$certFile"

    return 0
  fi

  mkdir -p "$certDir" || return 1
  chmod 700 "$certDir" || return 1

  (
    umask 077
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=sbx-hosttest-root-ca" -keyout "$keyFile" -out "$certFile" </dev/null
  )
  makeStatus=$?
  rm -f "$keyFile"

  return "$makeStatus"
}

# ------------------------------------------------------------------------------
# prepare_root_certificates: the build trusts your own root and the test root
# ------------------------------------------------------------------------------
# Your own root comes first when SBX_CA_CERT is set. The build file sits outside
# the run folder, which the sandbox mounts.
# ------------------------------------------------------------------------------
prepare_root_certificates() {
  local certFile buildFile rootLog

  certFile=$(test_root_ca_file)
  buildFile=$(dirname "$certFile")/build-ca.pem
  rootLog=$RUN/logs/root-ca.log

  if ! make_test_root_cert "$certFile" >"$rootLog" 2>&1; then
    fatal "could not make the test root certificate (log: $rootLog)"
  fi

  if [ -n "${SBX_CA_CERT:-}" ]; then
    if [ ! -f "$SBX_CA_CERT" ] || [ ! -r "$SBX_CA_CERT" ]; then
      fatal "SBX_CA_CERT is not a readable file: $SBX_CA_CERT"
    fi
  fi

  rm -f "$buildFile.tmp"

  if [ -n "${SBX_CA_CERT:-}" ]; then
    if ! cat "$SBX_CA_CERT" >"$buildFile.tmp" || ! printf '\n' >>"$buildFile.tmp"; then
      fatal "could not write the build certificate file $buildFile"
    fi
  fi

  if ! cat "$certFile" >>"$buildFile.tmp" || ! mv "$buildFile.tmp" "$buildFile"; then
    fatal "could not write the build certificate file $buildFile"
  fi

  SBX_CA_CERT=$buildFile
  export SBX_CA_CERT

  info "test root certificate: $certFile, SHA-256 $(cert_fingerprint "$certFile"); the build trusts $buildFile"
}

# ------------------------------------------------------------------------------
# remove_leftover_test_container: takes down an earlier test container
# ------------------------------------------------------------------------------
# Stops the run if the name belongs to something else or the take down fails.
# ------------------------------------------------------------------------------
remove_leftover_test_container() {
  local label

  if ! docker container inspect "$CONTAINER" >/dev/null 2>&1 </dev/null; then
    return 0
  fi

  label=$(docker container inspect --format '{{index .Config.Labels "sbx.name"}}' "$CONTAINER" 2>/dev/null </dev/null)
  if [ "$label" != "hosttest" ]; then
    printf 'A container named %s exists but is not labelled sbx.name=hosttest. It was left alone.\n' "$CONTAINER" >&2
    fatal "an earlier sbx-hosttest container is in the way and was not removed (see the messages above)"
  fi

  if ! compose_down >"$RUN/logs/leftover-down.log" 2>&1; then
    fatal "an earlier sbx-hosttest container is in the way and was not removed (see the messages above)"
  fi

  return 0
}

# ------------------------------------------------------------------------------
# build_all_images: builds every image; stops the run when the build fails
# ------------------------------------------------------------------------------
build_all_images() {
  info "building the $SBX_IMAGE_TAG images (logs in $RUN/logs)"

  if ! build_images build; then
    fatal "the image build failed"
  fi
}

# ------------------------------------------------------------------------------
# run_sandbox_checks: starts the test sandbox, then runs its checks and chain
# ------------------------------------------------------------------------------
run_sandbox_checks() {
  if compose_up; then
    run_list "$sandboxCheckList"
    run_chain "$chainCheckList"
  else
    record_setup_failure "the test sandbox did not start (log: $RUN/logs/compose-up.log)"
    mark_not_run "$sandboxCheckList $chainCheckList" "the test sandbox did not start"
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
install_traps
print_docker_target
check_docker_reachable
create_run_folder
create_best_practices_clone
prepare_root_certificates
remove_leftover_test_container
build_all_images
run_list "$noSandboxCheckList"
run_sandbox_checks
finish "not reached"
