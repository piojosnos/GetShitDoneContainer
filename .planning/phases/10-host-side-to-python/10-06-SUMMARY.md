---
phase: 10-host-side-to-python
plan: 06
subsystem: testing
tags: [python, pytest, integration, persistence, isolation, compose, docker]

requires:
  - phase: 10-host-side-to-python
    provides: the integration harness (AgentSpec rows, step, run_sbx, run_streamed, sandbox fixture, one_bind_mount_problem, other_sbx_container_map)
provides:
  - test_planted_files_survive_one_upgrade (persistence across one sbx-upgrade)
  - test_failed_upgrade_changes_nothing
  - test_missing_sandbox_directory_is_refused and test_uppercase_name_is_refused
  - test_one_bind_mount_and_no_privileges
affects: [10-07, 10-08, 10-11]

actuals:
  tokens: 6100
  tasks: 3
  commits: 3
plan_head_before: a52a466d142a183c4441c54fc88421905b73a85e
plan_head_after: df75d593b186feddcecd072b591400baa77cb198

tech-stack:
  added: []
  patterns:
    - "A plant registers its finalizer before it writes, so a failure half way leaves nothing behind"
    - "A history marker is written through a held-open shell, so the test proves per-command writes"
    - "The refusal scenarios run plain docker compose with a minimal caller environment and remove whatever the attempt made"

key-files:
  created:
    - tests/integration/test_persistence.py
    - tests/integration/test_failed_upgrade.py
    - tests/integration/test_refusal.py
    - tests/integration/test_sandbox_isolation.py
  modified: []

key-decisions:
  - "The failed-upgrade scenario runs sbx-upgrade through run_streamed into a StringIO and a log file, so stdout and stderr are merged and the order warning-before-failure is checkable"
  - "The refusal scenarios fail on a made container only; a network left by a refused attempt is removed by the finalizer but is not a failure"

patterns-established:
  - "One scenario per file; a private helper used by one scenario stays in that file; only helpers two scenarios share go to scenario_helpers.py"

requirements-completed: []

coverage:
  - id: D1
    description: "Every planted file (project, state, clone, login, Claude session and memory, three caches) and the shell history survive one sbx-upgrade of a stopped sandbox; the upgrade creates a new container, prints the new-images line and the tool-versions line last, keeps one bind mount and leaves every other sbx- container unchanged"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "uv run pytest --collect-only: test_planted_files_survive_one_upgrade[claude] and [cursor] collected; 10 step blocks; uv run pytest -q 940 passed, 1 skipped"
        status: pass
      - kind: manual_procedural
        ref: "the real run needs Docker: ./host-test.sh on the Mac at the phase's final check"
        status: not_run
    human_judgment: true
    rationale: "The scenario can only run against real Docker, which the dev sandbox lacks"
  - id: D2
    description: "A failed build (sbx-upgrade NAME --no-such-option) exits non-zero, prints the running warning before 'the build failed; sbx-NAME was left as it was', and leaves the container id, start time and running state unchanged"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "collected for claude and cursor; read against sbx/upgrade.py message text"
        status: pass
      - kind: manual_procedural
        ref: "real run on the host at the phase's final check"
        status: not_run
    human_judgment: true
    rationale: "Needs real Docker"
  - id: D3
    description: "Plain docker compose is refused for a missing sandbox directory (not created, no container) and for an uppercase SBX_NAME (refused by the name check before any container)"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "collected for claude and cursor (4 items)"
        status: pass
      - kind: manual_procedural
        ref: "real run on the host at the phase's final check"
        status: not_run
    human_judgment: true
    rationale: "Needs real Docker and Compose v2"
  - id: D4
    description: "HostConfig of the running container: not privileged, all capabilities dropped and none added, no-new-privileges, no unconfined profile, no devices or extra groups, no host or joined namespace, one bind mount from the registered directory"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "collected for claude and cursor; every field name the old check read is in the file"
        status: pass
      - kind: manual_procedural
        ref: "real run on the host at the phase's final check"
        status: not_run
    human_judgment: true
    rationale: "Needs a real container to inspect"

duration: about 25min
completed: 2026-11-20
status: complete
---

# Phase 10 Plan 06: Persistence, failed upgrade, refusals and isolation Summary

**Four scenario files on the harness, each run once per agent: planted state survives one `sbx-upgrade`, a failed build changes nothing, plain Compose refuses a missing directory and an uppercase name, and `docker inspect` shows no privilege and one bind mount.**

These scenarios need Docker, which the dev sandbox lacks. Here they are proven by collection (`[claude]` and `[cursor]` for all five functions, ten items), by the full suite (`uv run pytest -q`: 940 passed, 1 skipped) and by reading them against `sbx/upgrade.py`, `compose.yml` and the old host checks. **The real run happens on the host at the phase's final check (`./host-test.sh`); nothing here has run against Docker yet.**

## Accomplishments

- `test_persistence.py`: ten steps. It plants run-unique files in the project directory, the state directory, the best-practices clone, the agent's login file and (Claude) a session file and a memory file; writes a history marker through a held-open shell; checks the npm, uv and Maven cache locations and plants a marker in each; records the other `sbx-` containers; stops the sandbox; runs one `sbx-upgrade` on the stopped sandbox (exit 0, no open-shells warning, new container id, `runs on the new images` line before the last, the image's `/etc/sbx/tool-versions` last); then checks every file, the history in a fresh shell, one bind mount and the other containers unchanged.
- `test_failed_upgrade.py`: three steps; the bogus build option fails the build, the warning precedes the failure line, and id, start time and running state stay the same.
- `test_refusal.py`: two scenarios with four steps. Both run plain `docker compose ... up -d` with only PATH, HOME, `DOCKER_*` and the four `SBX_` values.
- `test_sandbox_isolation.py`: three field steps plus the shared one-mount check; each failing field is named with its value.

## Task Commits

1. **Task 1: persistence (tracer)**: `501253c`
2. **Task 2: failed upgrade and the two refusals**: `41877c1`
3. **Task 3: isolation**: `df75d59`

**Plan metadata:** the commit holding this file (docs: complete plan)

## Decisions Made

- `run_streamed` into a `StringIO` (and a log under the run directory's `logs/`) runs the failed upgrade, instead of `run_sbx`: its merged stream lets the scenario check that the warning comes before the failure line, which two separate pipes cannot show.
- No new helper was needed, so `scenario_helpers.py` and its unit tests are unchanged.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The uppercase-name step cannot look for the lowercase container name**
- **Found during:** Task 2 (writing the step)
- **Issue:** the plan says no container whose name holds `hosttest-<agent>` in either case. The shared test sandbox is `sbx-hosttest-<agent>`, so that check would always fail.
- **Fix:** the step checks for the exact uppercase name `sbx-HostTest-<agent>` (Docker names are case sensitive), and the refusal must carry `must be lowercase`, the name-check guard's own message.
- **Files modified:** `tests/integration/test_refusal.py`
- **Commit:** `41877c1`

**2. [Interpretation] "the scenario fails if one was made" covers a container, not a network**
- A refused attempt on a missing directory can leave `<project>_default` (Compose makes the network before it creates the container), which would fail a correct refusal. The finalizer removes both; only a made container fails the scenario.

## Issues Encountered

None. The `-p` project name is the lowercase `sbx-hosttest-refusal-<agent>` in both refusal scenarios, so the uppercase one reaches the name-check guard in `compose.yml` and not Compose's own project-name validation.

## Requirements left Pending, and why

- **HOST-04** stays Pending: it also needs plans 07 and 08, and none of these scenarios has run on a real host yet.
- **HOST-01, HOST-02, HOST-03, HOST-05** stay Pending (unchanged).

## User Setup Required

None. The host run at the phase's final check is `./host-test.sh` on the Mac; read `host-test.log` afterwards.

## Known Stubs

None.

## Threat Flags

None. T-10-15 holds by construction (the scenario only reads other containers and fails on a changed id or start time). T-10-16: login files hold a run-unique fake text and each has a finalizer. T-10-SC: no package installed.

## Next Phase Readiness

- Plans 07 and 08 can share `one_bind_mount_problem` and `other_sbx_container_map`.
- The first real run of these scenarios is the next `./host-test.sh`; likely first findings would be the cache location text, the `must be lowercase` match and the history marker timing (10 s).

## Self-Check: PASSED

- Commits `501253c`, `41877c1`, `df75d59` exist on `feat/host-side-to-python`; `git rev-list --count a52a466..HEAD` was 3 before this file was committed.
- The four scenario files exist under `tests/integration/`.
- `uv run pytest -q`: 940 passed, 1 skipped.
