---
phase: 10-host-side-to-python
plan: 09
subsystem: testing
tags: [python, pytest, integration, guard, clean, host-checks-removed]

requires:
  - phase: 10-host-side-to-python
    provides: every integration scenario (plans 05 to 08), hosttest_names.py, the launcher rule of the guard
provides:
  - clean.sh as a launcher into sbx.clean (per-agent test containers, explicit root certificate line)
  - an amended relink scenario that plants a settings key and CLAUDE.md for Claude
  - test_upgrade_of_a_running_sandbox (both agents), replacing three unit tests
  - tests/host/ deleted (25 files)
  - guard rule test_no_host_logic_in_shell
affects: [10-10, 10-11]

actuals:
  tokens: 13500
  tasks: 3
  commits: 7
plan_head_before: d5d635f58eda5c3edf3d4a0fa0bf1ebfef65967a
plan_head_after: 0031f7dfe86bd1be2f2a03f2ab46e1e14b357622

tech-stack:
  added: []
  patterns:
    - "A user file a scenario plants for one agent only is declared on AgentSpec (settings_file, instructions_file; None for Cursor), so the scenario holds no agent name test"
    - "A scenario that checks the order of output runs the command with run_streamed into an injected StringIO, so nothing reaches the real terminal"

key-files:
  created:
    - sbx/clean.py
    - tests/unit/sbx/test_sbx_clean.py
    - tests/integration/test_upgrade_running_sandbox.py
  modified:
    - clean.sh
    - tests/unit/sbx/test_sbx_launchers.py
    - tests/unit/sbx/test_sbx_upgrade.py
    - tests/integration/agent_specs.py
    - tests/integration/test_first_run_and_relink.py
    - tests/guard/guard_helpers.py
    - tests/guard/test_guard_launchers.py
    - tests/guard/test_guard_supply_chain.py
    - tests/guard/test_guard_isolation.py
  deleted:
    - tests/host/ (run-all.sh, eight libraries, seventeen checks)

key-decisions:
  - "Old-check map review (D-18): the user answered amend. Rows A (old relink check: settings key and CLAUDE.md) and C (upgrade of a running sandbox on real Docker) were amended; rows B and D stay as decided, no action."
  - "The running-sandbox upgrade is its own scenario file, not an extra step in test_persistence.py: persistence does one upgrade of a stopped sandbox (D-16) and this one needs a running sandbox, so the two stay independent"
  - "The three unit tests the new scenario supersedes were deleted; every refusal test, the three failure tests, the stopped-sandbox-not-warned test and the options tests stay"

patterns-established:
  - "The guard's list of root scripts (ROOT_SCRIPT_NAME_LIST) is public and shared by the file lists and the new rule"

requirements-completed: [HOST-05]

coverage:
  - id: D1
    description: "clean.sh is a two-line launcher into sbx.clean: a dry run unless --yes; removes a test container (sbx-hosttest or sbx-hosttest-*) and its network only when its workspace mount lies in a host-test run directory; names the test root certificate directories on their own line; prunes the build cache and unused images"
    requirement: HOST-05
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_clean.py and the launcher row; uv run pytest -q 982 passed, 1 skipped"
        status: pass
  - id: D2
    description: "The relink scenario plants, for Claude, a settings.json key (added to what the GSD sync wrote) and a user CLAUDE.md in state/claude, and after sbx-init proves the key is present with its value and CLAUDE.md is byte-identical; Cursor plants neither"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "collection of test_relink_after_a_pull[claude] and [cursor]; the two settings helpers run by hand against a temp file (key added to an existing object, a missing key and an empty object reported); read against base/init/gsd_sync.py and claude/init/050_gsd_sync.py"
        status: pass
      - kind: manual_procedural
        ref: "real run: ./host-test.sh on the Mac at the phase's final check"
        status: not_run
    human_judgment: true
    rationale: "Needs real Docker and the built test images; the GSD installer's effect on settings.json can only be seen there"
  - id: D3
    description: "One successful sbx-upgrade of a running sandbox: the sessions-close warning is printed before the build starts; the container id changes and the container runs on the current test image; the run ends with the marker line, the images line and the tool-versions line"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "collection of test_upgrade_of_a_running_sandbox[claude] and [cursor]; read against sbx/upgrade.py (warning printed and stdout flushed before build_function; marker line, images line, then docker exec cat of tool-versions), sbx/build.py (first line of a build is 'build.sh: building IMAGE') and sbx/docker.py (the same .Image versus .Id comparison the product uses for the older-image mark)"
        status: pass
      - kind: manual_procedural
        ref: "real run: ./host-test.sh on the Mac at the phase's final check"
        status: not_run
    human_judgment: true
    rationale: "Needs real Docker and a full image rebuild"
  - id: D4
    description: "tests/host/ is gone and the guard keeps host logic out of shell: build.sh, clean.sh and host-test.sh start with #!/bin/sh and are in the launcher list, every tracked file in bin/ is a launcher, git tracks no .sh file under tests/, and no tracked file under tests/ is named docker, xattr, shellcheck or hadolint"
    requirement: HOST-05
    verification:
      - kind: unit
        ref: "uv run pytest tests/guard -q: 22 passed; git ls-files 'tests/*.sh' empty; git grep of tests/host/ outside the plan 10 docs empty"
        status: pass

duration: about 40min (this continuation; Task 1 ran earlier)
completed: 2026-11-20
status: complete
---

# Phase 10 Plan 09: clean.sh in Python, the old-check review and the end of tests/host Summary

**`clean.sh` is a Python launcher that knows the per-agent test containers; the user amended two rows of the old-check map (relink: settings key and CLAUDE.md; upgrade of a running sandbox on real Docker); then the 25 bash host files were deleted and a guard rule keeps host logic out of shell.**

None of the new or amended scenarios has run against Docker (the dev sandbox has none). They are proven by collection, by careful reading against `sbx/upgrade.py`, `sbx/build.py`, `sbx/docker.py` and the init steps, and by `uv run pytest -q`: 982 passed, 1 skipped. **The real run is the host check at the end of the phase (`./host-test.sh`).**

## Task 2 decision (D-18, blocking-human)

The user answered **amend**, with rows **A** and **C**. Rows **B** and **D** stay as decided (no action). Task 3 ran only after both amendments were committed.

### Amended rows of the old-check map

| Old check | Old step | Was | Now |
|---|---|---|---|
| H-16 | plant a settings key and user files | `test_first_run_and_relink.py::test_relink_after_a_pull`, step "plant user files" (a skill, a note, session and memory for Claude only) | same step, also a user `settings.json` key and a user `CLAUDE.md` in `state/claude` for Claude (declared on `AgentSpec`; Cursor has neither) |
| H-16 | the uncommitted edit and the pulled rule stay in the clone; user files are spared | same file, step "the relink keeps your edits and files" | same step, also the settings key still present with its value and `CLAUDE.md` byte-identical (every planted file is now compared as bytes) |
| H-29 | the running sandbox gets the warning before the upgrade | `test_failed_upgrade.py` (warning before a failing build) | `test_upgrade_running_sandbox.py::test_upgrade_of_a_running_sandbox`, step "upgrade the running sandbox" (warning before the build start line, on a successful upgrade); `test_failed_upgrade.py` keeps the failed-build case |
| H-29 | sbx-upgrade recreates the container, which runs | `test_persistence.py`, step "upgrade the stopped sandbox" | the new scenario, step "the container is recreated on the current image" (id changed, running, image id equal to `sbx-AGENT:test`); persistence keeps its own recreate check |
| H-29 | the last line is the versions line, the one before it says new images | `test_persistence.py`, step "upgrade the stopped sandbox" | the new scenario, step "the run ends with the marker line, the images line and the tool versions" (the last three lines, equality); persistence keeps its two-line check |

The three unit tests the new scenario supersedes are deleted from `tests/unit/sbx/test_sbx_upgrade.py`: `test_a_running_sandbox_is_warned_before_the_build`, `test_the_recreate_runs_up_with_force_recreate_and_wait`, `test_the_run_ends_with_the_marker_line_the_images_line_and_the_tool_versions`. The module's `RUNNING_PREFIX` constant, left unused by the deletion, went with them, and its header and the `BuildStub` comment no longer promise an order check.

## Accomplishments

- **Task 1 (earlier commits)**: `sbx/clean.py` with `hosttest_container_verdict`, `run_dir_list`, `root_ca_dir_list`; `clean.sh` is a two-line launcher; unit tests and the launcher row.
- **Amendment A**: `AgentSpec` gained `settings_file` and `instructions_file`. The relink scenario adds the key to the existing `settings.json` object (the GSD sync may have written it already), plants `CLAUDE.md`, and after the second `sbx-init` reports a missing file, a non-JSON file or a missing key.
- **Amendment C**: `test_upgrade_running_sandbox.py` runs `sbx-upgrade NAME` on the running shared sandbox through `run_streamed` into a `StringIO`, so nothing prints to the terminal and the order is checkable. It asserts exit 0, the warning index before the `build.sh: building ` index, a new container id, running, `.Image` equal to `docker image inspect --format {{.Id}}` of the test image, and the last three lines (marker line, images line, the container's `/etc/sbx/tool-versions`). The recreate removes the init marker, so the next scenario's `sandbox` fixture runs `sbx-init` again.
- **Task 3**: `git rm -r tests/host`; `test_no_host_logic_in_shell` added (guard now 22 rules); two guard rules that still globbed the deleted directory were fixed.

## Task Commits

1. **Task 1: clean.sh in Python (tracer)**: `b4ba6cf`, `2413ae3`
2. **Task 2 amendment A (relink settings key and CLAUDE.md)**: `36ccae9`
3. **Task 2 amendment C (running-sandbox upgrade, then the superseded unit tests removed)**: `36b7ace`, `3047261`
4. **Task 3 (delete tests/host, then the guard rule)**: `293f0f8`, `0031f7d`

**Plan metadata:** the commit holding this file (docs: complete plan)

## Decisions Made

- The running-sandbox upgrade got a file of its own rather than a step in `test_persistence.py`, which does exactly one upgrade, of a stopped sandbox (D-16), and must stay independent of this one.
- The product's own comparison (`.Image` of the container against `{{.Id}}` of the image, `sbx/docker.py`) is the test's definition of "runs on the current image".
- `settings.json` is checked by key, not byte for byte, because the GSD installer legitimately writes into it; `CLAUDE.md` and the other planted files are compared as bytes.

## Deviations from Plan

**1. [Scope] The integration suite collects 33 tests, not 31**
- The amendment adds one scenario for each of two agents. Task 3's verify expected 31; it was run with 33 as the expected count.

**2. [Scope] AgentSpec gained two fields and `ROOT_SCRIPT_NAME_LIST` became public**
- `settings_file` and `instructions_file` carry the Claude-only user files (the amendment asked for declaration through `agent_specs.py`). The guard helper's root script list lost its underscore so the new rule shares it instead of repeating it.

**3. [Rule 1 - Bug] Two guard rules still pointed at the deleted tests/host/**
- `test_guard_supply_chain.py` listed `tests/host/support/**/*` and `tests/host/*.sh`; `test_guard_isolation.py` globbed `REPO_DIR / "tests" / "host"` (written as path parts, so the plan's text grep for `tests/host/` missed it). Both lines were removed; the globs matched nothing, so no rule lost coverage.

**4. [Scope] Plan 08's deviation 3 is reversed**
- Plan 08 left the settings key and `CLAUDE.md` out of the relink scenario as Claude-only files. Amendment A puts them back, as the old check had them.

**5. [Pre-existing, left] `BuildStub.docker_call_count_list` is written and never read**
- It was already unused before this plan's deletion, so it stays.

## Issues Encountered

None.

## Requirements

- **HOST-05** is complete: the bash host checks, libraries and runner are deleted, no tracked `.sh` file exists under `tests/`, no stand-in `docker`, `xattr`, `shellcheck` or `hadolint` is tracked, and the guard rule fails if one returns. The remaining mentions of `tests/host/` are in the docs plan 10 rewrites (`README.md`, `tests/README.md`, `tests/host-checklist.md`, `GLOSSARY.md`) and under `.planning/`.
- **HOST-04** stays **Pending**: its scenarios (now including the amended relink and the running-sandbox upgrade) have not run on a real host. The real run is the phase's final check.

## User Setup Required

None. At the end of the phase run `./host-test.sh` on the Mac and read `host-test.log`.

## Known Stubs

None.

## Threat Flags

None. T-10-20: `hosttest_container_verdict` removes a container only when its workspace mount is in a host-test run directory (unit tested in Task 1). T-10-21: the map was reviewed and amended by the user before `tests/host/` was deleted, and git keeps the history. T-10-SC: no package installed.

## Next Phase Readiness

- Likely findings of the real run: whether the GSD installer touches `settings.json` in a way that drops a user key (amendment A would then name it); whether `.Image` equals `{{.Id}}` under Docker Desktop's image store (the product's older-image mark relies on the same comparison).
- Plan 10 rewrites the docs that still name `tests/host/`.

## Self-Check: PASSED

- Commits `b4ba6cf`, `2413ae3`, `36ccae9`, `36b7ace`, `3047261`, `293f0f8`, `0031f7d` exist on `feat/host-side-to-python`; `git rev-list --count d5d635f..HEAD` was 7 before this file was committed.
- `tests/integration/test_upgrade_running_sandbox.py` and `sbx/clean.py` exist; `tests/host` does not.
