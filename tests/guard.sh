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

BASE=base/Dockerfile
CLAUDE=claude/Dockerfile
COMPOSE=compose.yml
ENTRY=base/sbx-entrypoint
DOCKERFILES="$BASE $CLAUDE"
SANDBOX_FILES="$BASE $CLAUDE $COMPOSE $ENTRY"

# The Mac host tests: every script, and the ones that must run unattended.
HOST_FILES="tests/host/*.sh tests/host/manual/*.sh"
HOST_UNATTENDED_FILES="tests/host/*.sh"

# Used by old_layout_untouched: the old ClaudeCode/ layout as it is on main.
# Remove both when the old layout is retired.
OLD_LAYOUT_COMMIT=304f80d1a0705d9ab668ef2ed4acd9fcf65060ac

# --- helpers ---

# nowhere_matches REGEX FILE...: true if no line matches; prints the offending lines.
nowhere_matches() {
  local regex=$1; shift
  local hits
  hits=$(grep -En -- "$regex" "$@" 2>/dev/null)
  [ -z "$hits" ] && return 0
  echo "$hits" | sed 's/^/    /'
  return 1
}

# has_line FILE LINE: true if FILE has a line exactly equal to LINE.
has_line() { grep -Fxq -- "$2" "$1"; }

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

# --- rules ---

# GSD must come only from @opengsd/gsd-core: the old package was compromised.
no_compromised_gsd_package() {
  nowhere_matches 'get-shit-done-cc|gsd-build' $SANDBOX_FILES SANDBOX.md tests/host-checklist.md tests/host/*.sh
}

# The agent must not reach the Docker daemon or become root.
no_docker_socket_or_sudo() {
  nowhere_matches 'docker\.sock' $COMPOSE && nowhere_matches '\bsudo\b' $DOCKERFILES
}

# Nothing is installed by piping a download into a shell (unverified code).
no_pipe_to_shell_installers() {
  nowhere_matches '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh([[:space:]]|$)' $DOCKERFILES
}

# No floating versions: what is in the image changes only when a pin changes.
no_floating_latest_versions() {
  nowhere_matches ':latest|@latest' $SANDBOX_FILES
}

# Every tool version is an exact pin.
versions_are_pinned() {
  has_line $BASE 'FROM ubuntu:24.04' \
    && grep -Eq '^ARG NODE_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' $BASE \
    && grep -Eq '^ARG GH_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' $BASE \
    && grep -Eq '^ARG CLAUDE_CODE_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' $CLAUDE
}

# Nothing is installed when the container starts: the image is the only source of tools.
no_installs_at_container_start() {
  nowhere_matches '\b(npm|npx|bunx|pip|apt-get|apt|curl|wget)\b' $ENTRY
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

# Internal planning IDs mean nothing to a reader of the scripts: keep them out.
host_tests_have_no_planning_ids() {
  nowhere_matches '\bD-[0-9]{2}\b|\bHT-0[0-9]\b|Phase [0-9]|CONTEXT\.md|\.planning' $HOST_FILES tests/host-selftest.sh
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

# --- runner ---

FAILS=0
for rule in \
  no_compromised_gsd_package \
  no_docker_socket_or_sudo \
  no_pipe_to_shell_installers \
  no_floating_latest_versions \
  versions_are_pinned \
  no_installs_at_container_start \
  exactly_one_mount_and_not_over_home \
  runs_without_privileges \
  old_layout_untouched \
  host_tests_are_portable \
  host_tests_never_delete \
  host_tests_are_unattended \
  host_checks_declare_dependencies \
  host_tests_have_no_planning_ids \
  host_tests_only_name_the_test_sandbox
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
