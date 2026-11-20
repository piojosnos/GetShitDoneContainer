---
phase: 10-host-side-to-python
plan: 01
subsystem: infra
tags: [python, uv, launcher, registry, json, docker, pytest, sbx-list, sbx-migrate-registry]

requires:
  - phase: 09-sbx-init-replaces-the-start-hooks
    provides: the Python module shape (main returns an exit code, injected dependency with a real default) and the pytest layout
provides:
  - the sbx package core (cli, names, registry, docker), standard library only
  - sbx-list in Python behind a two-line uv launcher, reading NAME.json
  - sbx-migrate-registry, the one-off converter from KEY=value entries to NAME.json
  - the exclusive registry writer (write_entry) and the Docker boundary (run_docker passed in as a parameter)
  - the pytest suite tests/unit/sbx (launcher, list, names, registry, migration) with a DockerRecorder helper
  - a host proof on a copy of the real registry (uv on macOS, migration, listing)
affects: [10-02, 10-03, 10-04, 10-05, 10-06, 10-07, 10-08, 10-09, 10-10, 10-11]

actuals:
  tokens: 20000
  tasks: 3
  commits: 4
plan_head_before: 670d0b048515efb18e21786fdd398daf1b87f996
plan_head_after: 318d528734c7d08fd1a6eebc72d13b9d5e538765

tech-stack:
  added: [uv launcher on the host (brew install uv is the only host prerequisite)]
  patterns:
    - "Two-line /bin/sh launcher: exec uv run --directory REPO --no-project --python 3.12 --quiet python -m sbx.MODULE; --no-project keeps the host from writing a .venv into the shared repo"
    - "Every command module has main(argument_list, environ, docker) -> int and ends with sys.exit(main(sys.argv[1:]))"
    - "Docker is a parameter (run_docker by default); tests pass a recorder object, never a stand-in executable or a patch"
    - "Registry entry is NAME.json with path and agent, parsed with json.loads, created exclusively (mode x), never resolved or executed"
    - "SbxError and UsageError caught in run_command: exit 1 with 'command: text' or exit 2 with one Usage line"

key-files:
  created:
    - sbx/__init__.py
    - sbx/cli.py
    - sbx/names.py
    - sbx/registry.py
    - sbx/docker.py
    - sbx/list_sandboxes.py
    - sbx/migrate_registry.py
    - bin/sbx-migrate-registry
    - tests/unit/sbx/conftest.py
    - tests/unit/sbx/sbx_helpers.py
    - tests/unit/sbx/test_sbx_launchers.py
    - tests/unit/sbx/test_sbx_list.py
    - tests/unit/sbx/test_sbx_names.py
    - tests/unit/sbx/test_sbx_registry.py
    - tests/unit/sbx/test_sbx_migrate_registry.py
  modified:
    - bin/sbx-list
    - pyproject.toml
    - MIGRATION.md
  deleted:
    - tests/unit/sbx/list.sh

key-decisions:
  - "The old KEY=value format is known only to sbx/migrate_registry.py; every other command reads NAME.json only"
  - "A missing docker binary reads as Docker not answering (DockerResult 127), so sbx-list refuses with its Docker message instead of a traceback"
  - "sbx-migrate-registry never deletes, renames or edits an old file; the user deletes them once each sandbox starts"

patterns-established:
  - "Launcher test: one map of bad arguments per launcher, every file in bin/ with a /bin/sh shebang must be a key"
  - "Host proof on a copy: SBX_CONFIG_DIR pointed at a copy of the real registry, so the real one is never touched"

requirements-completed: [HOST-01, HOST-02]

coverage:
  - id: D1
    description: "sbx-list runs from a two-line launcher through uv into Python, reads NAME.json, reaches Docker only through run_docker, and ports the messages and row format of the bash command"
    requirement: HOST-01
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_list.py"
        status: pass
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_launchers.py"
        status: pass
      - kind: other
        ref: "bash tests/unit/sbx/run-all.sh (All cases pass.)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The registry is one NAME.json per sandbox with path and agent; broken entries are named, the path is stored as given, and write_entry refuses to overwrite"
    requirement: HOST-02
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_registry.py"
        status: pass
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_names.py"
        status: pass
    human_judgment: false
  - id: D3
    description: "sbx-migrate-registry converts old SBX_DIR and SBX_AGENT files into NAME.json, leaves every old file byte for byte, skips existing entries, and exits 1 when any file fails"
    requirement: HOST-02
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_migrate_registry.py"
        status: pass
    human_judgment: false
  - id: D4
    description: "On the host (macOS, uv 0.13.9) the migration converts a copy of the real registry (6 converted, then 6 already done) and the new sbx-list lists the same sandboxes; no .venv appears in the repo"
    requirement: HOST-01
    verification:
      - kind: manual_procedural
        ref: "/home/sandbox/workspace/registry-try.log"
        status: pass
    human_judgment: true
    rationale: "uv on macOS, real Docker and the real registry exist only on the host; the user ran the steps and approved the log"

duration: 45min (commit span of the code tasks, excluding the host checkpoint wait)
completed: 2026-11-20
status: complete
---

# Phase 10 Plan 01: Host Tracer, sbx-list and sbx-migrate-registry Summary

**sbx-list is now Python behind a two-line uv launcher on a JSON registry (NAME.json), with Docker injected as a parameter and a one-off sbx-migrate-registry for the old entries; proven on macOS against a copy of the real registry.**

## Performance

- **Duration:** about 45 min of code work (first commit 00:43, last code commit 01:26 UTC), excluding the wait for the host check
- **Completed:** 2026-11-20
- **Tasks:** 3 (two auto, one host checkpoint)
- **Files modified:** 19 (18 in the code commits, plus this plan's planning files)

## Accomplishments

- The `sbx/` package core: `cli` (SbxError, UsageError, run_command), `names` (name rule as a full ASCII match, reserved names, image tag), `registry` (Entry, read_entry, exclusive write_entry, list_entry_names) and `docker` (run_docker and the state helpers). Standard library only; `pyproject.toml` keeps `dependencies = []`.
- `bin/sbx-list` and `bin/sbx-migrate-registry` are two-line launchers (mode 100755 in the index) that work from any directory and refuse a wrong argument count with exit 2 and one `Usage:` line.
- The pytest suite `tests/unit/sbx` runs without Docker; `uv run pytest -q` reports 567 passed (the plan asked for more than 463). `bash tests/unit/sbx/run-all.sh` ends `All cases pass.` and `bash tests/guard/run-all.sh` ends `All rules hold.`.
- Host proof (read in `/home/sandbox/workspace/registry-try.log`):
  - uv 0.13.9 (Homebrew, aarch64-apple-darwin) ran both launchers on macOS.
  - First migration on a copy of the real registry: 6 converted, 0 already done, 0 not converted. Second run: 0 converted, 6 already done (idempotent).
  - The new `bin/sbx-list` on the copy and the PATH `sbx-list` agree on 5 of 6 rows. `cur1` is `running, older image` in the new list and `broken entry` in the PATH one. The PATH `sbx-list` is an older tools clone at `~/sbx-tools/GetShitDoneContainer/bin`, and the entry itself is valid (`SBX_DIR=/Users/demian/sbx-cur1`, `SBX_AGENT=cursor`), so this is not a defect of the new code.
  - The copy holds each old file next to its `NAME.json`; `git status` shows no `.venv`.

## Task Commits

1. **Task 1: sbx-list end to end (tracer)** - `57dab99` (feat)
2. **Task 2: sbx-migrate-registry, registry writer, names and registry tests** - `0b131a5` (test, RED) and `9bc4aac` (feat, GREEN)
3. **Task 3: host tracer check** - no commit (human-verify checkpoint, approved; log at `/home/sandbox/workspace/registry-try.log`)
4. **Orchestrator addition at the user's request** - `318d528` (docs: MIGRATION.md try-run section)

**Plan metadata:** the commit holding this file (docs: complete plan)

## Files Created/Modified

- `sbx/cli.py`, `sbx/names.py`, `sbx/registry.py`, `sbx/docker.py` - the package core
- `sbx/list_sandboxes.py` - sbx-list in Python
- `sbx/migrate_registry.py` - the one-off migration; the only place that knows the old format
- `bin/sbx-list`, `bin/sbx-migrate-registry` - two-line uv launchers
- `pyproject.toml` - testpaths and pythonpath gain the sbx suite; header explains why the host never runs a bare `uv run`
- `tests/unit/sbx/*.py` - launcher, list, names, registry and migration tests plus the helpers
- `tests/unit/sbx/list.sh` - deleted; its cases live in `test_sbx_list.py`
- `MIGRATION.md` - new section "Move the registry to JSON" with "Try it on a copy first"

## Decisions Made

- The old `KEY=value` format lives only in `sbx/migrate_registry.py` (D-07), so a later plan deletes one file to drop it.
- A missing `docker` binary reads as Docker not answering, so `sbx-list` gives its normal Docker message.
- Old registry files are never touched by the migration; they are left for the user to delete.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] registry._load_object UnicodeDecodeError**
- **Found during:** Task 2 (registry and migration tests)
- **Issue:** A NAME.json holding bytes that are not UTF-8 raised an uncaught UnicodeDecodeError instead of the `cannot read <file>` refusal.
- **Fix:** `_load_object` catches it and raises the named refusal, so `sbx-list` shows a `broken entry` row.
- **Files modified:** `sbx/registry.py`
- **Committed in:** `9bc4aac`

### Other deviations

**2. Branch name.** The working branch is `feat/host-side-to-python`, as the plan says. The first executor briefly named it `feat/host-python-code` and renamed it before any later work.

**3. Migration failure message.** `sbx-migrate-registry` prints `N not converted; see the lines above` and exits 1 when any file fails. The plan fixed the exit code but not this extra line.

**4. Unused docker parameter.** `migrate_registry.main` keeps the `docker` parameter it never uses, so every command module has the same `main(argument_list, environ, docker)` signature (symmetry, D-04).

**5. [Orchestrator, user request] MIGRATION.md try-run.** Commit `318d528` adds a "Move the registry to JSON" section with "Try it on a copy first" to `MIGRATION.md`, so the user can repeat the check on a work computer. Plan 10-10 will add the real-move steps under that same section.

---

**Total deviations:** 5 (1 Rule 1 bug, 4 small scope notes)
**Impact on plan:** none on the contract; the bug fix is a correctness need and the other items are additions or clarifications.

## Issues Encountered

- The PATH `sbx-list` on the host is an older clone and shows `cur1` as a broken entry, which made the two tables differ in one row. Cause confirmed from the entry file; the new code is right.

## User Setup Required

Host only: `brew install uv` (already present on the user's Mac, uv 0.13.9). Behind a TLS proxy set `UV_SYSTEM_CERTS=true` for the first Python download.

## Known Stubs

None.

## Threat Flags

None. The register's mitigations hold: json.loads and plain text lines only with no shell (T-10-01), `--no-project` launchers and no `.venv` in the host `git status` (T-10-02), one printed line per file plus a count and old files left in place (T-10-03), no package installed (T-10-SC).

## Next Phase Readiness

- The launcher shape, the JSON registry and the injected Docker function are proven on real input; plans 10-02 onward import `sbx.cli`, `sbx.names`, `sbx.registry` and `sbx.docker` unchanged.
- HOST-01 covers every `bin/sbx-*` command, `build.sh` and `host-test.sh`; this plan ports only `sbx-list`, so the later plans of the phase finish it. HOST-02 (the JSON registry) is in place for the commands ported so far; the remaining commands switch to it as they move.
- The real registry has not been moved yet; plan 10-10 adds the real-move steps to `MIGRATION.md`.

## Self-Check: PASSED

- Commits `57dab99`, `0b131a5`, `9bc4aac`, `318d528` exist on `feat/host-side-to-python`.
- `sbx/` files, both launchers (100755) and the five test files exist; `tests/unit/sbx/list.sh` is gone.
- `uv run pytest -q`: 567 passed; `tests/unit/sbx/run-all.sh`: All cases pass.; `tests/guard/run-all.sh`: All rules hold.

---
*Phase: 10-host-side-to-python*
*Completed: 2026-11-20*
