#!/usr/bin/env bash
# H-09 (attended): rebuild the images, recreate the test sandbox, and confirm the login and the
# earlier Claude session survive.
# - Needs a terminal. Run it after bash tests/host/manual/h07-login.sh, against the same test
#   sandbox (sbx-hosttest). It finds the run folder from the container's mount.
# - Steps: rebuild sbx-base:local and sbx-claude:local (the real tags), take the sandbox down,
#   bring it up, check claude auth status is still logged in, open claude --continue, then ask you
#   whether the earlier session resumed. Nothing is deleted; the folders and the images stay.
# - Slow clean rebuild: pass --no-cache, or set SBXTEST_NO_CACHE=1.
# - Usage: bash tests/host/manual/h09-rebuild-resume.sh [--no-cache]   (exit 0 = PASS)
set -u

if [ ! -t 0 ] || [ ! -t 1 ]; then
  printf 'This helper needs a terminal. Run it directly, not through a pipe or a script.\n' >&2
  exit 1
fi

. "$(dirname "$0")/../lib.sh"
host_init

noCacheFlag=""

case "$#" in
  0) ;;
  1)
    if [ "$1" = "--no-cache" ]; then
      noCacheFlag="--no-cache"
    else
      printf 'Usage: bash tests/host/manual/h09-rebuild-resume.sh [--no-cache]\n' >&2
      exit 2
    fi
    ;;
  *)
    printf 'Usage: bash tests/host/manual/h09-rebuild-resume.sh [--no-cache]\n' >&2
    exit 2
    ;;
esac

if [ "${SBXTEST_NO_CACHE:-}" = "1" ]; then
  noCacheFlag="--no-cache"
fi

require_test_sandbox H-09 || exit 1

info "rebuilding sbx-base:local and sbx-claude:local (logs in $RUN/logs)"
if ! build_images manual-rebuild "$noCacheFlag"; then
  fail H-09 "the image rebuild failed"
  exit 1
fi

info "taking the test sandbox down"
if ! compose_down >"$RUN/logs/manual-down.log" 2>&1; then
  fail H-09 "compose down failed" "log: $RUN/logs/manual-down.log"
  exit 1
fi

info "starting the test sandbox"
if ! compose_up; then
  fail H-09 "compose up failed after the rebuild" "log: $RUN/logs/compose-up.log"
  exit 1
fi

require_test_sandbox H-09 || exit 1

authOutput=$(in_container claude auth status)

if ! printf '%s\n' "$authOutput" | grep -Eq '"loggedIn":[[:space:]]*true'; then
  fail H-09 "claude auth status does not show a login after the rebuild" \
    "got: $(printf '%s\n' "$authOutput" | head -n 3 | tr '\n' ' ')" \
    "if you have not logged in yet, run bash tests/host/manual/h07-login.sh first"
  exit 1
fi

pass H-09 'claude auth status still shows "loggedIn": true after the rebuild'

printf '\nClaude opens next with claude --continue.\n'
printf '  Look for: the session from the login helper is picked up again (earlier messages shown).\n'
printf '  Type /exit to come back here.\n\n'

docker exec -it -w /home/sandbox/workspace/hosttest "$CONTAINER" claude --continue

printf '\nDid the earlier session resume? [y/N] '
read -r answer

case "$answer" in
  y|Y)
    pass H-09 "claude --continue resumed the earlier session"
    exit 0
    ;;
esac

fail H-09 "claude --continue did not resume the earlier session" "answer: ${answer:-<none>}"
exit 1
