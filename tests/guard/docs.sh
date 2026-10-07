#!/usr/bin/env bash
# Guard rules on the docs and comments: they promise only what the sandbox and the tests do.
# - Run by tests/guard/run-all.sh; runs alone too.
# - Usage, from anywhere: bash tests/guard/docs.sh   (exit 0 = every rule holds)
set -u
. "$(dirname "$0")/lib.sh"

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
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  docs_promise_only_what_happens \
  sandbox_doc_checks_the_folder_first \
  sandbox_doc_shells_pass_w \
  sandbox_doc_names_what_only_the_helpers_check || exit 1
