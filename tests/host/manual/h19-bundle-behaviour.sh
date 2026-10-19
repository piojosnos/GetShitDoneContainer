#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-19 helper: the real bundle flow: login, clone, read, amend, refuse
# ------------------------------------------------------------------------------
# Usage: bash tests/host/manual/h19-bundle-behaviour.sh (exit 0 = all PASS)
# Needs a terminal, the test sandbox and a Claude login (h07-login.sh).
# ------------------------------------------------------------------------------
set -u

. "$(dirname "$0")/lib-manual.sh"
require_terminal

. "$(dirname "$0")/../lib.sh"
host_init

keptRealClone=0

# ------------------------------------------------------------------------------
# Moves the fixture clone aside; the real clone needs the folder
# ------------------------------------------------------------------------------
# A clone of the real repo from an earlier run stays, and the steps say to skip
# sbx-bundle-clone. Nothing is deleted: the printed cleanup removes the run.
# ------------------------------------------------------------------------------
set_clone_aside() {
  local cloneUrl

  if [ ! -e "$RUN/best-practices" ]; then
    return
  fi

  cloneUrl=$(git -C "$RUN/best-practices" remote get-url origin 2>/dev/null)

  if [ "$cloneUrl" = "$(pin_of BUNDLE_REPO_URL)" ]; then
    keptRealClone=1
    printf 'A clone of the real repo from an earlier run is kept: %s\n\n' "$RUN/best-practices"

    return
  fi

  mv "$RUN/best-practices" "$RUN/h19-fixture-clone-$$"
  printf 'The fixture clone was moved to %s\n\n' "$RUN/h19-fixture-clone-$$"
}

# ------------------------------------------------------------------------------
# Puts the shell file Claude reads in step 4 into the test project
# ------------------------------------------------------------------------------
make_probe_file() {
  mkdir -p "$RUN/hosttest/h19/deep"
  printf 'echo "h19 probe"\n' >"$RUN/hosttest/h19/deep/probe.sh"
}

# ------------------------------------------------------------------------------
# Prints the steps to follow in the shell and inside Claude
# ------------------------------------------------------------------------------
print_steps() {
  printf 'A shell in the test sandbox opens next. Follow these steps in order:\n'

  if [ "$keptRealClone" -eq 1 ]; then
    printf '  1. Run sbx-gh-login if it asks (open the URL on the Mac, enter the code;\n'
    printf '     give a git name and email if it asks for them).\n'
    printf '     Skip sbx-bundle-clone: the real clone is there. Then run sbx-claude.\n'
  else
    printf '  1. Run sbx-gh-login (open the URL it prints on the Mac, enter the code;\n'
    printf '     give a git name and email if it asks for them),\n'
    printf '     then sbx-bundle-clone, then sbx-claude.\n'
  fi

  printf '  2. Type / and look for pr-reply and merged in the list.\n'
  printf '  3. Ask: what do the practices say about dashes in prose?\n'
  printf '     The answer should come from the prose rule in the clone.\n'
  printf '  4. Run /context: the always-on rules are listed by their path under\n'
  printf '     /home/sandbox/workspace/best-practices and no approval dialog appeared;\n'
  printf '     shell.md is not listed. Ask Claude to read h19/deep/probe.sh, then run\n'
  printf '     /context again: shell.md is listed.\n'
  printf '  5. Ask Claude to amend the practices: add one line to rules/communication.md\n'
  printf '     of the clone, on a new branch, committed, not pushed. Note whether it\n'
  printf '     asked you to approve the edit.\n'
  printf '  6. Ask Claude to add a line to ~/.claude/skills/merged/SKILL.md. It must refuse.\n'
  printf '  7. Run /status and look for managed settings among the setting sources.\n'
  printf '  8. Optional, with your go: ask Claude to push the branch and open a PR\n'
  printf '     (gh pr create) against the bundle repo. Then close the PR on GitHub\n'
  printf '     without merging and delete its branch.\n'
  printf '  9. Type /exit to leave Claude, then exit to come back here.\n\n'
}

# ------------------------------------------------------------------------------
# Opens a shell in the test sandbox and waits until it exits
# ------------------------------------------------------------------------------
open_shell() {
  docker exec -it -w /home/sandbox/workspace/hosttest "$CONTAINER" bash

  printf '\n'
}

# ------------------------------------------------------------------------------
# Lists the clone's rules and skills files that start with a Source header
# ------------------------------------------------------------------------------
# A first line '<!-- Source:' marks a file copied from the old layout.
# ------------------------------------------------------------------------------
find_source_headers() {
  local cloneFile fileList

  fileList=$(find "$RUN/best-practices/rules" "$RUN/best-practices/skills" -type f 2>/dev/null)

  while IFS= read -r cloneFile; do
    if [ -n "$cloneFile" ] && [[ "$(sed -n 1p "$cloneFile")" == "<!-- Source:"* ]]; then
      printf '%s\n' "$cloneFile"
    fi
  done <<<"$fileList"
}

# ------------------------------------------------------------------------------
# Checks a local branch holds a commit that origin/main does not
# ------------------------------------------------------------------------------
has_unpublished_branch() {
  local branchName aheadCount

  for branchName in $(git -C "$RUN/best-practices" for-each-ref --format='%(refname:short)' refs/heads); do
    if [ "$branchName" = "main" ]; then
      continue
    fi

    aheadCount=$(git -C "$RUN/best-practices" rev-list --count "origin/main..$branchName" 2>/dev/null)

    if [ "${aheadCount:-0}" -gt 0 ]; then
      return 0
    fi
  done

  return 1
}

# ------------------------------------------------------------------------------
# Checks the clone, its remote, the links, the amend and that no token leaked
# ------------------------------------------------------------------------------
check_clone() {
  local originUrl sourceHeaderList

  if [ ! -d "$RUN/best-practices/.git" ]; then
    add_problem "$RUN/best-practices is not a git clone"
  else
    originUrl=$(git -C "$RUN/best-practices" remote get-url origin 2>/dev/null)

    if [ "$originUrl" != "$(pin_of BUNDLE_REPO_URL)" ]; then
      add_problem "the clone's origin is '$originUrl'; versions.env pins '$(pin_of BUNDLE_REPO_URL)'"
    fi

    if ! has_unpublished_branch; then
      add_problem "no local branch other than main has a commit that origin/main lacks; was the amend committed on a new branch?"
    fi

    if grep -Eq 'gho_|ghp_|ghu_|ghs_|x-access-token' "$RUN/best-practices/.git/config"; then
      add_problem "the clone's .git/config holds a token or an x-access-token entry"
    fi
  fi

  if [ ! "$RUN/state/claude/rules" -ef "$RUN/best-practices/rules" ]; then
    add_problem "state/claude/rules does not resolve to the clone's rules"
  fi

  if [ ! -f "$RUN/best-practices/rules/best-practices.md" ]; then
    add_problem "the clone has no rules/best-practices.md"
  fi

  sourceHeaderList=$(find_source_headers)

  if [ -n "$sourceHeaderList" ]; then
    add_problem "files with a '<!-- Source:' first line: $(first_lines "$sourceHeaderList")"
  fi

  if ! grep -Fq 'gh auth git-credential' "$RUN/state/git/config" 2>/dev/null; then
    add_problem "state/git/config has no gh auth git-credential entry; did sbx-gh-login run?"
  fi

  count_result H-19 "the clone, its remote, its links or the git config are wrong" \
    "the clone of the real repo is there with its remote, its links, the commit on a new branch, gh's helper entry and no token in .git/config"
}

# ------------------------------------------------------------------------------
# Asks one question for each step you judge
# ------------------------------------------------------------------------------
ask_judgments() {
  ask_judgment H-19 "Step 1: did sbx-gh-login, sbx-bundle-clone and sbx-claude work?" \
    "login, clone and sbx-claude worked in the sandbox shell" \
    "login, clone or sbx-claude did not work"
  ask_judgment H-19 "Step 2: were pr-reply and merged listed?" \
    "the skills pr-reply and merged appear in Claude" \
    "the skills pr-reply and merged were not both listed"
  ask_judgment H-19 "Step 3: did the answer about dashes come from the prose rule?" \
    "Claude answered from the prose rule in the clone" \
    "the answer did not come from the prose rule"
  ask_judgment H-19 "Step 4: rules listed by clone path with no dialog, shell.md only after the read?" \
    "the rules load from the clone with no approval dialog and shell.md loaded only after the read" \
    "the rules were not listed by clone path, a dialog appeared or shell.md loaded at the wrong time"
  ask_judgment H-19 "Step 5: did Claude amend a rule in the clone on a new branch and commit it?" \
    "Claude amended and committed a rule in the clone" \
    "Claude did not amend and commit a rule in the clone"
  ask_judgment H-19 "Step 6: did Claude refuse to edit through ~/.claude/skills?" \
    "Claude refused the edit through ~/.claude/skills" \
    "Claude did not refuse the edit through ~/.claude/skills"
  ask_judgment H-19 "Step 7: did /status show managed settings as a source?" \
    "the managed settings show up among the setting sources" \
    "the managed settings were not shown as a source"
  ask_judgment H-19 "Step 8: skipped, or pushed and opened only after your go, then closed?" \
    "the optional push and PR was skipped or done only with your go" \
    "the push or PR happened without your go or was left open"
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-19 || exit 1
set_clone_aside
make_probe_file
print_steps
open_shell
check_clone
ask_judgments
exit_with_result
