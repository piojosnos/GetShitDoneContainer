#!/usr/bin/env bash
# Guard rules on the docs and comments: they promise only what the sandbox and the tests do.
# - Run by tests/guard/run-all.sh; runs alone too.
# - Usage, from anywhere: bash tests/guard/docs.sh   (exit 0 = every rule holds)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# docs_promise_only_what_happens: The image comments do not promise that nothing is created on the Mac: Compose may still create a missing sandbox folder, and the entrypoint then refuses.
# --------------------------------------------------------------------------------
docs_promise_only_what_happens() {
  nowhere_matches 'never creates anything on the Mac' $BASE
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
enter_repo_root || exit 1
run_rules \
  docs_promise_only_what_happens || exit 1
