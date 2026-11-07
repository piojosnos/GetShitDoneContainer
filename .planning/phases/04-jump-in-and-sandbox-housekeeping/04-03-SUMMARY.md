---
phase: 04-jump-in-and-sandbox-housekeeping
plan: 03
subsystem: infra
tags: [bash, docker-compose, sbx-rm, guard-rule, selftest, host-checks]

requires:
  - phase: 04-jump-in-and-sandbox-housekeeping
    provides: sbx_usage without a trailing space, the scripted-docker knobs and the host check helpers from plans 01 and 02
provides:
  - bin/sbx-rm: removes a sandbox's container and network with one scoped compose down; --unregister also deletes the registry entry, only after a good down
  - host_scripts_keep_sandbox_data rewritten: broad rule for every bin/ file but sbx-rm, narrow rule for sbx-rm with its one delete pinned to an exact line
  - nine planted guard cases for the rewritten rule
  - docker-free self-test group tests/selftest/sbx/rm.sh
  - host check H-33 with the re-register round trip
affects: [04-04 docs, 04-05 gate and Mac run]

actuals:
  tokens: 9900
  tasks: 3
  commits: 3
plan_head_before: fb41a4930b5d83266c8139c09609f168709b8512
plan_head_after: a8079945d42cf904e6ab7c99e3dd7f7b4e9cc06f

tech-stack:
  added: []
  patterns:
    - "the one allowed delete in bin/ is pinned by the guard to an exact source line, so a second operand or another path fails the rule"
    - "a registry entry is deleted only after the compose down it names succeeded"
    - "folder_listing before and after a run proves a script left a folder untouched, file contents included"

key-files:
  created:
    - bin/sbx-rm
    - tests/selftest/sbx/rm.sh
    - tests/host/h33-sbx-rm.sh
  modified:
    - bin/sbx-lib.sh
    - tests/guard/isolation.sh
    - tests/selftest/guard/sandbox-rules.sh
    - tests/host/run-all.sh
    - tests/host-checklist.md

key-decisions:
  - "sbx-rm runs exactly run_compose NAME down: no -v, --rmi or --remove-orphans, so volumes and images stay for the other sandboxes"
  - "a sandbox with no container is removed quietly with exit 0 and the same last line, so a second run is harmless"
  - "sbx-rm checks neither the folder nor the image, so a sandbox whose folder moved or whose image was never built can still be removed"
  - "an unregistered leftover container is not removed by sbx-rm, because it needs the registry entry for the folder"
  - "the rule stays one rule (19 in all); a missing bin/sbx-rm fails it, so the guard cannot go green by deleting the exempt script"

patterns-established:
  - "Two mutants per safety property: ignoring a failed down fails the keep-the-entry case, adding -v fails the exact down-line case"

requirements-completed: [SCR-06]

coverage:
  - id: D1
    description: "sbx-rm NAME runs one scoped compose down for sbx-NAME with the registry's folder, warns first when the sandbox is running, never touches the sandbox folder, and ends with a line saying nothing in the folder was changed"
    requirement: SCR-06
    verification:
      - kind: unit
        ref: "tests/selftest/sbx/rm.sh#sbx-rm: compose down runs once, for the sandbox's own project, with no option"
        status: pass
      - kind: unit
        ref: "tests/selftest/sbx/rm.sh#sbx-rm: the files in the sandbox folder are unchanged"
        status: pass
    human_judgment: false
  - id: D2
    description: "--unregister (before or after the name) deletes only the registry entry and only after a good down; a failed down exits 1 and leaves the entry byte for byte; a second --unregister is refused"
    requirement: SCR-06
    verification:
      - kind: unit
        ref: "tests/selftest/sbx/rm.sh#sbx-rm: a failed down exits 1 and keeps the entry"
        status: pass
      - kind: unit
        ref: "tests/selftest/sbx/rm.sh#sbx-rm: --unregister deletes the entry after the down"
        status: pass
    human_judgment: false
  - id: D3
    description: "the guard allows exactly one delete in bin/ (the entry line of sbx-rm) and keeps every other bin/ file free of deletes and take-downs"
    requirement: SCR-06
    verification:
      - kind: unit
        ref: "tests/selftest/guard/sandbox-rules.sh#host scripts: a second operand to the entry delete fails"
        status: pass
      - kind: other
        ref: "bash tests/guard/run-all.sh ends All rules hold. with 19 PASS lines"
        status: pass
    human_judgment: false
  - id: D4
    description: "on the Mac, sbx-rm takes the real container and network and keeps the folder, entry, volumes, images and other sandboxes; sbx-add of the same folder brings back state/claude and the history (H-33)"
    requirement: SCR-06
    verification: []
    human_judgment: true
    rationale: "Docker does not run in the dev sandbox; H-33 runs on the Mac in the gate plan"

duration: 15min
completed: 2026-11-07
status: complete
---

# Phase 4 Plan 03: sbx-rm Summary

**sbx-rm takes a sandbox's container down with one scoped compose down and, with --unregister, deletes only its registry entry after a good down, under a rewritten guard rule that pins that one delete to an exact line.**

## Performance

- **Duration:** about 15 min
- **Started:** 2026-11-07T15:56Z (approximate; the start time was not recorded)
- **Completed:** 2026-11-07T16:11Z
- **Tasks:** 3
- **Files modified:** 8 (3 created, 5 modified)

## Accomplishments

- `bin/sbx-rm` (90 lines, mode 100755): `parse_arguments`, `warn_if_running`, `remove_container`, `unregister_sandbox`. No folder or image check, so a moved folder or a missing image does not block the removal.
- Tracer: with a stand-in docker, a failing compose exits 1 and keeps the entry byte for byte; a good run records exactly one call, `docker compose --env-file /dev/null -p sbx-demo -f REPO/compose.yml down | SBX_NAME=demo SBX_DIR=TMP/sp ace/sbx CPN=unset`, with bogus ambient `SBX_DIR`, `SBX_NAME` and `COMPOSE_PROJECT_NAME` ignored, deletes the entry, keeps both planted files, and `sbx-add` of the same folder writes the same entry again.
- `host_scripts_keep_sandbox_data` is still one rule (19 in all): broad for every other `bin/` file, narrow for `bin/sbx-rm`, fails when `bin/sbx-rm` is missing. The rehearsal guard ends `All rules hold.` with 19 PASS lines.
- Guard self-test: 127 PASS lines in `sandbox-rules.sh`. Planted labels: a volume take-down, an image removal, an orphan removal, a folder delete, a delete of another path and a second operand to the entry delete, all in sbx-rm; the word rm in sbx-list; the word down in sbx-shell; a missing sbx-rm; the two earlier cases (sbx-stop take-down, sbx-upgrade delete) stay.
- Self-test `tests/selftest/sbx/rm.sh` (318 lines): 154 PASS lines in the whole sbx suite, `All cases pass.`
- Two mutants fail as required: `FAIL: sbx-rm: a failed down exits 1 and keeps the entry` (ignores a failed down) and `FAIL: sbx-rm: compose down runs once, for the sandbox's own project, with no option` (adds -v). The -v mutant also fails the two no-folder and no-image cases, because they match a call that ends in down.
- Host check H-33 (`tests/host/h33-sbx-rm.sh`, 319 lines, 100644) after H-32 in the chain, plus its checklist row. It runs only on the Mac in the gate plan.

## Task Commits

1. **Task 1: Tracer, sbx-rm and the data guard rule** - `d2489df` (feat)
2. **Task 2: sbx-rm self-test group with two mutants** - `f8200e1` (test)
3. **Task 3: H-33, runner entry and checklist row** - `a807994` (test)

**Plan metadata:** the SUMMARY and the STATE and ROADMAP updates are separate planning-only commits.

## Files Created/Modified

- `bin/sbx-rm` - removes the container; `--unregister` also deletes the registry entry
- `bin/sbx-lib.sh` - `warn_sessions_close` banner now covers a recreate and a removal (comment only)
- `tests/guard/isolation.sh` - rewritten `host_scripts_keep_sandbox_data`
- `tests/selftest/guard/sandbox-rules.sh` - nine planted cases
- `tests/selftest/sbx/rm.sh` - usage, refusals, the exact down call, order of the delete, the untouched folder
- `tests/host/h33-sbx-rm.sh` - host check H-33
- `tests/host/run-all.sh` - H-33 right after H-32
- `tests/host-checklist.md` - H-33 row

## Decisions Made

See `key-decisions`. All follow the plan as written; no new choices were needed.

## Deviations from Plan

None - plan executed exactly as written. Two small notes, neither a deviation from behavior:

- The one banner title that was over 80 columns (`unregister_sandbox`) was shortened to `deletes the registry entry, the only delete here`, as the plan's comment rule asks.
- Message wording matches the plan; no message differs.

## Issues Encountered

- The plan commit ledger (`gsd-plan-head-before-04-03`) was not written before the first commit; it was written afterwards from `d2489df^`, which is the correct base (`fb41a49`), so `commits: 3` is measured.
- The header of `tests/host-checklist.md` still says H-00..H-30; earlier plans left it and it is outside this plan's files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 04 (docs) can describe `sbx-rm NAME [--unregister]`: an unregistered leftover container is not removed by it; register it again with `sbx-add` or use plain `docker`.
- Plan 05 runs H-33 on the Mac. Assumptions it proves: `docker compose down` exits 0 for a project with no container and does not need the registered folder to exist; the Compose network is named `sbx-hosttest_default`.

---
*Phase: 04-jump-in-and-sandbox-housekeeping*
*Completed: 2026-11-07*

## Self-Check: PASSED

- Created files exist: `bin/sbx-rm`, `tests/selftest/sbx/rm.sh`, `tests/host/h33-sbx-rm.sh` (verified on disk).
- Commits exist: `d2489df`, `f8200e1`, `a807994` (verified with `git log`).
- `git ls-files -s bin/sbx-rm` shows 100755; every other file is 100644 (`tests/host/run-all.sh` keeps its 100755).
- Rehearsal guard: `All rules hold.`; guard self-test and sbx self-test: `All cases pass.`
