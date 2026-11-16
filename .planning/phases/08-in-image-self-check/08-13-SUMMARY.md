---
phase: 08-in-image-self-check
plan: 13
subsystem: testing
tags: [selfcheck, doctor, runner, state-walk, gap-closure]
status: complete

requires:
  - phase: 08-12
    provides: the malformed CHECK_LIST guard and mark_unreadable_folder that this plan builds on
provides:
  - a check that returns something other than a CheckResult is that check's own FAIL with the rebuild fix
  - an entry stat error other than permission surfaces as the runner's named raised FAIL instead of marking the folder unreadable
  - the review ledger with WR-03 and IN-09 fixed, none open
affects: [phase-08 verification, phase-10 host check rewrite]

actuals:
  tokens: 2000
  tasks: 3
  commits: 5
plan_head_before: 64ddff972b82fa0084e60eea1479272ca781a5c5
plan_head_after: f579d30cc6bcaa66acc54d2cac873385e2bcb180

tech-stack:
  added: []
  patterns:
    - "run_check turns every way a check fails to produce a result (an exception, a wrong return type) into that check's FAIL line"
    - "Only a PermissionError at an entry stat names the folder unreadable; any other entry error propagates to the runner"

key-files:
  created: []
  modified:
    - base/selfcheck/sbx_selfcheck.py
    - base/selfcheck/shared_checks.py
    - tests/selftest/selfcheck/test_runner.py
    - tests/selftest/selfcheck/test_sandbox_checks.py
    - .planning/phases/08-in-image-self-check/08-REVIEW-DISPOSITION.md

key-decisions:
  - "run_check validates the returned value with isinstance, so run_selfcheck, outcome_lines and collect_checks stay untouched"
  - "The entry stat handler is narrowed to PermissionError with the break kept; the listing handler stays OSError because a failed listing is a whole-folder fact"
  - "The folder's relative path is computed once, right after the folder is popped"

requirements-completed: [CHECK-01, CHECK-04]

coverage:
  - id: D1
    description: "a check returning None, a bool or a tuple is one FAIL line 'returned <Type> instead of a CheckResult' with the rebuild fix, the other lines and the summary still print, exit status 1"
    requirement: CHECK-01
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_runner.py#test_a_check_that_returns_no_result_becomes_a_fail_line_with_the_rebuild_hint"
        status: pass
    human_judgment: false
  - id: D2
    description: "an entry stat error other than permission raises out of scan_owned_state instead of naming the folder unreadable"
    requirement: CHECK-04
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_sandbox_checks.py#test_scan_owned_state_lets_an_entry_error_other_than_permission_surface"
        status: pass
    human_judgment: false
  - id: D3
    description: "a mode 444 or mode 000 folder is still named once with the owner fix, and a tolerated sync folder stays tolerated"
    requirement: CHECK-04
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_sandbox_checks.py#test_root_owned_state_prints_the_owner_fix_for_a_folder_it_cannot_search"
        status: pass
    human_judgment: false
  - id: D4
    description: "the review ledger shows WR-03 and IN-09 fixed with their RED and fix hashes, none open"
    verification:
      - kind: command
        ref: "Task 3 ledger checks"
        status: pass
    human_judgment: false
---

# Phase 8 Plan 13: Last two review findings Summary

A check that returns the wrong thing now gets a named FAIL with the rebuild fix instead of crashing the run, and an entry stat error other than permission reaches the runner as a named FAIL instead of mislabeling the state folder.

## Accomplishments

- `run_check` in `base/selfcheck/sbx_selfcheck.py` keeps the check's result in a local, leaves the `raised ...` branch as it was, and returns early with `returned <type name> instead of a CheckResult` plus the same rebuild fix when the result is not a `CheckResult`. A forgotten `return` reads `NoneType`.
- `scan_owned_state` in `base/selfcheck/shared_checks.py` computes `relative_dir` once after popping the folder. The entry stat handler catches `PermissionError` only (with `FileNotFoundError` still first and the `break` kept), so a folder that cannot be searched is still named once, and any other error on an entry is raised to the runner and printed as that check's `raised ...` FAIL. The listing handler stays `OSError`.
- WR-03 and IN-09 are `fixed` in the review ledger with their RED and fix hashes; `open: 0`.

## Task Commits

| Task | Commit | Type | What |
|---|---|---|---|
| 1 RED | a63844b | test | three wrong return shapes (None, bool, tuple) through the runner output |
| 1 GREEN | 9cd424b | fix | `isinstance` result check in `run_check` |
| 2 RED | 41cad9a | test | entry stat `OSError(EIO)` through a stubbed listing |
| 2 GREEN | 4621eb0 | fix | `PermissionError` handler and the single `relative_dir` |
| 3 | f579d30 | docs | ledger rows and frontmatter for WR-03 and IN-09 |

Tracer gate (Task 1): the three verify commands were re-run after the fix commit (30 passed in the file, 3 passed for the new filter, 201 in the suite, the one-liner printed exit status 1 with the exact FAIL line, fix line and summary); logged "Tracer verified end-to-end, expanding".

## RED Evidence (failed against the old code)

Task 1, `-k returns_no_result`: 3 failed, 27 deselected.

```text
E  AttributeError: 'NoneType' object has no attribute 'passed'   [none]
E  AttributeError: 'bool' object has no attribute 'passed'       [bool]
E  AttributeError: 'tuple' object has no attribute 'passed'      [tuple]
```

Task 2, `-k other_than_permission`: 1 failed, 61 deselected.

```text
E  Failed: DID NOT RAISE OSError
FAILED test_scan_owned_state_lets_an_entry_error_other_than_permission_surface
```

Each RED commit is older than its fix commit (a63844b before 9cd424b, 41cad9a before 4621eb0).

## Verification (dev sandbox, uid 1000)

- `uv run pytest tests/selftest -q`: 198 passed at baseline, 201 after Task 1, 202 after Task 2 and at the end.
- `bash tests/guard/run-all.sh`: last line `All rules hold.`, 19 PASS lines.
- Check list sizes: `41 12 10`; `tests/host/h34-selfcheck.sh` still holds `expectedClaudeCount=53` and `expectedCursorCount=51`.
- Changed code paths since a1004a9: `base/selfcheck/sbx_selfcheck.py`, `base/selfcheck/shared_checks.py`, `tests/selftest/selfcheck/test_runner.py`, `tests/selftest/selfcheck/test_sandbox_checks.py`. No mode change. README files, `tests/host`, `claude`, `cursor`, `compose.yml`, build and run scripts and `base/Dockerfile` untouched.
- No commit since a1004a9 mixes `.planning/` files with code.
- Sweeps: non-ASCII and ID sweep over added code lines, dash sweep over the ledger, comprehension sweep and blank-line-before-control-flow sweep all printed nothing.
- Ledger checks: no `open` row, `open: 0`, WR-01 to WR-03 and IN-09 fixed with two hashes each, IN-01 to IN-05 deferred with their Phase 10 reason, all four recorded hashes resolve to commits.
- One-liner with `type(None)` as a check: exit status 1, `FAIL: check1: returned NoneType instead of a CheckResult`, the rebuild fix line, `sbx-selfcheck: 1 checks, 1 failed`.

## Deviations from Plan

None. The plan was executed as written. The working tree was at `64ddff9` (the commit that added this plan) rather than `a1004a9`; diffs were measured against `a1004a9` as the plan states, and `plan_head_before` is `64ddff9`.

## Known Stubs

None.

## Threat Surface

T-08-42 and T-08-43 mitigations are in place: `run_check` turns any non-`CheckResult` into that check's FAIL, and only a `PermissionError` names the folder, so a root-owned entry cannot go unexamined behind a partial report. No new threat flags. No package was installed.

## Issues Encountered

None. No Mac checkpoint: the changes are covered by pytest, and the next `./host-test.sh` run picks the code up through the image build.

## Next

Phase 8 has no open review finding; ready for re-verification. IN-01 to IN-05 wait in the pending todo for Phase 10.

## Self-Check: PASSED

- Files exist: `base/selfcheck/sbx_selfcheck.py`, `base/selfcheck/shared_checks.py`, `tests/selftest/selfcheck/test_runner.py`, `tests/selftest/selfcheck/test_sandbox_checks.py`, `.planning/phases/08-in-image-self-check/08-REVIEW-DISPOSITION.md`.
- Commits found in `git log`: a63844b, 9cd424b, 41cad9a, 4621eb0, f579d30.
- Acceptance criteria of Tasks 1 to 3 re-run: all pass.
