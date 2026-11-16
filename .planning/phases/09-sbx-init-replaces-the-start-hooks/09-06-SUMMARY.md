---
phase: 09-sbx-init-replaces-the-start-hooks
plan: 06
subsystem: infra
status: complete
tags: [shell, wrappers, sbx-init, agents]

requires:
  - phase: 09-sbx-init-replaces-the-start-hooks
    provides: paths.INIT_MARKER_FILE, paths.AGENT_BIN_DIR and init_helpers.write_stand_in (plan 01)
provides:
  - sbx-claude and sbx-cursor refuse without the init marker, else exec the agent with the agents folder first on PATH
  - sbx-bundle-clone ends in exec sbx-init
  - sbx-gh-login check_state_folders points at sbx-init when a state folder is missing
  - tests/selftest/init/test_init_wrappers.py, test_init_best_practices_clone.py, test_init_gh_login.py
affects: [09-07, 09-11, 09-13]

actuals:
  tokens: 14000
  tasks: 3
  commits: 3
plan_head_before: 9e70d2cd373fc1d7ca1e55232926ef3f43bbedd5
plan_head_after: cb5a0513d1bb36728500a4bf24a38a1a21fef2c4

tech-stack:
  added: []
  patterns:
    - "thin wrapper: marker test, PATH export, exec; SBX_INIT_MARKER and SBX_AGENT_BIN_DIR override the defaults for tests"
    - "a test pins the shell default literals to the Python paths so the two sides cannot drift"

key-files:
  created:
    - tests/selftest/init/test_init_wrappers.py
    - tests/selftest/init/test_init_best_practices_clone.py
    - tests/selftest/init/test_init_gh_login.py
  modified:
    - claude/bin/sbx-claude
    - cursor/bin/sbx-cursor
    - base/bin/sbx-bundle-clone
    - base/bin/sbx-gh-login

key-decisions:
  - "The two wrappers are the same script apart from the agent names; a test replaces the names and compares the files"
  - "The marker test is -f, so a folder at the marker path counts as missing"

patterns-established:
  - "Shell scripts are tested by running the real file under bash with stand-in executables on a temp PATH"

requirements-completed: [INIT-04]

coverage:
  - id: D1
    description: "wrappers refuse at once without the marker (exact stderr line, exit 1, no agent, under 2 s) and exec the agent from the agents folder with it"
    requirement: INIT-04
    status: covered
    evidence: "uv run pytest tests/selftest/init/test_init_wrappers.py: 11 pass"
  - id: D2
    description: "sbx-bundle-clone clones then execs sbx-init (status passed through); refuses an existing folder naming sbx-init; a missing origin names sbx-gh-login"
    requirement: INIT-04
    status: covered
    evidence: "uv run pytest tests/selftest/init/test_init_best_practices_clone.py: 4 pass"
  - id: D3
    description: "sbx-gh-login stops before gh when GH_CONFIG_DIR or the git config folder is missing"
    requirement: INIT-04
    status: covered
    evidence: "uv run pytest tests/selftest/init/test_init_gh_login.py: 3 pass"
---

# Phase 9 Plan 06: Wrappers, bundle clone and gh login Summary

The agent wrappers now refuse until `sbx-init` has passed in the container, then start the agent from the off-PATH agents folder; `sbx-bundle-clone` relinks through `sbx-init`; `sbx-gh-login` says to run `sbx-init` when its state folders are missing.

## What was built

| Task | Result | Commit |
|---|---|---|
| 1 (tracer) | `sbx-claude`: no marker -> one stderr line, exit 1; marker -> `PATH=$agentBinDir:$PATH`, `exec claude "$@"`. No warning, no pause, no clone test. | 8044d85 |
| 2 | `sbx-cursor` as the same script with `cursor-agent`; tests parametrised over both, literal pins to `paths.py`, symmetry test, folder-as-marker case | 0c899f1 |
| 3 | `sbx-bundle-clone` ends in `exec sbx-init`; already-exists error names `sbx-init`; `sbx-gh-login` gets `check_state_folders`; tests for both | cb5a051 |

Verification: `uv run pytest` 403 passed; `bash tests/guard/run-all.sh` ends in `All rules hold.`; `bash -n` clean on all four scripts; all four stay mode 100755.

## Deviations from Plan

None. The plan executed as written. The tracer task's test file held only the Claude cases; task 2 widened it to both wrappers.

## Notes for later plans

- `README.md` (lines 288, 314, 504, 505, 507) still tells users to relink with `/etc/sbx/start.d/10-best-practices` and mentions the wrapper WARNING; the docs plan must update these.
- `tests/host/h27-bundle-clone-and-publish.sh` still asserts `sbx-claude` does not print a WARNING after the clone and drives the old hook path; it needs a host-side pass on the Mac once the start hooks are gone (not in this plan's files).
- `tests/selftest/entrypoint/bundle-hook.sh` still exercises the old `start.d/10-best-practices` hooks; it goes with the hook removal.

## Known Stubs

None.

## Threat Flags

None. The override variables follow the plan's accepted threats (T-09-15, T-09-16).

## Self-Check: PASSED

- FOUND: claude/bin/sbx-claude, cursor/bin/sbx-cursor, base/bin/sbx-bundle-clone, base/bin/sbx-gh-login
- FOUND: the three test files under tests/selftest/init/
- FOUND commits: 8044d85, 0c899f1, cb5a051
