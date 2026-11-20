---
phase: 10-host-side-to-python
plan: 07
subsystem: testing
tags: [python, pytest, integration, smoke, pty, docker, sbx-add, sbx-start, sbx-stop, sbx-shell, sbx-list, sbx-rm]

requires:
  - phase: 10-host-side-to-python
    provides: the integration harness (AgentSpec rows, step, run_sbx, sandbox fixture, one_bind_mount_problem, other_sbx_container_map) and the plan 06 scenarios
provides:
  - test_add_start_stop_start (commands on PATH, add, start, stop, start again)
  - test_list_shows_the_docker_state
  - test_rm_removes_the_container_and_keeps_every_file
  - test_shell_opens_bash_in_the_project_dir (pty module, exit status through uv)
  - test_git_works_on_a_repo_made_on_the_host
  - throwaway_sandbox, register_sandbox, describe_result, container_is_running, container_id_of in scenario_helpers
affects: [10-08, 10-11]

actuals:
  tokens: 11800
  tasks: 3
  commits: 4
plan_head_before: c338a01a7e9284c9b07909fa13408831dfdcf37a
plan_head_after: 6aa8ddc0518896575de16b3ec121031763167418

tech-stack:
  added: []
  patterns:
    - "A scenario that stops, removes or re-registers a sandbox works on its own throwaway sandbox hosttest-STORY-AGENT in a directory with a space; the name goes on the cleanup list as soon as sbx-add worked"
    - "sbx-shell is driven through pty.openpty() in its own session; the script text is written only once a bash runs in the container, and a timeout kills the process group"
    - "Expected sbx-list rows are written out in the scenario (31 and 20 columns), not imported, so the format has an independent oracle"

key-files:
  created:
    - tests/integration/test_sandbox_lifecycle.py
    - tests/integration/test_sandbox_list.py
    - tests/integration/test_sandbox_rm.py
    - tests/integration/test_sandbox_shell.py
    - tests/integration/test_git_on_host_repo.py
  modified:
    - tests/integration/scenario_helpers.py
    - tests/unit/sbx/test_sbx_scenario_helpers.py

key-decisions:
  - "The five helpers four scenarios share went into scenario_helpers.py with unit tests that run the real sbx-add launcher (it needs no Docker), instead of four copies of the add-and-register code"
  - "The pty helper stays private in the shell scenario file, as the plan says, and was checked once by hand against stand-in sbx-shell and docker scripts (exit status 3 passed through, a hung shell killed on the timeout)"

patterns-established:
  - "One scenario per file; a helper only one scenario uses stays in that file; a helper two or more scenarios use goes to scenario_helpers.py with a unit test"

requirements-completed: []

coverage:
  - id: D1
    description: "Lifecycle: every sbx-* command is found through PATH in the repo bin/; sbx-add writes NAME.json with path and agent and makes NAME/ and state/; a second add is refused and leaves the entry; sbx-stop before a start exits 0; sbx-start runs on the registered directory in project sbx-NAME with no entrypoint, ignoring the ambient COMPOSE_PROJECT_NAME; sbx-stop takes under 10 s and keeps files; the next start reuses the container and a start of a running sandbox prints no older-image warning"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "uv run pytest --collect-only: test_add_start_stop_start[claude] and [cursor] collected; 8 step blocks; uv run pytest -q 947 passed, 1 skipped"
        status: pass
      - kind: manual_procedural
        ref: "the real run needs Docker: ./host-test.sh on the Mac at the phase's final check"
        status: not_run
    human_judgment: true
    rationale: "Needs real Docker and Compose"
  - id: D2
    description: "List: against docker ps -a, the empty-registry line and the running labeled container in the leftover block with no cc_ line, then the throwaway as no container, running (no older-image mark) and stopped, each as the exact formatted row with its directory"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "collected for claude and cursor; read against sbx/list_sandboxes.py (row format, leftover format, no-sandboxes line)"
        status: pass
      - kind: manual_procedural
        ref: "real run on the host at the phase's final check"
        status: not_run
    human_judgment: true
    rationale: "Needs real Docker"
  - id: D3
    description: "Rm: refused without a terminal and --yes (exit 1, names --yes, still running, entry unchanged); --yes removes the container and its network (the network is shown to exist first) and keeps files, entry, history and the test images; a second rm and an rm with the directory moved away succeed; --unregister deletes only the entry; sbx-add of the same directory brings the files and history back; the other sbx- containers keep id and start time"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "collected for claude and cursor; 10 step blocks; read against sbx/rm.py messages"
        status: pass
      - kind: manual_procedural
        ref: "real run on the host at the phase's final check"
        status: not_run
    human_judgment: true
    rationale: "Needs real Docker"
  - id: D4
    description: "Shell: no terminal gives Docker's refusal after the sandbox was started; through a pseudo-terminal bash opens in /home/sandbox/workspace/NAME on a running and on a stopped sandbox without replacing the container, and exit status 3 reaches the caller through uv (assumption A6)"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "collected for claude and cursor; the pty helper checked by hand against stand-ins: exit 3 passed through, a hung shell killed after the timeout"
        status: pass
      - kind: manual_procedural
        ref: "real run on the host at the phase's final check; A6 (the status through uv) is proven only there"
        status: not_run
    human_judgment: true
    rationale: "Needs a real terminal hand-off to docker exec on the Mac"
  - id: D5
    description: "Git: a repository made with git on the host in the project directory gives git status exit 0 in the container with no dubious-ownership message"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "collected for claude and cursor"
        status: pass
      - kind: manual_procedural
        ref: "real run on the host at the phase's final check"
        status: not_run
    human_judgment: true
    rationale: "Needs a real container"
  - id: D6
    description: "The new shared helpers (throwaway_sandbox, register_sandbox, describe_result, container_is_running, container_id_of) behave as specified"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_scenario_helpers.py: 7 new cases, 28 pass; register_sandbox runs the real sbx-add launcher on a temporary registry"
        status: pass

duration: about 40min
completed: 2026-11-20
status: complete
---

# Phase 10 Plan 07: Smoke scenarios for add, start, stop, shell, list, rm and git Summary

**Five scenario files on the harness, each run once per agent on a throwaway sandbox: add, start and stop by name, `sbx-list` against `docker ps -a`, `sbx-rm` and its `--unregister` and re-add round trip, `sbx-shell` through a pseudo-terminal from the `pty` module, and git on a repository made on the host.**

These scenarios need Docker, which the dev sandbox lacks. Here they are proven by collection (`[claude]` and `[cursor]` for all five functions, ten items; 22 integration items in all), by the full suite (`uv run pytest -q`: 947 passed, 1 skipped), by unit tests of the new shared helpers, and by reading each scenario against `sbx/add.py`, `start.py`, `stop.py`, `list_sandboxes.py`, `rm.py`, `shell.py`, `docker.py` and the old host checks. **The real run happens on the host at the phase's final check (`./host-test.sh`); nothing here has run against Docker yet.**

## Accomplishments

- `test_sandbox_lifecycle.py`: eight steps. Nine commands found through PATH as `<repo>/bin/<name>`; `sbx-add` entry parsed as `{"path", "agent"}` plus `NAME/` and `state/`; second add refused with the entry bytes unchanged; `sbx-stop` before a start exits 0; `sbx-start` gives a running container with one bind mount, project label `sbx-NAME` (the decoy `COMPOSE_PROJECT_NAME` ignored), no entrypoint, and a host-written file read back inside; `sbx-stop` under 10 s with files unchanged and a second stop ok; the next start reuses the container id; a start of a running sandbox prints no `older image` text.
- `test_sandbox_list.py`: four steps. Empty registry (a fresh empty config directory) prints the no-sandboxes line and lists the running shared sandbox in the leftover block with no `cc_` line; then the throwaway's exact row as `no container`, `running` (also absent from the leftover block) and `stopped`, each cross-checked with `docker ps -a` (none, running, exited).
- `test_sandbox_rm.py`: ten steps. Sentinels in the project directory, the state directory and `$HISTFILE`; refusal without a terminal; `--yes` removal with the network shown to exist first, the sessions warning, the closing line, the two test images kept; a second rm; an rm with the directory renamed away (restored in a `finally`); `--unregister`; add and start again with every file and the history line back; the other `sbx-` containers unchanged.
- `test_sandbox_shell.py`: five steps. `_shell_through_pty` runs `sbx-shell NAME` on a `pty.openpty()` terminal in its own session. A running sandbox gives exit status 3 and the working directory in a file; a stopped one is started again (same container id).
- `test_git_on_host_repo.py`: two steps, on the shared sandbox; the repository directory is removed by a finalizer.
- `scenario_helpers.py`: five shared helpers (`throwaway_sandbox`, `register_sandbox`, `describe_result`, `container_is_running`, `container_id_of`), with seven unit cases.

## Task Commits

0. **Shared helpers and their unit tests**: `07de5a3`
1. **Task 1: lifecycle (tracer)**: `0c9e140`
2. **Task 2: list and rm**: `a90f819`
3. **Task 3: shell and git**: `6aa8ddc`

**Plan metadata:** the commit holding this file (docs: complete plan)

The tracer gate (auto mode off, `human_verify_mode` end-of-phase, automated-only verify) was the collection re-run, which passed; the lifecycle scenario's real run is part of the phase's final check.

## Decisions Made

- Four scenarios start by registering a throwaway sandbox, so that code (name, directory with a space, `sbx-add`, cleanup list) became `throwaway_sandbox` and `register_sandbox` in `scenario_helpers.py`, not four copies. `register_sandbox` adds a name to the cleanup list once only, so the rm scenario's second add does not double it.
- The expected `sbx-list` rows are spelled out in the list scenario instead of imported from `sbx/`, so a change to the format shows as a failing scenario.

## Deviations from Plan

**1. [Rule 2 - Missing critical functionality] The pty helper waits for a bash before it writes, and returns a result, not an int**
- **Found during:** Task 3
- **Issue:** the plan has `_shell_through_pty` write the script at once and return the exit status. Input written before Docker has put the terminal in raw mode may be lost on some systems (the old check waited for a bash first), and a bare status gives no output when the scenario fails.
- **Fix:** the helper probes `docker exec CONTAINER pgrep -x bash` about once a second and writes the script when one runs; it returns a `CommandResult` (exit status, terminal output, timed-out flag). The exit status and the process-group kill on a timeout are as planned.
- **Files modified:** `tests/integration/test_sandbox_shell.py`
- **Commit:** `6aa8ddc`

**2. [Interpretation] The list scenario takes the `sandbox` fixture, not `shared_sandbox`**
- The plan names `shared_sandbox`. `sandbox` depends on it and also starts the sandbox again when an earlier scenario left it stopped, which the empty-registry step needs (it expects a running container in the leftover block).

**3. [Interpretation] The rm scenario starts and stops the sandbox before the moved-directory step**
- With no container left after the first rm, an rm with the directory moved away would pass without removing anything. A start and a stop first make the container exist, so its absence afterwards is not vacuous (the old check did the same).

**4. [Interpretation] The history line is appended to `$HISTFILE` through a container shell**
- `printf TEXT >> "$HISTFILE"` in `docker exec bash -c`, after `mkdir -p` of its directory, because `sbx-init` is not run here. The persistence scenario already proves that an interactive shell writes history per command.

**5. [Scope] `scenario_helpers.py` and its unit test file were modified**
- Not in the plan's `files_modified`, needed for the shared helpers (Decisions Made).

## Issues Encountered

None. The first hand check of the pty helper failed only because the stand-in `docker` was not on the PATH of the probe (the helper's own docker calls use the process environment, as every other helper does); with the stand-in on the PATH it passed.

## Requirements left Pending, and why

- **HOST-04** stays Pending: it also needs plan 08, and none of the scenarios has run on a real host yet.
- **HOST-01** stays Pending: `clean.sh` is still to convert (plan 08 and later).
- **HOST-02, HOST-03, HOST-05** stay Pending (unchanged).

## User Setup Required

None. The host run at the phase's final check is `./host-test.sh` on the Mac; read `host-test.log` afterwards.

## Known Stubs

None.

## Threat Flags

None. T-10-17: every name starts `hosttest-`, every entry lives in the run directory's test registry, and the only removal is `sbx-rm` (the scenarios delete no file; the git scenario removes only the repository directory it made, with `mkdir` refusing a pre-existing one). T-10-18: the pty helper kills its process group on a timeout (checked by hand). T-10-SC: no package installed.

## Next Phase Readiness

- Plan 08 can reuse `throwaway_sandbox`, `register_sandbox` and the container helpers.
- Likely first findings of the real run: the pty hand-off on macOS (assumption A6, the exit status through uv), the `not a tty` wording of Docker, the 10 s stop limit, and `docker network inspect` naming (`<container>_default`).
- Throwaway containers stay up until the run ends (cleanup is at session end), so eight more containers run beside the two shared ones.

## Self-Check: PASSED

- Commits `07de5a3`, `0c9e140`, `a90f819`, `6aa8ddc` exist on `feat/host-side-to-python`; `git rev-list --count c338a01..HEAD` was 4 before this file was committed.
- The five scenario files exist under `tests/integration/`.
- `uv run pytest -q`: 947 passed, 1 skipped; ASCII and planning-ID scans of `tests/integration` print nothing.
