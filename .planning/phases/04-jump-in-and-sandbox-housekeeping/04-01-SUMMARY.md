---
phase: 04-jump-in-and-sandbox-housekeeping
plan: 01
subsystem: infra
tags: [bash, docker-compose, sbx-shell, selftest, host-checks]

requires:
  - phase: 03-remembered-sandboxes-and-one-command-upgrade
    provides: registry, sbx-lib.sh, sbx-start, sbx-stop, the scripted-docker self-test
provides:
  - bin/sbx-shell: jump into a registered sandbox with one command
  - bring_up_sandbox and runs_older_image in bin/sbx-lib.sh, shared by sbx-start, sbx-shell and (plan 02) sbx-list
  - sbx-start ends with the sbx-shell NAME hint
  - docker-free self-test group tests/selftest/sbx/shell.sh and three stand-in knobs
  - host check H-31 and the attended helper h31-jump-in.sh
affects: [04-02 sbx-list, 04-03 sbx-rm, 04-04 docs, 04-05 gate and Mac run]

actuals:
  tokens: 8377
  tasks: 3
  commits: 3
plan_head_before: 8c99900ac2f2c1c8a35d5f94a4c9bd5be7af774a
plan_head_after: 2ce13b477572e73afc67700c5cfaec89eeff53f3

tech-stack:
  added: []
  patterns:
    - "start steps written once in the library (bring_up_sandbox), called from a plain statement, never inside an if test or with || exit"
    - "final command of a host script is exec, so the shell's exit status is the script's"
    - "scripted docker knobs are files in standin-state; set_standin_knob runs after set_standin_state"

key-files:
  created:
    - bin/sbx-shell
    - tests/selftest/sbx/shell.sh
    - tests/host/h31-sbx-shell.sh
    - tests/host/manual/h31-jump-in.sh
  modified:
    - bin/sbx-lib.sh
    - bin/sbx-start
    - tests/selftest/sbx/lib.sh
    - tests/selftest/sbx/start.sh
    - tests/host/run-all.sh
    - tests/host-checklist.md

key-decisions:
  - "bring_up_sandbox lives in bin/sbx-lib.sh instead of sbx-shell calling sbx-start, so the jump-in prints no start lines and never warns about an image it will not recreate"
  - "sbx-shell always runs check_name and read_registry_entry, also for a running sandbox, so only a registered sandbox is entered"
  - "entering a running sandbox does not wait for its start hooks; sbx-start and sbx-shell always wait for the sandboxes they start"
  - "no terminal test in sbx-shell; Docker's own refusal is the message"
  - "one host check per command (H-31 for sbx-shell), so a failure points at one script"

patterns-established:
  - "Running path = one inspect plus the exec: mutants that always start the sandbox or open the shell in the mount point fail named cases"

requirements-completed: [SCR-04]

coverage:
  - id: D1
    description: "sbx-shell NAME starts a sandbox with no container or a stopped one through bring_up_sandbox, then opens bash in /home/sandbox/workspace/NAME as its last command"
    requirement: SCR-04
    verification:
      - kind: unit
        ref: "tests/selftest/sbx/shell.sh#sbx-shell: a sandbox with no container is started, then the shell opens"
        status: pass
      - kind: unit
        ref: "tests/selftest/sbx/shell.sh#sbx-shell: a stopped sandbox is started, then the shell opens"
        status: pass
    human_judgment: false
  - id: D2
    description: "A running sandbox (also on an older image) is entered with one inspect and the exec: no compose, no recreate, no message"
    requirement: SCR-04
    verification:
      - kind: unit
        ref: "tests/selftest/sbx/shell.sh#sbx-shell: a running sandbox gets the shell only"
        status: pass
      - kind: unit
        ref: "tests/selftest/sbx/shell.sh#sbx-shell: a running sandbox on an older image is entered as it is"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every refusal (usage, name rule, unregistered, missing folders, missing image, failed compose, stopped during start) comes before the shell; the shell's exit status is the script's"
    requirement: SCR-04
    verification:
      - kind: unit
        ref: "tests/selftest/sbx/shell.sh#sbx-shell: a missing image is refused before compose and the shell"
        status: pass
      - kind: unit
        ref: "tests/selftest/sbx/shell.sh#sbx-shell: the exit status of the shell is the exit status of sbx-shell"
        status: pass
    human_judgment: false
  - id: D4
    description: "Real Docker and a real terminal: H-31 through BSD script, and Claude opening already logged in after a stop and a new sbx-shell"
    requirement: SCR-04
    verification: []
    human_judgment: true
    rationale: "Docker is not available in the dev sandbox; tests/host/h31-sbx-shell.sh and tests/host/manual/h31-jump-in.sh run on the Mac in plan 05"

duration: 68min
completed: 2026-11-07
status: complete
---

# Phase 4 Plan 01: sbx-shell Tracer Summary

**sbx-shell NAME starts a sandbox when needed through start steps shared with sbx-start (bring_up_sandbox in the library), then execs bash in the project folder; a running sandbox is entered as it is. Pinned by 19 docker-free cases, two mutants, H-31 and an attended login helper.**

## Performance

- **Duration:** 68 min
- **Started:** 2026-11-07T03:00:40Z
- **Completed:** 2026-11-07T04:09:00Z
- **Tasks:** 3
- **Files modified:** 10 (4 created, 6 modified)

## Accomplishments

- `bin/sbx-lib.sh` gains `runs_older_image NAME` (status only, false for a missing, stopped or unreadable container) and `bring_up_sandbox NAME` (folders, image, the older-image warning, `up -d --wait`, the start-hook wait). `bin/sbx-start` is now the registry read, `bring_up_sandbox`, and two closing lines, the last being `sbx-start: open a shell with: sbx-shell NAME`.
- `bin/sbx-shell` (100755): name check and registry read always run; `bring_up_sandbox` only when the sandbox is not running; the last command is `exec docker exec -it -w "/home/sandbox/workspace/$1" "sbx-$1" bash`, so the shell's exit status and Ctrl-C belong to the shell. It prints nothing of its own.
- Self-test: the scripted docker gains `shell-status`, `compose-fail` and `image-missing`; `set_standin_knob`, `reset_standin_calls` and `appears_before` live in `tests/selftest/sbx/lib.sh`; `tests/selftest/sbx/shell.sh` covers refusals, start paths, the running path, exit status and failed starts.
- `tests/host/h31-sbx-shell.sh` (H-31, after H-29 in the chain) and `tests/host/manual/h31-jump-in.sh` (attended, `sbx-claude` login survives a stop and a new `sbx-shell`) are ready for the Mac run.

## Evidence

Branch: `chore/planning-phase-04-context` (the dispatch said to stay on it; no branch was created or pushed).

Tracer, run through PATH with a stand-in docker and bogus exported `SBX_DIR`, `SBX_NAME`, `COMPOSE_PROJECT_NAME`:

```
docker compose --env-file /dev/null -p sbx-demo -f <repo>/compose.yml up -d --wait   (SBX_NAME=demo SBX_DIR=<folder with a space>)
docker exec sbx-demo pgrep -x sleep
docker exec -it -w /home/sandbox/workspace/demo sbx-demo bash                          (exit 7 passed through)
```

A running sandbox made exactly two calls: `docker container inspect --format {{.State.Running}} sbx-demo` and the `docker exec -it ...` line; stdout stayed empty.

- Self-test: `bash tests/selftest/sbx/run-all.sh` ends `All cases pass.` with 106 PASS lines.
- Mutant that always starts the sandbox (`if true; then`): `FAIL: sbx-shell: a running sandbox gets the shell only` (plus the older-image entered-as-is and no-message cases).
- Mutant that opens the shell in the mount point: `FAIL: sbx-shell: the shell opens in the project folder` (plus the three start-path cases that assert the folder).
- Rehearsal guard tail: `PASS: every_dockerfile_arg_is_pinned` then `All rules hold.` (19 PASS lines; `host_scripts_keep_sandbox_data` passes, no `bin/` file says rm, rmdir, prune, kill or down).
- shellcheck at warning level prints nothing for the new and changed files.

Line counts: `bin/sbx-lib.sh` 301, `bin/sbx-start` 24, `bin/sbx-shell` 36, `tests/selftest/sbx/shell.sh` 219, `tests/host/h31-sbx-shell.sh` 194, `tests/host/manual/h31-jump-in.sh` 111.

## Task Commits

1. **Task 1: Tracer, sbx-shell and the shared start steps** - `7ed9ead` (feat)
2. **Task 2: Docker-free self-test of every sbx-shell path** - `844315e` (test)
3. **Task 3: H-31, the attended helper, runner entry, checklist rows** - `2ce13b4` (test)

**Plan metadata:** the commit that adds this file and the STATE and ROADMAP updates (docs).

## Files Created/Modified

- `bin/sbx-shell` - jump-in: start when needed, then bash in the project folder
- `bin/sbx-lib.sh` - `runs_older_image`, `bring_up_sandbox`; three over-long comment lines rewrapped
- `bin/sbx-start` - uses `bring_up_sandbox`; closing hint names `sbx-shell`
- `tests/selftest/sbx/lib.sh` - knobs `shell-status`, `compose-fail`, `image-missing`; helpers `set_standin_knob`, `reset_standin_calls`, `appears_before`
- `tests/selftest/sbx/start.sh` - hint case added; `appears_before` moved out
- `tests/selftest/sbx/shell.sh` - the sbx-shell group
- `tests/host/h31-sbx-shell.sh`, `tests/host/manual/h31-jump-in.sh`, `tests/host/run-all.sh`, `tests/host-checklist.md` - the Mac run

## Decisions Made

- Start steps shared as a library function, not by calling `sbx-start` (no duplicate start lines, no warning for an image the jump-in would not recreate).
- `check_name` and `read_registry_entry` run for a running sandbox too, so a bad or unregistered name never reaches `-w` or the container name.
- A running sandbox is entered without waiting for start hooks; plan 04 documents it in one sentence.
- H-31 sends the shell its input only once `pgrep -x bash` succeeds in the container and keeps the input open until the shell wrote its file. Whether BSD `script` gives `sbx-shell` a terminal with piped input is a Mac assumption for plan 05; the FAIL text names the helper if it does not.

## Deviations from Plan

None - plan executed exactly as written, with these notes:

- The plan's first step (`git switch -c chore/phase-04-run`) was skipped because the dispatch prompt said to stay on the current branch; the plan itself allows this.
- The plan's output section says to leave `.planning/` files uncommitted; the dispatch prompt required a committed SUMMARY and updated STATE and ROADMAP, so those are committed in a separate planning commit with no code in it.
- Message wording matches the plan; the only wording choice of mine is the shell.sh banner and helper names (`started_then_shell`, `entered_as_it_is`, `quiet_run`, `failed_without_shell`, `refused_before_shell`), which the plan left open.

**Total deviations:** 0 auto-fixed. **Impact on plan:** none.

## Issues Encountered

None. Docker is not available here, so H-31 and the helper were checked only for syntax, lint, comment width, ASCII and the no-terminal refusal of the helper (`This helper needs a terminal.`, exit 1).

## Known Stubs

None.

## Threat Flags

None. No new network endpoint, auth path or file access beyond the plan's threat model; the interactive exec gives the container's bash the user's terminal, as accepted in the plan.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02 can use `runs_older_image` from the library for the `sbx-list` marker.
- H-31 and `tests/host/manual/h31-jump-in.sh` run on the Mac in plan 05; the BSD `script` pty assumption is the one open point.

---
*Phase: 04-jump-in-and-sandbox-housekeeping*
*Completed: 2026-11-07*
