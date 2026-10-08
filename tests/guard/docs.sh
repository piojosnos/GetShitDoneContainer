#!/usr/bin/env bash
# Guard rules on the docs and comments: they promise only what the sandbox and the tests do; the fake docker claims only what real Compose does.
# - Run by tests/guard/run-all.sh; runs alone too.
# - Usage, from anywhere: bash tests/guard/docs.sh   (exit 0 = every rule holds)
set -u
. "$(dirname "$0")/lib.sh"

# Old texts no doc, script or fake may state: the old name rule, its "rejected" claim, and a refusal of the project name.
OLD_NAME_RULE_REGEX='lowercase letters, digits, - and _|is rejected; .myproject. works|Invalid project name'

# --------------------------------------------------------------------------------
# docs_promise_only_what_happens: The docs and image comments promise only what happens: Compose may still create a missing sandbox folder, a green run does not prove the build is good, and a shell starts where "-w" says, not in the project folder.
# --------------------------------------------------------------------------------
docs_promise_only_what_happens() {
  nowhere_matches 'never creates anything on the Mac|the build is good|the shell starts here' $BASE SANDBOX.md tests/host-checklist.md
}

# --------------------------------------------------------------------------------
# sandbox_doc_checks_the_folder_first: The paste-before-start block in SANDBOX.md checks that SBX_DIR is an absolute path: Compose reads a relative one from the repo folder and does not expand "~".
# --------------------------------------------------------------------------------
sandbox_doc_checks_the_folder_first() {
  if ! grep -Fq 'case "$SBX_DIR" in /*)' SANDBOX.md; then
    echo '    SANDBOX.md has no line holding: case "$SBX_DIR" in /*)'
    return 1
  fi

  return 0
}

# --------------------------------------------------------------------------------
# sandbox_doc_shells_pass_w: Every "docker exec -it" shell command in SANDBOX.md passes "-w": a shell without it starts in the workspace, not in the project folder.
# --------------------------------------------------------------------------------
sandbox_doc_shells_pass_w() {
  local shellLineText
  local lineText
  local ok=0

  shellLineText=$(grep -n 'docker exec -it' SANDBOX.md)

  if [ -z "$shellLineText" ]; then
    echo "    SANDBOX.md has no docker exec -it line"
    return 1
  fi

  while IFS= read -r lineText; do
    case "$lineText" in
      *' -w '*) ;;
      *)
        echo "    SANDBOX.md:$lineText has no -w"
        ok=1
        ;;
    esac
  done <<EOF
$shellLineText
EOF

  return "$ok"
}

# --------------------------------------------------------------------------------
# sandbox_doc_names_what_only_the_helpers_check: SANDBOX.md names the checks only the manual helpers cover, H-07 (the login) and H-19 (the bundle as Claude uses it), so a green run is not read as proof of them.
# --------------------------------------------------------------------------------
sandbox_doc_names_what_only_the_helpers_check() {
  local checkId
  local ok=0

  for checkId in H-07 H-19; do
    if ! grep -Fq "$checkId" SANDBOX.md; then
      echo "    SANDBOX.md does not name $checkId"
      ok=1
    fi
  done

  return "$ok"
}

# --------------------------------------------------------------------------------
# checklist_lists_every_host_check: The host checklist has a row for every host check script, its title ends at the highest ID, and it names the chain in the order run-all.sh runs it.
# --------------------------------------------------------------------------------
# The IDs come from the file names (h20-... is H-20) and from the chainCheckList line of tests/host/run-all.sh.
checklist_lists_every_host_check() {
  local checklist=tests/host-checklist.md
  local checkScript
  local checkId
  local highestId=""
  local chainNameText
  local chainName
  local chainText=""
  local ok=0

  for checkScript in tests/host/h[0-9][0-9]-*.sh; do
    checkId=$(basename "$checkScript" | sed -E 's/^h([0-9]{2})-.*/H-\1/')
    highestId=$checkId

    if ! grep -q "^| $checkId |" "$checklist"; then
      echo "    $checklist has no table row starting \"| $checkId |\" for $checkScript"
      ok=1
    fi
  done

  if [ -z "$highestId" ]; then
    echo "    no tests/host/hNN-*.sh script found"
    return 1
  fi

  if ! head -n 1 "$checklist" | grep -Fq "(H-00..$highestId)"; then
    echo "    line 1 of $checklist does not hold (H-00..$highestId)"
    ok=1
  fi

  chainNameText=$(sed -n -E 's/^chainCheckList="([^"]*)".*/\1/p' tests/host/run-all.sh)

  if [ -z "$chainNameText" ]; then
    echo "    tests/host/run-all.sh has no chainCheckList line"
    return 1
  fi

  for chainName in $chainNameText; do
    checkId=$(echo "$chainName" | sed -E 's/^h([0-9]{2})-.*/H-\1/')

    if [ -z "$chainText" ]; then
      chainText=$checkId
    else
      chainText="$chainText, $checkId"
    fi
  done

  if ! grep -Fq "chain $chainText" "$checklist"; then
    echo "    $checklist does not hold: chain $chainText"
    ok=1
  fi

  return "$ok"
}

# --------------------------------------------------------------------------------
# docs_state_the_sandbox_name_rule: SANDBOX.md and compose.yml state the sandbox name rule exactly as base/sbx-start-lib.sh enforces it, and no doc or script states the old rule or a refusal of the project name.
# --------------------------------------------------------------------------------
# The pattern and the words come from the two constants in the start library, so a doc cannot drift from the check.
docs_state_the_sandbox_name_rule() {
  local namePattern
  local ruleText
  local docFile
  local ok=0

  namePattern=$(sed -n "s/^sandboxNamePattern='\(.*\)'\$/\1/p" base/sbx-start-lib.sh)
  ruleText=$(sed -n "s/^sandboxNameRuleText='\(.*\)'\$/\1/p" base/sbx-start-lib.sh)

  if [ -z "$namePattern" ] || [ -z "$ruleText" ]; then
    echo "    base/sbx-start-lib.sh has no sandboxNamePattern or sandboxNameRuleText line"
    return 1
  fi

  for docFile in SANDBOX.md compose.yml; do
    if ! grep -Fq -- "$namePattern" "$docFile"; then
      echo "    $docFile does not state the name pattern $namePattern"
      ok=1
    fi

    if ! grep -Fq -- "$ruleText" "$docFile"; then
      echo "    $docFile does not state the name rule: $ruleText"
      ok=1
    fi
  done

  if ! nowhere_matches "$OLD_NAME_RULE_REGEX" SANDBOX.md compose.yml tests/host-checklist.md base/sbx-start-lib.sh base/sbx-entrypoint tests/host/*.sh; then
    ok=1
  fi

  return "$ok"
}

# --------------------------------------------------------------------------------
# fake_docker_claims_only_real_compose: The fake docker claims no Compose behaviour that real Compose lacks: no refusal of a project name for its case, no switch for it, no old name rule.
# --------------------------------------------------------------------------------
# Real Compose turns the project name into lowercase and never refuses it for its case.
fake_docker_claims_only_real_compose() {
  nowhere_matches "$OLD_NAME_RULE_REGEX|not a valid project name|FAKE_CONFIG_NO_CASE_CHECK" tests/selftest/host/support/fake-docker tests/selftest/host/*.sh
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  docs_promise_only_what_happens \
  sandbox_doc_checks_the_folder_first \
  sandbox_doc_shells_pass_w \
  sandbox_doc_names_what_only_the_helpers_check \
  checklist_lists_every_host_check \
  docs_state_the_sandbox_name_rule \
  fake_docker_claims_only_real_compose || exit 1
