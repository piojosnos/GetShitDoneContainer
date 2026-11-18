#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Shared best-practices helpers for the host tests: the fixture clone and its links
# ------------------------------------------------------------------------------
# Sourced after lib.sh; runs nothing. Fixture commits use a test identity.
# The host user's git identity and GitHub login are never used.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# make_best_practices_origin ORIGIN_DIR: a local bare repo holding the fixture rules and skills
# ------------------------------------------------------------------------------
# A seed directory next to ORIGIN_DIR gets one commit on main; ORIGIN_DIR is a
# bare clone of it, so its HEAD names main. Returns non-zero on any failure.
# ------------------------------------------------------------------------------
make_best_practices_origin() {
  local originDir=$1
  local seedDir=$originDir.seed

  mkdir -p "$seedDir" || return 1
  cp -R "$HOST_DIR/support/best-practices/." "$seedDir/" || return 1
  git -C "$seedDir" init -q || return 1
  git -C "$seedDir" symbolic-ref HEAD refs/heads/main || return 1
  git -C "$seedDir" add -A || return 1
  git -C "$seedDir" -c user.name=sbx-hosttest -c user.email=sbx-hosttest@example.invalid -c commit.gpgsign=false commit -q -m "fixture best-practices repo" || return 1
  git clone -q --bare "$seedDir" "$originDir" || return 1
}

# ------------------------------------------------------------------------------
# make_best_practices_clone ORIGIN_DIR CLONE_DIR: the sandbox's own clone of the origin
# ------------------------------------------------------------------------------
make_best_practices_clone() {
  git clone -q "$1" "$2"
}

# ------------------------------------------------------------------------------
# clone_skill_names CLONE_DIR: the clone's skill names, one per line
# ------------------------------------------------------------------------------
clone_skill_names() {
  local skillDir

  for skillDir in "$1"/skills/*/; do
    if [ -d "$skillDir" ]; then
      basename "$skillDir"
    fi
  done
}

# ------------------------------------------------------------------------------
# check_best_practices_links AGENT_CONFIG_DIR CLONE_DIR: state/claude links into the clone
# ------------------------------------------------------------------------------
# Reports by add_problem and prints nothing itself. The links are relative, so
# they must also resolve on the host side of the bind mount. Only the links are
# compared with the clone; a link into the clone for a skill the clone dropped
# is a problem.
# ------------------------------------------------------------------------------
check_best_practices_links() {
  local configDir=$1
  local cloneDir=$2
  local linkText rulesDiff skillName skillEntry entryName

  if [ ! -L "$configDir/rules" ]; then
    add_problem "state/claude/rules is not a link"
  else
    linkText=$(readlink "$configDir/rules")

    if [ "$linkText" != "../../best-practices/rules" ]; then
      add_problem "state/claude/rules links to '$linkText'; expected '../../best-practices/rules'"
    fi

    rulesDiff=$(diff -r -x .DS_Store "$cloneDir/rules" "$configDir/rules/" 2>&1)

    if [ "$?" -ne 0 ]; then
      add_problem "state/claude/rules read through the link differs from the clone: $(first_lines "$rulesDiff")"
    fi
  fi

  for skillName in $(clone_skill_names "$cloneDir"); do
    linkText=$(readlink "$configDir/skills/$skillName" 2>/dev/null)

    if [ "$linkText" != "../../../best-practices/skills/$skillName" ]; then
      add_problem "state/claude/skills/$skillName links to '$linkText'; expected '../../../best-practices/skills/$skillName'"
    fi
  done

  for skillEntry in "$configDir"/skills/*; do
    entryName=$(basename "$skillEntry")
    linkText=$(readlink "$skillEntry" 2>/dev/null)

    if [[ "$linkText" == ../../../best-practices/skills/* ]] && [ ! -d "$cloneDir/skills/$entryName" ]; then
      add_problem "state/claude/skills/$entryName links into the clone, but the clone has no skill $entryName"
    fi
  done
}
