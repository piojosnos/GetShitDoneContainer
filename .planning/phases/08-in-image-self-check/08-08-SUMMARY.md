---
phase: 08-in-image-self-check
plan: 08
subsystem: testing
tags: [selfcheck, doctor, owner-fix, state-walk, runner]
status: complete

requires:
  - phase: 08-07
    provides: the verified self-check with the CHECK-04 gap found
provides:
  - a Mac owner fix hint for the no-root-owned-state FAIL (throwaway root container)
  - an OSError tolerant state walk that names unreadable folders
  - a runner level load-agent-checks FAIL when no agent check ran
affects: [08-09, 08-10, 08-11, phase-08 verification]

actuals:
  tokens: 5200
  tasks: 3
  commits: 7
plan_head_before: 49abb773de1eadd8d61a9b3a755b841f6e63b0c4
plan_head_after: e0e6d6125682efdc5ead9e19c06ebe7786891542

tech-stack:
  added: []
  patterns:
    - "A FAIL whose fix needs root runs a throwaway root container on the Mac with --volumes-from the sandbox, so the hint needs no Mac path"
    - "A walk that must report instead of crash catches FileNotFoundError (skip) and OSError (record the folder as unreadable)"

key-files:
  created: []
  modified:
    - base/selfcheck/shared_checks.py
    - base/selfcheck/sbx_selfcheck.py
    - tests/selftest/selfcheck/test_sandbox_checks.py
    - tests/selftest/selfcheck/test_runner.py
    - README.md
    - tests/README.md

key-decisions:
  - "The owner fix is docker run --rm --network none -u root --entrypoint chown --volumes-from sbx-NAME sbx-base:local -R 1000:1000 STATE, built by owner_fix_hint from constants and the scanned folder"
  - "load-agent-checks is added by collect_checks, not by CHECK_LIST, so the shared list and the H-34 counts (51 and 49) do not change"

patterns-established:
  - "RED tests are committed alone before the fix; each fix commit follows its test commit"

requirements-completed: []

coverage:
  - id: D1
    description: "the no-root-owned-state FAIL prints the Mac owner fix under its FAIL line"
    requirement: CHECK-04
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_sandbox_checks.py#test_root_owned_state_prints_the_mac_owner_fix_under_its_fail_line"
        status: pass
    human_judgment: false
  - id: D2
    description: "a folder the walk cannot open is named with (unreadable); sync folders stay tolerated; a missing state folder adds nothing"
    requirement: CHECK-04
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_sandbox_checks.py#test_root_owned_state_names_an_unreadable_folder_with_the_mac_fix"
        status: pass
    human_judgment: false
  - id: D3
    description: "an empty, missing or empty-list agent folder fails by name with the rebuild fix; a broken file prints only its load failure"
    requirement: CHECK-01
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_runner.py#test_empty_and_missing_agent_folders_fail_naming_the_folder"
        status: pass
    human_judgment: false
  - id: D4
    description: "the owner fix command works on real Docker"
    requirement: CHECK-04
    human_judgment: true
    rationale: "Docker is not available in the dev sandbox; plan 08-09 proves it in H-34 and plan 08-11 runs it on the Mac"
---

# Phase 8 Plan 08: Owner fix, unreadable folders and a missing agent checks file Summary

The no-root-owned-state FAIL now gives a Mac command that works on any engine, names a folder it cannot open instead of crashing, and the runner no longer reports green when the image's agent checks never ran.

## Accomplishments

- `owner_fix_hint` (and `OWNER_FIX_IMAGE`) in `base/selfcheck/shared_checks.py` prints: give the paths back to the sandbox user from a throwaway root container, since the sandbox cannot change owners: on the Mac run `docker run --rm --network none -u root --entrypoint chown --volumes-from sbx-NAME sbx-base:local -R 1000:1000 STATE`. `NAME` comes from `SBX_NAME`, `STATE` is the scanned folder. The old sandbox-side chown hint is gone.
- `scan_owned_state` skips a vanished folder and records any other `OSError` as `<path> (unreadable)` (`UNREADABLE_SUFFIX`), replacing the bare entry when the folder was already reported. An unreadable folder inside a tolerated GSD sync folder stays tolerated. The FAIL detail now reads "... owned by uid N or unreadable: ...", with no "raised PermissionError" crash line.
- `collect_checks` appends a `load-agent-checks` failure (rebuild fix) when the agent folder adds no check. A folder with one broken file still prints only that file's `load-<name>` failure. The shared list is unchanged, so H-34's 51 and 49 counts hold (a correct image prints no `load-agent-checks` line).
- IN-01: the test-only `owned_by_uid_paths` wrapper is deleted and its tests call `scan_owned_state(...)[0]`. IN-02: two blank lines added (`run_selfcheck`, `test_every_line_is_pass_fail_fix_or_the_summary`).
- Docs: the troubleshooting row says a `load-...` line means a checks file is broken or missing; the pytest "Catches" row says "a broken or missing checks file".

## Task Commits

| Task | Commit | Type | What |
|---|---|---|---|
| 1 RED | f08abb6 | test | exact owner fix hint, unset `SBX_NAME`, and the end to end FAIL plus fix lines |
| 1 GREEN | 5af642d | fix | `owner_fix_hint`, `OWNER_FIX_IMAGE` |
| 2 RED | d4611e3 | test | five unreadable folder cases, wrapper call sites and names moved to `scan_owned_state` |
| 2 GREEN | a61259d | fix | OSError tolerant walk, `UNREADABLE_SUFFIX`, wrapper deleted |
| 3 RED | 888e12e | test | agent folder cases, `agents1` fixture, IN-02 blank line |
| 3 GREEN | a543cb7 | fix | `AGENT_CHECKS_CHECK_NAME`, runner level failure, IN-02 blank line |
| 3 docs | e0e6d61 | docs | README troubleshooting row, tests/README Catches row |

Tracer gate: after Task 1 the verify commands were re-run (4 passed, hint one-liner exact, old text gone); logged "Tracer verified end-to-end, expanding".

## RED Evidence (failed against the old code)

Task 1 (`-k root_owned_state`): 3 failed, 1 passed.

```text
E  AssertionError: assert '--volumes-from sbx-NAME sbx-base:local -R 1000:1000' in 'give them back to the sandbox user: in this sandbox run: chown -R sandbox:sandbox /home/sandbox/workspace/state'
E  AssertionError: assert '      fix: g...rkspace/state' == '      fix: g...nts_t0/state1'
FAILED test_root_owned_state_fails_with_the_total_and_at_most_ten_paths
FAILED test_root_owned_state_hint_says_name_when_sbx_name_is_unset
FAILED test_root_owned_state_prints_the_mac_owner_fix_under_its_fail_line
```

Task 2 (whole file): 5 failed, 53 passed.

```text
E  PermissionError: [Errno 13] Permission denied: '.../state1/sub1/private1'    (three scan tests and the result test)
E  FileNotFoundError: [Errno 2] No such file or directory: '.../state1'          (missing state folder)
FAILED test_scan_owned_state_marks_a_reported_folder_it_cannot_open
FAILED test_scan_owned_state_reports_an_unreadable_folder_of_another_owner
FAILED test_scan_owned_state_tolerates_an_unreadable_folder_in_a_sync_folder
FAILED test_scan_owned_state_finds_nothing_in_a_missing_state_folder
FAILED test_root_owned_state_names_an_unreadable_folder_with_the_mac_fix
```

Task 3 (`test_runner.py`): 2 failed, 20 passed (the agents1-based tests already passed because the old runner printed the agent lines the same way).

```text
E  assert 0 == 1    (empty and missing agent folders exit 0 with shared lines only)
E  assert 0 == 1    (an agent file with CHECK_LIST = [] exits 0)
FAILED test_empty_and_missing_agent_folders_fail_naming_the_folder
FAILED test_an_agent_file_with_an_empty_check_list_is_no_agent_checks
```

`test_a_broken_agent_file_alone_is_one_load_failure` is a guard against over-triggering and passed before and after, as intended.

## Verification

- `uv run pytest tests/selftest/selfcheck -q`: 187 passed (178 before this plan; 9 net new).
- `owner_fix_hint` one-liner prints exactly the pinned hint; no `in this sandbox run: chown` text remains in source or tests.
- Missing agent folder one-liner: exit 1 and the exact `load-agent-checks` line.
- `grep -rn owned_by_uid_paths base tests` prints nothing; `grep -c load-agent-checks base/selfcheck/shared_checks.py` prints 0.
- `bash tests/guard/run-all.sh`: "All rules hold."
- The suite ran as uid 1000, so the mode 000 tests ran (no skips).

## Deviations from Plan

None. The plan was executed as written. Notes:

- Test count for the RED run of Task 3 is 2 failing tests, not every changed test; the other changed tests only repoint the agent folder and already passed against the old runner.
- A state folder that is itself unreadable is recorded as `. (unreadable)` (relative path of the root); this edge was not in the plan and is accepted as it still names the problem.

## Threat Surface

T-08-26 to T-08-29 mitigations are in place: the printed command is fixed text from constants plus the scanned path, the walk records `(unreadable)` instead of crashing and still never opens a file, and the runner exits 1 with the folder named when no agent check ran. No new threat flags.

## Known Stubs

None.

## Issues Encountered

None. Requirements are left for plan 08-11, which marks CHECK-01 to CHECK-04 complete after the Mac gate (the verification report asks that CHECK-04 not read complete until the gap closes on real Docker).

## Next

Ready for 08-09 (WR-04 `tool-bash` and `tool-keytool`, H-34 owner fix round trip on real Docker).

## Self-Check: PASSED

- Files modified exist: `base/selfcheck/shared_checks.py`, `base/selfcheck/sbx_selfcheck.py`, `tests/selftest/selfcheck/test_sandbox_checks.py`, `tests/selftest/selfcheck/test_runner.py`, `README.md`, `tests/README.md`.
- Commits found in `git log`: f08abb6, 5af642d, d4611e3, a61259d, 888e12e, a543cb7, e0e6d61.
- Acceptance criteria re-run: all pass (see Verification).
