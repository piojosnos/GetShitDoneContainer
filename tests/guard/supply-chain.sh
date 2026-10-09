#!/usr/bin/env bash
# Guard rules on the supply chain: GSD comes from one package, and every tool is pinned in versions.env and never piped into a shell.
# - Run by tests/guard/run-all.sh; runs alone too.
# - Usage, from anywhere: bash tests/guard/supply-chain.sh   (exit 0 = every rule holds)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# no_compromised_gsd_package: GSD must come only from @opengsd/gsd-core: the old package was compromised.
# --------------------------------------------------------------------------------
# Scans every file that is built into an image, runs at start or drives a host test.
no_compromised_gsd_package() {
  nowhere_matches 'get-shit-done-cc|gsd-build' $SANDBOX_FILES claude/start.d/* claude/managed-settings.json best-practices/rules/* best-practices/skills/*/* SANDBOX.md tests/host-checklist.md tests/host/*.sh tests/host/manual/*.sh tests/host/support/* tests/selftest/*.sh tests/selftest/*/*.sh tests/selftest/*/support/*
}

# --------------------------------------------------------------------------------
# gsd_installs_only_the_official_package: The GSD install in the Claude image is @opengsd/gsd-core at the pin from versions.env, and nothing else.
# --------------------------------------------------------------------------------
gsd_installs_only_the_official_package() {
  if ! grep -Fq 'npm install -g "@opengsd/gsd-core@${GSD_CORE_VERSION}"' $CLAUDE; then
    echo "    $CLAUDE does not install \"@opengsd/gsd-core@\${GSD_CORE_VERSION}\""
    return 1
  fi

  return 0
}

# --------------------------------------------------------------------------------
# no_pipe_to_shell_installers: Nothing is installed by piping a download into a shell (unverified code).
# --------------------------------------------------------------------------------
# Each Dockerfile RUN step is read as one line, so a line break cannot hide the pipe. Three forms are refused:
# a download piped into sh or bash, a shell run on a downloaded script through process substitution or sh -c, and eval or source of one.
no_pipe_to_shell_installers() {
  local pipeRegex='(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh([[:space:]]|$)'
  local substitutionRegex='(^|[^A-Za-z_])((ba)?sh|source|eval|\.)[[:space:]]+(-[A-Za-z]+[[:space:]]+)*"?(<|\$)\([[:space:]]*(curl|wget)'
  local dockerfile
  local stepHits
  local hits=""

  for dockerfile in $DOCKERFILES; do
    stepHits=$(run_steps_of "$dockerfile" | grep -E -e "$pipeRegex" -e "$substitutionRegex" | sed "s|^|$dockerfile:|")

    if [ -n "$stepHits" ]; then
      hits="$hits$stepHits
"
    fi
  done

  if [ -n "$hits" ]; then
    printf '%s' "$hits" | sed 's/^/    /'
    return 1
  fi

  nowhere_matches "$pipeRegex|$substitutionRegex" $ENTRY claude/start.d/* build.sh clean.sh
}

# --------------------------------------------------------------------------------
# installs_use_declared_pins: Every install in a Dockerfile names its package as NAME@${PIN}, with PIN declared as an ARG, so versions.env decides what is installed.
# --------------------------------------------------------------------------------
# An npm install argument that is not NAME@${PIN} (no version, a tag such as next, a typed version) fails, and so do npx, npm exec, pip and uv installs, which have no pin to check.
installs_use_declared_pins() {
  local dockerfile
  local fileHits
  local hits=""

  for dockerfile in $DOCKERFILES; do
    fileHits=$(awk -v file="$dockerfile" '
      FNR == NR {
        if ($0 ~ /^ARG [A-Z_]+$/) {
          declared[$2] = 1
        }
        next
      }
      function check_step(   rest, command, wordCount, words, i, word, name) {
        if (step == "") {
          return
        }

        if (step ~ /(^|[^A-Za-z_])(npx|uvx)[[:space:]]|npm[[:space:]]+exec|pip3?[[:space:]]+install|uv[[:space:]]+(tool|pip)[[:space:]]+install/) {
          print file ":" step_line ": an install with no pin to check: " step
        }

        rest = step
        while (match(rest, /npm[[:space:]]+(install|i|add)[[:space:]]/)) {
          rest = substr(rest, RSTART + RLENGTH)
          command = rest
          sub(/(&&|;|\|).*$/, "", command)
          wordCount = split(command, words, /[[:space:]]+/)

          for (i = 1; i <= wordCount; i++) {
            word = words[i]

            if (word == "" || word ~ /^-/) {
              continue
            }

            if (word !~ "^\"?[@A-Za-z0-9._/-]+@[$][{][A-Z_]+[}]\"?$") {
              print file ":" step_line ": npm install argument that is not NAME@${PIN}: " word
              continue
            }

            name = word
            sub(/^.*[$][{]/, "", name)
            sub(/[}].*$/, "", name)

            if (!(name in declared)) {
              print file ":" step_line ": npm install uses " name ", which this Dockerfile does not declare as an ARG"
            }
          }
        }

        step = ""
      }
      /^RUN[[:space:]]/ { check_step(); step_line = FNR; step = $0; continuing = /\\$/; sub(/[[:space:]]*\\$/, "", step); next }
      continuing { piece = $0; continuing = /\\$/; sub(/[[:space:]]*\\$/, "", piece); step = step " " piece; next }
      { check_step() }
      END { check_step() }
    ' "$dockerfile" "$dockerfile")

    if [ -n "$fileHits" ]; then
      hits="$hits$fileHits
"
    fi
  done

  if [ -n "$hits" ]; then
    printf '%s' "$hits" | sed 's/^/    /'
    return 1
  fi

  return 0
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
  gsd_installs_only_the_official_package \
  no_pipe_to_shell_installers \
  installs_use_declared_pins \
  no_floating_latest_versions \
  versions_are_pinned || exit 1
