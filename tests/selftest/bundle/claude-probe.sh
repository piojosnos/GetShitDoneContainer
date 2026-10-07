#!/usr/bin/env bash
# Self-test of what Claude Code at the pinned version sees after a sync: always-on rules and skills, no path-scoped rule; SKIP off the pin.
# - Syncs the repo bundle, runs claude -p /context offline with a dummy key and reads the listing.
# - Prints a SKIP line when claude is not at the pin in claude/Dockerfile.
# - Run by run-all.sh; runs alone too.
# - Makes one work folder under TMPDIR and removes only that folder at exit.
# - Usage, from anywhere: bash tests/selftest/bundle/claude-probe.sh   (exit 0 = every case passes)
set -u
. "$(dirname "$0")/lib.sh"

# --------------------------------------------------------------------------------
# Asks the real Claude at the pinned version for /context after a sync; skipped off the pin
# --------------------------------------------------------------------------------
case_claude_sees_bundle() {
  local pin found probeConfig ruleFile relative skillName

  echo "--- Claude at the pin sees the synced bundle"
  pin=$(claude_pin)
  found=$(claude --version 2>/dev/null || echo "none")

  if [ "$found" != "$pin (Claude Code)" ]; then
    echo "SKIP: Claude probe (claude $found is not the pinned $pin)"
    return
  fi

  probeConfig=$WORK/probe-config
  mkdir -p "$WORK/probe-project"
  run_sync "$BUNDLE" "$probeConfig" "$WORK/out.probe-sync"
  (
    cd "$WORK/probe-project" || exit 1
    env CLAUDE_CONFIG_DIR="$probeConfig" ANTHROPIC_API_KEY=sk-ant-dummy ANTHROPIC_BASE_URL=http://127.0.0.1:1 \
      claude -p /context >"$WORK/out.context" 2>&1 </dev/null
  )

  while IFS= read -r ruleFile; do
    relative=${ruleFile#"$BUNDLE/rules/"}

    if [ "$(head -n 1 "$ruleFile")" = "---" ]; then
      expect "claude: path-scoped rule $relative is not loaded at start" lacks_text "$WORK/out.context" "rules/$relative"
    else
      expect "claude: always-on rule $relative is a User memory file" has_text "$WORK/out.context" "| User | $probeConfig/rules/$relative |"
    fi
  done <<EOF_RULES
$(find "$BUNDLE/rules" -name '*.md' | sort)
EOF_RULES

  for skillName in $(bundle_skill_names); do
    expect "claude: skill $skillName is listed with source User" has_text "$WORK/out.context" "| $skillName | User |"
  done
}

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
start_group || exit 1
case_claude_sees_bundle
finish_cases
