#!/usr/bin/env bash
# Guard: a few rules the sandbox files must never break.
# - Reads the files only. Builds nothing, runs nothing; no Docker needed.
# - Each rule is one function below. Its comment says what it protects.
# - These are mistakes a manual test would not notice, because the sandbox still works.
# - Real behavior is tested on the Mac: tests/host/run-all.sh and tests/host-checklist.md.
# - Usage, from anywhere: bash tests/guard.sh   (exit 0 = all rules hold)
# - Runs only when started by hand: you, or an agent's verify step. No hook, no CI.
set -u
cd "$(dirname "$0")/.." || exit 1

. tests/guard/lib.sh

# Used by old_layout_untouched: the old ClaudeCode/ layout as it is on main.
# Remove both when the old layout is retired.
OLD_LAYOUT_COMMIT=304f80d1a0705d9ab668ef2ed4acd9fcf65060ac

# The generated-file header every bundle file carries (see best-practices/).
BUNDLE_HEADER='<!-- Source: best-practices/ in the GetShitDoneContainer repo. Each sandbox gets a fresh copy of this file at every container start, so edits to a copy are lost; change the source, then rebuild the image and restart. -->'

# --- helpers ---

# host_code_lines FILE...: every non-comment line of the files, as FILE:LINE:TEXT.
host_code_lines() {
  grep -Hn '^' "$@" 2>/dev/null | grep -Ev '^[^:]+:[0-9]+:[[:space:]]*#'
}

# no_host_code_matches REGEX EXEMPT FILE...: true if no code line matches REGEX.
# A line that also matches EXEMPT (when EXEMPT is not empty) is allowed. Prints the offenders.
no_host_code_matches() {
  local regex=$1
  local exempt=$2
  local hits

  shift 2
  hits=$(host_code_lines "$@" | grep -E -- "$regex")
  if [ -n "$hits" ] && [ -n "$exempt" ]; then
    hits=$(printf '%s\n' "$hits" | grep -Ev -- "$exempt")
  fi

  if [ -z "$hits" ]; then
    return 0
  fi
  echo "$hits" | sed 's/^/    /'

  return 1
}

# bundle_files: every file under best-practices/, one per line (macOS Finder noise skipped).
bundle_files() { find best-practices -type f ! -name .DS_Store | sort; }

# bundle_dash_hits FILE: lines of a Markdown file that use a dash as punctuation, as FILE:LINE: TEXT.
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

# --- rules ---

# The agent must not reach the Docker daemon or become root.
no_docker_socket_or_sudo() {
  nowhere_matches 'docker\.sock' $COMPOSE && nowhere_matches '\bsudo\b' $DOCKERFILES
}

# Nothing is installed when the container starts: the image is the only source of tools. This
# covers the entrypoint and every start hook.
no_installs_at_container_start() {
  nowhere_matches '\b(npm|npx|bunx|pip|apt-get|apt|curl|wget)\b' $ENTRY claude/start.d/*
}

# Start hooks run in text order, so every hook name is two digits, a hyphen, then lowercase
# letters, digits or hyphens (a name like 100- would sort before 20-).
start_hooks_have_two_digit_names() {
  local hook
  local found=0
  local ok=0

  for hook in claude/start.d/*; do
    if [ ! -f "$hook" ]; then
      continue
    fi

    found=1
    if ! basename "$hook" | grep -Eq '^[0-9]{2}-[a-z0-9-]+$'; then
      echo "    $hook: the name must be two digits, a hyphen, then lowercase letters, digits or hyphens"
      ok=1
    fi
  done

  if [ "$found" -eq 0 ]; then
    echo "    claude/start.d holds no start hook"
    ok=1
  fi

  return "$ok"
}

# Exactly one mount: the sandbox folder, at /home/sandbox/workspace. Never over
# /home/sandbox itself, and no Docker volumes (they can be deleted with the container).
exactly_one_mount_and_not_over_home() {
  [ "$(grep -Ec '^[[:space:]]*- type: bind$' $COMPOSE)" -eq 1 ] \
    && grep -Eq '^[[:space:]]*target: /home/sandbox/workspace$' $COMPOSE \
    && nowhere_matches 'target:[[:space:]]*"?/home/sandbox"?[[:space:]]*$' $COMPOSE \
    && nowhere_matches '^volumes:|type: volume' $COMPOSE \
    && nowhere_matches '^[[:space:]]*VOLUME([[:space:]]|$)' $DOCKERFILES
}

# The agent runs as the non-root sandbox user, with no extra privileges.
runs_without_privileges() {
  [ "$(grep -E '^USER' $BASE | tail -n 1)" = "USER sandbox" ] \
    && [ "$(grep -E '^USER' $CLAUDE | tail -n 1)" = "USER sandbox" ] \
    && grep -Fq 'no-new-privileges:true' $COMPOSE \
    && grep -A1 'cap_drop:' $COMPOSE | grep -Fq -- '- ALL'
}

# The old layout keeps working until it is retired: no change to its files.
old_layout_untouched() {
  git diff --quiet "$OLD_LAYOUT_COMMIT" -- ClaudeCode OpenCode README.md \
    && [ -z "$(git ls-files --others --exclude-standard -- ClaudeCode OpenCode)" ]
}

# The host tests run on a Mac with stock bash 3.2 and BSD tools: no bash 4 features, no GNU-only
# options. GNU tools are fine only inside the container (in_container, docker exec).
host_tests_are_portable() {
  no_host_code_matches 'declare -A|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^)\}|sed -i|grep -P|readlink -f|date -d|\btimeout\b|sha256sum|echo -e|&>>|\|&|\bjq\b|\bpython3?\b|\bcoproc\b|wait -n|EPOCHSECONDS|local -n' '' $HOST_FILES \
    && no_host_code_matches 'stat -c' 'in_container|docker exec' $HOST_FILES
}

# The host tests delete nothing: no rm, no docker removal or prune, no down with a volume flag.
# Allowed: docker run --rm (a throwaway container) and the cleanup line that print_next_block prints.
host_tests_never_delete() {
  no_host_code_matches '(^|[^A-Za-z0-9_.-])(rm|rmdir|unlink)([[:space:]]|$)|docker[[:space:]]+(container[[:space:]]+rm|rm|rmi|image[[:space:]]+(rm|prune)|system|volume[[:space:]]+(rm|prune))|prune|down[[:space:]].*(-v|--volumes)|find .*-delete' \
    'rm -rf %q' $HOST_FILES
}

# The runner and the checks never wait for a human: no read, no tty flags. tests/host/manual/ is exempt.
host_tests_are_unattended() {
  no_host_code_matches '(:[0-9]+:|[;&|(]|then|do|else)[[:space:]]*read[[:space:]]' '' $HOST_UNATTENDED_FILES \
    && no_host_code_matches 'docker[[:space:]]+(compose[[:space:]]+)?(exec|run)[^|;&]*[[:space:]](-it|-ti|-t|--tty)([[:space:]]|$)' '' $HOST_UNATTENDED_FILES
}

# Every check says what it depends on, is named in run-all.sh, and prints its own ID.
host_checks_declare_dependencies() {
  local file fileId
  local ok=0

  for file in tests/host/h[0-9][0-9]-*.sh tests/host/coexistence.sh; do
    if [ ! -e "$file" ]; then
      continue
    fi

    if [ "$(grep -c '^# Depends on:' "$file")" -ne 1 ]; then
      echo "    $file: needs exactly one '# Depends on:' line"
      ok=1
    fi

    if ! grep -Fq "$(basename "$file")" tests/host/run-all.sh; then
      echo "    $file: is not named in tests/host/run-all.sh"
      ok=1
    fi

    case "$(basename "$file")" in
      h[0-9][0-9]-*)
        fileId=$(basename "$file" | sed -E 's/^h([0-9]{2})-.*/H-\1/')
        if ! grep -Fq "$fileId" "$file"; then
          echo "    $file: does not mention its own ID $fileId"
          ok=1
        fi
        ;;
    esac
  done

  return "$ok"
}

# Only the test sandbox is named: container sbx-hosttest, images sbx-base and sbx-claude. The old
# layout's cc_ names appear only where the old containers are compared (Coexistence, the snapshot).
host_tests_only_name_the_test_sandbox() {
  local otherNames oldNames

  nowhere_matches 'sbx-demo|SBX_NAME=demo' $HOST_FILES || return 1

  otherNames=$(grep -ohE 'sbx-[A-Za-z][A-Za-z0-9_]*' $HOST_FILES 2>/dev/null | sort -u | grep -Ev '^sbx-(hosttest|base|claude)$')
  if [ -n "$otherNames" ]; then
    echo "$otherNames" | sed 's/^/    /'
    return 1
  fi

  oldNames=$(grep -En '(^|[^A-Za-z0-9])cc_' $HOST_FILES 2>/dev/null | grep -v 'tests/host/coexistence\.sh:' | grep -vF "grep -E '^[0-9a-f]+ cc_'")
  if [ -n "$oldNames" ]; then
    echo "$oldNames" | sed 's/^/    /'
    return 1
  fi

  return 0
}

# The bundle is plain Markdown only, so every change shows up in a diff: no archives, no memories,
# no CLAUDE.md, no session ids from the export. Each skill is a folder named after its SKILL.md.
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

# Every bundle file says it is generated, so nobody edits a copy by accident. The header sits on
# line 1, or right after the frontmatter when there is one. A SKILL.md starts with its frontmatter,
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

# The bundle follows its own prose rule: no dash as punctuation (em dash, en dash, " -- ", " - ").
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

# The bundle must reach the build: the .dockerignore allowlist lets best-practices/ in, and every
# COPY source in both Dockerfiles exists and sits inside base/, claude/ or best-practices/.
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

# An unquoted glob in a rule's frontmatter is invalid YAML, so Claude silently loads the rule at
# every session start instead of only when a matching file is touched.
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

# A skill added to the bundle must also be protected, and a deny entry for a skill that is gone is
# noise. Only Edit entries count (Claude never consults Write or NotebookEdit entries), and no
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

# --- runner ---

FAILS=0
for rule in \
  no_docker_socket_or_sudo \
  no_installs_at_container_start \
  start_hooks_have_two_digit_names \
  exactly_one_mount_and_not_over_home \
  runs_without_privileges \
  old_layout_untouched \
  host_tests_are_portable \
  host_tests_never_delete \
  host_tests_are_unattended \
  host_checks_declare_dependencies \
  host_tests_only_name_the_test_sandbox \
  bundle_is_plain_files_only \
  bundle_files_have_generated_header \
  bundle_has_no_dash_punctuation \
  bundle_reaches_build_context \
  bundle_path_globs_are_quoted \
  managed_settings_cover_bundle
do
  if "$rule"; then
    echo "PASS: $rule"
  else
    echo "FAIL: $rule"
    FAILS=$((FAILS + 1))
  fi
done

if [ "$FAILS" -eq 0 ]; then
  echo "All rules hold."
  exit 0
fi
echo "$FAILS rule(s) broken."
exit 1
