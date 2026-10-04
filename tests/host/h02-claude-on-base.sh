#!/usr/bin/env bash
# H-02: the Claude image is built on the base image. Its layers start with all the base
# layers, and claude/Dockerfile has one FROM line: FROM ${BASE_IMAGE}.
# Depends on: nothing
# Needs: images built
set -u
. "$(dirname "$0")/lib.sh"
host_init

layerTemplate='{{range .RootFS.Layers}}{{println .}}{{end}}'
baseLayers=$(docker image inspect --format "$layerTemplate" sbx-base:local </dev/null 2>&1)
claudeLayers=$(docker image inspect --format "$layerTemplate" sbx-claude:local </dev/null 2>&1)
layerProblem=""
fromProblem=""

if [ -z "$baseLayers" ]; then
  layerProblem="sbx-base:local reported no layers"
else
  baseCount=$(( $(printf '%s\n' "$baseLayers" | wc -l) ))
  claudePrefix=$(printf '%s\n' "$claudeLayers" | head -n "$baseCount")

  if [ "$claudePrefix" != "$baseLayers" ]; then
    i=1
    while [ "$i" -le "$baseCount" ]; do
      baseLine=$(printf '%s\n' "$baseLayers" | sed -n "${i}p")
      claudeLine=$(printf '%s\n' "$claudeLayers" | sed -n "${i}p")
      if [ "$baseLine" != "$claudeLine" ]; then
        layerProblem="layer $i differs: base has ${baseLine:-nothing}, Claude image has ${claudeLine:-nothing}"
        break
      fi
      i=$((i + 1))
    done
  fi
fi

fromCount=$(grep -c '^FROM' "$REPO_DIR/claude/Dockerfile")
if [ "$fromCount" -ne 1 ] || ! grep -Fxq 'FROM ${BASE_IMAGE}' "$REPO_DIR/claude/Dockerfile"; then
  fromProblem="claude/Dockerfile must have exactly one FROM line, FROM \${BASE_IMAGE} (found $fromCount FROM lines)"
fi

set --
if [ -n "$layerProblem" ]; then
  set -- "$@" "$layerProblem"
fi
if [ -n "$fromProblem" ]; then
  set -- "$@" "$fromProblem"
fi

if [ "$#" -gt 0 ]; then
  fail H-02 "the Claude image is not cleanly on top of the base image" "$@"
  exit 1
fi

pass H-02 "the Claude image sits on the $baseCount base layers; claude/Dockerfile has one FROM line"
exit 0
