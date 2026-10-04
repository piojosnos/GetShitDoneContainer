#!/usr/bin/env bash
# H-19 (attended): the bundle's skills, rules and edit protection, as Claude shows them.
# - Needs a terminal. Run it after bash tests/host/run-all.sh and bash tests/host/manual/h07-login.sh,
#   against the same test sandbox (sbx-hosttest). It finds the run folder from the container's mount.
# - Claude opens and you follow six numbered steps. Whether a skill is listed, a rule is followed, a
#   language rule loads on demand and the managed settings show up are for you to judge.
# - Automatic: after Claude exits, the copy of communication.md in the run folder must still equal
#   the repo's file (the refused edit left it unchanged).
# - Usage: bash tests/host/manual/h19-bundle-behaviour.sh   (exit 0 = every line is PASS)
set -u

if [ ! -t 0 ] || [ ! -t 1 ]; then
  printf 'This helper needs a terminal. Run it directly, not through a pipe or a script.\n' >&2
  exit 1
fi

. "$(dirname "$0")/../lib.sh"
host_init
require_test_sandbox H-19 || exit 1

failCount=0

# ask_judgment QUESTION PASS_TEXT FAIL_TEXT: asks one y/N question and prints PASS or FAIL for H-19.
ask_judgment() {
  local answer

  printf '%s [y/N] ' "$1"
  read -r answer

  case "$answer" in
    y|Y)
      pass H-19 "$2"
      ;;
    *)
      fail H-19 "$3" "answer: ${answer:-<none>}"
      failCount=$((failCount + 1))
      ;;
  esac
}

mkdir -p "$RUN/hosttest/h19/deep"
printf 'echo "h19 probe"\n' >"$RUN/hosttest/h19/deep/probe.sh"

printf 'Claude opens next, inside the test sandbox. Follow these steps in order:\n'
printf '  1. Type / and look for pr-reply and merged in the list.\n'
printf '  2. Ask: propose a way to rename a git branch\n'
printf '     Judge the answer: a brief pros and cons with one recommendation (the communication rule).\n'
printf '  3. Run /context and note that shell.md is not listed. Ask Claude to read h19/deep/probe.sh,\n'
printf '     then run /context again and look for shell.md.\n'
printf '  4. Ask Claude to add a line to ~/.claude/rules/communication.md. It must refuse.\n'
printf '  5. Run /status and look for managed settings among the setting sources.\n'
printf '  6. Type /exit to come back here.\n\n'

docker exec -it -w /home/sandbox/workspace/hosttest "$CONTAINER" claude

printf '\n'

if cmp -s "$REPO_DIR/best-practices/rules/communication.md" "$RUN/state/claude/rules/communication.md"; then
  pass H-19 "the copy of communication.md in the run folder still equals the repo file"
else
  fail H-19 "the copy of communication.md differs from the repo file" "compare: $RUN/state/claude/rules/communication.md"
  failCount=$((failCount + 1))
fi

ask_judgment "Step 1: were pr-reply and merged listed?" \
  "the skills pr-reply and merged appear in Claude" \
  "the skills pr-reply and merged were not both listed"
ask_judgment "Step 2: was the answer a brief pros and cons with one recommendation?" \
  "Claude followed the always-on communication rule" \
  "the answer did not follow the communication rule"
ask_judgment "Step 3: was shell.md absent at first and listed after the read?" \
  "the path-scoped shell rule loaded only after a matching file was read" \
  "shell.md was listed too early or never listed"
ask_judgment "Step 4: did Claude refuse to edit the rule?" \
  "Claude refused to edit the synced rule" \
  "Claude did not refuse to edit the synced rule"
ask_judgment "Step 5: did /status show managed settings as a source?" \
  "the managed settings show up among the setting sources" \
  "the managed settings were not shown as a source"

if [ "$failCount" -gt 0 ]; then
  exit 1
fi

exit 0
