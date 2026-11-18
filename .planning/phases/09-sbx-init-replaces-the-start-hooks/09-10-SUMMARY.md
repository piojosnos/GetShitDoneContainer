---
phase: 09-sbx-init-replaces-the-start-hooks
plan: 10
subsystem: testing
tags: [host-tests, bash, sbx-init]

requires:
  - phase: 09-sbx-init-replaces-the-start-hooks
    provides: sbx-init, images without an entrypoint (plans 05, 07)
provides:
  - compose_up that runs sbx-init in the test sandbox after up -d --wait
  - H-34 that runs sbx-init in the Claude and Cursor test sandboxes before the self-check
  - H-12, H-17 and H-20 deleted; H-10, H-23, H-28, H-29 and H-31 free of entrypoint and start hook wording
affects: [09-11, 09-12, 09-13]

status: complete
actuals:
  tokens: 9000
  tasks: 3
  commits: 3
plan_head_before: 55a34aaa9142571de921cd06c52b8fa115ab505c
plan_head_after: d1f83f1517bebb0c56bd8d92b9f6305ae9e88a89

tech-stack:
  added: []
  patterns:
    - "compose_up owns the sbx-init call, so chain checks need no init call of their own"

key-files:
  created: []
  modified:
    - tests/host/lib-sandbox.sh
    - tests/host/h34-selfcheck.sh
    - tests/host/run-all.sh
    - tests/host/h10-missing-folder-refused.sh
    - tests/host/h23-caches-survive-recreate.sh
    - tests/host/h28-sbx-add-start-stop.sh
    - tests/host/h29-sbx-upgrade.sh
    - tests/host/h31-sbx-shell.sh

key-decisions:
  - "tests/host-checklist.md rows for the deleted checks are left to plan 09-12, which owns that file"

requirements-completed: [INIT-02, INIT-03]

duration: 10min
completed: 2026-11-16
---

# Phase 9 Plan 10: Host test chain on the new start Summary

**The host chain now starts the test sandbox and runs sbx-init in it; H-34 proves init passes (4 steps Claude, 5 steps Cursor) before each self-check; the three entrypoint-era checks are gone.**

## Accomplishments

- `compose_up` drops the hook wait (and `SBXTEST_START_SECONDS`) and runs `docker exec sbx-hosttest sbx-init`, logging to `compose-up.log` and failing on a non-zero exit.
- H-34 gets `run_init` and the `expectedClaudeStepCount=4` and `expectedCursorStepCount=5` constants; each result is an INFO line.
- H-12, H-17 and H-20 deleted with their `run-all.sh` entries (16 checks remain; H-35 comes in plan 09-11).
- H-10 and H-23 no longer name the entrypoint; H-28 asserts `Config.Entrypoint` is `null` or `[]`; H-29 and H-31 no longer wait for a running `sleep`.

## Task Commits

1. Task 1 (tracer): `e6893e6`
2. Task 2: `1d4d62a`
3. Task 3: `d1f83f1`

## Deviations from Plan

One small addition: the comment in `lib-sandbox.sh` that named H-20 as a check leaving test sandboxes behind now names only H-10, since H-20 is deleted. Otherwise the plan ran as written.

## Verification

`bash -n` passes on every edited file; `bash tests/guard/run-all.sh` ends with `All rules hold.`; `uv run pytest tests/selftest/selfcheck/test_inventory.py -q` passes (12 tests). The host checks themselves run on the Mac in plan 09-13 (no Docker here).

## Known Stubs

None.

## Threat Flags

None. `docker exec` targets `$CONTAINER` (sbx-hosttest) and the H-34 Cursor test container only.

## Self-Check: PASSED

Files edited exist, the three deleted checks are gone, and commits `e6893e6`, `1d4d62a` and `d1f83f1` exist.
