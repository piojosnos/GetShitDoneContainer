#!/usr/bin/env bash
# Frees Docker disk space on the Mac and removes leftover host-test runs.
# - Without --yes it only shows what it would remove.
# - With --yes it removes:
#   1. the test sandbox container sbx-hosttest and its network,
#   2. every host-test run folder in the macOS temp folder (sbx-hosttest-*); each may hold a test Claude login,
#   3. the Docker build cache,
#   4. every image that no container uses, running or stopped.
# - It keeps every other container (old sandboxes included), the images they use, and all volumes.
# - sbx-base:local and sbx-claude:local go too when no container uses them; ./build.sh rebuilds them.
# - Stock bash 3.2 (macOS).
# - Usage: ./clean.sh [--yes]
set -u

# --------------------------------------------------------------------------------
# show_state: prints disk use, every container and the host-test run folders.
# --------------------------------------------------------------------------------
show_state() {
  echo "=== Docker disk use"
  docker system df
  echo
  echo "=== Containers (all kept, except sbx-hosttest)"
  docker ps -a --format '{{.Names}}  {{.Image}}  {{.Status}}'
  echo
  echo "=== Host-test run folders"

  if [ -n "$runFolderList" ]; then
    echo "$runFolderList"
  else
    echo "(none)"
  fi

  echo
}

# --------------------------------------------------------------------------------
# remove_test_runs: removes the test sandbox, its network and every host-test run folder.
# --------------------------------------------------------------------------------
remove_test_runs() {
  local runFolder

  echo "=== Removing the test sandbox"
  docker rm -f sbx-hosttest 2>/dev/null || echo "(no sbx-hosttest container)"
  docker network rm sbx-hosttest_default 2>/dev/null || echo "(no sbx-hosttest_default network)"
  echo
  echo "=== Removing host-test run folders"

  if [ -z "$runFolderList" ]; then
    echo "(none)"
  fi

  while IFS= read -r runFolder; do
    if [ -n "$runFolder" ]; then
      rm -rf "$runFolder" && echo "removed $runFolder"
    fi
  done <<EOF
$runFolderList
EOF

  echo
}

# --------------------------------------------------------------------------------
# remove_unused_images: removes the build cache and every image no container uses.
# --------------------------------------------------------------------------------
remove_unused_images() {
  echo "=== Removing the build cache"
  docker builder prune -a -f
  echo
  echo "=== Removing images no container uses"
  docker image prune -a -f
  echo
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
if [ $# -gt 1 ] || { [ $# -eq 1 ] && [ "$1" != "--yes" ]; }; then
  echo "Usage: ./clean.sh [--yes]" >&2
  exit 2
fi

tempFolder=${TMPDIR:-/tmp}
runFolderList=$(ls -d "${tempFolder%/}"/sbx-hosttest-* 2>/dev/null)
show_state

if [ $# -eq 0 ]; then
  echo "Dry run: nothing removed. Run ./clean.sh --yes to clean up."
  exit 0
fi

remove_test_runs
remove_unused_images
echo "=== Docker disk use after"
docker system df
