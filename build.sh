#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Builds sbx-base:local, then sbx-claude:local, with the pins in versions.env
# ------------------------------------------------------------------------------
# Usage: ./build.sh [DOCKER_BUILD_OPTION...]
# Extra options go to both builds, for example --no-cache.
# With SBX_CA_CERT set to a PEM file, both images also trust its root
# certificates.
# ------------------------------------------------------------------------------
set -eu

# ------------------------------------------------------------------------------
# check_versions_file: stops when versions.env is not next to this script
# ------------------------------------------------------------------------------
check_versions_file() {
  if [ ! -f ./versions.env ]; then
    echo "build.sh: versions.env is missing next to build.sh" >&2
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# load_versions: exports every NAME=value line of versions.env
# ------------------------------------------------------------------------------
# The file is read by bash, so it is code. The ./ stops a PATH search for it.
# ------------------------------------------------------------------------------
load_versions() {
  set -a
  source ./versions.env
  set +a
}

# ------------------------------------------------------------------------------
# collect_build_args: fills buildArgList with a --build-arg per pin
# ------------------------------------------------------------------------------
# A bare NAME has no value here: Docker reads it from the environment.
# So adding or bumping a pin never changes this file.
# ------------------------------------------------------------------------------
collect_build_args() {
  local pinName
  local pinCount=0

  buildArgList=()

  for pinName in $(grep -oE '^[A-Z_]+' versions.env); do
    buildArgList+=(--build-arg "$pinName")
    pinCount=$((pinCount + 1))
  done

  if [ "$pinCount" -eq 0 ]; then
    echo "build.sh: versions.env holds no pins" >&2
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# build_image DOCKERFILE TAG [OPTION...]: builds TAG with every pin
# ------------------------------------------------------------------------------
# The options come right after docker build.
# ------------------------------------------------------------------------------
build_image() {
  local dockerfile=$1
  local imageTag=$2

  shift 2

  echo "build.sh: building $imageTag"
  docker build "$@" -f "$dockerfile" "${buildArgList[@]}" -t "$imageTag" .
}

# ------------------------------------------------------------------------------
# prepare_extra_cert: with SBX_CA_CERT set, splits it into extraCertDir
# ------------------------------------------------------------------------------
# extraCertDir holds one .crt file per certificate. Only certificate blocks are
# kept, so a key in the same file never reaches the build. It stays empty when
# the variable is unset or empty.
# ------------------------------------------------------------------------------
prepare_extra_cert() {
  extraCertDir=""

  if [ -z "${SBX_CA_CERT:-}" ]; then
    return 0
  fi

  extraCertDir=$(mktemp -d "${TMPDIR:-/tmp}/sbx-cacert.XXXXXX") || return 1
  trap 'rm -rf "$extraCertDir"' EXIT

  if ! awk -v dir="$extraCertDir" '/-----BEGIN CERTIFICATE-----/ { count++; out = sprintf("%s/sbx-extra-ca-%d.crt", dir, count); inCert = 1 } inCert { print > out } /-----END CERTIFICATE-----/ { inCert = 0; close(out) } END { if (count == 0) { exit 1 } }' "$SBX_CA_CERT"; then
    echo "build.sh: SBX_CA_CERT holds no PEM certificate: $SBX_CA_CERT" >&2
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
cd "$(dirname "$0")"

check_versions_file
load_versions
collect_build_args
prepare_extra_cert || exit 1

if [ -n "$extraCertDir" ]; then
  build_image base/Dockerfile sbx-base:local --build-context "cacert=$extraCertDir" "$@"
else
  build_image base/Dockerfile sbx-base:local "$@"
fi

build_image claude/Dockerfile sbx-claude:local "$@"
