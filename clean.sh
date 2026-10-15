#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Frees Docker disk space on the Mac and removes leftover host-test runs
# ------------------------------------------------------------------------------
# Usage: ./clean.sh [--yes]
# Without --yes it only shows what it would remove.
# ------------------------------------------------------------------------------
set -u

# ------------------------------------------------------------------------------
# test_container_mount_source: prints the host folder sbx-hosttest mounts
# ------------------------------------------------------------------------------
# It is the folder mounted at /home/sandbox/workspace; nothing if there is none.
# ------------------------------------------------------------------------------
test_container_mount_source() {
  docker container inspect --format '{{range .Mounts}}{{if eq .Destination "/home/sandbox/workspace"}}{{.Source}}{{end}}{{end}}' sbx-hosttest 2>/dev/null </dev/null
}

# ------------------------------------------------------------------------------
# test_container_verdict: prints absent, remove or keep for sbx-hosttest
# ------------------------------------------------------------------------------
# Only a container that mounts a host-test run folder is removed; a sandbox of
# yours that is named hosttest is kept.
# ------------------------------------------------------------------------------
test_container_verdict() {
  if ! docker container inspect sbx-hosttest >/dev/null 2>&1 </dev/null; then
    echo "absent"

    return 0
  fi

  # Docker Desktop may report the temp folder with a /private prefix;
  # the leading * covers it.
  case "$(test_container_mount_source)" in
    *"${tempFolder%/}"/sbx-hosttest-*) echo "remove" ;;
    *) echo "keep" ;;
  esac
}

# ------------------------------------------------------------------------------
# show_state: prints disk use, containers, host-test run folders and images
# ------------------------------------------------------------------------------
# The dry run lists all images; docker image prune -a decides which of them go.
# ------------------------------------------------------------------------------
show_state() {
  echo "=== Docker disk use"
  docker system df
  echo
  echo "=== Containers (all kept, except sbx-hosttest when it mounts a host-test run folder)"
  docker ps -a --format '{{.Names}}  {{.Image}}  {{.Status}}'

  case "$testVerdict" in
    remove) echo "sbx-hosttest mounts a host-test run folder: --yes removes it" ;;
    keep) echo "sbx-hosttest does not mount a host-test run folder: --yes keeps it" ;;
  esac

  echo
  echo "=== Host-test run folders"

  if [ -n "$runFolderList" ]; then
    echo "$runFolderList"
  else
    echo "(none)"
  fi

  echo
  echo "=== Images"
  docker image ls
  echo "--yes runs docker image prune -a: it removes every image no container uses"
  echo
}

# ------------------------------------------------------------------------------
# remove_test_runs: removes the test sandbox, its network and the run folders
# ------------------------------------------------------------------------------
# Each run folder may hold a test Claude login.
# ------------------------------------------------------------------------------
remove_test_runs() {
  local runFolder

  echo "=== Removing the test sandbox"

  case "$testVerdict" in
    remove)
      docker rm -f sbx-hosttest
      docker network rm sbx-hosttest_default 2>/dev/null || echo "(no sbx-hosttest_default network)"
      ;;
    keep)
      echo "sbx-hosttest does not mount a host-test run folder (it mounts: $(test_container_mount_source)); left alone, with its network"
      ;;
    *)
      echo "(no sbx-hosttest container)"
      docker network rm sbx-hosttest_default 2>/dev/null || echo "(no sbx-hosttest_default network)"
      ;;
  esac

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

# ------------------------------------------------------------------------------
# remove_unused_images: removes the build cache and unused images
# ------------------------------------------------------------------------------
# Other containers, their images and all volumes are kept. sbx-base:local and
# sbx-claude:local go too when unused; ./build.sh rebuilds them.
# ------------------------------------------------------------------------------
remove_unused_images() {
  echo "=== Removing the build cache"
  docker builder prune -a -f
  echo
  echo "=== Removing images no container uses"
  docker image prune -a -f
  echo
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
if [ $# -gt 1 ] || { [ $# -eq 1 ] && [ "$1" != "--yes" ]; }; then
  echo "Usage: ./clean.sh [--yes]" >&2
  exit 2
fi

tempFolder=${TMPDIR:-/tmp}
runFolderList=$(ls -d "${tempFolder%/}"/sbx-hosttest-* 2>/dev/null)
testVerdict=$(test_container_verdict)
show_state

if [ $# -eq 0 ]; then
  echo "Dry run: nothing removed. Run ./clean.sh --yes to clean up."
  exit 0
fi

remove_test_runs
remove_unused_images
echo "=== Docker disk use after"
docker system df
