---
status: complete
phase: 05-migration-docs-and-old-layout-retirement
source: [05-VERIFICATION.md]
started: 2026-11-08T08:30:51Z
updated: 2026-11-08T08:30:51Z
---

## Current Test

none: all items skipped by the user

## Tests

### 1. Login survives a rebuild (h29 helper on the Mac)
expected: The helper ends PASS; logged in before and after sbx-upgrade; claude --continue resumes the session
result: skipped
reason: the user declined manual UAT on 2026-11-08

### 2. README threat model claims no isolation the sandbox lacks
expected: Network, the tokens in state/ and files the Mac later runs are all stated as not isolated
result: skipped
reason: the user declined manual UAT on 2026-11-08

### 3. README threat model "Rules" paragraph covers the concurrency edge
expected: The rules hold whatever the timing, with no "while the sandbox is stopped" exception
result: skipped
reason: the user declined manual UAT on 2026-11-08

### 4. README.md and MIGRATION.md read short and clear
expected: One short schematic guide; nothing to cut or move
result: skipped
reason: the user declined manual UAT on 2026-11-08

### 5. email-intel and radio-practice keep login, sessions and ccusage history
expected: sbx-claude starts logged in, /resume lists old sessions, ccusage daily shows pre-move days
result: skipped
reason: the user declined manual UAT on 2026-11-08

## Summary

total: 5
passed: 0
issues: 0
pending: 0
skipped: 5
blocked: 0

## Gaps
