---
phase: 08-in-image-self-check
plan: 11
subsystem: testing
tags: [selfcheck, review-dispositions, mac-gate, requirements, gap-closure]
status: complete

requires:
  - phase: 08-08
    provides: the owner fix command, the unreadable folder walk and the runner level agent check failure
  - phase: 08-09
    provides: tool-bash and tool-keytool, the 41, 53 and 51 counts and the H-34 owner fix round trip
  - phase: 08-10
    provides: the settings message, shape suffixes, type hints and loops
provides:
  - a disposition for each of the twelve review findings (eleven fixed, IN-08 deferred to Phase 10)
  - a pending todo carrying the IN-08 host check hygiene items
  - the dev-sandbox gate and the Mac gate, both green
  - CHECK-01 to CHECK-04 marked complete
affects: [phase 8 verification, phase 10]

actuals:
  tokens: 4200
  tasks: 3
  commits: 2
plan_head_before: 38127eac28a63a86e607b0277e7262a5be854c00
plan_head_after: cf49d998c54c50bed0d5b10dd5a5dc7d6d8a47f4

tech-stack:
  added: []
  patterns:
    - "Docs only plan: dispositions, a todo and requirement marks, each in a planning commit with no code"

key-files:
  created:
    - .planning/todos/pending/2026-11-14-h34-host-check-hygiene.md
  modified:
    - .planning/phases/08-in-image-self-check/08-REVIEW-DISPOSITION.md
    - .planning/REQUIREMENTS.md

key-decisions:
  - "IN-08 is deferred to Phase 10, where the bash host checks are rewritten in Python (HOST-01, HOST-05); part (b) is harmless on macOS, where TMPDIR is per user"
  - "All four CHECK requirements were marked complete together, the exact reverse of the revert in ff65692, only after the Mac run was approved"

requirements-completed: [CHECK-01, CHECK-02, CHECK-03, CHECK-04]

coverage:
  - id: D1
    description: "every review finding has a disposition, none open, IN-08 deferred with a reason and a todo"
    requirement: CHECK-04
    verification:
      - kind: command
        ref: "grep -cE '\\|[[:space:]]*(fixed|deferred)[[:space:]]*\\|' 08-REVIEW-DISPOSITION.md prints 12, no open row"
        status: pass
    human_judgment: false
  - id: D2
    description: "the dev sandbox suites, list sizes, change set and sweeps are green"
    requirement: CHECK-01
    verification:
      - kind: command
        ref: "Task 1 verify block, every command exited 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "on the Mac, host-test passes with 53 and 51 checks and the owner fix round trip goes from 1 failed to 0 failed"
    requirement: CHECK-04
    verification:
      - kind: human
        ref: "host-test.log and selfcheck-gate.log read after the Mac run on 2026-11-14, approved by the user"
        status: pass
    human_judgment: true
---

# Phase 8 Plan 11: Dispositions, dev gate and Mac gate Summary

Every review finding now has a recorded disposition, the dev sandbox and the Mac run both pass with the new counts and the owner fix round trip, and CHECK-01 to CHECK-04 are marked complete.

## Accomplishments

- `08-REVIEW-DISPOSITION.md` has a Reason column and twelve rows: WR-01 to WR-04 and IN-01 to IN-07 are `fixed` with their commits, IN-08 is `deferred`. No row is `open`.
- `.planning/todos/pending/2026-11-14-h34-host-check-hygiene.md` holds the three IN-08 items with the review's fix for each, with `resolves_phase: 10`.
- The dev-sandbox gate (Task 1) and the Mac gate (Task 2) are green; the evidence is below.
- `REQUIREMENTS.md`: CHECK-01 to CHECK-04 are checked and their traceability rows read `Complete`, exactly the eight lines ff65692 reverted.

## Task Commits

| Task | Commit | Type | What |
|---|---|---|---|
| 1 | 4e3fd1a | docs | dispositions and the deferred host check todo |
| 2 | none | checkpoint | the Mac gate, approved by the user |
| 3 | cf49d99 | docs | CHECK-01 to CHECK-04 complete |

## Dev-sandbox gate evidence (Task 1)

| Check | Result |
|---|---|
| `uv run pytest tests/selftest/selfcheck -q` | 190 passed |
| guard (`tests/guard/run-all.sh`) | 19 PASS lines, last line `All rules hold.` |
| sbx self-test | 150 PASS lines, last line `All cases pass.`; also green with `SBX_IMAGE_TAG=test` and `SBX_CA_CERT=/nonexistent/ca.pem` |
| entrypoint self-test | 58 PASS lines, last line `All cases pass.` |
| list sizes (shared, Claude, Cursor) | 41 12 10 |
| H-34 constants | `expectedClaudeCount=53`, `expectedCursorCount=51` |
| host check files | 19 |
| code paths changed since ff65692 | exactly the 14 the gap plans name |
| file modes | no mode change; `h34-selfcheck.sh` is 100644 and `sbx-selfcheck` is 100755 |
| untouched files | Dockerfiles, `compose.yml`, `build.sh`, `bin/`, `clean.sh`, `host-test.sh`, `tests/host/run-all.sh`, `versions.env` |
| commit mix | no commit since ff65692 holds both `.planning/` files and code |
| ASCII, planning ID and dash sweeps | empty output |
| comprehension and blank-line sweeps, removed names | empty output |

## Mac gate evidence (Task 2, run 2026-11-14)

Read from `host-test.log` and `selfcheck-gate.log` after the user ran `./host-test.sh`:

- `Summary: 19 passed, 0 failed, 0 not run` and `0 step(s) failed.`
- `PASS: H-34`, `PASS: H-32`, `PASS: H-33`, and `All rules hold.` for the guard.
- `INFO: H-34 Claude test sandbox: sbx-selfcheck: 53 checks, 0 failed`
- `INFO: H-34 Cursor test sandbox: sbx-selfcheck: 51 checks, 0 failed`
- Owner fix round trip: `owner fix, before: sbx-selfcheck: 53 checks, 1 failed`, then the fix line `docker run --rm --network none -u root --entrypoint chown --volumes-from sbx-hosttest sbx-base:local -R 1000:1000 /home/sandbox/workspace/state`, then `owner fix, after: sbx-selfcheck: 53 checks, 0 failed`. This confirms the flagged assumption: `--volumes-from sbx-hosttest` carries the bind mount into the throwaway root container, so the planted folder and the chown reach the sandbox state.
- Local image IDs are identical before and after (`sbx-base` aa738f67..., `sbx-claude` 5cc1c6ac..., `sbx-cursor` c6eb0aba...); zero `sbx-hosttest-cursor` containers remain.

## Deviations from Plan

None. The plan ran as written; Task 2 was the planned blocking checkpoint and the user approved it.

## Threat Surface

T-08-36 to T-08-38 held: the exec bits were restored by step 1 of the checkpoint, the `:local` image IDs did not change, and the requirements were marked only after the approved Mac run. No new threat flags.

## Known Stubs

None.

## Issues Encountered

None. One housekeeping note: commit 4e3fd1a carries a `Co-Authored-By` trailer that the user's git rules do not want; the Task 3 commit has none. It is unpushed, so it can be reworded before the PR if wanted.

## Next

Phase 8 is complete. Next: the code PR is prepared by hand as for plan 08-07 (cherry-pick the code commits onto a `feat/` branch cut from the updated `main`, push only with the user's go, open the PR against `main`); planning files go in their own PR.

## Self-Check: PASSED

- Files exist: `08-REVIEW-DISPOSITION.md`, `2026-11-14-h34-host-check-hygiene.md`, `REQUIREMENTS.md`.
- Commits found in `git log`: 4e3fd1a, cf49d99 (`git rev-list --count` from the plan base gives 2).
- Task 3 verify command passed: four `[x]` lines, four `Complete` rows, numstat `8 8` against ff65692.
