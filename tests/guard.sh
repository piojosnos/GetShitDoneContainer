#!/usr/bin/env bash
# Guard: a few rules the sandbox files must never break.
# - Reads the files only. Builds nothing, runs nothing; no Docker needed.
# - Each rule is one function below. Its comment says what it protects.
# - These are mistakes a manual test would not notice, because the sandbox still works.
# - Real behavior is tested on the Mac: tests/host-checklist.md.
# - Usage, from anywhere: bash tests/guard.sh   (exit 0 = all rules hold)
set -u
cd "$(dirname "$0")/.." || exit 1

BASE=base/Dockerfile
CLAUDE=claude/Dockerfile
COMPOSE=compose.yml
ENTRY=base/sbx-entrypoint
DOCKERFILES="$BASE $CLAUDE"
SANDBOX_FILES="$BASE $CLAUDE $COMPOSE $ENTRY"

# The commit on main that holds the old layout, before any of this work.
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

# --- rules ---

# GSD must come only from @opengsd/gsd-core: the old package was compromised.
no_compromised_gsd_package() {
  nowhere_matches 'get-shit-done-cc|gsd-build' $SANDBOX_FILES SANDBOX.md tests/host-checklist.md
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
  old_layout_untouched
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
