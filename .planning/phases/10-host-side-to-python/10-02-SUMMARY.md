---
phase: 10-host-side-to-python
plan: 02
subsystem: infra
tags: [python, uv, launcher, sbx-add, sbx-start, sbx-stop, sbx-shell, compose, overlap, pytest]

requires:
  - phase: 10-host-side-to-python
    provides: the sbx package core (cli, names, registry, docker), the two-line uv launcher shape, the NAME.json registry and the DockerRecorder test helper
provides:
  - sbx/overlap.py with check_host_path, locate_dir and paths_overlap, which resolves both paths itself
  - sbx-add, sbx-start, sbx-stop and sbx-shell in Python behind two-line uv launchers, on NAME.json
  - the Compose layer of sbx/docker.py (compose_command, run_compose, require_docker, require_images, check_sandbox_dirs, warn_sessions_close, bring_up_sandbox)
  - an injectable exec for sbx-shell, so the final docker exec is a recorded call in tests
affects: [10-03, 10-04, 10-05, 10-06, 10-07, 10-08, 10-09, 10-10, 10-11]

actuals:
  tokens: 36000
  tasks: 3
  commits: 5
plan_head_before: 154c8a928ab9771be2fb90480d15ef2881ec49fe
plan_head_after: d97840d60e0d4241de775e038615dfadcc0764c3

tech-stack:
  added: []
  patterns:
    - "Overlap is per directory: both paths go through os.path.realpath, the existing parts are compared with os.path.samefile, a missing tail is compared per part without letter case, and anything unresolvable (NUL byte, relative path, OSError) counts as an overlap"
    - "compose_command is pure: it rebuilds the environment per call, drops every COMPOSE_ key, and sets SBX_NAME, SBX_DIR, SBX_AGENT and SBX_IMAGE_TAG from the entry and the checked tag only"
    - "A command that ends in a process hand-over takes the exec as a parameter (exec_function, default os.execvpe); tests pass a recording function"
    - "Each ported command has main(argument_list, environ, docker, repo_dir) and is registered in LAUNCHER_BAD_ARGUMENTS_MAP"

key-files:
  created:
    - sbx/overlap.py
    - sbx/add.py
    - sbx/start.py
    - sbx/stop.py
    - sbx/shell.py
    - tests/unit/sbx/test_sbx_overlap.py
    - tests/unit/sbx/test_sbx_add.py
    - tests/unit/sbx/test_sbx_compose.py
    - tests/unit/sbx/test_sbx_start_stop.py
    - tests/unit/sbx/test_sbx_shell.py
  modified:
    - sbx/docker.py
    - bin/sbx-add
    - bin/sbx-start
    - bin/sbx-stop
    - bin/sbx-shell
    - tests/unit/sbx/test_sbx_launchers.py
    - tests/unit/sbx/sbx_helpers.py
    - tests/unit/sbx/lib.sh
    - tests/unit/sbx/fix-modes.sh
    - tests/unit/sbx/upgrade.sh
  deleted:
    - tests/unit/sbx/add.sh
    - tests/unit/sbx/entry.sh
    - tests/unit/sbx/start.sh
    - tests/unit/sbx/shell.sh

key-decisions:
  - "paths_overlap resolves both paths itself, so a caller cannot forget to; a symlink to another sandbox directory and a .. part that lands inside it both overlap when the function is called directly"
  - "sbx-stop keeps the bash behavior: name, entry, then compose stop; it checks no directory and does not ask Docker first, so a sandbox whose directory moved can still be stopped"
  - "bin/sbx-lib.sh is untouched; the bash commands that remain (sbx-upgrade, sbx-rm, sbx-fix-modes) and the guard rule still read it"

patterns-established:
  - "Test the hand-off with data, not with grep: the agent and the tag reaching Compose is a unit test on compose_command"
  - "Bash groups that still drive a bash command plant the older entry format with plant_sandbox instead of calling the ported sbx-add"

requirements-completed: []

coverage:
  - id: D1
    description: "paths_overlap, called directly, treats a path through a symlink to another sandbox directory, a path with a .. part that lands inside it, the same directory, nesting both ways, a not-yet-made tail that differs only in letter case and an unresolvable path (NUL byte) as overlaps, and /x/sbx against /x/sbx-other and two different new paths as no overlap"
    requirement: HOST-03
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_overlap.py"
        status: pass
    human_judgment: false
  - id: D2
    description: "sbx-add keeps the bash order and wording of its refusals (usage, config directory, tag, name, registered, host path text, registry directory, tools clone, each other sandbox in byte order), makes nothing on a refusal, writes NAME.json with the path byte for byte, and a second add leaves the file bytes unchanged"
    requirement: HOST-01
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_add.py"
        status: pass
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_launchers.py (add launcher stores a path with a space and a non-ASCII letter as given)"
        status: pass
    human_judgment: false
  - id: D3
    description: "compose_command builds 'compose --env-file /dev/null -p sbx-NAME -f REPO/compose.yml ...' with the SBX values from the entry and the checked tag and no COMPOSE_ key; sbx-start and sbx-stop refuse in order and print the bash lines"
    requirement: HOST-01
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_compose.py"
        status: pass
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_start_stop.py"
        status: pass
    human_judgment: false
  - id: D4
    description: "sbx-shell on a running sandbox never calls compose and ends in one exec of 'docker exec -it -w /home/sandbox/workspace/NAME sbx-NAME bash'; a stopped sandbox is brought up first; Docker down is refused before compose and the exec without sbx-upgrade advice"
    requirement: HOST-01
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_shell.py"
        status: pass
    human_judgment: false
  - id: D5
    description: "The real exec under uv on macOS (exit status and Ctrl-C of the shell reach the caller through the launcher) and a real compose up through the new commands"
    requirement: HOST-01
    verification:
      - kind: manual_procedural
        ref: "host run of tests/host h28 and h31 after the later plan that updates them"
        status: not_run
    human_judgment: true
    rationale: "Docker and macOS exist only on the host; the host groups still read the older entry format until the plan that ports them"

duration: about 25min
completed: 2026-11-20
status: complete
---

# Phase 10 Plan 02: sbx-add, sbx-start, sbx-stop and sbx-shell in Python Summary

**The four everyday commands run as Python behind two-line uv launchers on NAME.json, with one overlap function that resolves both paths (symlinks and .. included) and one pure Compose function that drops every COMPOSE_ key; the agent and tag hand-off to Compose is now a unit test.**

## Performance

- **Duration:** about 25 min (commits 01:44 to 01:46 UTC; the start time was not recorded)
- **Completed:** 2026-11-20
- **Tasks:** 3 (one tracer, two TDD)
- **Files modified:** 26 (10 created, 12 modified, 4 deleted, counting the test and bash files)

## Accomplishments

- `sbx/overlap.py`: `check_host_path` keeps the bash order and wording; `locate_dir` applies `os.path.realpath` and walks up to the deepest directory; `paths_overlap` compares the existing parts with `os.path.samefile`, the missing tails per part without letter case, and returns True on `OSError` or `ValueError`. The unit tests call it directly with `..` and symlink paths (the part the bash version only handled after its own resolve step).
- `sbx-add` refuses in the planned order and makes nothing on a refusal; a broken other entry stops the add with its own error; the path is stored as given.
- `compose_command` rebuilds the environment on every call; the caller's `SBX_DIR`, `SBX_NAME`, `SBX_AGENT` and every `COMPOSE_*` key never reach Compose (unit test with ambient values).
- `sbx-start`, `sbx-stop` and `sbx-shell` share `bring_up_sandbox`; `sbx-shell` takes `exec_function` so the final `docker exec -it` is a recorded call.
- Four launchers are two lines and mode 100755; four bash unit groups (`add.sh`, `entry.sh`, `start.sh`, `shell.sh`) are deleted.
- Results: `uv run pytest -q` 735 passed (272 in `tests/unit/sbx`); `bash tests/unit/sbx/run-all.sh` ends `All cases pass.`; `bash tests/guard/run-all.sh` ends `All rules hold.`.

## Task Commits

1. **Task 1: sbx-add with the resolved overlap check (tracer)**: `17f87cd` (feat). The tracer verify (both automated commands) passed before Task 2 began, so the slice was proven end to end before it was expanded.
2. **Task 2: the Compose layer, sbx-start and sbx-stop**: `41b4928` (test, RED) and `fafbf89` (feat, GREEN)
3. **Task 3: sbx-shell with an injectable exec**: `d2b6f80` (test, RED) and `d97840d` (feat, GREEN)

**Plan metadata:** the commit holding this file (docs: complete plan)

## Files Created/Modified

- `sbx/overlap.py`, `sbx/add.py`: the overlap rules and sbx-add
- `sbx/docker.py`: gains the Compose layer (the functions of the interfaces block)
- `sbx/start.py`, `sbx/stop.py`, `sbx/shell.py`: the other three commands
- `bin/sbx-add`, `bin/sbx-start`, `bin/sbx-stop`, `bin/sbx-shell`: two-line uv launchers
- `tests/unit/sbx/test_sbx_{overlap,add,compose,start_stop,shell}.py`: the new suites; `test_sbx_launchers.py` gains four map rows and an add-launcher case
- `tests/unit/sbx/sbx_helpers.py`: the recorder also notes environment and capture flag
- `tests/unit/sbx/lib.sh`, `fix-modes.sh`, `upgrade.sh`: `plant_sandbox` for the groups that still run bash commands

## Decisions Made

- `paths_overlap` fails closed on a relative path, a NUL byte and any `OSError`, as the plan asked; `locate_dir` raises `ValueError` for the first two so one `except` covers every case.
- `sbx-stop` ports the bash behavior (see Deviations 3).
- `bin/sbx-lib.sh` stays as it is for the commands that have not moved; the guard rule that greps it still holds.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Remaining bash groups used the ported sbx-add**
- **Found during:** Task 1
- **Issue:** `fix-modes.sh`, `upgrade.sh`, `start.sh` and `shell.sh` registered their sandboxes with `sbx-add`, which now writes NAME.json, while the bash commands they test (`sbx-fix-modes`, `sbx-upgrade`, `sbx-start`, `sbx-shell`, later `sbx-rm`) still read the older file. Four of them failed after the port, so `run-all.sh` could not end `All cases pass.` as the task verify requires.
- **Fix:** a `plant_sandbox NAME PATH` helper in `lib.sh` makes the two directories and plants the older entry; the five call sites use it. The helper and its uses go away when the plan that ports each command rewrites its group.
- **Files modified:** `tests/unit/sbx/lib.sh`, `fix-modes.sh`, `upgrade.sh`, `start.sh`, `shell.sh`
- **Commit:** `17f87cd`

**2. [Rule 3 - Blocking] The recorder did not note the environment**
- **Found during:** Task 2 (RED tests)
- **Issue:** The compose tests must see the environment handed to Docker, but `DockerRecorder` kept only argument lists.
- **Fix:** the recorder also keeps `environ_list` and `capture_list`; existing tests are unaffected.
- **Files modified:** `tests/unit/sbx/sbx_helpers.py`
- **Commit:** `41b4928`

### Other deviations

**3. sbx-stop refusals.** The plan's behavior block says "refusals as start" and the key truth lists the order name, entry, directories, Docker, images for all three commands. The bash `sbx-stop` checks only the name and the entry, then runs `compose stop`. I kept the bash behavior: stopping must work for a sandbox whose directory moved or whose images were removed, and the user has no other way to stop it. The sbx-stop tests cover usage, name, entry, tag, a failing stop and a stop with a missing project directory.

**4. Dropped bash case.** The deleted `start.sh` also held one case that pinned the wording of `sbx-upgrade`'s warning through the bash library. The same wording is now a unit test on `warn_sessions_close`; the bash `sbx-upgrade` itself is ported by plan 10-03.

**5. Host proof not run.** The real exec under uv on macOS and a real compose up need the host. The host groups h28 and h33 compare the older entry format and are updated by plans 10-07 and 10-09, so they cannot pass on the Mac yet. Nothing in this plan changes them.

---

**Total deviations:** 5 (2 Rule 3 blockers, 3 scope notes)
**Impact on plan:** none on the contract; the two blockers are test scaffolding.

## Issues Encountered

None beyond the deviations above.

## User Setup Required

None. The first host run of `sbx-shell` through uv is the one thing to watch (exit status and Ctrl-C of the shell reach the caller); the host check for it is in the later host plans.

## Known Stubs

None.

## Threat Flags

None. The mitigations hold: both paths resolved and compared with `samefile`, unresolvable counts as overlap, tested on the function itself (T-10-04); environment rebuilt per call with every `COMPOSE_` key dropped, tested with ambient values (T-10-05); a broken other entry stops `sbx-add` with its own error (T-10-06); no package installed (T-10-SC).

## Next Phase Readiness

- Plans 10-03 onward import `compose_command`, `run_compose`, `bring_up_sandbox`, `require_docker`, `require_images`, `check_sandbox_dirs` and `warn_sessions_close` from `sbx.docker`, and `paths_overlap` from `sbx.overlap`.
- HOST-01 (every `bin/sbx-*` command, `build.sh`, `host-test.sh`) and HOST-02 (the JSON registry for every command) stay Pending: `sbx-upgrade`, `sbx-rm`, `sbx-fix-modes`, `build.sh` and `host-test.sh` are still bash and still read the older entry format. HOST-03 stays Pending too: the overlap check is done and unit-tested in `sbx-add`, but it is left for the phase verification to close it.
- `plant_sandbox` in `tests/unit/sbx/lib.sh` is temporary scaffolding; delete it with the last bash group.

## Self-Check: PASSED

- Commits `17f87cd`, `41b4928`, `fafbf89`, `d2b6f80`, `d97840d` exist on `feat/host-side-to-python`.
- `sbx/overlap.py`, `sbx/add.py`, `sbx/start.py`, `sbx/stop.py`, `sbx/shell.py` and the five new test files exist; the four launchers are two lines and 100755; `add.sh`, `entry.sh`, `start.sh` and `shell.sh` are gone and `ls tests/unit/sbx/*.sh` lists only `fix-modes.sh`, `image-tag.sh`, `lib.sh`, `rm.sh`, `run-all.sh`, `upgrade.sh`.
- `uv run pytest -q`: 735 passed; `tests/unit/sbx/run-all.sh`: All cases pass.; `tests/guard/run-all.sh`: All rules hold.; no non-ASCII byte in `sbx/` or `tests/unit/sbx/*.py`; no planning ID in `sbx`, `tests/unit/sbx` or `bin`.

---
*Phase: 10-host-side-to-python*
*Completed: 2026-11-20*
