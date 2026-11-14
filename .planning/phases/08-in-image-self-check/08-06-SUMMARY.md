---
phase: 08-in-image-self-check
plan: 06
subsystem: testing
tags: [python, pytest, selfcheck, claude, cursor, credentials, symlinks]

requires:
  - phase: 08-01
    provides: the runner, the agent file loader and claude-env, cursor-env
  - phase: 08-05
    provides: tool_result, root_owned_result, protected_paths_result, versions_line_result, pin_value and the hint builders
provides:
  - four generic base helpers (login_file_result, gsd_synced_result, bundle_links_result, home_links_result)
  - the 12 Claude checks and the 10 Cursor checks, complete and in their final order
  - an inventory test that ties the 39, 12 and 10 lists to H-34's expected counts (51 and 49)
affects: [08-07]

actuals:
  tokens: 10100
  tasks: 2
  commits: 2
plan_head_before: 91781826ece5aef63555dd7bc99dd7138b3ff12c
plan_head_after: 55c09c4668b51eaf081119ac6e72606c79344622

tech-stack:
  added: []
  patterns:
    - "Each agent check is a thin function over a helper that takes its paths as parameters, so pytest runs it on tmp_path trees with real links"
    - "The login files are judged by presence and size only and are never opened"
    - "cursor-agent --version runs with a throwaway HOME from tempfile and without CURSOR_CONFIG_DIR, removed in a finally"

key-files:
  created:
    - tests/selftest/selfcheck/test_agent_checks.py
    - tests/selftest/selfcheck/test_inventory.py
  modified:
    - base/selfcheck/sbx_selfcheck.py
    - claude/selfcheck/claude.py
    - cursor/selfcheck/cursor.py
    - tests/selftest/selfcheck/conftest.py

key-decisions:
  - "The link texts the linker writes (../../best-practices/rules and ../../../best-practices/skills/NAME) are constants in the base library, next to the helper that checks them"
  - "managed_settings_result and no_home_copy_result live in the Claude file, since only Claude has them; they take their paths as parameters with the Claude constants as defaults"
  - "The managed settings lists are compared sorted, so the file's order never matters"
  - "H-34's counts stay 51 and 49: no check was added or dropped, so tests/host/ is untouched"

patterns-established:
  - "A failure detail names only the keys a check compares (the channel value, the two permission lists), never other settings"
  - "The agent_module fixture loads an agent file through the runner's own loader, so tests run what the image runs"

requirements-completed: [CHECK-01, CHECK-02, CHECK-04]

coverage:
  - id: D1
    description: "the Claude image declares 12 checks and the Cursor image 10, covering the CLI, env, home links, login file, GSD sync, bundle links, wrappers, protected paths and versions line, with Claude-only managed settings, ccusage and no-home-copy and Cursor-only self-update-off"
    requirement: CHECK-01
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_agent_checks.py (helpers on real trees and links, managed settings, no-home-copy, self-update, both name lists in order)"
        status: pass
      - kind: integration
        ref: "dev sandbox runner with the Claude file prints 51 check lines; the only new failures are the two the older image causes (claude.py not yet in /etc/sbx/selfcheck.d, an older versions line)"
        status: pass
    human_judgment: true
    rationale: "Login files, the pinned CLIs and the Cursor checks run for real only in rebuilt images on the Mac (plan 07)"
  - id: D2
    description: "the three lists sum to H-34's expectedClaudeCount (51) and expectedCursorCount (49), with unique, well formed names, and both agent files load with no load failure"
    requirement: CHECK-02
    verification:
      - kind: unit
        ref: "tests/selftest/selfcheck/test_inventory.py (sizes, sums read from tests/host/h34-selfcheck.sh, uniqueness, name pattern, Check type, collect_checks returns 61)"
        status: pass
    human_judgment: false
  - id: D3
    description: "the login files are never read and cursor-agent never sees the sandbox's HOME or CURSOR_CONFIG_DIR"
    requirement: CHECK-04
    verification:
      - kind: unit
        ref: "test_login_file_result_* (a planted token appears in no detail or hint), test_cursor_version_result_* (stand-in records HOME and the variable; the folder is gone after the call)"
        status: pass
    human_judgment: false

duration: 15 min
completed: 2026-11-14
status: complete
---

# Phase 8 Plan 06: The agent checks and the inventory Summary

**The Claude and Cursor images each carry their complete checks file on four new generic base helpers: 12 Claude checks and 10 Cursor checks that check the pinned CLIs, the env, the home links, the login files (presence and size only, never read), the GSD sync, the bundle links (exact link text and same folder), the wrappers, the protected paths and the versions line, so a Claude sandbox prints 51 lines and a Cursor sandbox 49, and an inventory test fails when a list and H-34's constants drift apart.**

## Performance

- **Duration:** about 15 min
- **Completed:** 2026-11-14T18:55:00Z
- **Tasks:** 2
- **Files:** 6 (2 created, 4 modified)

## Accomplishments

- Library (`base/selfcheck/sbx_selfcheck.py`): `login_file_result`, `gsd_synced_result`, `bundle_links_result`, `home_links_result` and their small helpers. No agent is named; the plan 01 test that checks this still passes.
- Claude (`claude/selfcheck/claude.py`): `tool-claude`, `tool-ccusage`, `claude-env`, `claude-home-links`, `claude-no-home-copy`, `claude-credentials`, `claude-gsd-synced`, `claude-bundle-links`, `claude-wrappers`, `claude-managed-settings`, `claude-image-paths-protected`, `claude-versions-line`.
- Cursor (`cursor/selfcheck/cursor.py`): `tool-cursor-agent`, `cursor-env`, `cursor-home-links`, `cursor-self-update-off`, `cursor-credentials`, `cursor-gsd-synced`, `cursor-bundle-links`, `cursor-wrappers`, `cursor-image-paths-protected`, `cursor-versions-line`.
- `cursor_version_result` makes a throwaway HOME with `tempfile.mkdtemp`, drops `CURSOR_CONFIG_DIR`, and removes the folder with `shutil.rmtree` in a `finally`.
- Tests: `test_agent_checks.py` (31 tests) and `test_inventory.py` (6 tests), plus the `agent_module` fixture; `uv run pytest tests/selftest/selfcheck`: 178 passed.

## Task Commits

1. **Task 1: the agent helpers and the complete Claude checks file** - `9043e3d`
2. **Task 2: the complete Cursor checks file and the inventory test** - `55c09c4`

## Verification

- `uv run pytest tests/selftest/selfcheck -q`: 178 passed.
- Task 1 verify: the Claude list is the 12 names in order, no base file names an agent, no credentials file is opened (exit 0).
- Task 2 verify: lists of 39, 12 and 10 with the Cursor names in order, `expectedClaudeCount=51` and `expectedCursorCount=49` unchanged, `tempfile.mkdtemp` and `shutil.rmtree` present; the dev-sandbox runner with the Claude file prints 51 check lines, a summary of 51, no `load-` failure and one fix line per FAIL.
- `bash tests/guard/run-all.sh`: "All rules hold."
- Dev sandbox run with the Claude file: the two new failures are `claude-wrappers` (the older image has no `/etc/sbx/selfcheck.d/claude.py`) and `claude-versions-line` (the older image's line has ccusage after gsd); both clear in a rebuilt image on the Mac (plan 07).

## Deviations from Plan

### Auto-fixed Issues

None.

### Design notes within the plan's latitude

- `managed_settings_result` and `no_home_copy_result` are in the Claude file, as the plan puts them; `no_home_copy_result` takes the path list as a parameter so a test covers a copy that is a folder and a copy that is a dangling link.
- A missing GSD version file gets its own detail (`FILE is missing`), not the empty-version wording, so the cause reads plainly; both carry the restart hint.
- `self_update_result` reports a missing `channel` key separately from a wrong value, and names only that value.
- The tests were written before the code, but the RED run was not watched separately (the new test files fail at import or attribute lookup by construction before the code exists).
- H-34's counts needed no change, so `tests/host/` is untouched.

## Known Stubs

None.

## Threat Flags

None. T-08-19 to T-08-22 are implemented as planned: the login files are never opened (a planted token appears in no detail or hint, and the verify greps for any open or read), the Cursor CLI runs in a throwaway HOME that is removed in a `finally`, each bundle link must carry the exact relative text and the rules link must be the same folder as the clone's, and only the compared keys appear in a detail.

## Next Phase Readiness

Plan 07's Mac gate runs H-34 against rebuilt images: 51 lines in a Claude sandbox, 49 in a Cursor sandbox. Phase 9 (sbx-init) edits only the named functions that depend on today's start hooks (`gsd_synced_result`, `bundle_links_result`, `self_update_result` and the hook entries of the two wrapper lists) and re-reads their hints.

## Self-Check: PASSED

- Files exist: `base/selfcheck/sbx_selfcheck.py`, `claude/selfcheck/claude.py`, `cursor/selfcheck/cursor.py`, `tests/selftest/selfcheck/conftest.py`, `tests/selftest/selfcheck/test_agent_checks.py`, `tests/selftest/selfcheck/test_inventory.py`.
- Commits `9043e3d` and `55c09c4` exist on `feat/phase-08-in-image-self-check`; `git rev-list --count` from the recorded base is 2.
