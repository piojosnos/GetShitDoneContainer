---
phase: 08-in-image-self-check
plan: 12
subsystem: testing
tags: [selfcheck, doctor, state-walk, check-list, gap-closure]
status: complete

requires:
  - phase: 08-11
    provides: the Mac run that passed, and the fresh review whose two warnings this closes
provides:
  - a state folder that lists but cannot be searched is named "(unreadable)" with the Mac owner fix
  - a malformed CHECK_LIST is that file's own load FAIL, never a traceback
  - the review ledger with both warnings fixed and the five info findings deferred to Phase 10
affects: [phase-08 verification, phase-10 host check rewrite]

actuals:
  tokens: 3300
  tasks: 3
  commits: 5
plan_head_before: 62d688038d01d37e9bc081ef48416de4c153c815
plan_head_after: 05ee23ec8d92ec7b40a370e1e1482a78e1162324

tech-stack:
  added: []
  patterns:
    - "One helper names an unreadable folder at every failure point of the state walk"
    - "A trusted attribute of an imported file is shape checked before use, and a bad shape is that file's load failure"

key-files:
  created:
    - .planning/todos/pending/2026-11-14-selfcheck-review-follow-ups.md
  modified:
    - base/selfcheck/shared_checks.py
    - base/selfcheck/sbx_selfcheck.py
    - tests/selftest/selfcheck/test_sandbox_checks.py
    - tests/selftest/selfcheck/test_runner.py
    - .planning/phases/08-in-image-self-check/08-REVIEW-DISPOSITION.md

key-decisions:
  - "A folder that lists but cannot be searched is reported as the folder, once, with the same (unreadable) name and owner fix as a folder that cannot be listed"
  - "CHECK_LIST must be a list of Check; any other shape is one load failure for the whole file and none of its checks run"

requirements-completed: [CHECK-01, CHECK-04]

coverage:
  - id: D1
    description: "a mode 444 state folder is named in the no-root-owned-state FAIL with the Mac owner fix and no raised line"
    requirement: CHECK-04
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_sandbox_checks.py#test_root_owned_state_prints_the_owner_fix_for_a_folder_it_cannot_search"
        status: pass
    human_judgment: false
  - id: D2
    description: "an unreadable folder inside a tolerated sync folder stays tolerated at the entry stat"
    requirement: CHECK-04
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_sandbox_checks.py#test_scan_owned_state_tolerates_a_folder_it_cannot_search_in_a_sync_folder"
        status: pass
    human_judgment: false
  - id: D3
    description: "a CHECK_LIST of None, a number, a text, a list of texts or a list mixing a check with a text is one load FAIL and the run prints every other line"
    requirement: CHECK-01
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_runner.py#test_an_agent_file_with_a_malformed_check_list_is_one_load_failure"
        status: pass
    human_judgment: false
  - id: D4
    description: "the review ledger shows WR-01 and WR-02 fixed with their commits, IN-01 to IN-05 deferred to Phase 10, none open, and one pending todo"
    verification:
      - kind: command
        ref: "Task 3 ledger check"
        status: pass
    human_judgment: false
---

# Phase 8 Plan 12: Review warning fixes and deferred follow-ups Summary

The self-check no longer crashes on a root-owned state folder of mode 444 or on a checks file with a malformed CHECK_LIST; both give a named FAIL with a fix that works, and the five review info findings are filed for Phase 10.

## Accomplishments

- `mark_unreadable_folder` in `base/selfcheck/shared_checks.py` holds the inline block the listing branch had (skip when tolerated, replace the bare entry, append `(unreadable)`). `scan_owned_state` calls it from the listing failure and from a new `OSError` clause on the entry stat. The entry loop breaks at the first stat failure, so the folder is named once however many entries it holds. The FAIL detail, owner fix text and `UNREADABLE_SUFFIX` did not change.
- `is_check_list` in `base/selfcheck/sbx_selfcheck.py` accepts a list of `Check` only (imperative loop, early return). `module_check_list` returns the file's `load-NAME` failure with the rebuild fix when the shape is wrong; an empty list still passes the shape check and reaches the `load-agent-checks` failure in `collect_checks`.
- The review ledger shows WR-01 and WR-02 fixed with their RED and fix hashes, IN-01 to IN-05 deferred with a Phase 10 reason, `open: 0`. One todo, `.planning/todos/pending/2026-11-14-selfcheck-review-follow-ups.md`, describes IN-01 to IN-05.

## Task Commits

| Task | Commit | Type | What |
|---|---|---|---|
| 1 RED | 6c1e974 | test | mode 444 walk case, tolerated sync folder case, end to end FAIL plus owner fix lines |
| 1 GREEN | 8fe8562 | fix | `mark_unreadable_folder` and the entry stat `OSError` clause |
| 2 RED | 72e8daf | test | five malformed CHECK_LIST shapes |
| 2 GREEN | 5d4ef02 | fix | `is_check_list` and the validated `module_check_list` |
| 3 | 05ee23e | docs | ledger dispositions and the follow-up todo |

Tracer gate (Task 1, auto mode style): the verify commands were re-run after the fix commit (61 passed in the file, 3 passed for the new filter, 193 in the suite, three `mark_unreadable_folder(` hits); logged "Tracer verified end-to-end, expanding".

## RED Evidence (failed against the old code)

Task 1, `-k 'list_but_not_search or cannot_search'`: 3 failed, 58 deselected.

```text
E  PermissionError: [Errno 13] Permission denied: '.../test_scan_owned_state_marks_a_0/state1/sub1/private1/file2'
E  PermissionError: [Errno 13] Permission denied: '.../test_scan_owned_state_tolerate0/state1/sub1/gsd-core/file1'
E  - FAIL: no-root-owned-state: 2 paths under state/ are owned by uid 1000 or unreadable: sub1, sub1/private1 (unreadable)
E  + FAIL: no-root-owned-state: raised PermissionError: [Errno 13] Permission denied: '.../state1/sub1/private1/file2'
FAILED test_scan_owned_state_marks_a_folder_it_can_list_but_not_search
FAILED test_scan_owned_state_tolerates_a_folder_it_cannot_search_in_a_sync_folder
FAILED test_root_owned_state_prints_the_owner_fix_for_a_folder_it_cannot_search
```

Task 2, `-k malformed_check_list`: 5 failed, 22 deselected.

```text
E  TypeError: 'NoneType' object is not iterable          [none]
E  TypeError: 'int' object is not iterable               [number]
E  AttributeError: 'str' object has no attribute 'name'  [text, list_of_text, list_with_a_text_item]
FAILED ...malformed_check_list_is_one_load_failure[none]
FAILED ...[number]
FAILED ...[text]
FAILED ...[list_of_text]
FAILED ...[list_with_a_text_item]
```

Each RED commit is older than its fix commit (6c1e974 before 8fe8562, 72e8daf before 5d4ef02).

## Verification (dev sandbox, uid 1000, so the mode 444 tests ran)

- `uv run pytest tests/selftest -q`: 190 passed at baseline, 193 after Task 1, 198 after Task 2 and at the end.
- `bash tests/guard/run-all.sh`: last line `All rules hold.`, 19 PASS lines.
- Check list sizes: `41 12 10`; `tests/host/h34-selfcheck.sh` still holds `expectedClaudeCount=53` and `expectedCursorCount=51`.
- Changed code paths since f4966de: `base/selfcheck/sbx_selfcheck.py`, `base/selfcheck/shared_checks.py`, `tests/selftest/selfcheck/test_runner.py`, `tests/selftest/selfcheck/test_sandbox_checks.py`. No mode change. README files, `tests/host`, `claude`, `cursor`, `compose.yml`, build and run scripts and `base/Dockerfile` untouched.
- No commit since f4966de mixes `.planning/` files with code.
- Sweeps: non-ASCII and ID sweep over added code lines, dash sweep over the two planning files, comprehension sweep and blank-line-before-control-flow sweep all printed nothing.
- `CHECK_LIST = None` one-liner: exit status 1, `FAIL: load-agent1: <path>/agent1.py defines a CHECK_LIST that is not a list of checks`, rebuild fix line, `sbx-selfcheck: 1 checks, 1 failed`.
- Ledger check: no `open` row, `open: 0`, two fixed rows with two hashes, five deferred rows with a Phase 10 reason, todo with `resolves_phase: 10` and items (a) to (e).

## Deviations from Plan

None. The plan was executed as written. The working tree was at `62d6880` (the commit that added this plan and the roadmap entry) rather than `f4966de`; all diffs were still measured against `f4966de` as the plan states, and `plan_head_before` is `62d6880`.

## Known Stubs

None.

## Threat Surface

T-08-40 and T-08-41 mitigations are in place: the walk names the folder through `mark_unreadable_folder` and still only lists folders (`test_state_walk_never_opens_a_file` passes), and `is_check_list` turns a bad shape into the file's load failure. No new threat flags. No package was installed.

## Issues Encountered

None. No Mac checkpoint: the changes are covered by pytest, and the next `./host-test.sh` run picks the code up through the image build.

## Next

Phase 8 gap closure is complete; ready for re-verification. IN-01 to IN-05 wait in the pending todo for Phase 10.

## Self-Check: PASSED

- Files exist: `base/selfcheck/shared_checks.py`, `base/selfcheck/sbx_selfcheck.py`, `tests/selftest/selfcheck/test_sandbox_checks.py`, `tests/selftest/selfcheck/test_runner.py`, `.planning/phases/08-in-image-self-check/08-REVIEW-DISPOSITION.md`, `.planning/todos/pending/2026-11-14-selfcheck-review-follow-ups.md`.
- Commits found in `git log`: 6c1e974, 8fe8562, 72e8daf, 5d4ef02, 05ee23e.
- Acceptance criteria of Tasks 1 to 3 re-run: all pass.
