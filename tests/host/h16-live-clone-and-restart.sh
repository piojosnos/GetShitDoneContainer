#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-16: the clone is live; sbx-init relinks it and never touches your files
# ------------------------------------------------------------------------------
# Needs: test sandbox running; stops and restarts it
# Moved and planted files stay in the run folder for the printed cleanup.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-best-practices.sh"
host_init

cloneDir=$RUN/best-practices
syncedDir=$RUN/state/claude
memoryDir=$syncedDir/projects/-home-sandbox-workspace-hosttest/memory
sentinelText="h16-$$-$(date +%s)"
sessionFile=$syncedDir/projects/-home-sandbox-workspace-hosttest/h16-session.jsonl
settingsScript='const fs = require("fs"); const file = process.env.CLAUDE_CONFIG_DIR + "/settings.json"; let settings = {}; if (fs.existsSync(file)) { settings = JSON.parse(fs.readFileSync(file, "utf8")); } settings.h16Sentinel = process.argv[1]; fs.writeFileSync(file, JSON.stringify(settings, null, 2) + "\n");'

# ------------------------------------------------------------------------------
# Stops the check when the run folder has no best-practices clone
# ------------------------------------------------------------------------------
require_clone() {
  if [ ! -d "$cloneDir/.git" ]; then
    fail H-16 "the run folder has no best-practices clone" "looked in $cloneDir"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# git_step DESCRIPTION CMD...: runs CMD; a failure adds a problem
# ------------------------------------------------------------------------------
git_step() {
  local description=$1
  local gitOutput

  shift

  if ! gitOutput=$("$@" 2>&1 </dev/null); then
    add_problem "$description failed: $(first_lines "$gitOutput")"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Checks an uncommitted edit in the clone on the Mac shows in the container
# ------------------------------------------------------------------------------
check_edit_is_live() {
  local seenText

  printf '%s edit\n' "$sentinelText" >>"$cloneDir/rules/sbx-fixture-always.md"
  seenText=$(in_container cat /home/sandbox/workspace/state/claude/rules/sbx-fixture-always.md)

  if [[ "$seenText" != *"$sentinelText edit"* ]]; then
    add_problem "an edit of the clone's rule on the Mac is not in the sandbox at once; got: $(first_lines "$seenText")"
  fi
}

# ------------------------------------------------------------------------------
# Checks a commit pushed to the origin and pulled in the sandbox is live
# ------------------------------------------------------------------------------
# The pulled commit only adds a file, so the uncommitted edit does not block it.
# The pull runs inside the container: the clone's .git is writable by the agent,
# so the Mac never runs git on it. The container reaches the origin by its
# mounted path, not by the clone's recorded Mac path.
# ------------------------------------------------------------------------------
check_pull_is_live() {
  local otherDir=$RUN/h16-other-$$
  local seenText

  git_step "cloning the origin for the pushed commit" git clone -q "$RUN/best-practices-origin.git" "$otherDir" || return
  printf '%s\n' "$sentinelText" >"$otherDir/rules/h16-pulled.md"
  git_step "adding the pulled rule" git -C "$otherDir" add rules/h16-pulled.md || return
  git_step "committing the pulled rule" git -C "$otherDir" -c user.name=sbx-hosttest \
    -c user.email=sbx-hosttest@example.invalid -c commit.gpgsign=false commit -q -m "h16 pulled rule" || return
  git_step "pushing the pulled rule to the origin" git -C "$otherDir" push -q origin main || return
  git_step "pulling in the sandbox" in_container git -C /home/sandbox/workspace/best-practices \
    pull -q --ff-only /home/sandbox/workspace/best-practices-origin.git main || return

  seenText=$(in_container cat /home/sandbox/workspace/state/claude/rules/h16-pulled.md)

  if [[ "$seenText" != *"$sentinelText"* ]]; then
    add_problem "a pulled rule is not in the sandbox at once; got: $(first_lines "$seenText")"
  fi
}

# ------------------------------------------------------------------------------
# Plants user files and drops a skill from the clone
# ------------------------------------------------------------------------------
# One fixture skill is moved aside into the run folder, never deleted. User
# files: a skill, memory, session, CLAUDE.md and a settings.json key.
# ------------------------------------------------------------------------------
plant_files() {
  local plantOutput

  mv "$cloneDir/skills/sbx-fixture-two" "$RUN/h16-dropped-skill-$$"
  mkdir -p "$syncedDir/skills/h16-user-skill" "$memoryDir"

  printf '%s\n' "$sentinelText" >"$syncedDir/skills/h16-user-skill/SKILL.md"
  printf '%s\n' "$sentinelText" >"$memoryDir/h16-memory.md"
  printf '# %s\n' "$sentinelText" >"$syncedDir/CLAUDE.md"
  printf '%s\n' "$sentinelText" >"$sessionFile"

  if ! plantOutput=$(in_container node -e "$settingsScript" "$sentinelText"); then
    add_problem "could not plant the settings key: $(first_lines "$plantOutput")"
  fi
}

# ------------------------------------------------------------------------------
# Checks the dropped skill has no file or link after sbx-init
# ------------------------------------------------------------------------------
check_dropped_skill_gone() {
  if [ -e "$syncedDir/skills/sbx-fixture-two" ] || [ -L "$syncedDir/skills/sbx-fixture-two" ]; then
    add_problem "state/claude/skills/sbx-fixture-two is still there after sbx-init"
  fi
}

# ------------------------------------------------------------------------------
# Checks the restart kept the uncommitted edit and the pulled file in the clone
# ------------------------------------------------------------------------------
check_clone_kept() {
  if ! grep -Fq "$sentinelText edit" "$cloneDir/rules/sbx-fixture-always.md" 2>/dev/null; then
    add_problem "the uncommitted edit in the clone's rule is gone after sbx-init"
  fi

  if [ ! -f "$cloneDir/rules/h16-pulled.md" ]; then
    add_problem "the pulled rule is gone from the clone after sbx-init"
  fi
}

# ------------------------------------------------------------------------------
# Checks every planted user file still holds its sentinel
# ------------------------------------------------------------------------------
check_user_files_spared() {
  local userFile

  for userFile in "$syncedDir/skills/h16-user-skill/SKILL.md" "$memoryDir/h16-memory.md" "$sessionFile" \
    "$syncedDir/settings.json" "$syncedDir/CLAUDE.md"; do
    if ! grep -Fq "$sentinelText" "$userFile" 2>/dev/null; then
      add_problem "${userFile#"$RUN"/} is missing or changed after sbx-init"
    fi
  done
}

# ------------------------------------------------------------------------------
# Checks sbx-init keeps a user's skill folder and rules folder and reports both
# ------------------------------------------------------------------------------
# The two links are moved aside into the run folder, then a real
# skills/sbx-fixture-one folder and a real rules folder take their place.
# sbx-init must fail at the links step naming both, leave both files as they are
# and not write its marker.
# ------------------------------------------------------------------------------
check_clash_kept_and_reported() {
  local clashFile=$RUN/logs/h16-clash.out
  local clashStatus

  mv "$syncedDir/skills/sbx-fixture-one" "$RUN/h16-clash-skill-link-$$"
  mv "$syncedDir/rules" "$RUN/h16-clash-rules-link-$$"
  mkdir -p "$syncedDir/skills/sbx-fixture-one" "$syncedDir/rules"
  printf '%s\n' "$sentinelText" >"$syncedDir/skills/sbx-fixture-one/SKILL.md"
  printf '%s\n' "$sentinelText" >"$syncedDir/rules/h16-own-rule.md"

  run_timeout 600 docker exec "$CONTAINER" sbx-init >"$clashFile" 2>&1 </dev/null
  clashStatus=$?

  if [ "$clashStatus" -ne 1 ]; then
    add_problem "sbx-init exited $clashStatus with a user skill folder and rules folder in the way; expected 1; output: $clashFile"
  fi

  if ! grep -E '^FAIL: claude-best-practices-links: ' "$clashFile" 2>/dev/null | grep -F 'skills/sbx-fixture-one' | grep -Fq 'state/claude/rules'; then
    add_problem "sbx-init did not report both skills/sbx-fixture-one and rules in a FAIL line for claude-best-practices-links; output: $(first_lines "$(cat "$clashFile" 2>/dev/null)")"
  fi

  if ! grep -Fq "$sentinelText" "$syncedDir/skills/sbx-fixture-one/SKILL.md" 2>/dev/null; then
    add_problem "the planted skills/sbx-fixture-one/SKILL.md is missing or changed after the clash"
  fi

  if ! grep -Fq "$sentinelText" "$syncedDir/rules/h16-own-rule.md" 2>/dev/null; then
    add_problem "the planted rules/h16-own-rule.md is missing or changed after the clash"
  fi

  if docker exec "$CONTAINER" test -e /home/sandbox/.sbx-init-done </dev/null 2>&1; then
    add_problem "sbx-init failed at the links step but the marker /home/sandbox/.sbx-init-done exists"
  fi
}

# ------------------------------------------------------------------------------
# Moves the planted folders aside, reruns sbx-init and checks the links again
# ------------------------------------------------------------------------------
# Both folders go into the run folder, never deleted. The rerun must pass and
# relink, so the chain continues on a passing sandbox.
# ------------------------------------------------------------------------------
restore_after_clash() {
  local restoreFile=$RUN/logs/h16-restore.out
  local restoreStatus

  mv "$syncedDir/skills/sbx-fixture-one" "$RUN/h16-clash-skill-folder-$$"
  mv "$syncedDir/rules" "$RUN/h16-clash-rules-folder-$$"

  run_timeout 600 docker exec "$CONTAINER" sbx-init >"$restoreFile" 2>&1 </dev/null
  restoreStatus=$?

  if [ "$restoreStatus" -ne 0 ]; then
    add_problem "sbx-init exited $restoreStatus after the planted folders were moved aside; expected 0; output: $restoreFile"
  fi

  check_best_practices_links "$syncedDir" "$cloneDir"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-16 || exit 1
require_clone || exit 1
check_edit_is_live
check_pull_is_live
plant_files
restart_test_sandbox H-16 h16-down.log || exit 1
check_best_practices_links "$syncedDir" "$cloneDir"
check_dropped_skill_gone
check_clone_kept
check_user_files_spared
check_clash_kept_and_reported
restore_after_clash
report_check H-16 "the clone is not live, or sbx-init did not relink it, spare your files or report a clash" \
  "an edit of the clone on the Mac and a pull inside the sandbox showed in the sandbox at once; sbx-init relinked the clone, dropped the link of a removed skill, kept the uncommitted edit and kept your skills, memories, sessions, settings key and CLAUDE.md; a skill folder and a rules folder of your own were kept and reported, and sbx-init relinked once they were moved aside"
