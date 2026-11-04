#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Shared bundle helpers for the host tests: the fixture clone and its links
# ------------------------------------------------------------------------------
# Sourced after lib.sh; runs nothing. Fixture commits use a test identity.
# The Mac user's git identity and GitHub login are never used.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# make_bundle_origin ORIGIN_DIR: a local bare repo holding the fixture bundle
# ------------------------------------------------------------------------------
# A seed folder next to ORIGIN_DIR gets one commit on main; ORIGIN_DIR is a bare
# clone of it, so its HEAD names main. Returns non-zero on any failure.
# ------------------------------------------------------------------------------
make_bundle_origin() {
  local originDir=$1
  local seedDir=$originDir.seed

  mkdir -p "$seedDir" || return 1
  cp -R "$HOST_DIR/support/bundle/." "$seedDir/" || return 1
  git -C "$seedDir" init -q || return 1
  git -C "$seedDir" symbolic-ref HEAD refs/heads/main || return 1
  git -C "$seedDir" add -A || return 1
  git -C "$seedDir" -c user.name=sbx-hosttest -c user.email=sbx-hosttest@example.invalid -c commit.gpgsign=false commit -q -m "fixture bundle" || return 1
  git clone -q --bare "$seedDir" "$originDir" || return 1
}

# ------------------------------------------------------------------------------
# make_bundle_clone ORIGIN_DIR CLONE_DIR: the sandbox's own clone of the origin
# ------------------------------------------------------------------------------
make_bundle_clone() {
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
# check_bundle_links CONFIG_DIR CLONE_DIR: state/claude links into the clone
# ------------------------------------------------------------------------------
# Reports by add_problem and prints nothing itself. The links are relative, so
# they must also resolve on the Mac side of the bind mount.
# ------------------------------------------------------------------------------
check_bundle_links() {
  local configDir=$1
  local cloneDir=$2
  local linkText rulesDiff skillName expectedList actualList

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

  expectedList=$(clone_skill_names "$cloneDir")
  actualList=$(cat "$configDir/.best-practices-skills" 2>/dev/null)

  if [ "$actualList" != "$expectedList" ]; then
    add_problem "state/claude/.best-practices-skills lists '$(printf '%s' "$actualList" | tr '\n' ' ')'; the clone has '$(printf '%s' "$expectedList" | tr '\n' ' ')'"
  fi
}
