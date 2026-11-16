#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-27: the first run in a fresh sandbox folder: refusal, init, clone, push
# ------------------------------------------------------------------------------
# Needs: images built; the run folder (not the running sandbox)
# One offline docker run --rm container on a fresh folder of the run folder. It
# walks the first run in order: sbx-claude refuses before sbx-init, sbx-init
# stops at the missing clone, sbx-bundle-clone clones and runs sbx-init, Claude
# then starts, and a push reaches the origin.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-bundle.sh"
host_init

h27Dir=$RUN/h27-$$-$(date +%s)

# ------------------------------------------------------------------------------
# FAIL and return 1 when there is no run folder
# ------------------------------------------------------------------------------
require_run_folder() {
  if [ -z "${RUN:-}" ]; then
    fail H-27 "no run folder" "run: bash tests/host/run-all.sh first"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Makes the fresh folder: project, state and a bare origin
# ------------------------------------------------------------------------------
# The origin is a bare copy of the run's origin; a push here never changes it.
# ------------------------------------------------------------------------------
prepare_folder() {
  mkdir -p "$h27Dir/hosttest" "$h27Dir/state"

  if ! git clone -q --bare "$RUN/bundle-origin.git" "$h27Dir/bundle-origin.git" >"$h27Dir/prepare.log" 2>&1; then
    fail H-27 "could not copy the fixture origin into $h27Dir" "log: $h27Dir/prepare.log"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Runs the whole in-container script in one offline container
# ------------------------------------------------------------------------------
# The script prints one 'STEP NAME STATUS' line per step to the run log and
# writes each step's output into the folder, where the Mac side reads it.
# ------------------------------------------------------------------------------
run_script() {
  local scriptText

  IFS= read -r -d '' scriptText <<'SCRIPT' || true
ws=/home/sandbox/workspace
step() { echo "STEP $1 $2"; }

sbx-claude --version >"$ws/before.out" 2>"$ws/before.err"
step before $?

command -v claude >"$ws/plainpath.out" 2>&1
step plainpath $?

sbx-init >"$ws/noclone.out" 2>&1
step noclone $?

sbx-bundle-clone >"$ws/clone.out" 2>&1
step clone $?

echo "RULES $(readlink "$ws/state/claude/rules")"
for skillDir in "$ws"/best-practices/skills/*/; do
  skillName=$(basename "$skillDir")
  echo "SKILL $skillName $(readlink "$ws/state/claude/skills/$skillName")"
done

cat "$ws/state/claude/rules/sbx-fixture-always.md" >"$ws/through-link.out" 2>&1
step read $?

sbx-bundle-clone >"$ws/again.out" 2>&1
step again $?

echo "REMOTE $(git -C "$ws/best-practices" remote get-url origin)"

(
  cd "$ws/best-practices" &&
  git checkout -q -b h27-change &&
  echo "h27 change" >>rules/sbx-fixture-always.md &&
  git -c user.name=sbx-hosttest -c user.email=sbx-hosttest@example.invalid -c commit.gpgsign=false commit -q -am "h27 change" &&
  git push -q origin h27-change
) >"$ws/push.out" 2>&1
step push $?

sbx-claude --version >"$ws/after.out" 2>"$ws/after.err"
step after $?

SBX_BUNDLE_DIR="$ws/h27-missing" BUNDLE_REPO_URL="$ws/no-such-origin.git" sbx-bundle-clone >"$ws/missing.out" 2>&1
step missing $?
SCRIPT

  run_timeout 180 docker run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true \
    -e SBX_NAME=hosttest -e BUNDLE_REPO_URL=/home/sandbox/workspace/bundle-origin.git \
    --mount "type=bind,source=$h27Dir,target=/home/sandbox/workspace" \
    "$CLAUDE_IMAGE" bash -c "$scriptText" </dev/null >"$h27Dir/run.log" 2>&1
  runStatus=$?
}

# ------------------------------------------------------------------------------
# Prints the status of a step from the run log; empty when the step never ran
# ------------------------------------------------------------------------------
step_status() {
  local stepLine

  stepLine=$(grep -E "^STEP $1 [0-9]+\$" "$h27Dir/run.log" | head -n 1)
  printf '%s' "${stepLine##* }"
}

# ------------------------------------------------------------------------------
# Adds a problem unless step NAME ended with status EXPECTED
# ------------------------------------------------------------------------------
check_step() {
  local stepName=$1
  local expectedStatus=$2
  local actualStatus

  actualStatus=$(step_status "$stepName")

  if [ "$actualStatus" != "$expectedStatus" ]; then
    add_problem "step $stepName ended with '$actualStatus'; expected $expectedStatus"
  fi
}

# ------------------------------------------------------------------------------
# Prints the first lines of a file in the folder, or a note when it is missing
# ------------------------------------------------------------------------------
file_head() {
  if [ ! -f "$h27Dir/$1" ]; then
    printf '(no %s)' "$1"
    return
  fi

  first_lines "$(cat "$h27Dir/$1")"
}

# ------------------------------------------------------------------------------
# Checks sbx-claude refused to start before sbx-init and printed nothing else
# ------------------------------------------------------------------------------
check_before() {
  local beforeOut beforeErr

  check_step before 1
  beforeErr=$(cat "$h27Dir/before.err" 2>/dev/null)
  beforeOut=$(cat "$h27Dir/before.out" 2>/dev/null)

  if [[ "$beforeErr" != *"run sbx-init first"* ]]; then
    add_problem "sbx-claude did not tell the user to run sbx-init first; stderr: $(file_head before.err)"
  fi

  if [ -n "$beforeOut" ]; then
    add_problem "sbx-claude printed output before sbx-init; stdout: $(file_head before.out)"
  fi
}

# ------------------------------------------------------------------------------
# Checks claude is not on the plain PATH, so only the wrapper can start it
# ------------------------------------------------------------------------------
check_plain_path() {
  local plainOut

  check_step plainpath 1
  plainOut=$(cat "$h27Dir/plainpath.out" 2>/dev/null)

  if [ -n "$plainOut" ]; then
    add_problem "command -v claude found '$plainOut' on the plain PATH; the agent must live off the PATH"
  fi
}

# ------------------------------------------------------------------------------
# Checks sbx-init without a clone did the mechanical steps, then stopped at the
# links step and named sbx-bundle-clone
# ------------------------------------------------------------------------------
check_init_without_clone() {
  local noCloneFile=$h27Dir/noclone.out
  local expectedLine

  check_step noclone 1

  for expectedLine in "OK: state-folders: " "OK: claude-gsd-sync: " "OK: state-owner: "; do
    if ! grep -Fq "$expectedLine" "$noCloneFile" 2>/dev/null; then
      add_problem "sbx-init without a clone printed no line with '$expectedLine'; output: $(file_head noclone.out)"
    fi
  done

  if ! grep -Fq "FAIL: claude-best-practices-links: no best-practices clone at /home/sandbox/workspace/best-practices" "$noCloneFile" 2>/dev/null; then
    add_problem "sbx-init without a clone did not fail at claude-best-practices-links; output: $(file_head noclone.out)"
  fi

  if ! grep -Eq '^ +fix: .*sbx-bundle-clone' "$noCloneFile" 2>/dev/null; then
    add_problem "sbx-init without a clone printed no fix line naming sbx-bundle-clone; output: $(file_head noclone.out)"
  fi

  if [ "$(tail -n 1 "$noCloneFile" 2>/dev/null)" != "sbx-init: stopped at claude-best-practices-links" ]; then
    add_problem "the last sbx-init line is not 'sbx-init: stopped at claude-best-practices-links'; output: $(file_head noclone.out)"
  fi
}

# ------------------------------------------------------------------------------
# Checks the first sbx-bundle-clone cloned, ran sbx-init to a pass and linked
# ------------------------------------------------------------------------------
check_clone_and_links() {
  local cloneFile=$h27Dir/clone.out
  local skillName skillLine

  check_step clone 0

  if [ "$(tail -n 1 "$cloneFile" 2>/dev/null)" != "sbx-init: 4 steps passed; run sbx-selfcheck to check the sandbox" ]; then
    add_problem "the last line of sbx-bundle-clone is not 'sbx-init: 4 steps passed; run sbx-selfcheck to check the sandbox'; got: $(file_head clone.out)"
  fi

  if ! grep -Fxq "RULES ../../best-practices/rules" "$h27Dir/run.log"; then
    add_problem "the rules link is not 'RULES ../../best-practices/rules'; run log: $(grep '^RULES ' "$h27Dir/run.log" | head -n 1)"
  fi

  for skillName in $(clone_skill_names "$h27Dir/best-practices"); do
    skillLine="SKILL $skillName ../../../best-practices/skills/$skillName"

    if ! grep -Fxq "$skillLine" "$h27Dir/run.log"; then
      add_problem "the link of skill $skillName is wrong; expected '$skillLine'; run log: $(grep "^SKILL $skillName " "$h27Dir/run.log" | head -n 1)"
    fi
  done
}

# ------------------------------------------------------------------------------
# Checks the rule read through the link equals the fixture rule
# ------------------------------------------------------------------------------
check_read_through_link() {
  check_step read 0

  if ! diff "$HOST_DIR/support/bundle/rules/sbx-fixture-always.md" "$h27Dir/through-link.out" >/dev/null 2>&1; then
    add_problem "the rule read through state/claude/rules differs from the fixture; got: $(file_head through-link.out)"
  fi
}

# ------------------------------------------------------------------------------
# Checks a second sbx-bundle-clone changed nothing and said so
# ------------------------------------------------------------------------------
check_second_clone_refused() {
  local againOut

  check_step again 1
  againOut=$(cat "$h27Dir/again.out" 2>/dev/null)

  if [[ "$againOut" != *"already exists; nothing was changed"* ]]; then
    add_problem "the second sbx-bundle-clone did not say it changed nothing; got: $(file_head again.out)"
  fi

  if [[ "$againOut" != *"sbx-init"* ]]; then
    add_problem "the second sbx-bundle-clone did not name sbx-init as the way to relink; got: $(file_head again.out)"
  fi
}

# ------------------------------------------------------------------------------
# Checks the clone's remote is the given URL, with no credentials in it
# ------------------------------------------------------------------------------
check_remote() {
  if ! grep -Fxq "REMOTE /home/sandbox/workspace/bundle-origin.git" "$h27Dir/run.log"; then
    add_problem "the clone's remote is not the given URL; run log: $(grep '^REMOTE ' "$h27Dir/run.log" | head -n 1)"
  fi
}

# ------------------------------------------------------------------------------
# Checks the container's branch reached the origin and main did not move
# ------------------------------------------------------------------------------
check_push() {
  local originMain runMain

  check_step push 0

  if ! git -C "$h27Dir/bundle-origin.git" rev-parse --verify -q refs/heads/h27-change >/dev/null 2>&1; then
    add_problem "the branch h27-change is not in the origin; push output: $(file_head push.out)"
  fi

  originMain=$(git -C "$h27Dir/bundle-origin.git" rev-parse main 2>/dev/null)
  runMain=$(git -C "$RUN/bundle-origin.git" rev-parse main 2>/dev/null)

  if [ -z "$originMain" ] || [ "$originMain" != "$runMain" ]; then
    add_problem "main of the pushed origin is '$originMain'; the run's origin has '$runMain'"
  fi
}

# ------------------------------------------------------------------------------
# Checks sbx-claude starts Claude once sbx-init has passed
# ------------------------------------------------------------------------------
check_after() {
  local afterOut expectedOut

  check_step after 0
  afterOut=$(cat "$h27Dir/after.out" 2>/dev/null)
  expectedOut="$(claude_pin) (Claude Code)"

  if [ "$afterOut" != "$expectedOut" ]; then
    add_problem "sbx-claude did not print the pinned version after sbx-init; expected '$expectedOut'; got: $(file_head after.out)"
  fi
}

# ------------------------------------------------------------------------------
# Checks a clone of a missing origin failed, named sbx-gh-login, left no folder
# ------------------------------------------------------------------------------
check_missing_origin() {
  local missingOut

  check_step missing 1
  missingOut=$(cat "$h27Dir/missing.out" 2>/dev/null)

  if [[ "$missingOut" != *"sbx-gh-login"* ]]; then
    add_problem "the failed clone did not name sbx-gh-login; got: $(file_head missing.out)"
  fi

  if [ -e "$h27Dir/h27-missing" ]; then
    add_problem "the failed clone left the folder $h27Dir/h27-missing"
  fi
}

# ------------------------------------------------------------------------------
# Checks the offline GSD sync wrote the pinned version and never used npx
# ------------------------------------------------------------------------------
check_gsd_synced() {
  local gsdPin syncedVersion outputName

  gsdPin=$(pin_of GSD_CORE_VERSION)
  syncedVersion=$(cat "$h27Dir/state/claude/gsd-core/VERSION" 2>/dev/null)

  if [ -z "$gsdPin" ] || [ "$syncedVersion" != "$gsdPin" ]; then
    add_problem "state/claude/gsd-core/VERSION holds '$syncedVersion'; the GSD_CORE_VERSION pin is '$gsdPin'"
  fi

  for outputName in noclone.out clone.out; do
    if grep -Eq 'npx|@latest' "$h27Dir/$outputName" 2>/dev/null; then
      add_problem "$outputName names npx or @latest; the GSD sync must run the image's own installer"
    fi
  done
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_run_folder || exit 1
prepare_folder || exit 1
run_script

if ! grep -Eq '^STEP missing [0-9]+$' "$h27Dir/run.log"; then
  fail H-27 "the in-container script did not finish (docker run exit $runStatus)" \
    "log: $h27Dir/run.log" "first lines: $(file_head run.log)"
  exit 1
fi

check_before
check_plain_path
check_init_without_clone
check_clone_and_links
check_read_through_link
check_second_clone_refused
check_remote
check_push
check_after
check_missing_origin
check_gsd_synced
report_check H-27 "the first run is wrong in a fresh sandbox folder: the refusal, sbx-init, the clone, the GSD sync or the push" \
  "offline: sbx-claude refused before sbx-init and claude is off the plain PATH; sbx-init without a clone stopped at the links step naming sbx-bundle-clone; sbx-bundle-clone cloned and its sbx-init passed with 4 steps; a second clone was refused; a branch was pushed to the origin; Claude started after init; GSD synced offline at the pinned version; a failed clone left no folder"
