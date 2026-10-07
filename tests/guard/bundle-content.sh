#!/usr/bin/env bash
# Guard rules on the bundle content: plain Markdown, a generated header on every file, no dash as punctuation.
# - Run by tests/guard/run-all.sh; runs alone too.
# - Usage, from anywhere: bash tests/guard/bundle-content.sh   (exit 0 = every rule holds)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Constants: the header every bundle file carries
# --------------------------------------------------------------------------------
# The generated-file header every bundle file carries (see best-practices/).
BUNDLE_HEADER='<!-- Source: best-practices/ in the GetShitDoneContainer repo. Each sandbox gets a fresh copy of this file at every container start, so edits to a copy are lost; change the source, then rebuild the image and restart. -->'

# --------------------------------------------------------------------------------
# bundle_files: every file under best-practices/, one per line (macOS Finder noise skipped).
# --------------------------------------------------------------------------------
bundle_files() { find best-practices -type f ! -name .DS_Store | sort; }

# --------------------------------------------------------------------------------
# bundle_dash_hits FILE: lines of a Markdown file that use a dash as punctuation, as FILE:LINE: TEXT.
# --------------------------------------------------------------------------------
# Skipped first: fenced blocks. Then removed from each line: inline code spans, comment delimiters,
# one leading list bullet. A line that is only "---" (a frontmatter fence) counts as empty.
bundle_dash_hits() {
  LC_ALL=C awk '
    /^[[:space:]]*```/ { fenced = !fenced; next }
    fenced { next }
    {
      line = $0
      gsub(/`[^`]*`/, "", line)
      gsub(/<!--|-->/, "", line)
      sub(/^[[:space:]]*[-*+] /, "", line)
      if (line == "---") { line = "" }
      if (index(line, "\342\200\224") || index(line, "\342\200\223") || index(line, " -- ") || index(line, " - ")) {
        print FILENAME ":" FNR ": " $0
      }
    }' "$1"
}

# --------------------------------------------------------------------------------
# bundle_is_plain_files_only: The bundle is plain Markdown only, so every change shows up in a diff: no archives, no memories, no CLAUDE.md, no session ids from the export.
# --------------------------------------------------------------------------------
# Each skill is a folder named after its SKILL.md.
bundle_is_plain_files_only() {
  local file skillDir skillName
  local ok=0

  while IFS= read -r file; do
    case "$file" in
      *.md) ;;
      *)
        echo "    $file: not a Markdown file"
        ok=1
        ;;
    esac

    case "$(basename "$file")" in
      CLAUDE.md | MEMORY.md)
        echo "    $file: the bundle ships no CLAUDE.md or MEMORY.md"
        ok=1
        ;;
    esac
  done <<EOF
$(bundle_files)
EOF

  if [ -n "$(find best-practices -type d -name memory)" ]; then
    echo "    best-practices has a memory folder; memories are per project"
    ok=1
  fi

  if grep -rq 'originSessionId' best-practices; then
    grep -rn 'originSessionId' best-practices | sed 's/^/    /'
    ok=1
  fi

  if [ -z "$(find best-practices/rules -type f -name '*.md' 2>/dev/null)" ]; then
    echo "    best-practices/rules holds no rule file"
    ok=1
  fi

  for skillDir in best-practices/skills/*/; do
    if [ ! -d "$skillDir" ]; then
      continue
    fi

    skillDir=${skillDir%/}
    skillName=$(basename "$skillDir")
    if [ ! -f "$skillDir/SKILL.md" ]; then
      echo "    $skillDir: no SKILL.md"
      ok=1
    elif ! frontmatter_of "$skillDir/SKILL.md" | grep -Fxq "name: $skillName"; then
      echo "    $skillDir/SKILL.md: frontmatter lacks the line 'name: $skillName'"
      ok=1
    fi
  done

  return "$ok"
}

# --------------------------------------------------------------------------------
# bundle_files_have_generated_header: Every bundle file says it is generated, so nobody edits a copy by accident.
# --------------------------------------------------------------------------------
# The header sits on line 1, or right after the frontmatter when there is one. A SKILL.md starts with its frontmatter,
# or Claude reads the whole file as skill text.
bundle_files_have_generated_header() {
  local file closingLine headerLine
  local ok=0

  while IFS= read -r file; do
    case "$file" in
      *.md) ;;
      *) continue ;;
    esac

    if [ "$(grep -Fxc -- "$BUNDLE_HEADER" "$file")" -ne 1 ]; then
      echo "    $file: the header must appear exactly once"
      ok=1
      continue
    fi

    if [ "$(basename "$file")" = "SKILL.md" ] && [ "$(sed -n 1p "$file")" != "---" ]; then
      echo "    $file: line 1 must be the frontmatter fence"
      ok=1
    fi

    if [ "$(sed -n 1p "$file")" = "---" ]; then
      closingLine=$(awk 'NR > 1 && $0 == "---" { print NR; exit }' "$file")
      headerLine=$((${closingLine:-0} + 1))
      if [ "$(sed -n "${headerLine}p" "$file")" != "$BUNDLE_HEADER" ]; then
        echo "    $file: the header must be the line right after the frontmatter"
        ok=1
      fi
    elif [ "$(sed -n 1p "$file")" != "$BUNDLE_HEADER" ]; then
      echo "    $file: line 1 must be the header"
      ok=1
    elif [ "$(sed -n 3p "$file")" = "---" ]; then
      echo "    $file: frontmatter must come before the header"
      ok=1
    fi
  done <<EOF
$(bundle_files)
EOF

  return "$ok"
}

# --------------------------------------------------------------------------------
# bundle_has_no_dash_punctuation: The bundle follows its own prose rule: no dash as punctuation (em dash, en dash, double hyphen, or a lone hyphen between spaces).
# --------------------------------------------------------------------------------
# Exempt: inline code spans, fenced blocks, list bullets, and the backticked examples in prose-style.md.
bundle_has_no_dash_punctuation() {
  local file hits
  local ok=0

  while IFS= read -r file; do
    case "$file" in
      *.md) ;;
      *) continue ;;
    esac

    hits=$(bundle_dash_hits "$file")
    if [ -n "$hits" ]; then
      echo "$hits" | sed 's/^/    /'
      ok=1
    fi
  done <<EOF
$(bundle_files)
EOF

  return "$ok"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  bundle_is_plain_files_only \
  bundle_files_have_generated_header \
  bundle_has_no_dash_punctuation || exit 1
