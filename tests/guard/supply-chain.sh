#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Guard rules on the supply chain: one GSD package, exact pins, no pipes
# ------------------------------------------------------------------------------
# Usage: bash tests/guard/supply-chain.sh (exit 0 = every rule holds)
# Run by tests/guard/run-all.sh; runs alone too.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# no_compromised_gsd_package: GSD comes only from @opengsd/gsd-core
# ------------------------------------------------------------------------------
# The old package was compromised. Scans every file that is built into an
# image, runs at start or drives a host test.
# ------------------------------------------------------------------------------
no_compromised_gsd_package() {
  nowhere_matches 'get-shit-done-cc|gsd-build' $SANDBOX_FILES claude/start.d/* claude/managed-settings.json best-practices/rules/* best-practices/skills/*/* SANDBOX.md tests/host-checklist.md tests/host/*.sh tests/host/manual/*.sh tests/host/support/* tests/selftest/*.sh tests/selftest/*/*.sh tests/selftest/*/support/*
}

# ------------------------------------------------------------------------------
# gsd_installs_only_the_official_package: the Claude image installs pinned GSD
# ------------------------------------------------------------------------------
gsd_installs_only_the_official_package() {
  if ! grep -Fq 'npm install -g "@opengsd/gsd-core@${GSD_CORE_VERSION}"' $CLAUDE; then
    echo "    $CLAUDE does not install \"@opengsd/gsd-core@\${GSD_CORE_VERSION}\""
    return 1
  fi

  return 0
}

# ------------------------------------------------------------------------------
# no_pipe_to_shell_installers: nothing is installed by piping a download to sh
# ------------------------------------------------------------------------------
# Each download line is read with the next one, so a pipe two lines down is not
# seen. Refused: a pipe into sh or bash, and a shell run on a download.
# ------------------------------------------------------------------------------
no_pipe_to_shell_installers() {
  local pipeRegex='(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh([[:space:]]|$)'
  local substitutionRegex='(^|[^A-Za-z_])((ba)?sh|source|eval|\.)[[:space:]]+(-[A-Za-z]+[[:space:]]+)*"?(<|\$)\([[:space:]]*(curl|wget)'

  if grep -hE -A1 'curl|wget' $DOCKERFILES | tr '\n' ' ' | grep -qE -e "$pipeRegex" -e "$substitutionRegex"; then
    grep -nE 'curl|wget' $DOCKERFILES | sed 's/^/    /'
    return 1
  fi

  nowhere_matches "$pipeRegex|$substitutionRegex" $ENTRY claude/start.d/* build.sh clean.sh
}

# ------------------------------------------------------------------------------
# installs_use_pins: every install is NAME@${X_VERSION}, so versions.env decides
# ------------------------------------------------------------------------------
# A pin with no ARG expands empty, and each install RUN's own ${X_VERSION:?}
# check stops the build. npx, npm exec, pip and uv installs have no pin at all.
# ------------------------------------------------------------------------------
installs_use_pins() {
  local ok=0
  local leftOver

  leftOver=$(grep -hE 'npm (install|i|add) ' $DOCKERFILES | sed -E 's#"[@A-Za-z0-9._/-]+@\$\{[A-Z_]+_VERSION\}"##g' | grep -E 'npm (install|i|add)( +-[^ ]+)* +[^- \\&;|]')

  if [ -n "$leftOver" ]; then
    printf '%s\n' "$leftOver" | sed 's/^/    an npm install argument that is not "NAME@${X_VERSION}": /'
    ok=1
  fi

  nowhere_matches '(^|[[:space:];&(])(npx|uvx)[[:space:]]|npm[[:space:]]+exec|pip3?[[:space:]]+install|uv[[:space:]]+(tool|pip)[[:space:]]+install' $DOCKERFILES || ok=1

  return "$ok"
}

# ------------------------------------------------------------------------------
# no_floating_latest_versions: what is in the image changes only with a pin
# ------------------------------------------------------------------------------
no_floating_latest_versions() {
  nowhere_matches ':latest|@latest' $SANDBOX_FILES
}

# ------------------------------------------------------------------------------
# pin_lines: prints the lines of versions.env that are not blank or comments
# ------------------------------------------------------------------------------
pin_lines() {
  grep -Ev '^[[:space:]]*(#.*)?$' versions.env 2>/dev/null
}

# ------------------------------------------------------------------------------
# report_problems TEXT: prints TEXT and returns 1 when it is not empty
# ------------------------------------------------------------------------------
report_problems() {
  if [ -z "$1" ]; then
    return 0
  fi

  printf '%s\n' "$1"
  return 1
}

# ------------------------------------------------------------------------------
# versions_file_has_one_pin_per_line: NAME=value lines, no name set twice
# ------------------------------------------------------------------------------
versions_file_has_one_pin_per_line() {
  local ok=0
  local badLines
  local repeatedNames

  if [ ! -f versions.env ]; then
    echo "    versions.env is missing"
    return 1
  fi

  badLines=$(pin_lines | grep -Ev '^[A-Z_]+=[^[:space:]]+$' | sed 's/^/    versions.env: not a NAME=value line: /')
  repeatedNames=$(pin_lines | sed 's/=.*//' | sort | uniq -d | sed 's/.*/    versions.env: & is set on more than one line/')
  report_problems "$badLines" || ok=1
  report_problems "$repeatedNames" || ok=1

  return "$ok"
}

# ------------------------------------------------------------------------------
# pins_are_exact: _VERSION is x.y.z, _IMAGE is tag@sha256:digest, no other kind
# ------------------------------------------------------------------------------
pins_are_exact() {
  local ok=0
  local badVersions
  local badImages
  local otherNames

  badVersions=$(pin_lines | grep -E '^[A-Z_]+_VERSION=' | grep -Ev '^[A-Z_]+_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/.*/    versions.env: & is not an exact x.y.z version/')
  badImages=$(pin_lines | grep -E '^[A-Z_]+_IMAGE=' | grep -Ev '^[A-Z_]+_IMAGE=[a-z0-9][a-z0-9./-]*:[A-Za-z0-9._-]+@sha256:[0-9a-f]{64}$' | sed 's/.*/    versions.env: & is not an image tag with its @sha256 digest/')
  otherNames=$(pin_lines | grep -Ev '^[A-Z_]+_(VERSION|IMAGE)=' | sed 's/=.*//' | sed 's/.*/    versions.env: & must end in _VERSION or _IMAGE/')
  report_problems "$badVersions" || ok=1
  report_problems "$badImages" || ok=1
  report_problems "$otherNames" || ok=1

  return "$ok"
}

# ------------------------------------------------------------------------------
# dockerfile_args_have_no_defaults: no ARG default, every FROM takes a pin
# ------------------------------------------------------------------------------
# The one exception is the local base tag in the Claude Dockerfile.
# ------------------------------------------------------------------------------
dockerfile_args_have_no_defaults() {
  local ok=0
  local dockerfile
  local defaults
  local looseFroms

  for dockerfile in $DOCKERFILES; do
    defaults=$(grep -E '^ARG .*=' "$dockerfile")

    if [ "$dockerfile" = "$CLAUDE" ]; then
      defaults=$(printf '%s\n' "$defaults" | grep -Fvx 'ARG BASE_IMAGE=sbx-base:local')
    fi

    report_problems "$(printf '%s' "$defaults" | sed "s|^|    $dockerfile: an ARG with a default value: |")" || ok=1
  done

  looseFroms=$(grep -E '^FROM ' "$BASE" | grep -Ev '^FROM \$\{[A-Z_]+\}( AS [a-z]+)?$' | sed "s|^|    $BASE: FROM must take its image from a pin: |")
  report_problems "$looseFroms" || ok=1

  return "$ok"
}

# ------------------------------------------------------------------------------
# every_dockerfile_arg_is_pinned: ARGs and versions.env pins match both ways
# ------------------------------------------------------------------------------
every_dockerfile_arg_is_pinned() {
  local ok=0
  local dockerfile
  local argName
  local pinName

  for dockerfile in $DOCKERFILES; do
    for argName in $(grep -E '^ARG [^=]*$' "$dockerfile" | sed 's/^ARG //'); do
      if ! grep -q "^${argName}=" versions.env; then
        echo "    $dockerfile declares ARG $argName, which versions.env does not set"
        ok=1
      fi
    done
  done

  for pinName in $(pin_lines | grep -E '^[A-Z_]+=' | sed 's/=.*//'); do
    if ! grep -Fxq -- "ARG $pinName" $DOCKERFILES; then
      echo "    versions.env sets $pinName, which no Dockerfile declares"
      ok=1
    fi
  done

  return "$ok"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  no_compromised_gsd_package \
  gsd_installs_only_the_official_package \
  no_pipe_to_shell_installers \
  installs_use_pins \
  no_floating_latest_versions \
  versions_file_has_one_pin_per_line \
  pins_are_exact \
  dockerfile_args_have_no_defaults \
  every_dockerfile_arg_is_pinned || exit 1
