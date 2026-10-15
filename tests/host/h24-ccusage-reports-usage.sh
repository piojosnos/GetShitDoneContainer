#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-24: ccusage reports this sandbox's Claude usage from state/claude
# ------------------------------------------------------------------------------
# Needs: test sandbox running
# --offline keeps the price lookup off the network, so every run agrees.
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init

sessionId="h24-$$-$(date +%s)"

# ------------------------------------------------------------------------------
# project_stdout CMD...: runs CMD in the project folder of the test container
# ------------------------------------------------------------------------------
# Stdin is closed, stderr discarded (ccusage prints notices there), never a tty.
# Running as the sandbox user also proves ccusage's native binary is executable.
# ------------------------------------------------------------------------------
project_stdout() {
  docker exec -w "$PROJECT_DIR" "$CONTAINER" "$@" </dev/null 2>/dev/null
}

# ------------------------------------------------------------------------------
# write_transcript: writes the one-message transcript for the run
# ------------------------------------------------------------------------------
# 100 input and 200 output tokens on 2020-01-07 under a run-unique session ID,
# in state/claude/projects/.../h24-usage.jsonl, the same file every run.
# ------------------------------------------------------------------------------
write_transcript() {
  local transcriptDir="$RUN/state/claude/projects/-home-sandbox-workspace-hosttest"

  mkdir -p "$transcriptDir"
  printf '%s\n' '{"type":"assistant","timestamp":"2020-01-07T12:00:00.000Z","sessionId":"'"$sessionId"'","cwd":"/home/sandbox/workspace/hosttest","requestId":"h24-request","message":{"id":"h24-message","model":"claude-sonnet-4-5-20250929","role":"assistant","usage":{"input_tokens":100,"output_tokens":200,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}},"costUSD":0.01}' >"$transcriptDir/h24-usage.jsonl"
}

# ------------------------------------------------------------------------------
# Reads the daily, monthly, session and table reports with their statuses
# ------------------------------------------------------------------------------
run_reports() {
  dailyOutput=$(run_timeout 60 project_stdout ccusage daily --offline --json --since 20200107 --until 20200107)
  dailyStatus=$?
  monthlyOutput=$(run_timeout 60 project_stdout ccusage monthly --offline --json --since 20200107 --until 20200107)
  monthlyStatus=$?
  sessionOutput=$(run_timeout 60 project_stdout ccusage session --offline --json --id "$sessionId")
  sessionStatus=$?
  tableOutput=$(run_timeout 60 project_stdout ccusage daily --offline --since 20200107 --until 20200107)
  tableStatus=$?
}

# ------------------------------------------------------------------------------
# check_report LABEL STATUS OUTPUT REGEX...: a problem per failed expectation
# ------------------------------------------------------------------------------
# STATUS must be 0 and each REGEX must match a line of OUTPUT. Daily, monthly
# and session give 100, 200 and 300 as whole numbers; the table has a Total row.
# ------------------------------------------------------------------------------
check_report() {
  local label=$1
  local reportStatus=$2
  local reportOutput=$3
  local expectedRegex

  shift 3

  if [ "$reportStatus" -ne 0 ]; then
    add_problem "$label exited $reportStatus"
  fi

  for expectedRegex in "$@"; do
    if ! printf '%s\n' "$reportOutput" | grep -Eq -- "$expectedRegex"; then
      add_problem "$label lacks $expectedRegex; got: $(first_lines "$reportOutput")"
    fi
  done
}

# ------------------------------------------------------------------------------
# Main / Entry Point
# ------------------------------------------------------------------------------
require_no_arguments "$@" || exit 2
require_test_sandbox H-24 || exit 1
write_transcript
run_reports
# A count ends at the next non-digit, so 1000 never satisfies 100.
check_report "ccusage daily" "$dailyStatus" "$dailyOutput" '"period": "2020-01-07"' '"inputTokens": 100([^0-9]|$)' '"outputTokens": 200([^0-9]|$)' '"totalTokens": 300([^0-9]|$)'
check_report "ccusage monthly" "$monthlyStatus" "$monthlyOutput" '"period": "2020-01"' '"inputTokens": 100([^0-9]|$)' '"outputTokens": 200([^0-9]|$)' '"totalTokens": 300([^0-9]|$)'
check_report "ccusage session" "$sessionStatus" "$sessionOutput" '"sessionId": "'"$sessionId"'"' '"totalTokens": 300([^0-9]|$)'
check_report "ccusage daily (table)" "$tableStatus" "$tableOutput" 'Total' '(^|[^0-9.,])300([^0-9.,]|$)'
report_check H-24 "ccusage does not report this sandbox's usage" \
  "ccusage daily, monthly and session report the planted transcript from state/claude (100, 200, 300 tokens) as the sandbox user"
