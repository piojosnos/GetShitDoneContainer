---
phase: quick-261118-0vx
plan: 01
subsystem: selfcheck-init
tags: [refactor, symmetry, tests, conventions]
requires: []
provides:
  - hints.state_writable_hint
  - check_result.make_state_folder, capped_list_text
  - paths.state_folder_name_list
  - bundle_links.clone_failure, linked_detail
affects: [sbx-init, sbx-selfcheck, cursor init steps, sbx-gh-login]
key-files:
  created: []
  modified:
    - base/selfcheck/hints.py
    - base/selfcheck/check_result.py
    - base/selfcheck/paths.py
    - base/selfcheck/bundle_links.py
    - base/selfcheck/step_files.py
    - base/selfcheck/runner.py
    - base/init/init_runner.py
    - base/init/steps/800_state_owner.py
    - base/bin/sbx-gh-login
key-decisions:
  - "The init wording wins for the missing-clone failure; the self-check now prints it"
  - "The state-writable fix line is the init text; the 030 check no longer names a restart"
status: complete
commits: 3
plan_head_before: 749c15114b090942537daa1fd3b48428996aa3df
plan_head_after: f75a7f587a908d064e20f58ab0f5c28c110bd727
actuals:
  tokens: 60000
  tasks: 3
  commits: 3
---

# Quick 261118-0vx: PR 52 best-practices review fixes Summary

One shared state-writable hint, folder maker, clone failure, linked detail, folder list and capped join, each used by both sbx-init and sbx-selfcheck, plus the shell, test and comment convention fixes from the review.

## Commits

| Task | Commit | Message |
| ---- | ------ | ------- |
| 1 | ce93fcd | refactor(selfcheck): share the state folder hint, folder maker and clone results between sbx-init and sbx-selfcheck |
| 2 | d57855e | test(init): inject the GSD sync into its step and drop source-text tests |
| 3 | f75a7f5 | chore: align parameter order, wrap long comments and tidy sbx-init |

## What changed

- Task 1 (tracer, red first): `state_writable_hint()` is the one text; the 030 fix line now points at sbx-init. `make_state_folder` replaces the three private folder makers (010 step, GSD sync, cursor 060). `clone_failure` and `linked_detail` serve `bundle_links_result` and `link_best_practices`, so the self-check no-clone detail and fix line are now the init wording. `state_folder_name_list` and `capped_list_text` replace the private copies in 010, 030 and 040.
- Task 2: the agent GSD steps take `sync_function` as a default parameter, so the test calls the step with a recording function and no attribute patching. `check_state_folders` in sbx-gh-login reports and returns 1; Main stops with `check_state_folders || exit 1`. Removed the timing assert, the wrappers source-text test and three source-text asserts in the inventory test (the Dockerfile test now builds its COPY line from `paths.AGENT_STEPS_DIR`).
- Task 3: why block under "Loading the steps"; parameter order (`cursor_version_result`, `managed_settings_result`, output stream last in the writers); 23 over-long comment lines wrapped; Dockerfile sentence; one passed return in `give_back_state_result` (same scan count and round limit); `_take_lock` takes `flock_function` and closes the handle on any OSError; `_folder_writable_hint` names the file's own folder; `_place_link` returns nothing.

## Verification

- `uv run pytest -q`: 463 passed (baseline 451).
- `bash tests/guard/run-all.sh`: All rules hold.
- `bash tests/selftest/sbx/run-all.sh`: All cases pass.
- H-34 counts untouched (`expectedClaudeCount=55`, `expectedCursorCount=53`); no ASCII or internal-ID hits in touched files.
- Host checks (`./host-test.sh`) not run here: Docker is unavailable in the dev sandbox.

## Deviations from Plan

None in behavior. Two small notes:

- **[Process]** The first commit initially carried a co-author trailer; it was amended off before anything else happened, since the user's rule says no AI attribution.
- The h34 `run_init` banner title lost "checks its summary" to fit 82 columns; its why block already says the summary is checked.

## Known Stubs

None.

## Deferred Issues

IN-01 and IN-04 left open as the plan says. The unit tests in `test_init_gsd_sync.py` still time the installer's time limit with `time.monotonic`; that test is about the limit itself and was out of the plan's scope.

## Threat Flags

None.

## Self-Check: PASSED

All three commits exist on feat/sbx-init-code (`git rev-list --count` from the recorded base gives 3); nothing under `.planning/` is staged; nothing pushed.
