---
phase: 04-jump-in-and-sandbox-housekeeping
plan: 02
subsystem: infra
tags: [bash, docker-ps, sbx-list, selftest, host-checks]

requires:
  - phase: 04-jump-in-and-sandbox-housekeeping
    provides: runs_older_image and the scripted-docker knobs from plan 01
provides:
  - bin/sbx-list: every registered sandbox with status and folder, from one docker ps call
  - the older-image marker and the section for labelled containers without a registry entry
  - sbx_usage prints no trailing space for a script without arguments
  - docker-free self-test group tests/selftest/sbx/list.sh and the ps-lines and ps-fail knobs
  - host check H-32
affects: [04-03 sbx-rm, 04-04 docs, 04-05 gate and Mac run]

actuals:
  tokens: 7600
  tasks: 3
  commits: 3
plan_head_before: 00566e14ac0decb86bb58e7100f600dd57f21e1c
plan_head_after: 6b6249b7d3014a9c9c335c45d60dadaaf72b004a

tech-stack:
  added: []
  patterns:
    - "one docker ps call read into a global, then looked up by exact container name sbx-NAME"
    - "a docker failure is an error with empty stdout, never an empty list"
    - "registry glob under a local LC_ALL=C so the row order never depends on the Mac locale"

key-files:
  created:
    - bin/sbx-list
    - tests/selftest/sbx/list.sh
    - tests/host/h32-sbx-list.sh
  modified:
    - bin/sbx-lib.sh
    - tests/selftest/sbx/lib.sh
    - tests/host/run-all.sh
    - tests/host-checklist.md

key-decisions:
  - "paused and restarting read stopped, so the list keeps the three statuses running, stopped, no container"
  - "a broken registry entry is a row (broken entry plus the entry file path), not a failure of the whole list; sbx-start NAME prints the reason"
  - "the leftover hint names only sbx-add, because sbx-rm needs a registry entry and no bin/ file other than sbx-rm may name it"
  - "printf with fixed widths instead of column, because a path may hold spaces"

patterns-established:
  - "Mutant check per safety property: a prefix-match mutant fails the adjacency case, an ignore-the-failure mutant fails the docker failure case"

requirements-completed: [SCR-05]

coverage:
  - id: D1
    description: "sbx-list prints a header and one row per registry entry (name, status, folder), in byte order, with the status read from one docker ps call: running, stopped (every other state) or no container"
    requirement: SCR-05
    verification:
      - kind: unit
        ref: "tests/selftest/sbx/list.sh#sbx-list: one docker ps call reads every labelled container"
        status: pass
      - kind: unit
        ref: "tests/selftest/sbx/list.sh#sbx-list: rows are in name order"
        status: pass
      - kind: unit
        ref: "tests/selftest/sbx/list.sh#sbx-list: a path with spaces is printed whole"
        status: pass
    human_judgment: false
  - id: D2
    description: "A running sandbox on an older image reads running, older image with one note under the table; a running sandbox on the current image, a stopped one and one with no container are never marked"
    requirement: SCR-05
    verification:
      - kind: unit
        ref: "tests/selftest/sbx/list.sh#sbx-list: a running sandbox on an older image is marked"
        status: pass
      - kind: unit
        ref: "tests/selftest/sbx/list.sh#sbx-list: a stopped sandbox on an older image is not marked"
        status: pass
    human_judgment: false
  - id: D3
    description: "Containers with the sbx.name label but no sbx-NAME entry are listed after the table; a name that only starts like an entry is not that entry; old cc_ containers never show"
    requirement: SCR-05
    verification:
      - kind: unit
        ref: "tests/selftest/sbx/list.sh#sbx-list: a container whose name only starts like an entry is not that entry"
        status: pass
      - kind: unit
        ref: "tests/selftest/sbx/list.sh#sbx-list: a labelled container with no entry is listed after the table"
        status: pass
    human_judgment: false
  - id: D4
    description: "A failed docker ps exits 1 with the error and prints nothing on stdout; a broken entry is a row; sbx-list changes nothing"
    requirement: SCR-05
    verification:
      - kind: unit
        ref: "tests/selftest/sbx/list.sh#sbx-list: a failed docker ps exits 1 and prints no table"
        status: pass
      - kind: unit
        ref: "tests/selftest/sbx/list.sh#sbx-list: a broken entry is a row, and the other rows still print"
        status: pass
      - kind: unit
        ref: "tests/selftest/sbx/list.sh#sbx-list: the registry is unchanged"
        status: pass
    human_judgment: false
  - id: D5
    description: "Real Docker on the Mac: the hosttest row reads no container, running and stopped as docker ps -a does, with the spaced folder, no false older-image mark and no cc_ line (H-32)"
    requirement: SCR-05
    verification: []
    human_judgment: true
    rationale: "Docker is not available in the dev sandbox; tests/host/h32-sbx-list.sh runs on the Mac in plan 05"

duration: 11min
completed: 2026-11-07
status: complete
---

# Phase 4 Plan 02: sbx-list Summary

**sbx-list prints every registered sandbox with its folder and a status read from one docker ps call (running, stopped, no container), marks a running sandbox on an older image, keeps a broken entry as a row, lists labelled containers that have no entry, and treats a Docker failure as an error instead of an empty list.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-11-07T04:03:00Z (approximate; the start time was not captured)
- **Completed:** 2026-11-07T04:14:00Z
- **Tasks:** 3
- **Files modified:** 7 (3 created, 4 modified)

## Accomplishments

- `bin/sbx-list` (100755, 175 lines): `read_container_states`, `status_word`, `status_of`, `print_row`, `print_table`, `print_older_image_note`, `print_leftovers`. It calls `runs_older_image`, `read_registry_entry` and `check_name` from the library and runs only `docker ps` plus the inspect calls for running rows.
- `sbx_usage` in `bin/sbx-lib.sh` prints no trailing space for an empty argument text, so `sbx-list extra` gives exactly `Usage: sbx-list`; every other usage line is byte for byte as before.
- Self-test: the scripted docker gains `ps-lines` and `ps-fail`, plus `set_standin_ps`; `tests/selftest/sbx/list.sh` (341 lines) has 24 cases for statuses, marker, broken rows, leftovers, order, adjacency and the Docker failure.
- `tests/host/h32-sbx-list.sh` (180 lines, 100644) compares the hosttest row with `docker ps -a` for no container, running and stopped, and checks the empty-registry leftover and the absence of `cc_` lines; it runs after H-31 and has its checklist row.

## Evidence

Branch: `chore/planning-phase-04-context` (the dispatch said to stay on it; nothing was created, pushed or merged).

Tracer through PATH with a stand-in docker, two registered sandboxes (`demo` with a spaced folder, running on another image id; `idle`, no container) and the unregistered `sbx-stray`:

```
NAME                            STATUS               PATH
demo                            running, older image /tmp/sbx-tracer.eLZGhq/sp ace/sbx
idle                            no container         /tmp/sbx-tracer.eLZGhq/idle
older image: sbx-start NAME recreates it on the current image; that closes its open shells and Claude sessions

Containers with the sbx.name label but no registry entry (sbx-add NAME HOST_PATH registers one again):
  sbx-stray                           stopped
```

One `docker ps` call, no compose call; a failing `docker ps` gave exit 1, the error on stderr and an empty stdout; an argument gave `Usage: sbx-list` and exit 2.

- Self-test: `bash tests/selftest/sbx/run-all.sh` ends `All cases pass.` with 130 PASS lines (106 before this plan, 24 new).
- Mutant that matches a container by name prefix: `FAIL: sbx-list: a container whose name only starts like an entry is not that entry`.
- Mutant that ignores a failed `docker ps` (`|| true`): `FAIL: sbx-list: a failed docker ps exits 1 and prints no table`.
- Rehearsal guard tail: `PASS: every_dockerfile_arg_is_pinned` then `All rules hold.` (19 PASS lines; `host_scripts_keep_sandbox_data` passes).
- shellcheck at warning level prints nothing for `bin/sbx-lib.sh`, `bin/sbx-list`, the self-test files and `tests/host/h32-sbx-list.sh`; no comment line is over 80 columns; every file is ASCII.

Line counts: `bin/sbx-list` 175, `tests/selftest/sbx/list.sh` 341, `tests/host/h32-sbx-list.sh` 180, `bin/sbx-lib.sh` 301 (unchanged length).

## Task Commits

1. **Task 1: Tracer, sbx-list and the sbx_usage change** - `2502e79` (feat)
2. **Task 2: Docker-free self-test of every status, marker and edge** - `112bfed` (test)
3. **Task 3: H-32, runner entry and checklist row** - `6b6249b` (test)

**Plan metadata:** the commit that adds this file, and the STATE and ROADMAP commit after it (docs).

## Files Created/Modified

- `bin/sbx-list` - the list of sandboxes with status, folder, older-image marker and leftovers
- `bin/sbx-lib.sh` - `sbx_usage` body line only
- `tests/selftest/sbx/lib.sh` - `ps-lines` and `ps-fail` knobs, `set_standin_ps`
- `tests/selftest/sbx/list.sh` - the sbx-list group
- `tests/host/h32-sbx-list.sh`, `tests/host/run-all.sh`, `tests/host-checklist.md` - the Mac run

## Decisions Made

- `paused` and `restarting` read `stopped`; the three statuses of the roadmap stay the only ones.
- A broken entry is a row (`broken entry` plus the entry file path); the reason is not repeated, `sbx-start NAME` prints it.
- The leftover hint suggests only `sbx-add`; removing a leftover stays plain `docker`, to be documented in plan 04.
- Fixed-width `printf` instead of `column`, because `column` splits paths with spaces.

## Deviations from Plan

None - plan executed exactly as written, with these notes:

- Message wording matches the plan. The test helper names (`unmarked_row`, `rows_in_name_order`, `leftover_after_table`, `broken_row_beside_good`, `adjacent_is_not_entry`, `one_ps_call_only`, `registry_snapshot`, `usage_is_exact`, `failed_without_table`, `row_start`, `line_starts_with`, `row_ends_with`) and the H-32 helper names are my choice; the plan left them open. The marker case folds the "no older image text" check into `unmarked_row`, so the expect names are exactly the planned ones.
- The plan's output section says to leave `.planning/` files uncommitted; the dispatch prompt required a committed SUMMARY and updated STATE and ROADMAP, so those are committed in separate planning-only commits with no code in them.
- Two comment lines in `h32-sbx-list.sh` were reworded to fit 80 columns (same meaning).
- The host checklist title line still says H-00..H-30 (it was already out of date after H-31); the plan changes only the row, so it is left for the documentation plan.

**Total deviations:** 0 auto-fixed. **Impact on plan:** none.

## Issues Encountered

None. Docker is not available here, so H-32 was checked only for syntax, lint, comment width, ASCII and its usage refusal (`Usage: bash tests/host/h32-sbx-list.sh`, exit 2).

## Known Stubs

None.

## Threat Flags

None. sbx-list reads the registry and calls `docker ps` and `docker inspect` only; no new network endpoint, auth path or write access beyond the plan's threat model (T-04-07 to T-04-12 are mitigated or accepted as planned).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 03 (`sbx-rm`) can rely on the data guard rule staying green: `bin/sbx-list` and the library say none of rm, rmdir, prune, kill, down or eval.
- H-32 runs on the Mac in plan 05, together with H-31 and its attended helper.

---
*Phase: 04-jump-in-and-sandbox-housekeeping*
*Completed: 2026-11-07*

## Self-Check: PASSED

Files bin/sbx-list, tests/selftest/sbx/list.sh and tests/host/h32-sbx-list.sh exist; commits 2502e79, 112bfed and 6b6249b exist. SCR-05 stays open in REQUIREMENTS.md: plans 04 and 05 of this phase also declare it and have no summary yet.
