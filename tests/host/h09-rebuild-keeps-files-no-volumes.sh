#!/usr/bin/env bash
# H-09: files survive a rebuild of both images, no volumes appear, and the container has exactly
# one bind mount of the run folder at /home/sandbox/workspace.
# - The rebuild uses the cache. SBXTEST_NO_CACHE=1 (optional) rebuilds with --no-cache; slow.
# - The memory sentinel under state/claude/projects proves a rebuild with restart leaves learned
#   memories alone.
# - The Claude login and claude --continue part needs a person: manual/h09-rebuild-resume.sh.
# - The mount Source is compared by its last path component only, because Docker Desktop may
#   show the folder under a different prefix.
# Depends on: nothing
# Needs: test sandbox running; stops and restarts it
set -u
. "$(dirname "$0")/lib.sh"
host_init
require_test_sandbox H-09 || exit 1

sentinelText="h09-$$-$(date +%s)"
printf '%s\n' "$sentinelText" >"$RUN/hosttest/h09-sentinel.txt"
printf '%s\n' "$sentinelText" >"$RUN/state/h09-sentinel.txt"
memorySentinel=$RUN/state/claude/projects/-home-sandbox-workspace-hosttest/memory/h09-memory.md
mkdir -p "$(dirname "$memorySentinel")"
printf '%s\n' "$sentinelText" >"$memorySentinel"
volumesBefore=$(docker volume ls -q </dev/null 2>&1)

cacheFlag=""
if [ "${SBXTEST_NO_CACHE:-0}" = "1" ]; then
  cacheFlag="--no-cache"
fi

set --

if ! compose_down >"$RUN/logs/h09-down.log" 2>&1; then
  set -- "$@" "compose down failed; log: $RUN/logs/h09-down.log"
fi

if ! build_images rebuild "$cacheFlag"; then
  set -- "$@" "the rebuild failed (see the build log above)"
fi

if ! compose_up; then
  set -- "$@" "compose up failed after the rebuild; log: $RUN/logs/compose-up.log"
fi

for sentinelFile in "$RUN/hosttest/h09-sentinel.txt" "$RUN/state/h09-sentinel.txt" "$memorySentinel"; do
  if [ "$(cat "$sentinelFile" 2>/dev/null)" != "$sentinelText" ]; then
    set -- "$@" "$sentinelFile is missing or changed after the rebuild"
  fi
done

volumesAfter=$(docker volume ls -q </dev/null 2>&1)
if [ "$volumesBefore" != "$volumesAfter" ]; then
  set -- "$@" "the volume list changed during the rebuild" \
    "before: $(printf '%s\n' "$volumesBefore" | tr '\n' ' ')" \
    "after:  $(printf '%s\n' "$volumesAfter" | tr '\n' ' ')"
fi

mountLines=$(docker container inspect \
  --format '{{range .Mounts}}{{.Type}} {{.Destination}} {{.Source}}{{println}}{{end}}' \
  "$CONTAINER" </dev/null 2>&1 | grep .)
mountCount=$(printf '%s\n' "$mountLines" | grep -c .)
runBase=$(basename "$RUN")

if [ "$mountCount" -ne 1 ]; then
  set -- "$@" "expected exactly one mount; got $mountCount: $(printf '%s\n' "$mountLines" | tr '\n' ';')"
else
  mountType=$(printf '%s\n' "$mountLines" | cut -d' ' -f1)
  mountDestination=$(printf '%s\n' "$mountLines" | cut -d' ' -f2)
  mountSource=$(printf '%s\n' "$mountLines" | cut -d' ' -f3-)

  if [ "$mountType" != "bind" ] || [ "$mountDestination" != "/home/sandbox/workspace" ]; then
    set -- "$@" "expected a bind mount at /home/sandbox/workspace; got: $mountLines"
  fi

  case "$mountSource" in
    *"/$runBase") ;;
    *) set -- "$@" "the mount Source does not end in $runBase; Source is: $mountSource" ;;
  esac
fi

if [ "$#" -gt 0 ]; then
  fail H-09 "the rebuild lost something or the mounts are wrong" "$@"
  exit 1
fi

pass H-09 "files survived the rebuild, the volume list is unchanged, one bind mount ${cacheFlag:+(built with $cacheFlag)}"
exit 0
