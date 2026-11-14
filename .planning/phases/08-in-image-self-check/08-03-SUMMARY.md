---
phase: 08-in-image-self-check
plan: 03
subsystem: testing
tags: [python, pytest, selfcheck, git, mountinfo, permissions]

requires:
  - phase: 08-01
    provides: the sbx-selfcheck runner, CheckResult, the hint builders and the pinned pytest harness
provides:
  - 15 new shared checks (16 with user-sandbox) in the base image's shared list, in their final order
  - library helpers the agent files reuse in plan 06 (root_owned_result, protected_paths_result, pin_value, missing_pin_result, run_command, mount point readers)
  - the no-login extras: git identity, writable state, no root-owned leftovers under state/
affects: [08-04, 08-05, 08-06, 08-07]

actuals:
  tokens: 9000
  tasks: 2
  commits: 2
plan_head_before: b09df0a5cbc9b9bb813a7f86efa3931dffd217c3
plan_head_after: a9170695da47e83d897a9fb29bf464aa2897cf85

tech-stack:
  added: []
  patterns:
    - "Every check is a thin function over a helper that takes its paths, environment and mountinfo file as parameters, so pytest runs it on real files in tmp_path with no mock"
    - "The state walk reads owners with lstat through os.scandir and an explicit stack, never opens a file and never follows a link"
    - "git runs through run_command (argument list, closed stdin, 60 s limit) and its values are never printed"

key-files:
  created:
    - tests/selftest/selfcheck/test_sandbox_checks.py
  modified:
    - base/selfcheck/sbx_selfcheck.py
    - base/selfcheck/shared_checks.py

key-decisions:
  - "One shared walk (scan_owned_state) returns the reported paths and the tolerated count; owned_by_uid_paths is its list-only view, so the pass line can say how many paths were tolerated"
  - "Tolerated GSD sync folders are matched by the second path part in any state subfolder and are walked only to count them, never reported"
  - "protected_paths_result lists the top path, every folder and every file by name from os.walk (followlinks off) and tests writability with os.access, which follows a link the way a write would"

patterns-established:
  - "no-bundle-copy and the other image checks use os.path.lexists, so a dangling link counts as present"

requirements-completed: [CHECK-01, CHECK-04]

coverage:
  - id: D1
    description: "workspace-mount, project-folder, state-folders, state-writable and no-root-owned-state check the sandbox shape and each failure carries its Mac or sandbox fix"
    requirement: CHECK-01
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_sandbox_checks.py (mount, project folder, state folders, probe file removed, walk with links, tolerated and skipped folders, ten paths plus total)"
        status: pass
    human_judgment: false
  - id: D2
    description: "home-layout, home-owners, git-safe-directory, git-identity, env-state-paths, env-bundle, java-home port the in-container assertions of H-05, H-06, H-13 and H-14 and never print the git identity"
    requirement: CHECK-01
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_sandbox_checks.py (real git with config files in tmp_path, real owners, pin parsing)"
        status: pass
    human_judgment: false
  - id: D3
    description: "wrappers-root-owned, image-paths-protected and no-bundle-copy check owners, modes, writable paths, mounts and the missing bundle copy"
    requirement: CHECK-04
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_sandbox_checks.py (real root files, chmod 444 and 555 trees, mountinfo fixtures)"
        status: pass
      - kind: integration
        ref: "python3 base/selfcheck/sbx-selfcheck in the dev sandbox: 16 check lines, every FAIL has one fix line"
        status: pass
    human_judgment: true
    rationale: "The dev sandbox runs an older image, so the root-owned and protected-path checks run for real only inside a rebuilt image on the Mac (plan 07)"

duration: 12 min
completed: 2026-11-14
status: complete
---

# Phase 8 Plan 03: Sandbox, home, git, environment and image-path checks Summary

**The shared self-check list now holds 16 checks in their final order: the mount, project folder, state folders, writable state and root-owned leftovers (with the GSD sync folders tolerated), the user and home, git safe.directory and identity, the environment, and the image paths that must stay root-owned, read-only and unmounted, each failure naming its fix.**

## Performance

- **Duration:** 12 min
- **Completed:** 2026-11-14T18:37:00Z
- **Tasks:** 2
- **Files:** 3 (1 created, 2 modified)

## Accomplishments

- Library (`base/selfcheck/sbx_selfcheck.py`): `WORKSPACE_DIR`, `STATE_DIR`, `BUNDLE_DIR`, `VERSIONS_FILE`, `MOUNTINFO_FILE`, `COMMAND_TIMEOUT_SECONDS`, `run_command`, `parse_versions_text`, `pin_value`, `missing_pin_result`, `mount_point_set`, `read_mount_point_set`, `root_owned_result`, `protected_paths_result`. The two last ones name no agent and are what plan 06 reuses.
- Task 1 checks: `workspace-mount`, `project-folder`, `state-folders`, `state-writable` (one `mkstemp` probe, removed before the check returns), `no-root-owned-state` (uid 0, `cache/npm`, `cache/uv` and `m2` skipped, `gsd-core`, `hooks` and `scripts` tolerated under any state subfolder, at most ten paths plus the total, hint `chown -R sandbox:sandbox /home/sandbox/workspace/state`).
- Task 2 checks: `home-layout`, `home-owners`, `git-safe-directory`, `git-identity`, `env-state-paths`, `env-bundle`, `java-home`, `wrappers-root-owned`, `image-paths-protected`, `no-bundle-copy`.
- Probe-to-check map as in the plan: H-04 stays `user-sandbox`, H-05 (reaches the Mac) is dropped, H-05 layout and owners, H-06 safe.directory, H-13 and H-14 assertions all have a check.
- Tests: `tests/selftest/selfcheck/test_sandbox_checks.py` holds 51 tests on real files, real permissions and the real git; `uv run pytest tests/selftest/selfcheck`: 71 passed (20 runner tests plus these).

## Task Commits

1. **Task 1: the sandbox's shape and its state folder** - `2bfc4ea`
2. **Task 2: the user's home, git, the environment and the protected image paths** - `a917069`

## Verification

- `uv run pytest tests/selftest/selfcheck -q`: 71 passed. The tests were written first and watched failing (27 failed before the Task 1 code, 25 before the Task 2 code).
- Both Task 1 and both Task 2 `<verify>` commands exit 0: the shared list is the six, then the sixteen, in order; no base file names an agent; no `shell=True`, `follow_symlinks=True` or `followlinks=True`; the launcher in the dev sandbox prints 16 check lines and every FAIL has a fix line.
- Dev sandbox launcher run: 16 checks, 3 failed (`git-identity` because no identity is set here; `wrappers-root-owned` and `image-paths-protected` because this dev sandbox runs an older image without the self-check files). Expected, not a gate.
- Acceptance greps: 51 `def test_`, `GSD_SYNC_FOLDER_SET` line, the `chown` hint, the state git config path and `/opt/sbx/best-practices` all present; both commits touch only the three plan files.
- `bash tests/guard/run-all.sh`: "All rules hold."; no `__pycache__` under `base/`, `claude/` or `cursor/`.

## Deviations from Plan

### Auto-fixed Issues

None.

### Design notes within the plan's latitude

- `owned_by_uid_paths` is a thin view over a new `scan_owned_state` that also returns the tolerated count, because `root_owned_state_result` must say how many paths it tolerated. The plan text says the walk does not "descend below" a tolerated path; the tolerated folders are walked only to count their owned entries (still by lstat, no links followed, nothing reported), so the result list is exactly what the plan describes.
- Owned folders of the walk are reported too, not only files: with the test user as owner, `cache` and `sub1` appear next to `sub1/notes1` and `sub1/link1` in the expected list. A root-owned folder in `state/` is a real fault.
- The limit of ten for `protected_paths_result` lives in the library as `REPORTED_PROBLEM_LIMIT`; the state walk keeps `REPORTED_PATH_LIMIT` in `shared_checks.py`, as the plan names it.
- Small extra helpers beyond the plan's list: `no_bundle_copy_result` (so the check is testable on a tmp path), `is_tolerated_path`, `owner_name_of_path`, `protected_paths_problem_list`.
- Tests that rely on a read-only folder blocking a write are skipped when the suite runs as root (root ignores mode bits); the dev sandbox user is uid 1000, so they run here.

**Total deviations:** 0 auto-fixed. **Impact:** none on scope.

## Issues Encountered

None.

## Known Stubs

None. H-34's pinned counts (51 for Claude, 49 for Cursor) still fail until plans 05 and 06 add the other checks; that is the tripwire plan 02 set, not a stub.

## Threat Flags

None. The surface (the walk over `state/`, `git config`, `/proc/self/mountinfo`) is the one the plan's threat model covers: T-08-08 (lstat only, no links, no file opened, relative paths, ten at most), T-08-09 (probe file removed, folder asserted empty), T-08-10 (argument lists, closed stdin, 60 s), T-08-11 (git values never printed).

## Next Phase Readiness

Ready for 08-04 (delete the old probes now covered here). Hint strings of `state-folders` name the restart that runs the start today; Phase 9 replaces the start hooks, so re-read them there. The first Mac run may show root-owned paths outside `gsd-core`, `hooks` and `scripts` in the Cursor state folder; the check prints up to ten of them so the tolerance can be adjusted.

## Self-Check: PASSED

- Files exist: base/selfcheck/sbx_selfcheck.py, base/selfcheck/shared_checks.py, tests/selftest/selfcheck/test_sandbox_checks.py.
- Commits exist: 2bfc4ea, a917069.
