---
phase: 09-sbx-init-replaces-the-start-hooks
plan: 13
subsystem: testing
tags: [phase-gate, host-test, sbx-init, docker-desktop, verification]

requires:
  - phase: 09-sbx-init-replaces-the-start-hooks
    provides: plans 09-01 to 09-12 (sbx-init, steps, wrappers, agents folder, deletions, guard, host checks, docs)
provides:
  - a green dev-sandbox gate (suites, counts, deletions, modes, sweeps) recorded here
  - a passing Mac run of host-test.sh with H-16, H-27, H-34 and H-35 on the real images
  - confirmation that the sandbox user can give root-owned state back to itself on Docker Desktop
affects: [phase-9 verification, phase-9 PR, phase 10]

status: complete
actuals:
  tokens: 0
  tasks: 2
  commits: 0
plan_head_before: 458f5a82d91281d9b2e60c5847d15a570a62f070
plan_head_after: 458f5a82d91281d9b2e60c5847d15a570a62f070

tech-stack:
  added: []
  patterns:
    - "phase gate: read-only dev-sandbox proof first, then one Mac run recorded in two logs outside git"

key-files:
  created: []
  modified: []

key-decisions:
  - "Flagged assumption A1 is confirmed: on Docker Desktop the sandbox user gives root-owned state back to itself (H-35 state-owner, 314 paths); no gap-closure plan is needed"
  - "Flagged assumptions A2, A3 and A4 are confirmed by H-34 (compose up returns at running, init then passes) and H-27 (agents run the same through the agents folder)"

requirements-completed: [INIT-01, INIT-02, INIT-03, INIT-04, INIT-05, INIT-06]

coverage:
  - id: D1
    description: "Dev-sandbox gate: every suite passes, the counts and lists agree, the old start path is gone, modes and sweeps are clean"
    requirement: "INIT-03"
    verification:
      - kind: unit
        ref: "uv run pytest -q (422 passed)"
        status: pass
      - kind: integration
        ref: "bash tests/guard/run-all.sh (20 PASS, All rules hold.) and bash tests/selftest/sbx/run-all.sh (150 PASS, also with SBX_IMAGE_TAG=test SBX_CA_CERT=/nonexistent/ca.pem)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Mac gate: host-test.sh passes with H-16, H-27, H-34 and H-35 on the real images and the local images untouched"
    requirement: "INIT-01"
    verification:
      - kind: manual_procedural
        ref: "host-test.log (Summary: 17 passed, 0 failed, 0 not run; 0 step(s) failed.) and ../init-gate.log"
        status: pass
    human_judgment: true
    rationale: "Docker does not run in the dev sandbox; the run is a human action on the Mac and the executor only read its two logs"

duration: 40min
completed: 2026-11-16
---

# Phase 9 Plan 13: Phase gate Summary

**Phase 9 is proven end to end: 422 tests, 20 guard rules and 150 self-test cases pass in the dev sandbox, and on the Mac host-test.sh passes 17 of 17 host checks with sbx-init green on both real test images and the :local images unchanged.**

## Performance

- **Duration:** about 40 min across the dev-sandbox gate, the Mac checkpoint and this close-out
- **Completed:** 2026-11-16T19:55:10Z
- **Tasks:** 2
- **Files modified:** 0 (the gate changes no file; this SUMMARY and the planning state files are the only output)

## Accomplishments

- Dev-sandbox gate green (task 1), values below.
- Mac gate green (task 2): the user ran the four blocks and replied "Done, all looks good"; the executor read both logs and confirmed every acceptance line itself.
- Flagged assumption A1 (the sandbox user can lchown root-owned state back on Docker Desktop) is confirmed, so INIT-06 holds on the real platform.
- The phase has no open gap: all five ROADMAP success criteria are met.

## Dev-sandbox gate (task 1)

| Check | Result |
|---|---|
| `uv run pytest -q` | 422 passed (the phase started at 272; both tests/selftest/init and tests/selftest/selfcheck run) |
| Guard (`tests/guard/run-all.sh`) | 20 PASS lines, last line `All rules hold.`; `container_runs_no_entrypoint` and `agents_stay_off_the_path` PASS; the two start hook rules are gone |
| sbx self-test (`tests/selftest/sbx/run-all.sh`) | 150 PASS, `All cases pass.`; same result with `SBX_IMAGE_TAG=test SBX_CA_CERT=/nonexistent/ca.pem` |
| Self-check counts | shared 42, Claude 13, Cursor 11 |
| H-34 constants | 55 and 53 checks, 4 and 5 init steps |
| Host check list | 17 entries, every file exists |
| Deleted paths | entrypoint, start library, both start hook folders, sbx-link-bundle and tests/selftest/entrypoint are gone; no code file names the old start path |
| Modes | sbx-init, both wrappers, sbx-bundle-clone and sbx-gh-login are 100755; H-35 is 100644; no other mode change |
| Commit hygiene | no test module basename repeats; no commit since the phase start mixes .planning/ with code |
| Sweeps | ASCII, ID, dash and bundle-name sweeps are clean for product files; two sweeps printed over-broad hits only in tests that assert absence on purpose (`test_init_inventory.py`, `test_init_wrappers.py`, `test_init_best_practices_link.py`) and in test names around the existing `bundle_links_result` |
| Amended wording | INIT-02 to INIT-05 and ROADMAP Phase 9 criteria hold the amended text |

## Mac gate (task 2)

Checkpoint approved by the user ("Done, all looks good"). Evidence read from the logs:

`/home/sandbox/workspace/get-shit-done-container/host-test.log` (branch `feat/sbx-init`, commit `458f5a8`):

- `Summary: 17 passed, 0 failed, 0 not run`
- `PASS: H-16`, `PASS: H-27`, `PASS: H-34`, `PASS: H-35`
- Claude test sandbox: `sbx-init: 4 steps passed`, `sbx-selfcheck: 55 checks, 0 failed`
- Cursor test sandbox: `sbx-init: 5 steps passed`, `sbx-selfcheck: 53 checks, 0 failed`
- `INFO: H-35 OK: state-owner: 314 paths given back to sandbox`
- `All rules hold.` (twice: in sbx-hosttest and in the Mac shell)
- `0 step(s) failed.`

`/home/sandbox/workspace/init-gate.log`: the IDs of `sbx-base:local`, `sbx-claude:local` and `sbx-cursor:local` are identical before and after the run, so the gate never replaced an image a real sandbox runs.

## Task Commits

This plan changes no tracked file, so it has no task commit.

1. **Task 1: Phase gate in the dev sandbox (tracer)** - none (read-only verification)
2. **Task 2: The Mac gate (checkpoint:human-verify)** - none (the Mac run writes host-test.log, which is gitignored, and init-gate.log outside the repo)

**Plan metadata:** the docs commit that adds this SUMMARY, STATE.md and ROADMAP.md

## Files Created/Modified

- `.planning/phases/09-sbx-init-replaces-the-start-hooks/09-13-SUMMARY.md`: this gate record

## Decisions Made

None beyond confirming the flagged assumptions: A1, A2, A3 and A4 hold on Docker Desktop; A7 stays moot because of the sbx-gh-login precondition.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Two dev-sandbox sweeps printed hits that are not defects (see the sweeps row above); they sit in tests that check for absence on purpose.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 9 is complete; run phase verification next.
- The code PR is prepared by hand: code commits on a `feat/` branch cut from the updated `main`, push only with the user's go, PR against `main`. Planning files and `.claude/` go in their own PRs (the `.claude/CLAUDE.md` refresh for the new start is one).
- Not run on the Mac and not required: the optional real-sandbox step (`sbx-upgrade NAME` then the manual shell walk-through).

## Known Stubs

None.

## Threat Flags

None. This plan adds no code and no new trust surface.

## Self-Check: PASSED

- SUMMARY file exists on disk.
- host-test.log and init-gate.log read and every acceptance line found.
- No code commit expected for this plan; `git rev-list --count 458f5a8..HEAD` is 0 and no code file is changed.

---
*Phase: 09-sbx-init-replaces-the-start-hooks*
*Completed: 2026-11-16*
