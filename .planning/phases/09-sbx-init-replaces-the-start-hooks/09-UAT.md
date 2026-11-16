---
status: testing
phase: 09-sbx-init-replaces-the-start-hooks
source: [09-VERIFICATION.md]
started: 2026-11-16T20:03:16Z
updated: 2026-11-16T20:03:16Z
---

## Current Test

number: 1
name: The agents folder reaches a login shell inside each agent's Bash tool
expected: |
  In a live sbx-claude session, both `command -v claude` and `bash -lc 'command -v claude'` print /opt/sbx/agents/bin/claude; the same holds for cursor-agent in sbx-cursor.
awaiting: user response

## Tests

### 1. The agents folder reaches a login shell inside each agent's Bash tool
expected: In a live sbx-claude session, both `command -v claude` and `bash -lc 'command -v claude'` print /opt/sbx/agents/bin/claude; the same holds for cursor-agent in sbx-cursor.
result: [pending]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
