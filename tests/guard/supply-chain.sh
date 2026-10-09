#!/usr/bin/env bash
# Guard rules on the supply chain: GSD comes from one package, and every tool is pinned in versions.env and never piped into a shell.
# - Run by tests/guard/run-all.sh; runs alone too.
# - Usage, from anywhere: bash tests/guard/supply-chain.sh   (exit 0 = every rule holds)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# no_compromised_gsd_package: GSD must come only from @opengsd/gsd-core: the old package was compromised.
# --------------------------------------------------------------------------------
no_compromised_gsd_package() {
  nowhere_matches 'get-shit-done-cc|gsd-build' $SANDBOX_FILES SANDBOX.md tests/host-checklist.md tests/host/*.sh tests/selftest/*.sh tests/selftest/*/*.sh tests/selftest/*/support/*
}

# --------------------------------------------------------------------------------
# no_pipe_to_shell_installers: Nothing is installed by piping a download into a shell (unverified code).
# --------------------------------------------------------------------------------
no_pipe_to_shell_installers() {
  nowhere_matches '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh([[:space:]]|$)' $DOCKERFILES
}

# --------------------------------------------------------------------------------
# no_floating_latest_versions: No floating versions: what is in the image changes only when a pin changes.
# --------------------------------------------------------------------------------
no_floating_latest_versions() {
  nowhere_matches ':latest|@latest' $SANDBOX_FILES
}

# --------------------------------------------------------------------------------
# versions_are_pinned: Every version is an exact pin set once in versions.env, and the Dockerfiles take versions only from there.
# --------------------------------------------------------------------------------
# Fail closed: every problem found is printed. The only ARG with a default is the local base tag.
versions_are_pinned() {
  local ok=0
  local lineText pinName pinValue dockerfile argText argName
  local seenNameText=" "
  local declaredNameText=" "

  if [ ! -f versions.env ]; then
    echo "    versions.env is missing"
    return 1
  fi

  while IFS= read -r lineText; do
    if printf '%s\n' "$lineText" | grep -Eq '^[[:space:]]*(#.*)?$'; then
      continue
    fi

    if ! printf '%s\n' "$lineText" | grep -Eq '^[A-Z_]+=[^[:space:]]+$'; then
      echo "    versions.env: not a NAME=value line: $lineText"
      ok=1
      continue
    fi

    pinName=${lineText%%=*}
    pinValue=${lineText#*=}

    case "$seenNameText" in
      *" $pinName "*)
        echo "    versions.env: $pinName is set on more than one line"
        ok=1
        ;;
    esac

    seenNameText="$seenNameText$pinName "

    case "$pinName" in
      *_VERSION)
        if ! printf '%s\n' "$pinValue" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
          echo "    versions.env: $pinName=$pinValue is not an exact x.y.z version"
          ok=1
        fi
        ;;
      *_IMAGE)
        if ! printf '%s\n' "$pinValue" | grep -Eq '^[a-z0-9][a-z0-9./-]*:[A-Za-z0-9._-]+@sha256:[0-9a-f]{64}$'; then
          echo "    versions.env: $pinName=$pinValue is not an image tag with its @sha256 digest"
          ok=1
        fi
        ;;
      *)
        echo "    versions.env: $pinName must end in _VERSION or _IMAGE"
        ok=1
        ;;
    esac
  done <<EOF
$(cat versions.env)
EOF

  for dockerfile in $DOCKERFILES; do
    while IFS= read -r lineText; do
      if [ -z "$lineText" ]; then
        continue
      fi

      argText=${lineText#ARG }

      case "$argText" in
        *=*)
          if [ "$dockerfile" = "$CLAUDE" ] && [ "$lineText" = "ARG BASE_IMAGE=sbx-base:local" ]; then
            continue
          fi

          echo "    $dockerfile: an ARG with a default value: $lineText"
          ok=1
          ;;
        *)
          argName=$argText
          declaredNameText="$declaredNameText$argName "

          case "$seenNameText" in
            *" $argName "*) ;;
            *)
              echo "    $dockerfile declares ARG $argName, which versions.env does not set"
              ok=1
              ;;
          esac
          ;;
      esac
    done <<EOF
$(grep -E '^ARG ' "$dockerfile")
EOF
  done

  for pinName in $seenNameText; do
    case "$declaredNameText" in
      *" $pinName "*) ;;
      *)
        echo "    versions.env sets $pinName, which no Dockerfile declares"
        ok=1
        ;;
    esac
  done

  while IFS= read -r lineText; do
    if [ -z "$lineText" ]; then
      continue
    fi

    if ! printf '%s\n' "$lineText" | grep -Eq '^FROM \$\{[A-Z_]+\}( AS [a-z]+)?$'; then
      echo "    $BASE: FROM must take its image from a pin: $lineText"
      ok=1
    fi
  done <<EOF
$(grep -E '^FROM ' "$BASE")
EOF

  return "$ok"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  no_compromised_gsd_package \
  no_pipe_to_shell_installers \
  no_floating_latest_versions \
  versions_are_pinned || exit 1
