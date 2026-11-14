#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Builds sbx-base, then one image per agent, with the pins in versions.env
# ------------------------------------------------------------------------------
# Usage: ./build.sh [DOCKER_BUILD_OPTION...]
# Extra options go to every build, for example --no-cache.
# With SBX_CA_CERT set to a PEM file, every image also trusts its root
# certificates.
# SBX_IMAGE_TAG picks the tag of all three: local when unset or empty, or test
# for the test run. Any other value stops the build.
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
# build_image DOCKERFILE IMAGE [OPTION...]: builds IMAGE with every pin
# ------------------------------------------------------------------------------
# The options come right after docker build.
# ------------------------------------------------------------------------------
build_image() {
  local dockerfile=$1
  local imageName=$2

  shift 2

  echo "build.sh: building $imageName"
  docker build "$@" -f "$dockerfile" "${buildArgList[@]}" -t "$imageName" .
}

# ------------------------------------------------------------------------------
# prepare_extra_cert: with SBX_CA_CERT set, splits it into extraCertDir
# ------------------------------------------------------------------------------
# extraCertDir holds one .crt file per certificate. Only certificate blocks are
# kept, so a key in the same file never reaches the build. It stays empty when
# the variable is unset or empty.
# ------------------------------------------------------------------------------
prepare_extra_cert() {
  local certPath

  extraCertDir=""

  if [ -z "${SBX_CA_CERT:-}" ]; then
    return 0
  fi

  case "$SBX_CA_CERT" in
    /*) ;;
    *)
      echo "build.sh: SBX_CA_CERT must be an absolute path: $SBX_CA_CERT" >&2
      return 1
      ;;
  esac

  if [ ! -f "$SBX_CA_CERT" ] || [ ! -r "$SBX_CA_CERT" ]; then
    echo "build.sh: SBX_CA_CERT is not a readable file: $SBX_CA_CERT" >&2
    return 1
  fi

  if ! command -v openssl >/dev/null 2>&1; then
    echo "build.sh: SBX_CA_CERT is set, but openssl is missing to check it" >&2
    return 1
  fi

  extraCertDir=$(mktemp -d "${TMPDIR:-/tmp}/sbx-cacert.XXXXXX") || return 1
  trap 'rm -rf "$extraCertDir"' EXIT

  if ! awk -v dir="$extraCertDir" '/-----BEGIN CERTIFICATE-----/ { count++; out = sprintf("%s/sbx-extra-ca-%d.crt", dir, count); inCert = 1 } inCert { print > out } /-----END CERTIFICATE-----/ { inCert = 0; close(out) } END { if (count == 0) { exit 1 } }' "$SBX_CA_CERT"; then
    echo "build.sh: SBX_CA_CERT holds no PEM certificate: $SBX_CA_CERT" >&2
    return 1
  fi

  for certPath in "$extraCertDir"/*.crt; do
    if ! openssl x509 -noout -in "$certPath" >/dev/null 2>&1; then
      echo "build.sh: SBX_CA_CERT holds a block that is not a valid certificate: $SBX_CA_CERT" >&2
      return 1
    fi
  done
}

# ------------------------------------------------------------------------------
# print_cert_banner: prints a starred banner naming the extra root, if any
# ------------------------------------------------------------------------------
# Printed before the first build and after the last. openssl output is only
# shown, never parsed, because LibreSSL and OpenSSL 3 format it differently.
# ------------------------------------------------------------------------------
print_cert_banner() {
  local certPath
  local starLine="******************************************************************************"

  if [ -z "$extraCertDir" ]; then
    return 0
  fi

  echo "$starLine"
  echo "* build.sh: the sbx images trust an EXTRA ROOT CERTIFICATE"
  echo "* file: $SBX_CA_CERT"

  for certPath in "$extraCertDir"/*.crt; do
    openssl x509 -noout -subject -fingerprint -sha256 -in "$certPath" | sed 's/^/* /'
  done

  echo "* Whoever holds its key can read and change HTTPS traffic in the sandbox. See README.md."
  echo "$starLine"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
cd "$(dirname "$0")"

# The agent list and the tag check live once, in the library the sbx-* scripts
# use; its errors start with scriptName.
scriptName=build.sh
. bin/sbx-lib.sh

check_image_tag || exit 1
check_versions_file
load_versions
collect_build_args
prepare_extra_cert || exit 1
print_cert_banner

if [ -n "$extraCertDir" ]; then
  build_image base/Dockerfile "sbx-base:$imageTag" --build-context "cacert=$extraCertDir" "$@"
else
  build_image base/Dockerfile "sbx-base:$imageTag" "$@"
fi

for agent in $knownAgentList; do
  build_image "$agent/Dockerfile" "sbx-$agent:$imageTag" --build-arg "BASE_IMAGE=sbx-base:$imageTag" "$@"
done

print_cert_banner
