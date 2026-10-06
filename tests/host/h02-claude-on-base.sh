#!/usr/bin/env bash
# H-02: the Claude image is built on the base image. Its layers start with all the base
# layers, and claude/Dockerfile has one FROM line: FROM ${BASE_IMAGE}.
# Depends on: nothing
# Needs: images built
set -u
. "$(dirname "$0")/lib.sh"
host_init

# --------------------------------------------------------------------------------
# Reads the layer lists of both images
# --------------------------------------------------------------------------------
read_layers() {
  layerTemplate='{{range .RootFS.Layers}}{{println .}}{{end}}'
  baseLayers=$(docker image inspect --format "$layerTemplate" sbx-base:local </dev/null 2>&1)
  claudeLayers=$(docker image inspect --format "$layerTemplate" sbx-claude:local </dev/null 2>&1)
  baseCount=0
}

# --------------------------------------------------------------------------------
# Checks the Claude image's layers start with every base layer
# --------------------------------------------------------------------------------
check_layer_prefix() {
  local claudePrefix
  local i
  local baseLine
  local claudeLine

  if [ -z "$baseLayers" ]; then
    add_problem "sbx-base:local reported no layers"
  else
    baseCount=$(( $(printf '%s\n' "$baseLayers" | wc -l) ))
    claudePrefix=$(printf '%s\n' "$claudeLayers" | head -n "$baseCount")

    if [ "$claudePrefix" != "$baseLayers" ]; then
      i=1
      while [ "$i" -le "$baseCount" ]; do
        baseLine=$(printf '%s\n' "$baseLayers" | sed -n "${i}p")
        claudeLine=$(printf '%s\n' "$claudeLayers" | sed -n "${i}p")

        if [ "$baseLine" != "$claudeLine" ]; then
          add_problem "layer $i differs: base has ${baseLine:-nothing}, Claude image has ${claudeLine:-nothing}"
          break
        fi

        i=$((i + 1))
      done
    fi
  fi
}

# --------------------------------------------------------------------------------
# Checks claude/Dockerfile has one FROM line, FROM ${BASE_IMAGE}
# --------------------------------------------------------------------------------
check_single_from_line() {
  local fromCount

  fromCount=$(grep -c '^FROM' "$REPO_DIR/claude/Dockerfile")
  if [ "$fromCount" -ne 1 ] || ! grep -Fxq 'FROM ${BASE_IMAGE}' "$REPO_DIR/claude/Dockerfile"; then
    add_problem "claude/Dockerfile must have exactly one FROM line, FROM \${BASE_IMAGE} (found $fromCount FROM lines)"
  fi
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
read_layers
check_layer_prefix
check_single_from_line
report_check H-02 "the Claude image is not cleanly on top of the base image" \
  "the Claude image sits on the $baseCount base layers; claude/Dockerfile has one FROM line"
