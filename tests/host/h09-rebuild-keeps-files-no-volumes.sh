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

sentinelText="h09-$$-$(date +%s)"
memorySentinel=$RUN/state/claude/projects/-home-sandbox-workspace-hosttest/memory/h09-memory.md
cacheFlag=""

# --------------------------------------------------------------------------------
# Writes the three sentinel files and records the volume list before the rebuild
# --------------------------------------------------------------------------------
plant_sentinels() {
  printf '%s\n' "$sentinelText" >"$RUN/hosttest/h09-sentinel.txt"
  printf '%s\n' "$sentinelText" >"$RUN/state/h09-sentinel.txt"
  mkdir -p "$(dirname "$memorySentinel")"
  printf '%s\n' "$sentinelText" >"$memorySentinel"
  volumesBefore=$(docker volume ls -q </dev/null 2>&1)
}

# --------------------------------------------------------------------------------
# Takes the sandbox down, rebuilds both images and starts it again
# --------------------------------------------------------------------------------
rebuild_and_restart() {
  if [ "${SBXTEST_NO_CACHE:-0}" = "1" ]; then
    cacheFlag="--no-cache"
  fi

  if ! compose_down >"$RUN/logs/h09-down.log" 2>&1; then
    add_problem "compose down failed; log: $RUN/logs/h09-down.log"
  fi

  if ! build_images rebuild "$cacheFlag"; then
    add_problem "the rebuild failed (see the build log above)"
  fi

  if ! compose_up; then
    add_problem "compose up failed after the rebuild; log: $RUN/logs/compose-up.log"
  fi
}

# --------------------------------------------------------------------------------
# Checks the three sentinel files still hold their text
# --------------------------------------------------------------------------------
check_sentinels_survived() {
  local sentinelFile

  for sentinelFile in "$RUN/hosttest/h09-sentinel.txt" "$RUN/state/h09-sentinel.txt" "$memorySentinel"; do
    if [ "$(cat "$sentinelFile" 2>/dev/null)" != "$sentinelText" ]; then
      add_problem "$sentinelFile is missing or changed after the rebuild"
    fi
  done
}

# --------------------------------------------------------------------------------
# Checks the rebuild created no volume
# --------------------------------------------------------------------------------
check_volumes_unchanged() {
  local volumesAfter

  volumesAfter=$(docker volume ls -q </dev/null 2>&1)

  if [ "$volumesBefore" != "$volumesAfter" ]; then
    add_problem "the volume list changed during the rebuild"
    add_problem "before: $(join_lines "$volumesBefore")"
    add_problem "after:  $(join_lines "$volumesAfter")"
  fi
}

# --------------------------------------------------------------------------------
# Checks the container has exactly one bind mount of the run folder at the workspace
# --------------------------------------------------------------------------------
check_one_bind_mount() {
  local mountLines mountCount runBase mountType mountDestination mountSource

  mountLines=$(docker container inspect \
    --format '{{range .Mounts}}{{.Type}} {{.Destination}} {{.Source}}{{println}}{{end}}' \
    "$CONTAINER" </dev/null 2>&1 | grep .)
  mountCount=$(printf '%s\n' "$mountLines" | grep -c .)
  runBase=$(basename "$RUN")

  if [ "$mountCount" -ne 1 ]; then
    add_problem "expected exactly one mount; got $mountCount: $(join_lines "$mountLines" ';')"
  else
    mountType=$(printf '%s\n' "$mountLines" | cut -d' ' -f1)
    mountDestination=$(printf '%s\n' "$mountLines" | cut -d' ' -f2)
    mountSource=$(printf '%s\n' "$mountLines" | cut -d' ' -f3-)

    if [ "$mountType" != "bind" ] || [ "$mountDestination" != "/home/sandbox/workspace" ]; then
      add_problem "expected a bind mount at /home/sandbox/workspace; got: $mountLines"
    fi

    case "$mountSource" in
      *"/$runBase") ;;
      *) add_problem "the mount Source does not end in $runBase; Source is: $mountSource" ;;
    esac
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-09 || exit 1
plant_sentinels
rebuild_and_restart
check_sentinels_survived
check_volumes_unchanged
check_one_bind_mount
report_check H-09 "the rebuild lost something or the mounts are wrong" \
  "files survived the rebuild, the volume list is unchanged, one bind mount ${cacheFlag:+(built with $cacheFlag)}"
