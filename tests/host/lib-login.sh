#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Fake Claude login files for the host tests: plant them, check them after a
# recreate
# ------------------------------------------------------------------------------
# Sourced after lib.sh by the checks that prove persistence; functions only.
# The files hold a run-unique text; no real credential is ever written.
# ------------------------------------------------------------------------------

# The project folder name Claude uses for the hosttest workspace
loginProjectName=-home-sandbox-workspace-hosttest

# ------------------------------------------------------------------------------
# plant_login_files STATE_DIR TEXT PREFIX: writes the fake login files
# ------------------------------------------------------------------------------
# Writes STATE_DIR/claude/.credentials.json and the session file
# STATE_DIR/claude/projects/<project>/PREFIX-session.jsonl, each holding TEXT in
# a fake key. An empty STATE_DIR plants nothing, adds a problem and returns 1.
# ------------------------------------------------------------------------------
plant_login_files() {
  local claudeDir projectDir

  if [ -z "$1" ]; then
    add_problem "no state folder given; the fake login files were not planted"
    return 1
  fi

  claudeDir=$1/claude
  projectDir=$claudeDir/projects/$loginProjectName

  mkdir -p "$projectDir"
  printf '{"fake":"%s"}\n' "$2" >"$claudeDir/.credentials.json"
  printf '{"fake":"%s"}\n' "$2" >"$projectDir/$3-session.jsonl"
}

# ------------------------------------------------------------------------------
# check_login_files STATE_DIR TEXT PREFIX WHEN: both fake files still hold TEXT
# ------------------------------------------------------------------------------
# Adds one problem for each file that is missing, empty or changed. WHEN says
# when, for example "after the rebuild".
# ------------------------------------------------------------------------------
check_login_files() {
  local claudeDir=$1/claude
  local loginFile

  for loginFile in "$claudeDir/.credentials.json" "$claudeDir/projects/$loginProjectName/$3-session.jsonl"; do
    if ! grep -Fq -- "$2" "$loginFile" 2>/dev/null; then
      add_problem "${loginFile#"$1"/} is missing or changed $4"
    fi
  done
}
