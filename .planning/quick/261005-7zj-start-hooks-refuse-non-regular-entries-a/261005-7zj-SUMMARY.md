---
phase: quick-261005-7zj
plan: 01
subsystem: sandbox-entrypoint
tags: [start-hooks, entrypoint, host-tests, h-17]
requires: []
provides:
  - "run_start_hooks refuses any non-folder entry that is not an executable regular file"
  - "H-17 covers a mode-644 hook and a dangling hook link against the real image"
affects: [base/sbx-entrypoint, tests/host/h17-start-offline-and-failing-hook.sh]
key-files:
  modified:
    - base/sbx-entrypoint
    - tests/entrypoint-selftest.sh
    - tests/host/h17-start-offline-and-failing-hook.sh
    - tests/host-selftest.sh
    - SANDBOX.md
    - base/Dockerfile
    - tests/host-checklist.md
decisions:
  - "Folders and the unmatched glob are the only skipped entries; everything else must be an executable regular file"
metrics:
  tasks: 3
  files: 7
status: complete
commits: 4
plan_head_before: f45fa7371641f22d37463ba1ac669b1c17e527b6
plan_head_after: 6664206c5f00cf543f88a8350e9cf934914a50bc
actuals:
  tokens: 14000
  tasks: 3
  commits: 4
---

# Phase quick-261005-7zj Plan 01: Start hooks refuse non-regular entries Summary

The start hook folder now fails closed: a dangling link, fifo or socket in /etc/sbx/start.d stops the start with `[sbx] ERROR: start hook <path> is not a regular file; the container was not started.` and exit 1, before any later hook and before the command.

## Commits

| Task | Commit | Files |
|------|--------|-------|
| 1 (RED) | 192b3f7 | tests/entrypoint-selftest.sh |
| 1 (GREEN) | 3d6d494 | base/sbx-entrypoint |
| 2 | 05e73e7 | tests/host/h17-start-offline-and-failing-hook.sh, tests/host-selftest.sh |
| 3 | 6664206 | SANDBOX.md, base/Dockerfile, tests/host-checklist.md |

## What changed

- `run_start_hooks` checks in order: unmatched glob (skip), folder (skip), not a regular file (error), not executable (error), hook fails (error). Nothing is opened or run before the regular-file test, so a fifo cannot block.
- `tests/entrypoint-selftest.sh` gained dangling-link and fifo cases (25 PASS lines). The RED commit showed both failing before the fix.
- H-17 now starts four containers. Two mount their own read-only folder over /etc/sbx/start.d (one mode-644 hook, one dangling link) and must exit non-zero with the matching `[sbx] ERROR` line without running their command. `make_hook_folders` is safe to run again on the same run folder.
- The fake docker in `tests/host-selftest.sh` records mounts by target, and for a run with a hook-folder mount it runs the real entrypoint `run_start_hooks` on that folder. `FAKE_HOOK_DIR_IGNORED=1` skips that step; the self-test shows H-17 then fails naming both errors.
- SANDBOX.md (Safety checks bullet, troubleshooting row), the base/Dockerfile start.d comment (wrapped, within 90 columns) and the H-17 checklist row describe the enforced rule.
- Review disposition: WR-01 and IN-04 set to `fixed` (Source `quick 261005-7zj`) in `.planning/phases/01.3-shell-script-layout/01.3-REVIEW-DISPOSITION.md`; left uncommitted for the orchestrator.

## Verification run here

- `bash tests/entrypoint-selftest.sh`: All cases pass (25 PASS).
- `bash tests/host-selftest.sh`: All cases pass, no FAIL line.
- `bash tests/guard.sh`: All rules hold. `layout-lint.sh`: clean.
- ASCII, no spaced double dash, Dockerfile block within 90 columns.

## Pending human check (Mac)

Docker is not available in the dev sandbox. On the Mac with this branch checked out, run `bash tests/host/run-all.sh` (rebuilds both images). Expected: `PASS: H-17 starts and syncs with --network none; a failing hook, a hook file that is not executable and a dangling hook link each stop the start with [sbx] ERROR`. If only the dangling link fails and the output shows `h17-command-ran`, check whether Docker Desktop shows the link inside the container: `docker run --rm --entrypoint ls --mount "type=bind,source=$RUN/h17/hooks-dangling,target=/etc/sbx/start.d,readonly" sbx-claude:local -la /etc/sbx/start.d`. Status: pending.

## Deviations from Plan

None. The plan commit ledger was created after the first (RED) commit from its parent (`f45fa73`), which is the same base.

## Known Stubs

None.

## Threat Flags

None.

## Self-Check: PASSED

Commits 192b3f7, 3d6d494, 05e73e7, 6664206 exist; all seven code files exist; no code commit contains a .planning path.
