---
phase: 09-sbx-init-replaces-the-start-hooks
plan: 02
subsystem: infra
tags: [python, sbx-init, gsd, cursor, pytest, selfcheck]

requires:
  - phase: 09-01
    provides: the sbx-init runner, the STEP_LIST contract, init_hint and the init test helpers
provides:
  - gsd_sync_result in base/init/gsd_sync.py (folder first, own session, 300 s limit, log kept only on failure)
  - step claude-gsd-sync and step cursor-gsd-sync (050 step files)
  - step cursor-self-update-off (060 step file) and cursor_shared.CLI_CONFIG_FILE
  - self-check twins claude-gsd-synced, cursor-gsd-synced and cursor-self-update-off fix lines now point at sbx-init
affects: [09-03, 09-04, 09-09, 09-11]

actuals:
  tokens: 9000
  tasks: 2
  commits: 2
plan_head_before: 30ad8f254d8b156598e9ba0e501f4cf06b77608d
plan_head_after: deb54c3751f8e5fa5c60a977d0f6093159b0c9eb

tech-stack:
  added: []
  patterns:
    - "One base function for the GSD sync, two agent step files that differ only in the agent name"
    - "Config file rewrite through a temp file in the same folder and os.replace; a refused file is left byte for byte"

key-files:
  created:
    - base/init/gsd_sync.py
    - claude/init/050_gsd_sync.py
    - cursor/init/050_gsd_sync.py
    - cursor/init/060_self_update_off.py
    - tests/selftest/init/test_init_gsd_sync.py
    - tests/selftest/init/test_init_self_update.py
  modified:
    - base/selfcheck/agent_config.py
    - cursor/selfcheck/lib/cursor_shared.py
    - cursor/selfcheck/050_self_update_off.py
    - tests/selftest/selfcheck/test_agent_config.py
    - tests/selftest/selfcheck/test_cursor_self_update_off.py

key-decisions:
  - "The GSD step reports only the installer's own outcome; the version comparison stays in the self-check twins"
  - "A whitespace-only cli-config.json counts as empty and is rewritten as {\"channel\": \"static\"}"
  - "An unreadable cli-config.json path (a folder, bad bytes) fails with the fix-or-delete hint and is left alone"

requirements-completed: [INIT-01]

coverage:
  - id: D1
    description: "The Claude and Cursor GSD sync steps run 'gsd-core --AGENT --global --config-dir DIR' with stdin closed, make the folder first, stop a stuck installer with its whole process group after the time limit, and keep the output only on failure"
    requirement: INIT-01
    verification:
      - kind: unit
        ref: "tests/selftest/init/test_init_gsd_sync.py"
        status: pass
      - kind: integration
        ref: "tests/selftest/init/test_init_gsd_sync.py#test_the_image_installer_syncs_the_pinned_version_offline"
        status: pass
    human_judgment: false
  - id: D2
    description: "The Cursor channel step sets channel to static, keeps other keys, refuses non-JSON and non-object files byte for byte, and writes through a temp file and os.replace"
    requirement: INIT-01
    verification:
      - kind: unit
        ref: "tests/selftest/init/test_init_self_update.py"
        status: pass
    human_judgment: false
  - id: D3
    description: "The self-check twins keep verifying and their fix lines name sbx-init; the Cursor check and step share CLI_CONFIG_FILE"
    requirement: INIT-01
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_agent_config.py"
        status: pass
      - kind: unit
        ref: "tests/selftest/selfcheck/test_cursor_self_update_off.py"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-11-16
status: complete
---

# Phase 9 Plan 02: GSD sync and static channel init steps Summary

**The two start-hook jobs ported to sbx-init steps: a shared `gsd_sync_result` (folder first, own session, 300 s process-group kill, output kept only on failure) used by both agents, and Cursor's atomic static-channel write in `cli-config.json`.**

## Performance

- **Duration:** about 15 min
- **Started:** 2026-11-16T16:36:00Z (approx.)
- **Completed:** 2026-11-16T16:52:00Z
- **Tasks:** 2
- **Files modified:** 11 (6 created, 5 modified)

## Accomplishments

- `base/init/gsd_sync.py` runs the image's `gsd-core` from an argument list (never a shell string, never npx or a network name), with stdin closed and its own session. Past the limit the whole process group gets SIGKILL; the test starts a grandchild and checks it is gone.
- `claude/init/050_gsd_sync.py` and `cursor/init/050_gsd_sync.py` differ only in the agent name (the plan's `diff` check prints nothing).
- `cursor/init/060_self_update_off.py` exposes `static_channel_result`; a refused file stays byte for byte and no temp file is left beside it.
- The self-check fix lines of `claude-gsd-synced`, `cursor-gsd-synced` and `cursor-self-update-off` are now `init_hint()`. `CLI_CONFIG_FILE` lives in `cursor_shared` and both the check and the step read it.
- `uv run pytest tests/selftest/init tests/selftest/selfcheck -q`: 329 passed. `bash tests/guard/run-all.sh` ends with `All rules hold.` The real `gsd-core` test ran here (not skipped) and found the pinned version in the synced `VERSION` file, offline.

## Task Commits

1. **Task 1: Claude GSD sync step end to end (tracer)** - `17cea0d` (feat)
2. **Task 2: Cursor GSD sync and static channel steps, shared constant** - `deb54c3` (feat)

## Decisions Made

- The folder-cannot-be-made test uses a regular file as the parent (works as root too) and a second test with a read-only parent that skips when run as root, instead of only the read-only form the plan named.
- Process liveness in the timeout test is read with `ps -o stat= -p PID` (works on macOS and Linux) and counts a zombie as gone, since a container without a reaping init leaves killed orphans as zombies.
- The step test for the agent files replaces `gsd_sync_result` in the loaded step module to prove which agent option each file passes, so it needs no installer.

## Deviations from Plan

### Auto-fixed Issues

None beyond the choices above. The plan said the Cursor GSD step file belongs to Task 2; it was created while writing Task 1's sibling and kept out of the Task 1 commit, so each commit holds its own files.

### TDD note

Task 2 followed RED then GREEN: `test_init_self_update.py` failed at collection (the step file did not exist), then passed after the step and the constant were added. The RED run was not committed separately because the step file and its tests are one reviewable unit.

## Known Stubs

None.

## Threat Flags

None. T-09-04 (argument list only, pinned installer, no npx or @latest, checked by grep and the `no_compromised_gsd_package` guard), T-09-05 (limit, own session, group kill, folder first) and T-09-06 (`json.loads` only, non-object refused, temp file plus `os.replace`) are implemented and tested.

## Issues Encountered

None.

## User Setup Required

None. Host-side checks of these steps in a real image come in a later plan of this phase; Docker is not available in the dev sandbox. The Dockerfile lines that copy `claude/init`, `cursor/init` and `gsd_sync.py` into the image are not part of this plan.

## Next Phase Readiness

Later plans can add 800-series shared steps and the Dockerfile installs; the step order inside the Cursor image is 050 GSD sync, 060 channel, then the shared ownership step.

## Self-Check: PASSED

- FOUND: base/init/gsd_sync.py, claude/init/050_gsd_sync.py, cursor/init/050_gsd_sync.py, cursor/init/060_self_update_off.py, tests/selftest/init/test_init_gsd_sync.py, tests/selftest/init/test_init_self_update.py
- FOUND commits: 17cea0d, deb54c3
