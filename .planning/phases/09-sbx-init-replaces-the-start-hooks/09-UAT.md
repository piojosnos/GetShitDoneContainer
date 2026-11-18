---
status: complete
phase: 09-sbx-init-replaces-the-start-hooks
source: [09-VERIFICATION.md]
started: 2026-11-16T20:03:16Z
updated: 2026-11-17T04:56:15Z
---

## Current Test

[testing complete]

## Tests

### 1. The agents folder reaches a login shell inside each agent's Bash tool
expected: In a live sbx-claude session, both `command -v claude` and `bash -lc 'command -v claude'` print /opt/sbx/agents/bin/claude; the same holds for cursor-agent in sbx-cursor.
result: skipped
reason: "Deferred follow-up: user skipped the manual Mac check to keep moving; no automated test covers it yet"
follow_up: "H-27 (Claude) and H-34 (Cursor) now automate this check and passed on the Mac (host-test.log, commit 8b74b76): a login shell inside an agent session finds the agent in /opt/sbx/agents/bin and a plain login shell does not"

## Summary

total: 1
passed: 0
issues: 0
pending: 0
skipped: 1
blocked: 0

## Gaps

## Deferred Follow-Ups

- test: 1
  idea: "Automate the login-shell PATH check (bash -lc 'command -v claude' and the cursor-agent twin) in a host check"
  deferred_at: 2026-11-17
