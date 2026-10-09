#!/usr/bin/env bash
# H-23: the npm, uv and Maven caches live in the state folder and survive a recreate.
# - npm and uv find their caches through image ENV (npm config get cache, uv cache dir), and ~/.m2 is a link into state/m2.
# - The entrypoint makes state/cache/npm, state/cache/uv and state/m2 at start.
# - A run-unique file is written into each cache from inside the container. It must be on the Mac,
#   and still be there after the sandbox is taken down and started again.
# - A real Maven download (junit 4.13.2) is run in the project folder as the sandbox user. The jar must be on the Mac,
#   and still be there after the recreate. Maven 3.9.12 and later fail here on the Docker Desktop for Mac mount.
# - The files are left in the run folder for the printed cleanup.
# Depends on: nothing
# Needs: test sandbox running with network access to Maven Central; stops and restarts it
set -u
. "$(dirname "$0")/lib.sh"
host_init

marker="h23-$$-$(date +%s)"
mavenJar="$RUN/state/m2/repository/junit/junit/4.13.2/junit-4.13.2.jar"

# --------------------------------------------------------------------------------
# container_stdout CMD...: runs CMD in the test container; stdin closed, stderr discarded, so a tool notice never reaches a compared value.
# --------------------------------------------------------------------------------
container_stdout() {
  docker exec "$CONTAINER" "$@" </dev/null 2>/dev/null
}

# --------------------------------------------------------------------------------
# Checks the entrypoint made the three cache folders on the Mac
# --------------------------------------------------------------------------------
check_state_folders() {
  local folderName

  for folderName in cache/npm cache/uv m2; do
    if [ ! -d "$RUN/state/$folderName" ]; then
      add_problem "state/$folderName is not a folder; the entrypoint did not make it"
    fi
  done
}

# --------------------------------------------------------------------------------
# Checks npm, uv and Maven find their caches under state
# --------------------------------------------------------------------------------
check_cache_locations() {
  local npmCache uvCache m2Link

  npmCache=$(container_stdout npm config get cache)

  if [ "$npmCache" != "/home/sandbox/workspace/state/cache/npm" ]; then
    add_problem "npm keeps its cache in '$npmCache', not in /home/sandbox/workspace/state/cache/npm"
  fi

  uvCache=$(container_stdout uv cache dir)

  if [ "$uvCache" != "/home/sandbox/workspace/state/cache/uv" ]; then
    add_problem "uv keeps its cache in '$uvCache', not in /home/sandbox/workspace/state/cache/uv"
  fi

  m2Link=$(container_stdout readlink /home/sandbox/.m2)

  if [ "$m2Link" != "/home/sandbox/workspace/state/m2" ]; then
    add_problem "~/.m2 points to '$m2Link', not to /home/sandbox/workspace/state/m2"
  fi
}

# --------------------------------------------------------------------------------
# Writes the marker into a file in each cache, from inside the container
# --------------------------------------------------------------------------------
# The first command is a no-op that names the script, so the fake docker can recognise it.
plant_cache_files() {
  in_container sh -c ': h23-plant; for cacheDir in "$NPM_CONFIG_CACHE" "$UV_CACHE_DIR" "$HOME/.m2"; do printf "%s\n" "$1" >"$cacheDir/$1"; done' h23-plant "$marker" >/dev/null
}

# --------------------------------------------------------------------------------
# Downloads junit 4.13.2 with Maven as the sandbox user, in the project folder
# --------------------------------------------------------------------------------
download_maven_artifact() {
  local mvnOutput mvnStatus

  mvnOutput=$(run_timeout 300 in_project mvn -q dependency:get -Dartifact=junit:junit:4.13.2)
  mvnStatus=$?

  if [ "$mvnStatus" -ne 0 ]; then
    add_problem "mvn dependency:get exited with status $mvnStatus; an 'Input/output error' or 'Failed to delete tracking file' means this Maven cannot keep its local repository on the Mac mount (see SANDBOX.md troubleshooting); last lines: $(printf '%s\n' "$mvnOutput" | tail -n 5 | tr '\n' ' ')"
  fi
}

# --------------------------------------------------------------------------------
# check_files_on_host WHEN: checks each cache folder on the Mac holds the marker file and the Maven jar; WHEN says which moment goes in the message.
# --------------------------------------------------------------------------------
check_files_on_host() {
  local folderName

  for folderName in cache/npm cache/uv m2; do
    if ! grep -Fq "$marker" "$RUN/state/$folderName/$marker" 2>/dev/null; then
      add_problem "state/$folderName/$marker is missing on the Mac $1"
    fi
  done

  if [ ! -f "$mavenJar" ]; then
    add_problem "state/m2/repository/junit/junit/4.13.2/junit-4.13.2.jar is missing on the Mac $1"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-23 || exit 1
check_state_folders
check_cache_locations
plant_cache_files
download_maven_artifact
check_files_on_host "before the recreate"
restart_test_sandbox H-23 h23-down.log || exit 1
check_files_on_host "after the recreate"
report_check H-23 "a cache is not in the state folder or did not survive the recreate" \
  "npm, uv and Maven use state/cache/npm, state/cache/uv and state/m2, a file in each survived the recreate, and a Maven download of junit 4.13.2 reached state/m2 and survived it"
