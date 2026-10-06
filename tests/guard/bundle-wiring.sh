#!/usr/bin/env bash
# Guard rules on the bundle wiring: it reaches the build, rule globs are quoted, managed settings cover every skill.
# - Run by tests/guard/run-all.sh; runs alone too.
# - Usage, from anywhere: bash tests/guard/bundle-wiring.sh   (exit 0 = every rule holds)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# bundle_reaches_build_context: The bundle must reach the build: the .dockerignore allowlist lets best-practices/ in, and every COPY source in both Dockerfiles exists and sits inside base/, claude/ or best-practices/.
# --------------------------------------------------------------------------------
bundle_reaches_build_context() {
  local wanted dockerfile source firstSegment
  local ok=0

  for wanted in '*' '!base' '!claude' '!best-practices'; do
    if ! has_line .dockerignore "$wanted"; then
      echo "    .dockerignore: missing the line $wanted"
      ok=1
    fi
  done

  for dockerfile in $DOCKERFILES; do
    while IFS= read -r source; do
      firstSegment=${source%%/*}
      if [ ! -e "$source" ]; then
        echo "    $dockerfile: COPY source $source does not exist"
        ok=1
      fi

      case "$firstSegment" in
        base | claude | best-practices) ;;
        *)
          echo "    $dockerfile: COPY source $source is outside base, claude and best-practices"
          ok=1
          ;;
      esac
    done <<EOF
$(grep -E '^COPY ' "$dockerfile" | awk '{ print $2 }')
EOF
  done

  return "$ok"
}

# --------------------------------------------------------------------------------
# bundle_path_globs_are_quoted: An unquoted glob in a rule's frontmatter is invalid YAML, so Claude silently loads the rule at every session start instead of only when a matching file is touched.
# --------------------------------------------------------------------------------
bundle_path_globs_are_quoted() {
  local file item
  local ok=0

  for file in best-practices/rules/*.md; do
    if [ ! -f "$file" ] || [ "$(sed -n 1p "$file")" != "---" ]; then
      continue
    fi

    while IFS= read -r item; do
      if [ -z "$item" ]; then
        continue
      fi

      if ! echo "$item" | grep -Eq '^[[:space:]]*-[[:space:]]+"'; then
        echo "    $file: unquoted list item in the frontmatter: $item"
        ok=1
      fi
    done <<EOF
$(frontmatter_of "$file" | grep -E '^[[:space:]]*-[[:space:]]')
EOF
  done

  return "$ok"
}

# --------------------------------------------------------------------------------
# managed_settings_cover_bundle: A skill added to the bundle must also be protected, and a deny entry for a skill that is gone is noise.
# --------------------------------------------------------------------------------
# Only Edit entries count (Claude never consults Write or NotebookEdit entries), and no
# wholesale skills entry, which would also block the user's own and GSD's skills.
managed_settings_cover_bundle() {
  local managed=claude/managed-settings.json
  local denyPrefix='"Edit(//home/sandbox/workspace/state/claude/'
  local skillDir skillName entryName
  local ok=0

  if [ ! -f "$managed" ]; then
    echo "    $managed: missing"
    return 1
  fi

  if command -v node >/dev/null 2>&1; then
    if ! node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$managed" 2>/dev/null; then
      echo "    $managed: does not parse as JSON"
      ok=1
    fi
  else
    echo "    note: node is not on PATH, so the JSON parse of $managed was skipped"
  fi

  if ! grep -Fq -- "${denyPrefix}rules/**)\"" "$managed"; then
    echo "    $managed: missing the rules/** entry"
    ok=1
  fi

  if ! grep -Fq -- "${denyPrefix}.best-practices-skills)\"" "$managed"; then
    echo "    $managed: missing the .best-practices-skills entry"
    ok=1
  fi

  for skillDir in best-practices/skills/*/; do
    if [ ! -d "$skillDir" ]; then
      continue
    fi

    skillName=$(basename "$skillDir")
    if ! grep -Fq -- "${denyPrefix}skills/$skillName/**)\"" "$managed"; then
      echo "    $managed: no entry for the bundle skill $skillName"
      ok=1
    fi
  done

  for entryName in $(grep -oE 'claude/skills/[^/"]+/\*\*\)' "$managed" | sed -E 's|^claude/skills/([^/]+)/.*|\1|'); do
    if [ ! -d "best-practices/skills/$entryName" ]; then
      echo "    $managed: an entry names the skill $entryName, which the bundle does not have"
      ok=1
    fi
  done

  if ! nowhere_matches '(Write|NotebookEdit)\(' "$managed"; then
    ok=1
  fi

  if ! nowhere_matches 'skills/\*\*\)' "$managed"; then
    ok=1
  fi

  return "$ok"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  bundle_reaches_build_context \
  bundle_path_globs_are_quoted \
  managed_settings_cover_bundle || exit 1
