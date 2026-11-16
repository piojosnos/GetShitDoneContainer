---
phase: 09-sbx-init-replaces-the-start-hooks
plan: 01
subsystem: infra
tags: [python, sbx-init, flock, pytest, selfcheck]

requires:
  - phase: 08
    provides: the sbx-selfcheck launcher, runner, Check/CheckResult types and hints that sbx-init copies
provides:
  - sbx-init launcher, runner and the state-folders step (base/init/)
  - init constants in paths.py and init_hint() in hints.py
  - pytest suite tests/selftest/init/ (launcher, runner, state folders)
affects: [09-02, 09-03, 09-04, 09-05, 09-06, 09-07, 09-08, 09-09, 09-10, 09-11, 09-12, 09-13]

actuals:
  tokens: 11000
  tasks: 3
  commits: 3
plan_head_before: a963979e09f28eb826339281d3c06624b5abdeca
plan_head_after: 6ad9267bdcc0909e2d8f5ad03f625bc774856c10

tech-stack:
  added: []
  patterns:
    - "Numbered step files with a module-level STEP_LIST of Check, loaded by path from a shared and an agent folder and sorted by file name"
    - "Run lock with fcntl.flock LOCK_EX|LOCK_NB on a file in the container layer, marker removed after the lock and written after the last step"

key-files:
  created:
    - base/init/sbx-init
    - base/init/init_runner.py
    - base/init/steps/010_state_folders.py
    - tests/selftest/init/init_helpers.py
    - tests/selftest/init/test_init_launcher.py
    - tests/selftest/init/test_init_runner.py
    - tests/selftest/init/test_init_state_folders.py
  modified:
    - base/selfcheck/paths.py
    - base/selfcheck/hints.py
    - base/selfcheck/checks/030_state_folders.py
    - pyproject.toml
    - tests/selftest/selfcheck/test_hints.py
    - tests/selftest/selfcheck/test_state_folders.py

key-decisions:
  - "Init merges shared and agent step files and sorts by (file name, group), so a shared 800 step runs after an agent 050 step and a shared step wins a name tie"
  - "AGENT_STEPS_DIR lives in paths.py so the launcher test can point every init path into a temp folder through one module"
  - "The init step type is the self-check's own Check and CheckResult, shared and not copied"

patterns-established:
  - "Launcher test copies the image layout (lib/sbx-init next to lib/sbx-selfcheck) into tmp_path and appends path overrides to the copied paths.py"
  - "Lock test uses a real second process holding the flock"

requirements-completed: [INIT-01, INIT-02]

coverage:
  - id: D1
    description: "sbx-init runs the shared and agent steps in file-name order, prints OK or FAIL lines, stops at the first FAIL and writes the marker only when every step passed"
    requirement: INIT-01
    verification:
      - kind: unit
        ref: "tests/selftest/init/test_init_runner.py"
        status: pass
      - kind: integration
        ref: "tests/selftest/init/test_init_launcher.py"
        status: pass
    human_judgment: false
  - id: D2
    description: "A rerun redoes every step with the same lines, and a run blocked by another process holding the flock changes nothing"
    requirement: INIT-02
    verification:
      - kind: unit
        ref: "tests/selftest/init/test_init_runner.py#test_a_run_started_while_another_process_holds_the_lock_changes_nothing"
        status: pass
    human_judgment: false
  - id: D3
    description: "The state-folders step makes the base and SBX_STATE_DIRS folders, refuses absolute and '..' names, and the self-check twin reads the same base list and points at sbx-init"
    requirement: INIT-01
    verification:
      - kind: unit
        ref: "tests/selftest/init/test_init_state_folders.py"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-11-16
status: complete
---

# Phase 9 Plan 01: sbx-init runner and state folders step Summary

**sbx-init: a `python3 -I` launcher and runner that merges shared and agent step files by file name, takes a flock run lock, prints OK or FAIL per step, writes the init marker, and makes the state folders the entrypoint used to make.**

## Performance

- **Duration:** about 25 min
- **Started:** 2026-11-16T16:25:00Z (approx.)
- **Completed:** 2026-11-16T16:50:00Z
- **Tasks:** 3
- **Files modified:** 13 (7 created, 6 modified)

## Accomplishments

- `base/init/sbx-init` mirrors `sbx-selfcheck` (shebang `#!/usr/bin/python3 -I`, mode 100755 in git) and puts its own folder, the sibling `sbx-selfcheck` folder and its `agents` folder on `sys.path`.
- `base/init/init_runner.py` provides `SHARED_STEPS_DIR`, `load_step_module`, `collect_steps`, `run_init` and `main`. Order inside a run: lock, remove marker, steps, write marker, closing line. Stops at the first FAIL with `sbx-init: stopped at NAME`.
- `base/init/steps/010_state_folders.py` makes `shell`, `gh`, `git` plus `SBX_STATE_DIRS`, keeps existing folders, lists a repeated name once, and refuses absolute or `..` names before making anything.
- `paths.py` gains `BASE_STATE_DIR_LIST`, `AGENT_STEPS_DIR`, `INIT_MARKER_FILE`, `INIT_LOCK_FILE`, `AGENT_BIN_DIR`; `hints.init_hint()` added; the self-check's state-folders check reads the shared list and its fix line is now `init_hint()`.
- `tests/selftest/init/` (34 tests) runs on real files in `tmp_path`, with a real second process holding the flock. Selfcheck suite still passes (272 tests); total 306; `bash tests/guard/run-all.sh` ends with `All rules hold.`

## Task Commits

1. **Task 1: launcher, runner, state folders step (tracer)** - `9f6381d` (feat)
2. **Task 2: lock, marker, order, stop rule, load failures, rerun** - `85d3af3` (test)
3. **Task 3: hostile names, init_hint, self-check twin** - `6ad9267` (feat)

## Decisions Made

- Tuples `(file name, group, path)` sort naturally, so `collect_steps` needs no key function; ties between two agent folders fall back to the path, which keeps the order deterministic.
- When no agent step file exists, `collect_steps` returns only the `load-agent-steps` failure, so no shared step runs and no marker is written.
- A lock file that cannot be opened is a FAIL named `lock` with the `/home/sandbox is writable` hint plus the rebuild hint (the plan named the error and the rebuild hint; the extra hint text mirrors the marker failure).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `init_helpers.py` created in Task 1 as a minimal file**
- **Found during:** Task 1
- **Issue:** the launcher test needs `REPO_DIR`, which the plan puts in `init_helpers.py`, a Task 2 file.
- **Fix:** Task 1 created `init_helpers.py` with `REPO_DIR` only; Task 2 extended it with the other helpers.
- **Files modified:** tests/selftest/init/init_helpers.py
- **Commit:** 9f6381d, 85d3af3

**2. [Rule 3 - Blocking] State folder tests do not use the selfcheck `restorable_mode` fixture or `helpers`**
- **Found during:** Task 3
- **Issue:** the init test folder has no conftest (by plan) and `helpers` is only importable when the selfcheck test folder is collected, so the init folder would break when run alone.
- **Fix:** the read-only case restores the mode in a `finally`, and the self-check module is loaded through `init_helpers.load_step`.
- **Files modified:** tests/selftest/init/test_init_state_folders.py
- **Commit:** 6ad9267

### TDD note

Task 2 is marked `tdd="true"` and its tests passed on first run: the Task 1 runner already implemented the lock, marker, order and load-failure behavior in full (the plan itself said "expected gaps: none"), so there was no RED phase to commit. The tests were written against the behavior list and checked line by line; no implementation change was needed.

## Known Stubs

None.

## Threat Flags

None. T-09-01 (hostile names) and T-09-02 (flock) are implemented and tested.

## Issues Encountered

None. `git update-index --chmod=+x` only works after `git add`; the mode 100755 was set in that order.

## User Setup Required

None. Host-side checks on the real image (lock case, H-35) come in plan 09-11; Docker is not available in the dev sandbox.

## Next Phase Readiness

Plans 09-02 onward can add step files to `base/init/steps/` and `claude/init`, `cursor/init`, and rely on the `STEP_LIST` contract, the marker `paths.INIT_MARKER_FILE` and the exit codes 0, 1 and 2. The Dockerfile install block that places `base/init/` at `/usr/local/lib/sbx-init/` is not part of this plan.

## Self-Check: PASSED

- FOUND: base/init/sbx-init, base/init/init_runner.py, base/init/steps/010_state_folders.py, tests/selftest/init/{init_helpers,test_init_launcher,test_init_runner,test_init_state_folders}.py
- FOUND commits: 9f6381d, 85d3af3, 6ad9267
