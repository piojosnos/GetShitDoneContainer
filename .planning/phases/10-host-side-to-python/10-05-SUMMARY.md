---
phase: 10-host-side-to-python
plan: 05
subsystem: testing
tags: [python, pytest, integration, harness, host-test, live-log, docker]

requires:
  - phase: 10-host-side-to-python
    provides: the sbx package, the two-line uv launcher shape, the guard in pytest
provides:
  - sbx/host_test.py and the two-line host-test.sh launcher (pytest over three suites, live log, Compose v2 preflight)
  - sbx/hosttest_names.py (run directory prefix, test sandbox names, temp base)
  - tests/integration harness (AgentSpec rows, step, run_timeout, run_streamed, session fixtures, shared and known-state sandboxes)
  - the first scenario, init and selfcheck for claude and cursor, proven on the host
affects: [10-06, 10-07, 10-08, 10-09, 10-10, 10-11]

actuals:
  tokens: 17500
  tasks: 3
  commits: 6
plan_head_before: 18e8c12a57ba8fa416c922fcee574e1c80fb506b
plan_head_after: 6af5ddd987601b647738a200c4fafe1efdd35fff

tech-stack:
  added: []
  patterns:
    - "Anything that echoes child output takes the output stream as a parameter; only the entry point (python -m sbx.host_test) and the build fixture pass sys.stdout"
    - "A scenario names its failed step through an exception note (STEP FAILED: name)"
    - "The integration session builds the test images; the guard runs after it so its linter rules can use sbx-base:test"

key-files:
  created:
    - sbx/host_test.py
    - sbx/hosttest_names.py
    - tests/integration/agent_specs.py
    - tests/integration/scenario_helpers.py
    - tests/integration/conftest.py
    - tests/integration/test_init_and_selfcheck.py
    - tests/unit/sbx/test_sbx_host_test.py
    - tests/unit/sbx/test_sbx_scenario_helpers.py
  modified:
    - host-test.sh
    - pyproject.toml
    - tests/unit/sbx/test_sbx_launchers.py
    - tests/unit/selfcheck/test_inventory.py
    - tests/unit/init/test_init_inventory.py
  moved:
    - tests/host/support/best-practices to tests/integration/support/best-practices

key-decisions:
  - "The output stream is an injected parameter (run_and_log, main, run_streamed), not sys.stdout read inside; main takes it as a required second argument so no default is bound at import time"
  - "run_streamed takes OUTPUT before LOG_FILE, the same order as run_and_log (output, then log)"
  - "The usage line of main stays on sys.stderr; the unit tests capture it with capsys, so it does not leak"

patterns-established:
  - "A leak test uses capfd, asserts the real terminal stays empty, and asserts the injected stream holds the lines"

requirements-completed: []

coverage:
  - id: D1
    description: "./host-test.sh is a two-line launcher into sbx.host_test, which checks Compose v2, writes the context lines, runs pytest -v -s over tests/unit/sbx, tests/integration and tests/guard with SBX_IMAGE_TAG=test, streams to the terminal and host-test.log, and returns pytest's code without a stop-early option"
    requirement: HOST-01
    verification:
      - kind: unit
        ref: "uv run pytest -q (940 passed, 1 skipped); tests/unit/sbx/test_sbx_host_test.py and test_sbx_launchers.py"
        status: pass
      - kind: manual_procedural
        ref: "macOS host run, host-test.log: 474 passed, 1 skipped in 95 s; last line 'host-test.sh: every test passed'"
        status: pass
    human_judgment: false
  - id: D2
    description: "The first scenario, init and selfcheck, passes for claude and cursor against real Docker with the test images; the guard linters pass through the docker fallback"
    requirement: HOST-04
    verification:
      - kind: manual_procedural
        ref: "host-test.log: test_init_and_selfcheck_pass[claude] PASSED and [cursor] PASSED; shellcheck and hadolint rules PASSED"
        status: pass
    human_judgment: false
  - id: D3
    description: "The run touches no user image or sandbox: the :local image ids are identical before and after and no hosttest container is left"
    requirement: HOST-04
    verification:
      - kind: manual_procedural
        ref: "harness-gate.log: three :local ids equal before and after; no hosttest container line"
        status: pass
    human_judgment: false
  - id: D4
    description: "Output of the unit tests of host_test and run_streamed never reaches the real terminal or host-test.log"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "three capfd tests (RED at 09c0558, GREEN at 6af5ddd); uv run pytest -q -s on both files printed no child output; 940 passed, 1 skipped"
        status: pass
    human_judgment: false
  - id: D5
    description: "The remaining HOST-04 edges (space in the sandbox path, the leftover container rule, the process-group kill) hold on a real host"
    requirement: HOST-04
    verification:
      - kind: manual_procedural
        ref: "the space in the path ran in the claude and cursor scenarios of the host run; the group kill is unit tested here; the leftover-container removal was not exercised (no leftover existed)"
        status: not_run
    human_judgment: true
    rationale: "The leftover-container branch needs an interrupted earlier run to trigger"

duration: about 35min of work across two sessions (commits 02:07 to 02:41 UTC), plus the host run
completed: 2026-11-20
status: complete
---

# Phase 10 Plan 05: The host run and the integration harness Summary

**`./host-test.sh` now runs the sbx unit tests, the integration scenarios and the guard through one pytest session with a live log, and the harness is proven on a real Mac: init and selfcheck pass for both agents.**

## Performance

- **Duration:** about 35 min of work (commits 02:07 to 02:41 UTC), plus the host run
- **Completed:** 2026-11-20
- **Tasks:** 3 (one tracer, one auto with tests first, one blocking-human host run)
- **Files changed:** 16 (8 created, 5 modified, 3 moved, plus this summary and the state files)

## Accomplishments

- `sbx/host_test.py`: Compose v2 preflight, context lines, the pytest child with `SBX_IMAGE_TAG=test`, every line flushed to the terminal and to `host-test.log`, pytest's exit code returned. No stop-early option.
- `tests/integration`: `AgentSpec` rows hold every per-agent number (selfcheck count 55 and 53, init steps 4 and 5); the session fixtures build the test images once, make the shared sandboxes `hosttest-claude` and `hosttest-cursor` with the real `sbx-add`, `sbx-start` and `sbx-init`, and remove them with `sbx-rm`.
- The host run (Docker 28.5.1, Compose v2.40.0-desktop.1), see `/home/sandbox/workspace/get-shit-done-container/host-test.log` and `/home/sandbox/workspace/harness-gate.log`: 474 passed, 1 skipped in 95 s; `test_init_and_selfcheck_pass[claude]` and `[cursor]` PASSED; shellcheck and hadolint rules PASSED through the docker fallback; the last line was `host-test.sh: every test passed`. The three `:local` image ids were identical before and after, and no `hosttest` container was left.

## Task Commits

1. **Task 1: harness and first scenario (tracer)**: `905f0e6` (feat, names) and `ec228c7` (test, harness and scenario)
2. **Task 2: host_test, launcher and unit tests**: `2da7186` (test) and `9b1fde6` (feat)
3. **Task 3: host run**: no commit; approved after the host run, with the fix below
4. **Fix from the host run**: `09c0558` (test, RED) and `6af5ddd` (fix, GREEN)

**Plan metadata:** the commit holding this file (docs: complete plan)

## Decisions Made

- The terminal stream is injected. `main(argument_list, output, environ, docker, repo_dir)` has no default for `output` on purpose: a default of `sys.stdout` would be bound at import and would miss a redirected stream.
- The same change applies to `run_streamed`, which the unit tests also called with the real stdout.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Unit-test output of host_test and run_streamed leaked into the real terminal and host-test.log**
- **Found during:** Task 3 (host run, lines 160 to 198 of host-test.log)
- **Issue:** `run_and_log` and `_emit` wrote child output to `sys.stdout`. The unit tests of the child-failure path (`test_main_runs_every_suite_after_a_failure...`, `test_run_and_log_merges_the_error_stream_of_the_child`) ran with `-s` under the real host run, so a fake failing session (`test_probe_*.py FAILED`, `2 failed, 1 passed`, `branch unknown, commit unknown`) appeared inside the real log. A reader of a real failing run would be misled. `test_run_streamed_stops_the_group_on_a_timeout` leaked a process id line the same way.
- **Fix:** `run_and_log`, `_emit`, `_emit_line`, `_write_context`, `_run`, `main` and `run_streamed` take the output stream. Only `python -m sbx.host_test` (`sys.stdout`) and the `test_images` fixture pass the real stream. The unit tests pass a `StringIO` and assert on it; three new `capfd` tests prove the real terminal stays empty.
- **RED evidence:** at `09c0558` the three new tests failed on the leaked text (`'one\n' == ''`, and the whole fake session for `main`). At `6af5ddd` they pass; `uv run pytest -q -s tests/unit/sbx/test_sbx_host_test.py tests/unit/sbx/test_sbx_scenario_helpers.py` printed 51 dots and no child output; `uv run pytest -q` gave 940 passed, 1 skipped.
- **Files modified:** `sbx/host_test.py`, `tests/integration/scenario_helpers.py`, `tests/integration/conftest.py`, `tests/unit/sbx/test_sbx_host_test.py`, `tests/unit/sbx/test_sbx_scenario_helpers.py`
- **Commits:** `09c0558`, `6af5ddd`

**2. [Interface change] Signatures differ from the plan's interfaces block**
- `run_and_log(argument_list, environ, output, log_handle, popen, cwd)`, `main(argument_list, output, environ, docker, repo_dir)` and `run_streamed(argument_list, seconds, environ, output, log_file)` gained the `output` parameter. Later plans that call `run_streamed` must pass it (`sys.stdout` in a fixture).

## Issues Encountered

The leak above. The fix was not re-run on the host: it changes no behavior of a real run (the entry point still passes `sys.stdout`), and the unit tests prove the terminal stays clean. The next host run (plan 06) will show the log without the fake session.

## Requirements left Pending, and why

- **HOST-01** stays Pending: `clean.sh` is still bash (`#!/usr/bin/env bash`), so not every host script is Python yet.
- **HOST-04** stays Pending: this plan delivered the harness and the init and selfcheck scenario only; the persistence group, the refusal group and the smoke tests are plans 06 to 08.
- **HOST-02, HOST-03, HOST-05** stay Pending (unchanged).

## User Setup Required

None beyond the host run already done.

## Known Stubs

None.

## Threat Flags

None. T-10-12 holds (image ids unchanged, the local-tag guard rule passes over the new code). T-10-13 holds in part: the run left no container; the leftover-removal branch was not exercised. T-10-SC: no package installed.

## Next Phase Readiness

- Plans 06 to 08 add scenarios on this harness; any call of `run_streamed` needs the `output` argument.
- Not committed by this plan: `host-test.log` (a host artifact) and the untracked planning, `.gsd` and export files.

## Self-Check: PASSED

- Commits `905f0e6`, `ec228c7`, `2da7186`, `9b1fde6`, `09c0558`, `6af5ddd` exist on `feat/host-side-to-python`; `git rev-list --count 18e8c12..HEAD` was 6 before this file was committed.
- `sbx/host_test.py`, `sbx/hosttest_names.py`, `tests/integration/conftest.py`, `tests/integration/scenario_helpers.py`, `tests/integration/agent_specs.py`, `tests/integration/test_init_and_selfcheck.py` exist.
- `uv run pytest -q`: 940 passed, 1 skipped.
