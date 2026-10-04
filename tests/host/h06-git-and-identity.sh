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
require_test_sandbox H-06 || exit 1

GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git init -q "$RUN/hosttest"
initStatus=$?

statusOutput=$(in_container git status)
statusCode=$?
safeOutput=$(in_container git config --system --get-all safe.directory)
identityOutput=$(in_container git config --global user.name T)
identityCode=$?

set --

if [ "$initStatus" -ne 0 ]; then
  set -- "$@" "git init of $RUN/hosttest on the host failed"
fi

if [ "$statusCode" -ne 0 ] || [[ "$statusOutput" == *"dubious ownership"* ]]; then
  set -- "$@" "git status in the container exited $statusCode: $(printf '%s\n' "$statusOutput" | head -n 2 | tr '\n' ' ')"
fi

if ! printf '%s\n' "$safeOutput" | grep -Fxq '*'; then
  set -- "$@" "the system safe.directory value must be *; got: $(printf '%s\n' "$safeOutput" | tr '\n' ' ')"
fi

if [ "$identityCode" -ne 0 ]; then
  set -- "$@" "git config --global user.name T failed in the container: $identityOutput"
fi

if ! grep -Fq "name = T" "$RUN/state/git/config" 2>/dev/null; then
  set -- "$@" "$RUN/state/git/config does not contain 'name = T'"
fi

if [ "$#" -gt 0 ]; then
  fail H-06 "git or the stored identity is wrong" "$@"
  exit 1
fi

pass H-06 "git status is clean of ownership errors, safe.directory is *, the identity is in state/git/config"
exit 0
