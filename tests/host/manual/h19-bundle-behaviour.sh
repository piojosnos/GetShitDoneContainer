#!/usr/bin/env bash
# H-19 (attended): the bundle's skills, rules and edit protection, as Claude shows them.
# - Needs a terminal, the test sandbox (sbx-hosttest) that bash tests/host/run-all.sh leaves running,
#   and a Claude login (bash tests/host/manual/h07-login.sh makes one). It finds the run folder from
#   the container's mount.
# - Claude opens and you follow six numbered steps. Whether a skill is listed, a rule is followed, a
#   language rule loads on demand and the managed settings show up are for you to judge.
# - Automatic: after Claude exits, the copy of communication.md in the run folder must still equal
#   the repo's file (the refused edit left it unchanged).
# - Usage: bash tests/host/manual/h19-bundle-behaviour.sh   (exit 0 = every line is PASS)
set -u

. "$(dirname "$0")/lib-manual.sh"
require_terminal

. "$(dirname "$0")/../lib.sh"
host_init

# --------------------------------------------------------------------------------
# Puts the shell file Claude reads in step 3 into the test project
# --------------------------------------------------------------------------------
make_probe_file() {
  mkdir -p "$RUN/hosttest/h19/deep"
  printf 'echo "h19 probe"\n' >"$RUN/hosttest/h19/deep/probe.sh"
}

# --------------------------------------------------------------------------------
# Prints the steps to follow inside Claude
# --------------------------------------------------------------------------------
print_steps() {
  printf 'Claude opens next, inside the test sandbox. Follow these steps in order:\n'
  printf '  1. Type / and look for pr-reply and merged in the list.\n'
  printf '  2. Ask: propose a way to rename a git branch\n'
  printf '     Judge the answer: a brief pros and cons with one recommendation (the communication rule).\n'
  printf '  3. Run /context and note that shell.md is not listed. Ask Claude to read h19/deep/probe.sh,\n'
  printf '     then run /context again and look for shell.md.\n'
  printf '  4. Ask Claude to add a line to ~/.claude/rules/communication.md. It must refuse.\n'
  printf '  5. Run /status and look for managed settings among the setting sources.\n'
  printf '  6. Type /exit to come back here.\n\n'
}

# --------------------------------------------------------------------------------
# Opens Claude in the test sandbox and waits until it exits
# --------------------------------------------------------------------------------
open_claude() {
  run_claude

  printf '\n'
}

# --------------------------------------------------------------------------------
# Checks the synced communication.md still equals the repo file
# --------------------------------------------------------------------------------
check_rule_copy() {
  if ! cmp -s "$REPO_DIR/best-practices/rules/communication.md" "$RUN/state/claude/rules/communication.md"; then
    add_problem "compare: $RUN/state/claude/rules/communication.md"
  fi

  count_result H-19 "the copy of communication.md differs from the repo file" \
    "the copy of communication.md in the run folder still equals the repo file"
}

# --------------------------------------------------------------------------------
# Asks one question for each step you judge
# --------------------------------------------------------------------------------
ask_judgments() {
  ask_judgment H-19 "Step 1: were pr-reply and merged listed?" \
    "the skills pr-reply and merged appear in Claude" \
    "the skills pr-reply and merged were not both listed"
  ask_judgment H-19 "Step 2: was the answer a brief pros and cons with one recommendation?" \
    "Claude followed the always-on communication rule" \
    "the answer did not follow the communication rule"
  ask_judgment H-19 "Step 3: was shell.md absent at first and listed after the read?" \
    "the path-scoped shell rule loaded only after a matching file was read" \
    "shell.md was listed too early or never listed"
  ask_judgment H-19 "Step 4: did Claude refuse to edit the rule?" \
    "Claude refused to edit the synced rule" \
    "Claude did not refuse to edit the synced rule"
  ask_judgment H-19 "Step 5: did /status show managed settings as a source?" \
    "the managed settings show up among the setting sources" \
    "the managed settings were not shown as a source"
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-19 || exit 1
make_probe_file
print_steps
open_claude
check_rule_copy
ask_judgments
exit_with_result
