---
phase: 04-jump-in-and-sandbox-housekeeping
plan: 04
subsystem: docs
tags: [sandbox-docs, sbx-shell, sbx-list, sbx-rm, host-checklist]

requires:
  - phase: 04-jump-in-and-sandbox-housekeeping
    provides: bin/sbx-shell, bin/sbx-list, bin/sbx-rm, host checks H-31 to H-33 and the h31-jump-in.sh helper from plans 01 to 03
provides:
  - SANDBOX.md teaches sbx-shell as the way in, sbx-list and sbx-rm, with the raw commands and four troubleshooting rows
  - tests/README.md and tests/host-checklist.md name H-00 to H-33, seven helpers, the new chain and the narrowed data rule
  - host-test.sh banner comment names H-00 to H-33
affects: [04-05 gate and Mac run]

actuals:
  tokens: 5900
  tasks: 2
  commits: 2
plan_head_before: a98a9b94c7cb66f58d5aba7bd14b781b34d422d5
plan_head_after: 76969377a04c8708ad74fa847b214cecbbf8b798

tech-stack:
  added: []
  patterns:
    - "the example table in SANDBOX.md starts with the exact printf layout header of sbx-list, and the verify compares them byte for byte"
    - "the raw docker exec line appears once in SANDBOX.md, in What the scripts run"

key-files:
  created: []
  modified:
    - SANDBOX.md
    - tests/README.md
    - tests/host-checklist.md
    - host-test.sh

key-decisions:
  - "the sbx-list example also shows the older-image note line and the unregistered-containers section, copied from the script, so the example is the full output"
  - "the H-31 checklist bullet quotes the real FAIL text (script may not give sbx-shell a terminal) instead of a paraphrase"

patterns-established:
  - "docs follow code: usage lines, messages and the table header are copied from bin/ as the earlier plans left them"

requirements-completed: [SCR-04, SCR-05, SCR-06]

coverage:
  - id: D1
    description: "SANDBOX.md teaches sbx-shell, sbx-list and sbx-rm: Scripts table, Start enter stop, List sandboxes, Remove a sandbox, What the scripts run, Upgrade, Verify a new build and four troubleshooting rows"
    requirement: SCR-04
    verification:
      - kind: other
        ref: "Task 1 automated verify: content strings, sbx-list header byte for byte, one raw docker exec line, ASCII, no dash punctuation, README.md and old layout unchanged, guard ends All rules hold."
        status: pass
    human_judgment: false
  - id: D2
    description: "The test docs name H-00 to H-33, seven helpers, the chain H-29, H-31, H-32, H-33, H-20, the H-31 terminal case and the narrowed data rule; host-test.sh comment names H-33"
    requirement: SCR-06
    verification:
      - kind: other
        ref: "Task 2 automated verify: ranges, chain, helper count, log names, comment length, guard and bash tests/selftest/sbx/run-all.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: "The docs read clearly to a non-expert maintainer and match the neighbouring sections' voice"
    requirement: SCR-05
    verification: []
    human_judgment: true
    rationale: "Voice and clarity are judged in PR review; no test asserts them"

duration: 2min
completed: 2026-11-07
status: complete
---

# Phase 4 Plan 04: Jump-in, list and remove docs Summary

**SANDBOX.md teaches `sbx-shell`, `sbx-list` and `sbx-rm` from the scripts as they are, and the test docs list H-31 to H-33, the seventh helper and the narrowed data rule.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-11-07T16:12:37Z
- **Completed:** 2026-11-07T16:14:03Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- SANDBOX.md "Scripts" names seven scripts; the table has rows for `sbx-shell NAME`, `sbx-list` and `sbx-rm NAME [--unregister]` in the planned order, and the bullet says every script but `sbx-list` takes the name.
- "Start, enter, stop" teaches `sbx-shell demo` as the way in: starts a stopped or container-less sandbox, enters a running one as it is (older image too), does not wait for hooks of a sandbox that already runs, needs a terminal (both Docker refusal texts), passes the shell's exit status. "Start Claude there" says no command starts Claude from the Mac.
- New "List sandboxes" and "Remove a sandbox" sections right after "Start, enter, stop"; "What the scripts run" gains the `down`, `docker exec` and `docker ps` lines (the `docker exec` line appears once in the file).
- "Register a sandbox", "Upgrade" and "Verify a new build" mention `sbx-rm --unregister`, the `running, older image` mark and `h31-jump-in.sh`; the troubleshooting table has the four new rows.
- tests/README.md and tests/host-checklist.md: H-00 to H-33, H-28 to H-33 for the `sbx-*` scripts, seven helpers, the chain H-08, H-16, H-23, H-11, H-09, H-28, H-29, H-31, H-32, H-33, H-20, H-10, the h28 to h33 log names and the H-31 terminal case, the guard's narrowed data rule (19 rules kept). host-test.sh's banner comment says H-00 to H-33.

### The sbx-list example as written

```text
NAME                            STATUS               PATH
demo                            running              /Users/you/sbx-demo
docs                            running, older image /Users/you/my docs
scratch                         stopped              /Users/you/sbx-scratch
tryout                          no container         /Users/you/sbx-tryout
older image: sbx-start NAME recreates it on the current image; that closes its open shells and Claude sessions

Containers with the sbx.name label but no registry entry (sbx-add NAME HOST_PATH registers one again):
  sbx-hosttest                        stopped
```

## Task Commits

1. **Task 1: SANDBOX.md teaches jump-in, list and remove** - `da0ecb4` (docs)
2. **Task 2: test docs name H-31 to H-33, the seventh helper and the data rule** - `7696937` (docs)

**Plan metadata:** committed separately with STATE.md and ROADMAP.md.

## Files Created/Modified

- `SANDBOX.md` - Scripts table, Start enter stop, What the scripts run, List sandboxes, Remove a sandbox, Upgrade, Verify a new build, troubleshooting rows
- `tests/README.md` - guard, sbx self-test and host sections name the new checks and the narrowed data rule
- `tests/host-checklist.md` - title and ranges H-00..H-33, seven helpers, chain, failure bullets, clean-up note (the header range had been left at H-30)
- `host-test.sh` - one comment

## Decisions Made

See `key-decisions`. The plan's wording was followed; two small additions are listed below.

## Deviations from Plan

None - plan executed exactly as written. Wording notes, neither a behaviour change:

- The sbx-list example also shows the older-image note line and the unregistered-containers section as `bin/sbx-list` prints them (the plan asked for rows only), plus one bullet saying the note appears only when a row has the mark.
- The H-31 bullet in the checklist quotes the real message of `tests/host/h31-sbx-shell.sh` (`script may not give sbx-shell a terminal`) rather than the plan's paraphrase "BSD script gave no terminal".

## Issues Encountered

None. The Mac-side behaviour the docs describe (real Docker refusal texts, the shell through a terminal) is proven by `./host-test.sh` on the Mac, not in this sandbox.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None.

## Next Phase Readiness

- Ready for the final plan of the phase: the gate over every changed file (planning-ID scan) and the Mac run of `./host-test.sh`.

## Self-Check: PASSED

- SANDBOX.md, tests/README.md, tests/host-checklist.md, host-test.sh exist; commits `da0ecb4` and `7696937` found.
- Task 1 and Task 2 automated verifies passed; README.md, `ClaudeCode/` and `OpenCode/` unchanged; guard ends `All rules hold.`; sbx self-test ends `All cases pass.`

---
*Phase: 04-jump-in-and-sandbox-housekeeping*
*Completed: 2026-11-07*
