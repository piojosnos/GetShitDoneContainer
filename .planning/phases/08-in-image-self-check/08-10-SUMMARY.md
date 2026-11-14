---
phase: 08-in-image-self-check
plan: 10
subsystem: testing
tags: [selfcheck, naming, type-hints, review-info-findings, managed-settings]
status: complete

requires:
  - phase: 08-08
    provides: the final self-check sources and tests this plan cleans up
  - phase: 08-09
    provides: tool-bash and tool-keytool and the 41, 53 and 51 counts
provides:
  - managed_settings_result tells a missing file from a broken one, in the same words as the Cursor config check
  - shape suffixes on every collection name in the self-check sources, e for caught exceptions
  - typed load_check_module and sorted_text_list
  - a check_name_list_of conftest fixture and loops in place of every comprehension in the self-check tests
affects: [08-11, phase 9]

actuals:
  tokens: 6950
  tasks: 3
  commits: 4
plan_head_before: 9999a169a55a0f14a7c7d9adbb4c54d98470492a
plan_head_after: aab375d206ab08681603de41680e081c14267917

tech-stack:
  added: []
  patterns:
    - "A check that reads one file separates FileNotFoundError ('<path> is missing') from OSError and ValueError ('<path> is not valid JSON') in both agent files"
    - "check names in tests come from the check_name_list_of fixture, built with a for loop"

key-files:
  created: []
  modified:
    - claude/selfcheck/claude.py
    - cursor/selfcheck/cursor.py
    - base/selfcheck/sbx_selfcheck.py
    - base/selfcheck/shared_checks.py
    - tests/selftest/selfcheck/conftest.py
    - tests/selftest/selfcheck/test_agent_checks.py
    - tests/selftest/selfcheck/test_sandbox_checks.py
    - tests/selftest/selfcheck/test_tool_checks.py

key-decisions:
  - "The unreadable settings file test restores the mode in try/finally inside the test, because the restorable_mode fixture lives in test_sandbox_checks.py and moving it was outside this plan"
  - "tool_result's keyword is now environment_map, so every keyword caller (cursor.py and the tool tests) changed with it; positional callers did not"

requirements-completed: []

coverage:
  - id: D1
    description: "a missing managed settings file reads '<path> is missing' and bad or unreadable JSON reads '<path> is not valid JSON', both with the rebuild fix"
    requirement: CHECK-04
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_agent_checks.py#test_managed_settings_result_fails_for_text_that_is_not_json_and_for_a_missing_file"
        status: pass
      - kind: unit
        ref: "tests/selftest/selfcheck/test_agent_checks.py#test_managed_settings_result_reports_an_unreadable_file_as_not_valid_json"
        status: pass
    human_judgment: false
  - id: D2
    description: "collection names carry their shape suffix, caught exceptions are e, the two public signatures are typed, no comprehension or generator is left and no control-flow line lacks its blank line, with no behavior change"
    requirement: CHECK-01
    verification:
      - kind: command
        ref: "uv run pytest tests/selftest -q (190 passed, the same count as after Task 1)"
        status: pass
      - kind: command
        ref: "the rename, comprehension and blank-line sweeps of the plan print nothing"
        status: pass
    human_judgment: false
---

# Phase 8 Plan 10: Settings message fix, naming, hints and loops Summary

A missing managed settings file now reads "is missing" instead of a JSON parse complaint, and the self-check sources and tests follow the shape-suffix, `e`, type-hint, loop and blank-line rules with no other behavior change.

## Accomplishments

- IN-06: `managed_settings_result` in `claude/selfcheck/claude.py` catches `FileNotFoundError` first (`<path> is missing`), then `(OSError, ValueError)` (`<path> is not valid JSON`). Both keep the rebuild fix. The wording matches `self_update_result` in `cursor.py`, and the old "does not parse as JSON" text is gone from `claude` and `tests`. Only the path is printed, never the settings content (T-08-34).
- IN-04: every environment mapping parameter or local is `environment_map` (`sbx_selfcheck.py`, `shared_checks.py`, `cursor.py`); `cursor_environment` became `cursor_environment_map`; `mount_point_collection` became `mount_point_found_set`; `history_free` became `history_free_environment_map`; `settings_map`, `permissions_map` and `config_map`; both `except Exception as error` clauses are `as e`. The keyword calls of `tool_result` in `cursor.py` and `test_tool_checks.py` use `environment_map=`.
- IN-05: `load_check_module(module_path: Path) -> ModuleType` with `from types import ModuleType`, and `sorted_text_list(value: object) -> list[str] | None`.
- IN-03: new `check_name_list_of` fixture in `conftest.py`, used by the Claude and Cursor name tests, the final-order test and `test_every_tool_line_has_a_check_of_its_own`. The skill list text, the link-not-followed test and the history test use plain `for` loops.
- IN-02: the last missing blank line (before the `for result in [...]` loop of the Cursor self-update test) added; the helper `cursor_environment` in the tests uses `environment_map`.

## Task Commits

| Task | Commit | Type | What |
|---|---|---|---|
| 1 RED | 762cc3e | test | exact detail text for missing and bad JSON, plus the unreadable file test |
| 1 GREEN | 0b1d6c2 | fix | the missing-file branch and the symmetric JSON message |
| 2 | 8d8d56c | refactor | shape suffixes, `e`, `ModuleType`, `object` |
| 3 | aab375d | refactor | `check_name_list_of`, loops, last blank line |

## RED Evidence (failed against the old code)

Task 1: 2 failed, 30 passed in `test_agent_checks.py`.

```text
FAILED test_agent_checks.py::test_managed_settings_result_fails_for_text_that_is_not_json_and_for_a_missing_file
FAILED test_agent_checks.py::test_managed_settings_result_reports_an_unreadable_file_as_not_valid_json
E  AssertionError: assert '/tmp/pytest-...parse as JSON' == '/tmp/pytest-...ot valid JSON'
E    - ked1.json is not valid JSON
E    + ked1.json does not parse as JSON
```

After GREEN: 32 passed in the file, 190 passed in `tests/selftest` (189 before plus the one new test). Tasks 2 and 3 ended at 190 again, so no test was added or removed by them.

## Verification

- `uv run pytest tests/selftest/selfcheck -q` after each task: 190 passed (Task 1 GREEN: 32 in the file; the new test ran, since the sandbox user is not root).
- Message one-liner prints `/nonexistent/managed1.json is missing`; `grep -c 'is not valid JSON'` prints 1 for `claude.py` and 1 for `cursor.py`; `grep -rn 'does not parse as JSON' claude tests` prints nothing.
- Rename sweep (`environment`, `mount_point_collection`, `history_free`, `as error`, bare `settings`, `permissions`, `config`, and the `environment=` keyword): prints nothing.
- Both hint greps match. Comprehension sweep and blank-line sweep print nothing; `grep -c check_name_list_of` shows the fixture defined once and used in `test_agent_checks.py`, `test_sandbox_checks.py` and `test_tool_checks.py`.
- The lists still hold 41 shared checks (Claude 12 and Cursor 10 are asserted by `test_inventory.py`, which passed unchanged).

## Deviations from Plan

None - plan executed exactly as written.

## Threat Surface

T-08-34: the new `is missing` branch prints only the file path. T-08-35: the passed count after Tasks 2 and 3 equals the count after Task 1 (190), and the rename sweeps find no half-renamed name. No new threat flags.

## Known Stubs

None.

## Issues Encountered

None. The CHECK requirements stay open for plan 08-11, which runs H-34 on the Mac.

## Next

Ready for 08-11.

## Self-Check: PASSED

- Files modified exist: `claude/selfcheck/claude.py`, `cursor/selfcheck/cursor.py`, `base/selfcheck/sbx_selfcheck.py`, `base/selfcheck/shared_checks.py` and the four test files.
- Commits found in `git log`: 762cc3e, 0b1d6c2, 8d8d56c, aab375d (`git rev-list --count` from the plan base gives 4).
- Acceptance criteria re-run: all pass (see Verification).
