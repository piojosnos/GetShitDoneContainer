---
phase: 09-sbx-init-replaces-the-start-hooks
plan: 03
subsystem: infra
status: complete
tags: [python, sbx-init, selfcheck, ownership]

requires:
  - phase: 09-sbx-init-replaces-the-start-hooks
    provides: the sbx-init runner and the shared step folder (plan 01)
provides:
  - base/selfcheck/root_owned_scan.py with SKIPPED_STATE_DIR_SET, scan_owned_state and owner_fix_hint
  - the state-owner init step that gives root-owned state back to sandbox with os.lchown
  - a strict no-root-owned-state check without the GSD sync folder tolerance
affects: [09-11, 09-13]

actuals:
  tokens: 9200
  tasks: 2
  commits: 2
plan_head_before: bcde9f063fdc5b6633aa8178046428a3c2fca7cc
plan_head_after: 0e339a4b0c8da2193e157a9e736e71531ba19330

tech-stack:
  added: []
  patterns:
    - "init and the self-check share one scan module, so the step fixes exactly what the check reports"

key-files:
  created:
    - base/selfcheck/root_owned_scan.py
    - base/init/steps/800_state_owner.py
    - tests/selftest/init/test_init_state_owner.py
    - tests/selftest/selfcheck/test_root_owned_scan.py
  modified:
    - base/selfcheck/checks/040_root_owned_state.py
    - tests/selftest/selfcheck/test_root_owned_state.py
    - tests/selftest/init/test_init_launcher.py
    - tests/guard/isolation.sh

key-decisions:
  - "The step scans, gives back, and rescans up to three rounds; a final scan after the last round reports whatever is still owned"
  - "The scan helper also exports UNREADABLE_SUFFIX so the step can strip it without a second copy of the string"

patterns-established:
  - "A chown stand-in that removes a file plays the owner change in tests, since a non-root test cannot give a file to another user"

requirements-completed: [INIT-06]

coverage:
  - id: D1
    description: "The state-owner step gives every root-owned path under state/ back to sandbox with os.lchown through the shared scan"
    requirement: INIT-06
    status: covered
    evidence: "uv run pytest tests/selftest/init/test_init_state_owner.py: 12 pass"
  - id: D2
    description: "The self-check no longer tolerates gsd-core, hooks or scripts; a root-owned path there FAILs"
    requirement: INIT-06
    status: covered
    evidence: "test_a_root_owned_path_in_a_gsd_core_folder_fails_the_check; uv run pytest tests/selftest: 343 pass"
  - id: D3
    description: "The guard rule owner_fix_hint_matches_container_name reads the fix from root_owned_scan.py"
    requirement: INIT-06
    status: covered
    evidence: "bash tests/guard/run-all.sh ends with All rules hold."
  - id: D4
    description: "On Docker Desktop the sandbox user can lchown a root-owned file in state/ to itself (RESEARCH A1)"
    requirement: INIT-06
    status: not-run
    evidence: "Mac only; H-35 (plan 09-11) and the phase gate (plan 09-13) prove it"
---

# Phase 9 Plan 03: State owner step Summary

**The state-owner init step gives root-owned paths in state/ back to sandbox with os.lchown, through one scan shared with the now strict no-root-owned-state check.**

## Performance

- **Tasks:** 2 of 2
- **Files:** 4 created, 4 modified

## Accomplishments

- `root_owned_scan.py` holds the scan (never follows a link), the skip set (`cache/npm`, `cache/uv`, `m2`) and the Mac fix, moved from the check.
- `800_state_owner.py` runs at most three scan and give-back rounds, so folders the scan could not read at first are reached once they are the sandbox's. A path `lchown` cannot change, or one still owned after the last round, FAILs with at most ten paths and the Mac command naming the container.
- The check drops the GSD sync folder tolerance; any root-owned path under `gsd-core`, `hooks` or `scripts` now FAILs.
- The guard rule reads the fix from `root_owned_scan.py`.

## Task Commits

1. **Task 1: state-owner step on a shared scan (tracer)**: `8478dc4`
2. **Task 2: scan tests in their own module, strict check tests**: `0e339a4`

The tracer feedback gate was met by the task's own verification (state owner tests and the guard run).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Launcher end-to-end test counted two steps**
- **Found during:** Task 1 (full selftest run)
- **Issue:** `test_init_launcher.py` runs the real shared step folder, so the new step adds an `OK: state-owner` line and a third step to the output.
- **Fix:** expected output updated and the test renamed to mention the give-back.
- **Files modified:** tests/selftest/init/test_init_launcher.py
- **Commit:** 8478dc4

**2. [Rule 1 - Plan test cannot hold] Test (1) of the plan**
- **Found during:** Task 1
- **Issue:** with `from_uid = to_uid = os.getuid()` the files stay owned by `from_uid` after every lchown, so the scan never empties; the real-lchown pass case the plan describes would run three rounds and then correctly FAIL as "still owned".
- **Fix:** the count and second-run tests use a stand-in chown function that removes the file (the tree then reads as given back); a separate test pins the real `os.lchown` behaviour (accepted for every path, then FAIL after three rounds with no "Operation not permitted"). The step code follows the plan unchanged.
- **Files modified:** tests/selftest/init/test_init_state_owner.py
- **Commit:** 8478dc4

**3. Task order note.** Task 1 changed the check module, so the old `test_root_owned_state.py` was stale until Task 2's commit; the intermediate commit does not pass that one file.

## Known Stubs

None.

## Threat Flags

None. The step stays inside state/, uses `os.lchown` only, and never deletes.

## Issues Encountered

None beyond the deviations above. Docker is not available here; the Docker Desktop assumption (RESEARCH A1) stays for H-35 and the phase gate.

## Self-Check: PASSED

- base/selfcheck/root_owned_scan.py, base/init/steps/800_state_owner.py, tests/selftest/init/test_init_state_owner.py, tests/selftest/selfcheck/test_root_owned_scan.py exist
- commits 8478dc4 and 0e339a4 exist
- `uv run pytest tests/selftest`: 343 passed; guard ends with `All rules hold.`
