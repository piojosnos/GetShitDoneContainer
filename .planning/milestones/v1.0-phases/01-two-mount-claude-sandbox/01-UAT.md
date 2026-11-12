---
status: complete
phase: 01-two-mount-claude-sandbox
source: [01-VERIFICATION.md]
started: 2026-10-01T19:20:00Z
updated: 2026-10-04T02:05:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Full host checklist H-00..H-13 plus Coexistence (tests/host-checklist.md)
expected: Every check meets its pass condition. This is the only evidence for SC1-SC5. Fix WR-02 (H-06 overwrites the git identity) before running it.
result: pass
evidence: |
  Run on the Mac (MacBook Pro M1, macOS stock bash, Compose 2.40.0-desktop.1, Docker Desktop 4.48.0) on 2026-10-03 with bash tests/host/run-all.sh:
  Summary: 14 passed, 0 failed, 0 not run
  Manual pass helpers:
  PASS: H-07 .claude.json, .credentials.json and projects/ are in .../state/claude
  PASS: H-07 claude auth status shows "loggedIn": true
  PASS: H-07 no ~/.claude.json in the container home
  PASS: H-09 claude auth status still shows "loggedIn": true after the rebuild
  PASS: H-09 claude --continue resumed the earlier session
  PASS: H-13 claude doctor shows auto-updates disabled

### 2. H-10: start with a nonexistent SBX_DIR
expected: `up` errors and the path is not created. If Docker creates the folders, Compose is not honoring `create_host_path: false`. The env_file-sentinel follow-up (needs user approval) then becomes a gap-closure item.
result: pass
evidence: |
  Run on the Mac on 2026-10-03 with bash tests/host/run-all.sh (Compose 2.40.0-desktop.1):
  PASS: H-10 a missing folder is refused (rc=1) and not created. Compose 2.40.0-desktop.1
  Compose honors create_host_path: false, so the env_file-sentinel follow-up is not needed.

### 3. H-12: installed Claude Code equals the approved pin, and a plain `docker run` is refused
expected: `docker run --rm --entrypoint claude sbx-claude:local --version` prints `2.1.285 (Claude Code)`. A plain `docker run` prints `[sbx] ERROR ... not a bind mount` and exits with rc=1.
result: pass
evidence: |
  Run on the Mac on 2026-10-03 with bash tests/host/run-all.sh:
  PASS: H-12 a plain docker run is refused and Claude Code 2.1.285 is installed

### 4. No false writability refusal on VirtioFS
expected: `docker compose up -d --wait` succeeds, and there is no `[sbx] ERROR: ... is not writable by sandbox` while the Mac folder is writable.
result: pass
evidence: |
  Run on the Mac on 2026-10-03 with bash tests/host/run-all.sh. The run reached the sandbox stage and every in-container check passed, with no "is not writable" error and no FAIL: SETUP line:
  PASS: H-04 container user is uid=1000(sandbox)
  PASS: H-05 x.txt reached the host, .bashrc and .local exist, owners are sandbox

### 5. Judgment-tier prohibitions from 01-01-PLAN.md hold on the Mac
expected: The H-09 `docker inspect` Mounts show only `$SBX_DIR` directory binds. The H-06 and H-07 credentials land in `state/`, not `workspace/`.
result: pass
evidence: |
  Run on the Mac on 2026-10-03 with bash tests/host/run-all.sh and the manual pass:
  PASS: H-09 files survived the rebuild, the volume list is unchanged, one bind mount
  PASS: H-06 git status is clean of ownership errors, safe.directory is *, the identity is in state/git/config
  PASS: H-07 .claude.json, .credentials.json and projects/ are in .../state/claude

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
