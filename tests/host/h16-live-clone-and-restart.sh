#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-16: the clone is live; a restart relinks it and spares your files
# ------------------------------------------------------------------------------
# Needs: test sandbox running; stops and restarts it
# Moved files stay in the run folder for the printed cleanup.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-bundle.sh"
host_init

cloneDir=$RUN/best-practices
syncedDir=$RUN/state/claude
memoryDir=$syncedDir/projects/-home-sandbox-workspace-hosttest/memory
sentinelText="h16-$$-$(date +%s)"
sessionFile=$syncedDir/projects/-home-sandbox-workspace-hosttest/h16-session.jsonl
settingsScript='const fs = require("fs"); const file = process.env.CLAUDE_CONFIG_DIR + "/settings.json"; let settings = {}; if (fs.existsSync(file)) { settings = JSON.parse(fs.readFileSync(file, "utf8")); } settings.h16Sentinel = process.argv[1]; fs.writeFileSync(file, JSON.stringify(settings, null, 2) + "\n");'

# ------------------------------------------------------------------------------
# Picks the first GSD skill to edit; needs the clone and a synced GSD
# ------------------------------------------------------------------------------
# The fixture rule and skill names are fixed; only the GSD skill is looked up.
# ------------------------------------------------------------------------------
pick_samples() {
  local gsdSkillPath

  if [ ! -d "$cloneDir/.git" ]; then
    fail H-16 "the run folder has no best-practices clone" "looked in $cloneDir"
    return 1
  fi

  gsdSkillPath=$(find "$syncedDir/skills" -maxdepth 1 -type d -name 'gsd-*' 2>/dev/null | sort | sed -n 1p)

  if [ -z "$gsdSkillPath" ]; then
    fail H-16 "state/claude has no skills/gsd-* folder; GSD never synced" "looked in $syncedDir/skills"
    return 1
  fi

  firstGsdSkill=$(basename "$gsdSkillPath")
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

  git_step "cloning the origin for the pushed commit" git clone -q "$RUN/bundle-origin.git" "$otherDir" || return
  printf '%s\n' "$sentinelText" >"$otherDir/rules/h16-pulled.md"
  git_step "adding the pulled rule" git -C "$otherDir" add rules/h16-pulled.md || return
  git_step "committing the pulled rule" git -C "$otherDir" -c user.name=sbx-hosttest \
    -c user.email=sbx-hosttest@example.invalid -c commit.gpgsign=false commit -q -m "h16 pulled rule" || return
  git_step "pushing the pulled rule to the origin" git -C "$otherDir" push -q origin main || return
  git_step "pulling in the sandbox" in_container git -C /home/sandbox/workspace/best-practices \
    pull -q --ff-only /home/sandbox/workspace/bundle-origin.git main || return

  seenText=$(in_container cat /home/sandbox/workspace/state/claude/rules/h16-pulled.md)

  if [[ "$seenText" != *"$sentinelText"* ]]; then
    add_problem "a pulled rule is not in the sandbox at once; got: $(first_lines "$seenText")"
  fi
}

# ------------------------------------------------------------------------------
# Plants stale and user files, drops a skill from the clone, ages GSD
# ------------------------------------------------------------------------------
# The rules link and one fixture skill are moved aside, never deleted.
# User files: a skill, memory, session, CLAUDE.md and a settings.json key.
# ------------------------------------------------------------------------------
plant_files() {
  local plantOutput

  mv "$cloneDir/skills/sbx-fixture-two" "$RUN/h16-dropped-skill-$$"
  mv "$syncedDir/rules" "$RUN/h16-old-rules-link-$$"
  mkdir -p "$syncedDir/rules" "$syncedDir/skills/h16-old-bundle-skill" "$syncedDir/skills/h16-user-skill" \
    "$syncedDir/gsd-core" "$memoryDir"

  printf '%s\n' "$sentinelText" >"$syncedDir/rules/h16-stale.md"
  printf '%s\n' "$sentinelText" >"$syncedDir/skills/h16-old-bundle-skill/SKILL.md"
  printf '%s\n' "h16-old-bundle-skill" >>"$syncedDir/.best-practices-skills"
  printf '%s\n' "$sentinelText" >"$syncedDir/skills/h16-user-skill/SKILL.md"
  printf '%s\n' "$sentinelText" >"$memoryDir/h16-memory.md"
  printf '# %s\n' "$sentinelText" >"$syncedDir/CLAUDE.md"
  printf '%s\n' "$sentinelText" >"$sessionFile"
  printf '0.0.0' >"$syncedDir/gsd-core/VERSION"
  printf 'h16 hand edit\n' >>"$syncedDir/skills/$firstGsdSkill/SKILL.md"

  if ! plantOutput=$(in_container node -e "$settingsScript" "$sentinelText"); then
    add_problem "could not plant the settings key: $(first_lines "$plantOutput")"
  fi
}

# ------------------------------------------------------------------------------
# Checks the dropped skill has no file or link, and the stale copies are gone
# ------------------------------------------------------------------------------
check_stale_files_gone() {
  if [ -e "$syncedDir/skills/sbx-fixture-two" ] || [ -L "$syncedDir/skills/sbx-fixture-two" ]; then
    add_problem "state/claude/skills/sbx-fixture-two is still there after the restart"
  fi

  if [ -e "$syncedDir/rules/h16-stale.md" ]; then
    add_problem "state/claude/rules/h16-stale.md is still there after the restart"
  fi

  if [ -e "$syncedDir/skills/h16-old-bundle-skill" ] || [ -L "$syncedDir/skills/h16-old-bundle-skill" ]; then
    add_problem "state/claude/skills/h16-old-bundle-skill is still there after the restart"
  fi
}

# ------------------------------------------------------------------------------
# Checks the restart kept the uncommitted edit and the pulled file in the clone
# ------------------------------------------------------------------------------
check_clone_kept() {
  if ! grep -Fq "$sentinelText edit" "$cloneDir/rules/sbx-fixture-always.md" 2>/dev/null; then
    add_problem "the uncommitted edit in the clone's rule is gone after the restart"
  fi

  if [ ! -f "$cloneDir/rules/h16-pulled.md" ]; then
    add_problem "the pulled rule is gone from the clone after the restart"
  fi
}

# ------------------------------------------------------------------------------
# Checks GSD is back at the pin and the hand edit in the GSD skill is undone
# ------------------------------------------------------------------------------
check_gsd_refreshed() {
  local pinnedVersion syncedVersion=""

  pinnedVersion=$(pin_of GSD_CORE_VERSION)

  if [ -f "$syncedDir/gsd-core/VERSION" ]; then
    syncedVersion=$(cat "$syncedDir/gsd-core/VERSION")
  fi

  if [ "$syncedVersion" != "$pinnedVersion" ]; then
    add_problem "state/claude/gsd-core/VERSION is '$syncedVersion' after the restart; the image has GSD $pinnedVersion"
  fi

  if [ ! -f "$syncedDir/skills/$firstGsdSkill/SKILL.md" ]; then
    add_problem "state/claude/skills/$firstGsdSkill/SKILL.md is missing after the restart"
  elif grep -Fq "h16 hand edit" "$syncedDir/skills/$firstGsdSkill/SKILL.md"; then
    add_problem "state/claude/skills/$firstGsdSkill still has the hand edit after the restart"
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
      add_problem "${userFile#"$RUN"/} is missing or changed after the restart"
    fi
  done
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-16 || exit 1
pick_samples || exit 1
check_edit_is_live
check_pull_is_live
plant_files
restart_test_sandbox H-16 h16-down.log || exit 1
check_bundle_links "$syncedDir" "$cloneDir"
check_stale_files_gone
check_clone_kept
check_gsd_refreshed
check_user_files_spared
report_check H-16 "the clone is not live or the restart did not relink it and spare your files" \
  "an edit of the clone on the Mac and a pull inside the sandbox showed in the sandbox at once; a restart relinked the clone, dropped a removed skill and stale copies, kept the uncommitted edit, refreshed GSD and kept your skills, memories, sessions, settings key and CLAUDE.md"
