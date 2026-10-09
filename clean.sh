#!/usr/bin/env bash
# Frees Docker disk space on the Mac and removes leftover host-test runs.
# - Without --yes it only shows what it would remove.
# - With --yes it removes:
#   1. the test sandbox container sbx-hosttest and its network, only when the container mounts a
#      host-test run folder; a sandbox of yours that is named hosttest is refused and kept,
#   2. every host-test run folder in the macOS temp folder (sbx-hosttest-*); each may hold a test Claude login,
#   3. the Docker build cache,
#   4. every image that no container uses, running or stopped.
# - The dry run lists those images, so you see them before --yes removes them.
# - It keeps every other container (old sandboxes included), the images they use, and all volumes.
# - sbx-base:local and sbx-claude:local go too when no container uses them; ./build.sh rebuilds them.
# - Stock bash 3.2 (macOS).
# - Usage: ./clean.sh [--yes]
set -u

# --------------------------------------------------------------------------------
# test_container_mount_source: prints the host folder that sbx-hosttest mounts at /home/sandbox/workspace; prints nothing when there is no such container or mount.
# --------------------------------------------------------------------------------
test_container_mount_source() {
  docker container inspect --format '{{range .Mounts}}{{if eq .Destination "/home/sandbox/workspace"}}{{.Source}}{{end}}{{end}}' sbx-hosttest 2>/dev/null </dev/null
}

# --------------------------------------------------------------------------------
# is_host_test_path PATH: true if PATH is a host-test run folder, or a folder inside one, in the temp folder.
# --------------------------------------------------------------------------------
# Docker Desktop may report the temp folder with a /private prefix; it is dropped on both sides.
is_host_test_path() {
  local pathText=$1
  local tempText=${tempFolder%/}

  case "$pathText" in
    /private/*) pathText=${pathText#/private} ;;
  esac

  case "$tempText" in
    /private/*) tempText=${tempText#/private} ;;
  esac

  case "$pathText" in
    "$tempText"/sbx-hosttest-*) return 0 ;;
  esac

  return 1
}

# --------------------------------------------------------------------------------
# test_container_verdict: prints absent (no sbx-hosttest container), remove (it mounts a host-test run folder) or keep (it does not).
# --------------------------------------------------------------------------------
test_container_verdict() {
  if ! docker container inspect sbx-hosttest >/dev/null 2>&1 </dev/null; then
    echo "absent"

    return 0
  fi

  if is_host_test_path "$(test_container_mount_source)"; then
    echo "remove"
  else
    echo "keep"
  fi
}

# --------------------------------------------------------------------------------
# show_unused_images: lists the images that no container uses, as docker image prune -a would remove them.
# --------------------------------------------------------------------------------
# - sbx-hosttest does not count as a user when it is going to be removed.
# - An image counts as used when a container names it by repository:tag or by ID.
# - This is the list the prune works from; the prune has the last word.
show_unused_images() {
  local usedText
  local containerName
  local containerImage
  local imageName
  local imageId
  local imageSize
  local unusedCount=0

  usedText=$(docker ps -a --no-trunc --format '{{.Names}} {{.Image}}' | while read -r containerName containerImage; do
    if [ "$containerName" != "sbx-hosttest" ] || [ "$testVerdict" != "remove" ]; then
      echo "$containerImage"
    fi
  done)

  while IFS='|' read -r imageName imageId imageSize; do
    if [ -z "$imageName" ]; then
      continue
    fi

    if printf '%s\n' "$usedText" | grep -Fxq -e "$imageName" -e "$imageId" -e "${imageId#sha256:}"; then
      continue
    fi

    echo "$imageName  $imageSize"
    unusedCount=$((unusedCount + 1))
  done <<EOF
$(docker images --no-trunc --format '{{.Repository}}:{{.Tag}}|{{.ID}}|{{.Size}}')
EOF

  if [ "$unusedCount" -eq 0 ]; then
    echo "(none)"
  fi
}

# --------------------------------------------------------------------------------
# show_state: prints disk use, every container, the host-test run folders and the images --yes would remove.
# --------------------------------------------------------------------------------
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
  echo "=== Images that no container uses (--yes removes them)"
  show_unused_images
  echo
}

# --------------------------------------------------------------------------------
# remove_test_runs: removes the test sandbox, its network and every host-test run folder.
# --------------------------------------------------------------------------------
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
