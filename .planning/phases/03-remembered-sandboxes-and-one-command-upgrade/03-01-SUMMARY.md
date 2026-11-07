---
phase: 03-remembered-sandboxes-and-one-command-upgrade
plan: 01
subsystem: infra
tags: [bash, registry, docker-compose, selftest, host-tests]

requires:
  - phase: 02-start-readiness
    provides: base/sbx-start-lib.sh name rule, compose.yml with SBX_NAME and SBX_DIR, host test harness
provides:
  - bin/sbx-lib.sh shared library (registry reader, name rule loader, run_compose, start wait)
  - bin/sbx-add, bin/sbx-start, bin/sbx-stop (register once, start and stop by name)
  - sandboxReservedNameList in base/sbx-start-lib.sh (reserved names written once)
  - docker-free self-test tests/selftest/sbx/ (54 cases)
  - host check H-28 and the Mac-shell self-test step in host-test.sh
affects: [03-02 sbx-upgrade, 03-03 version line and docs, 03-04 gate and Mac run]

actuals:
  tokens: 14900
  tasks: 3
  commits: 3
plan_head_before: a0c6109df235340bb83b2b512d80afe37a4e76eb
plan_head_after: 978416efacd76b0efef2a7b671431f9fd631b0e4

tech-stack:
  added: []
  patterns:
    - "registry entry read line by line with case, never sourced"
    - "one Compose call shape: -p sbx-NAME, -f REPO/compose.yml, --env-file /dev/null, SBX_* set on the command"
    - "stand-in docker that refuses every call keeps self-tests off the Mac's Docker"

key-files:
  created:
    - bin/sbx-lib.sh
    - bin/sbx-add
    - bin/sbx-start
    - bin/sbx-stop
    - tests/selftest/sbx/run-all.sh
    - tests/selftest/sbx/lib.sh
    - tests/selftest/sbx/add.sh
    - tests/selftest/sbx/entry.sh
    - tests/host/lib-sbx.sh
    - tests/host/h28-sbx-add-start-stop.sh
  modified:
    - base/sbx-start-lib.sh
    - tests/guard/lib.sh
    - tests/host/run-all.sh
    - host-test.sh
    - tests/host-checklist.md

key-decisions:
  - "Registry entries are two-line text files read with a case loop; a mutant that sources the entry fails the suite"
  - "sbx-add refuses a host path that is, holds or sits inside the registry folder or another sandbox's folder, compared per path segment"
  - "The reserved-name list lives only in base/sbx-start-lib.sh; bin/ reads it by sourcing that file in a subshell"
  - "SC2154 for library globals is silenced per file with a directive in sbx-add and sbx-stop, not in .shellcheckrc"

requirements-completed: [SCR-01, SCR-02]

coverage:
  - id: D1
    description: "sbx-add NAME HOST_PATH writes the two-line registry entry and creates HOST_PATH, HOST_PATH/NAME and HOST_PATH/state; sbx-start and sbx-stop then work by name through one Compose call shape"
    requirement: "SCR-01"
    verification:
      - kind: integration
        ref: "tracer command (stand-in docker records the up -d --wait and stop lines with bogus exported SBX_DIR, SBX_NAME, COMPOSE_PROJECT_NAME ignored)"
        status: pass
      - kind: unit
        ref: "tests/selftest/sbx/add.sh#sbx-add: the entry is the two lines SBX_DIR and SBX_AGENT=claude"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every bad name, bad path, registry overlap, sandbox overlap and bad registry entry is refused before Docker, and a registry value is never run"
    requirement: "SCR-01"
    verification:
      - kind: unit
        ref: "tests/selftest/sbx/run-all.sh (54 PASS, two mutants fail the matching cases)"
        status: pass
    human_judgment: false
  - id: D3
    description: "sbx-stop keeps the container and every file, a second stop exits 0, and the next sbx-start reuses the container (real Docker)"
    requirement: "SCR-02"
    verification: []
    human_judgment: true
    rationale: "H-28 needs the Mac's Docker; it is written and linted here but runs in the Mac run of plan 04"
  - id: D4
    description: "The reserved-name list is written once in base/sbx-start-lib.sh and read by the entrypoint and by bin/"
    requirement: "SCR-01"
    verification:
      - kind: unit
        ref: "tests/selftest/entrypoint/run-all.sh (state and best-practices cases)"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-11-06
status: complete
---

# Phase 3 Plan 01: Register Once, Start and Stop by Name Summary

**A sandbox registered once with sbx-add starts and stops by name alone, through a sourced bin/sbx-lib.sh that reads the name rule from the image's start library, never sources the registry entry, and runs a single Compose call shape that ignores the caller's COMPOSE_*, SBX_NAME and SBX_DIR.**

## Performance

- **Duration:** about 25 min (start time was not captured at the start; estimated from file timestamps)
- **Completed:** 2026-11-06T20:11Z
- **Tasks:** 3
- **Files modified:** 15 (10 created, 5 modified)

## Accomplishments

- `bin/sbx-lib.sh`, `bin/sbx-add`, `bin/sbx-start`, `bin/sbx-stop` (modes 100755, 100755, 100755, 100644 for the library as `git ls-files -s bin` shows).
- `sandboxReservedNameList="state best-practices"` in `base/sbx-start-lib.sh`; `check_sandbox_name` loops over it with its message unchanged; the entrypoint self-test still passes.
- Docker-free self-test `tests/selftest/sbx/`: 54 PASS lines, ends `All cases pass.`, prints `INFO: bash VERSION` first.
- Host check H-28 in the chain after H-09, `tests/host/lib-sbx.sh`, the `mac_sbx_selftest` step right after the context step, the checklist row. H-28 itself has not run (no Docker here); it runs in plan 04.
- Guard lists: `bin/*` is in `SHELL_FILES` and `SANDBOX_FILES`.

## Task Commits

1. **Task 1: Tracer, register once, start and stop by name** - `aa794c3` (feat)
2. **Task 2: Docker-free self-test and guard lists** - `ad2f27a` (test)
3. **Task 3: H-28, host runner, Mac-shell self-test step, checklist row** - `978416e` (test)

**Plan metadata:** not committed. The plan's output spec says to leave this SUMMARY and every other `.planning/` file uncommitted for the orchestrator.

## Evidence

- **Branch used:** `chore/planning-phase-03-context` (see Deviations).
- **Tracer, recorded Compose lines** (stand-in docker, bogus `SBX_DIR=/bogus SBX_NAME=bogus COMPOSE_PROJECT_NAME=bogus` exported; `SPACED` is the registered folder with a space):
  - `docker compose --env-file /dev/null -p sbx-demo -f REPO/compose.yml up -d --wait | SBX_NAME=demo SBX_DIR=SPACED CPN=unset`
  - `docker compose --env-file /dev/null -p sbx-demo -f REPO/compose.yml stop | SBX_NAME=demo SBX_DIR=SPACED CPN=unset`
  - plus `docker image inspect sbx-claude:local` and `docker exec sbx-demo pgrep -x sleep`; exactly two compose calls.
- **Self-test:** 54 PASS lines, `All cases pass.`
- **Mutant FAIL lines:**
  - without the registry refusal: `FAIL: sbx-add: a path that holds the registry folder is refused`
  - sourcing the entry: `FAIL: registry: a value is read as text and never run`
- **Rehearsal guard tail:** `PASS: every_dockerfile_arg_is_pinned` then `All rules hold.`, 18 PASS lines. `tests/selftest/guard/run-all.sh` and `tests/selftest/entrypoint/run-all.sh` end `All cases pass.`
- **shellcheck (warning level)** is clean for `bin/*`, `base/sbx-start-lib.sh`, `tests/selftest/sbx/*.sh`, `tests/host/lib-sbx.sh`, `tests/host/h28-sbx-add-start-stop.sh`, `tests/host/run-all.sh`, `host-test.sh`.
- **Line counts:** bin/sbx-add 168, bin/sbx-lib.sh 232, bin/sbx-start 34, bin/sbx-stop 33; tests/selftest/sbx: add.sh 203, entry.sh 141, lib.sh 110, run-all.sh 16; tests/host/lib-sbx.sh 81; tests/host/h28-sbx-add-start-stop.sh 199.
- **Not verified here:** H-28 (needs the Mac's Docker) and the `/bin/bash` 3.2 run of the self-test (this sandbox has bash 5.3). Both belong to plan 04.

## Decisions Made

- The registry reader uses `read -r` and a `case` on `SBX_DIR=*` and `SBX_AGENT=*`; lines may come in any order, the last of a repeated key wins, a missing final newline is fine.
- `sbx_usage` falls back to `${0##*/}` for the script name because the usage check runs before `sbx_init`.
- `read_start_variable` (one small helper using `${!1}` in a subshell) reads all three values from the start library, so the three loads do not repeat the same line.
- In the self-test each case in `entry.sh` gets its own registry folder, because `sbx-add` stops on any broken entry in its registry.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] shellcheck SC2154 on library globals in bin scripts**
- **Found during:** Task 1 (verify command 2)
- **Issue:** `sbx-add` and `sbx-stop` use `registryDir`, `configDir`, `entryDir`, set by the sourced library; shellcheck at warning level flags them, and the guard would fail.
- **Fix:** a file-level `# shellcheck disable=SC2154` with a one-line reason before `set -eu` in those two files. `.shellcheckrc` is untouched (a global disable would hide real unset-variable bugs).
- **Files modified:** bin/sbx-add, bin/sbx-stop
- **Committed in:** aa794c3

**2. [Rule 3 - Blocking] shellcheck SC2154 on library globals in H-28**
- **Found during:** Task 3 (verify command 1)
- **Issue:** `sbxDir`, `sbxPath`, `sbxStatus` are set by `lib-sbx.sh`.
- **Fix:** the check file starts them with empty defaults, like its other globals.
- **Files modified:** tests/host/h28-sbx-add-start-stop.sh
- **Committed in:** 978416e

### Instruction conflicts resolved (not code defects)

- **Branch:** the plan says to run `git switch -c chore/phase-03-run` when the branch starts with `chore/planning-`; the dispatch prompt said to stay on `chore/planning-phase-03-context` and not create or switch branches. I followed the dispatch prompt. The three code commits therefore sit on the planning branch; plan 04 moves them onto a branch cut from an updated `origin/main` as planned. Nothing was pushed.
- **Commit trailer:** the plan and the user's rule say no Co-Authored-By or AI attribution; the three commits carry none.
- **SUMMARY commit:** the plan says to leave this file and all `.planning/` files uncommitted; the dispatch prompt said to commit after writing. I followed the plan (it is specific and keeps `.planning/` out of the code history).

**Total deviations:** 2 auto-fixed (both Rule 3), 3 instruction conflicts resolved toward the plan or the user's rules.
**Impact on plan:** none on behavior; messages match the plan's wording.

## TDD Gate Compliance

Task 2 is marked `tdd="true"` but its plan order is scripts first (Task 1), then the cases written against the real scripts. There is no RED commit before the code it tests; the order is reversed by design. The RED proof is the two mutants (registry refusal removed, entry sourced), each of which makes the matching named case FAIL. The mutant without the registry refusal also fails 12 other cases, because the unsafe registration it allows (a sandbox registered on the whole work folder) makes every later registration overlap.

## Issues Encountered

None beyond the deviations above.

## Known Stubs

None.

## Threat Flags

None. No new network endpoint, auth path or schema; the registry file and the Compose call are the surfaces in the plan's threat model.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02 can add `sbx-upgrade` on `bin/sbx-lib.sh` (`sbx_init`, `check_name`, `read_registry_entry`, `check_sandbox_folders`, `run_compose`, `wait_until_ready`) and add the guard rule for destructive words in `bin/`.
- H-28 and the Mac-shell self-test step are ready for the Mac run in plan 04; they are unproven on real Docker and bash 3.2 until then.

## Self-Check: PASSED

- Created files exist: all ten files listed under key-files.created found on disk.
- Commits `aa794c3`, `ad2f27a`, `978416e` found in `git log`; `git rev-list --count a0c6109..HEAD` is 3.
- Re-ran at the end: tracer command, self-test (54 PASS), both mutants, rehearsal guard (All rules hold., 18 PASS), entrypoint and guard self-tests.

---
*Phase: 03-remembered-sandboxes-and-one-command-upgrade*
*Completed: 2026-11-06*
