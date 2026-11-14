---
phase: 08-in-image-self-check
plan: 09
subsystem: testing
tags: [selfcheck, tool-checks, h34, owner-fix, host-test]
status: complete

requires:
  - phase: 08-08
    provides: owner_fix_hint, the Mac owner fix under the no-root-owned-state FAIL
provides:
  - tool-bash and tool-keytool lines that fail when a copy under /home shadows the image's
  - counts 41 shared, 53 Claude and 51 Cursor agreed across pytest, H-34 and the README
  - an H-34 doctor round trip of the Mac owner fix on real Docker
affects: [08-10, 08-11, phase-08 verification]

actuals:
  tokens: 4300
  tasks: 2
  commits: 4
plan_head_before: 1bb4994fcbe4814a9a7015bf723fb5bf45e7185a
plan_head_after: 4b96908d141330d311545734e5f50494dd4e1f24

tech-stack:
  added: []
  patterns:
    - "A host check that needs root runs a throwaway --rm --network none container of the test base image with --volumes-from the test sandbox, so it reaches only the run folder"
    - "A host check greps fixed fragments out of self-check output and runs its own copy of the command; it never evaluates output text"

key-files:
  created: []
  modified:
    - base/selfcheck/shared_checks.py
    - tests/selftest/selfcheck/test_sandbox_checks.py
    - tests/selftest/selfcheck/test_tool_checks.py
    - tests/selftest/selfcheck/test_inventory.py
    - tests/host/h34-selfcheck.sh
    - tests/host-checklist.md
    - README.md

key-decisions:
  - "tool-bash and tool-keytool use tool_result with no version argument: the versions-line checks already prove what bash prints and tool-java proves the JDK version"
  - "H-34 does not assert the image tag in the fix line, because host checks never spell out the tag your sandboxes run (the guard rule host_tests_never_name_the_local_tag)"

requirements-completed: []

coverage:
  - id: D1
    description: "tool-bash and tool-keytool resolve to the image outside /home, each with its own check line in the final order"
    requirement: CHECK-02
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_tool_checks.py#test_tool_bash_resolves_to_the_image_outside_the_home"
        status: pass
      - kind: unit
        ref: "tests/selftest/selfcheck/test_tool_checks.py#test_tool_keytool_resolves_to_the_jdk_outside_the_home"
        status: pass
      - kind: unit
        ref: "tests/selftest/selfcheck/test_sandbox_checks.py#test_the_shared_list_holds_the_checks_in_the_final_order"
        status: pass
    human_judgment: false
  - id: D2
    description: "the shared, Claude and Cursor counts (41, 53, 51) agree in pytest, H-34 and the README"
    requirement: CHECK-01
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_inventory.py#test_the_shared_list_plus_each_agent_list_equals_the_count_h34_expects"
        status: pass
    human_judgment: false
  - id: D3
    description: "H-34 plants a root-owned folder, sees the FAIL with the Mac owner fix, runs it and sees the check pass"
    requirement: CHECK-04
    human_judgment: true
    rationale: "Needs real Docker; bash -n, shellcheck through the guard and a fixture run of the fix-line check pass here, and plan 08-11 runs H-34 on the Mac"
---

# Phase 8 Plan 09: tool-bash, tool-keytool and the H-34 owner fix round trip Summary

Every tool the self-check runs by name is now guarded against a copy under /home, and H-34 proves the Mac owner fix on real Docker (plant, FAIL with the fix, run it, pass, remove) instead of only as printed text.

## Accomplishments

- `check_tool_bash` and `check_tool_keytool` in `base/selfcheck/shared_checks.py`, each `tool_result(...)` with no version argument. The list has `tool-bash` right after `tool-git` and `tool-keytool` right after `tool-java` (review WR-04, threat T-08-30). Shared list 41, Claude 53, Cursor 51.
- Inventory test renamed to `test_the_lists_hold_the_declared_check_counts` (IN-07); the blank line before the loop added (IN-02). README sample reads `sbx-selfcheck: 53 checks, 1 failed`.
- H-34 (`tests/host/h34-selfcheck.sh`) gains `root_run`, `check_owner_fix_line`, `check_owner_fix` and `remove_planted_folder`, called between the Claude and Cursor runs:
  - `root_run` is a throwaway `docker run --rm --network none -u root --entrypoint ... --volumes-from sbx-hosttest <test base image>`; it reaches only the run folder.
  - `check_owner_fix` plants a mode 700 `state/h34-root-owned`, expects exit 1 and `FAIL: no-root-owned-state` naming it, expects the fix line to hold the `on the Mac run: ... --entrypoint chown --volumes-from sbx-hosttest sbx-base:` and ` -R 1000:1000 /home/sandbox/workspace/state` fragments, runs its own `chown -R 1000:1000` with the test base image, then expects no `no-root-owned-state` FAIL.
  - It prints `INFO: H-34 owner fix, before: ...`, `INFO: H-34 owner fix line: ...` and `INFO: H-34 owner fix, after: ...`, so `host-test.log` shows the round trip.
  - `remove_planted_folder` always runs, and records the hand `rm -rf` command when the folder is still there from the Mac side.
  - The script never evals or runs text from the self-check output (grep confirms no `eval`).
- `tests/host-checklist.md`: the H-34 row describes the round trip; the failure note names `h34-owner-fix-before.out`, `h34-owner-fix-after.out`, the `h34-plant`, `h34-chown` and `h34-cleanup` logs, and says to delete `state/h34-root-owned` if left over.

## Task Commits

| Task | Commit | Type | What |
|---|---|---|---|
| 1 RED | 6fe06ee | test | final order, tool list, two direct tool tests, counts 41 and 53 and 51, IN-07 and IN-02 |
| 1 GREEN | 0ca3e69 | fix | `check_tool_bash`, `check_tool_keytool` and their list entries |
| 2 | 78f9fb0 | test | H-34 owner fix round trip |
| 2 docs | 4b96908 | docs | H-34 checklist row and failure note, README sample count |

## RED Evidence (failed against the old code)

Task 1: 7 failed, 182 passed.

```text
E  AttributeError: module 'shared_checks' has no attribute 'check_tool_keytool'
FAILED test_inventory.py::test_the_lists_hold_the_declared_check_counts
FAILED test_inventory.py::test_the_shared_list_plus_each_agent_list_equals_the_count_h34_expects
FAILED test_inventory.py::test_collect_checks_loads_both_agent_files_without_a_load_failure
FAILED test_sandbox_checks.py::test_the_shared_list_holds_the_checks_in_the_final_order
FAILED test_tool_checks.py::test_every_tool_line_has_a_check_of_its_own
FAILED test_tool_checks.py::test_tool_bash_resolves_to_the_image_outside_the_home
FAILED test_tool_checks.py::test_tool_keytool_resolves_to_the_jdk_outside_the_home
```

After GREEN: 189 passed.

## Verification

- `uv run pytest tests/selftest/selfcheck -q` and `tests/selftest`: 189 passed.
- List sizes print `41 12 10`; H-34 holds `expectedClaudeCount=53` and `expectedCursorCount=51`; the name order has `tool-git tool-bash tool-gh` and `tool-java tool-keytool tool-maven`.
- `bash -n tests/host/h34-selfcheck.sh`: ok. `bash tests/guard/run-all.sh`: 19 PASS lines, "All rules hold." (shellcheck and the local-tag rule included).
- Main block order: `check_claude_sandbox`, `check_owner_fix`, `remove_planted_folder`, `check_cursor_sandbox`.
- `check_owner_fix_line` run against a fixture output: no problem for the correct fix line, one problem naming the line when `-R 1000` is changed to `-R 999`.
- `grep -c 'test_the_lists_hold_39'` prints 0; no `eval` in H-34.
- Not run here: H-34 itself (needs Docker); plan 08-11 runs it on the Mac.

## Deviations from Plan

None - plan executed exactly as written.

## Threat Surface

T-08-30 to T-08-33 mitigations are in place: tool-bash and tool-keytool fail a shadowing copy by name; each root container is `--rm --network none` on the test base image with only the test sandbox mount; no output text reaches a shell; the planted folder is always removed and checked from the Mac side. No new threat flags.

## Known Stubs

None.

## Issues Encountered

None. The root round trip is unproven on real Docker until the Mac run in plan 08-11, so the CHECK requirements stay open for that plan.

## Next

Ready for 08-10.

## Self-Check: PASSED

- Files modified exist: `base/selfcheck/shared_checks.py`, the three selfcheck test files, `tests/host/h34-selfcheck.sh`, `tests/host-checklist.md`, `README.md`.
- Commits found in `git log`: 6fe06ee, 0ca3e69, 78f9fb0, 4b96908.
- Acceptance criteria re-run: all pass (see Verification).
