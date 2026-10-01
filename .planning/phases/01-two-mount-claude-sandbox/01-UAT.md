---
status: testing
phase: 01-two-mount-claude-sandbox
source: [01-VERIFICATION.md]
started: 2026-10-01T19:20:00Z
updated: 2026-10-01T19:20:00Z
---

## Current Test

number: 1
name: Full host checklist H-00..H-13 plus Coexistence (SANDBOX.md)
expected: |
  Every check meets its stated pass condition, and the "Record your results" table is filled in with the `docker compose version` and Docker Desktop versions.
  On 2026-10-01 the user deferred this to Phase 2. It has not been run.
awaiting: user response

## Tests

### 1. Full host checklist H-00..H-13 plus Coexistence (SANDBOX.md)
expected: Every check meets its pass condition. This is the only evidence for SC1-SC5. Fix WR-02 (H-06 overwrites the git identity) before running it.
result: [pending]

### 2. H-10: start with a nonexistent SBX_DIR
expected: `up` errors and the path is not created. If Docker creates the folders, Compose is not honoring `create_host_path: false`. The env_file-sentinel follow-up (needs user approval) then becomes a gap-closure item.
result: [pending]

### 3. H-12: installed Claude Code equals the approved pin, and a plain `docker run` is refused
expected: `docker run --rm --entrypoint claude sbx-claude:local --version` prints `2.1.285 (Claude Code)`. A plain `docker run` prints `[sbx] ERROR ... not a bind mount` and exits with rc=1.
result: [pending]

### 4. No false writability refusal on VirtioFS
expected: `docker compose up -d --wait` succeeds, and there is no `[sbx] ERROR: ... is not writable by sandbox` while the Mac folder is writable.
result: [pending]

### 5. Judgment-tier prohibitions from 01-01-PLAN.md hold on the Mac
expected: The H-09 `docker inspect` Mounts show only `$SBX_DIR` directory binds. The H-06 and H-07 credentials land in `state/`, not `workspace/`.
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
