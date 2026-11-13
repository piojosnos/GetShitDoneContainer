---
phase: 06-test-diet
plan: 03
subsystem: testing
tags: [bash, host-tests, persistence, claude-state]

requires: []
provides:
  - "tests/host/lib-login.sh: loginProjectName, plant_login_files, check_login_files"
  - "H-09 and H-29 plant and check a fake credentials file and a fake session file; no test logs in to Claude"
affects: [06-04, 06-06, host-test.sh]

actuals:
  tokens: 1500
  tasks: 2
  commits: 2
plan_head_before: 5d80ca34f9baaf6d7c2c822c18c8555d04ba0c2f
plan_head_after: 958e05e3df73c01d0359db5cbffbd872093c83d1

tech-stack:
  added: []
  patterns:
    - "Persistence proxies: plant a run-unique fake file where Claude keeps its state, check it after the recreate"

key-files:
  created:
    - tests/host/lib-login.sh
  modified:
    - tests/host/h09-rebuild-keeps-files-no-volumes.sh
    - tests/host/h29-sbx-upgrade.sh
    - tests/host-checklist.md
    - README.md

key-decisions:
  - "One shared helper file next to lib-sbx.sh; lib.sh stays untouched so only the two persistence checks load it"
  - "Host-side presence check only (grep for the run-unique text); no mode or owner assertion because stat flags differ between GNU and BSD"
  - "plant_login_files refuses an empty STATE_DIR (adds a problem, returns 1, writes nothing) so a wrong caller can never write to the filesystem root"

requirements-completed: [DIET-03]

coverage:
  - id: D1
    description: "lib-login.sh plants and checks the fake files; missing, changed and empty-STATE_DIR cases behave as specified"
    requirement: DIET-03
    verification:
      - kind: unit
        ref: "helper probe from the plan (fresh plant checks clean; removed session file gives 1 problem; changed credentials file gives 2; empty STATE_DIR gives 1 problem and writes nothing)"
        status: pass
    human_judgment: false
  - id: D2
    description: "H-09 and H-29 call plant_login_files before the rebuild or upgrade and check_login_files after it"
    requirement: DIET-03
    verification:
      - kind: other
        ref: "awk region greps over plant_sentinels, check_sentinels_survived, plant_and_snapshot, check_upgrade; bash -n; bash tests/guard/run-all.sh (All rules hold.)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Checklist rows H-09 and H-29 and the README Verify table name the fake files and no manual helper"
    requirement: DIET-03
    verification:
      - kind: other
        ref: "grep acceptance criteria for the H-09 and H-29 rows and the README row"
        status: pass
    human_judgment: false
  - id: D4
    description: "H-09 and H-29 print PASS in ./host-test.sh on the Mac with the fake files planted and checked"
    verification: []
    human_judgment: true
    rationale: "Needs the Mac and Docker Desktop; Docker is not available in the dev sandbox. Proven in the final plan's Mac run"

duration: 3min
completed: 2026-11-13
status: complete
---

# Phase 6 Plan 03: Fake login files as persistence proxies Summary

**H-09 (rebuild) and H-29 (`sbx-upgrade`) now plant a fake credentials file and a fake session file under `state/claude` through one shared helper, `tests/host/lib-login.sh`, and check both survive; no test logs in to Claude and the docs no longer name a manual helper.**

## Performance

- **Duration:** about 3 min
- **Completed:** 2026-11-13T08:14Z
- **Tasks:** 2
- **Files modified:** 5 (1 created)

## Accomplishments

- `plant_login_files STATE_DIR TEXT PREFIX` writes `state/claude/.credentials.json` and `state/claude/projects/-home-sandbox-workspace-hosttest/PREFIX-session.jsonl`, each holding only the check's run-unique text in a fake key.
- `check_login_files STATE_DIR TEXT PREFIX WHEN` adds one problem per file that is missing, empty or changed.
- H-09 plants in `plant_sentinels` (before the rebuild) and checks in `check_sentinels_survived` (after the recreate).
- H-29 plants in `plant_and_snapshot` (before `sbx-upgrade`) and checks in `check_upgrade` (after it); both pass their own state folder inside the run folder.
- Checklist rows H-09 and H-29 and the README "Login survives a rebuild" row now say the fake files survive, with Run set to automatic and `./host-test.sh`.

## Task Commits

1. **Task 1: New tests/host/lib-login.sh, wired into H-09 end to end (tracer)** - `967d312` (test)
2. **Task 2: Wire the fake login files into H-29; update the checklist rows and the README Verify table** - `958e05e` (test)

**Plan metadata:** committed separately (docs: complete plan)

## Files Created/Modified

- `tests/host/lib-login.sh` - new library: the project-folder constant and the plant and check helpers
- `tests/host/h09-rebuild-keeps-files-no-volumes.sh` - sources the library; plants and checks around the rebuild
- `tests/host/h29-sbx-upgrade.sh` - sources the library; plants and checks around `sbx-upgrade`
- `tests/host-checklist.md` - H-09 and H-29 rows
- `README.md` - Verify table row

## Decisions Made

See key-decisions. The tracer (Task 1) was verified end to end (`bash -n`, the guard, and the helper probe) before H-29 and the docs were touched.

## Deviations from Plan

None - plan executed exactly as written. Two small wording touches inside plan scope: the H-29 `plant_and_snapshot` banner was reflowed to stay within 80 columns, and `grep -Fq --` is used so a text starting with a hyphen is never read as an option.

## Verification

- `bash -n` on `tests/host/lib-login.sh`, H-09 and H-29: PASS
- `bash tests/guard/run-all.sh`: PASS (`All rules hold.`)
- Helper probe (plant, check clean, removed file, changed file, empty STATE_DIR, nothing written at `/claude`): PASS
- awk region checks for the plant and check calls in H-09 and H-29: PASS
- Acceptance greps for the checklist rows, README row and no `manual/`, `stat`, `readlink` or `sed -i`: PASS

## Mac-only checks (not run here)

- `./host-test.sh`: H-09 and H-29 print PASS with the fake credentials and session files planted and checked (covered by the final plan's Mac run).

## Known Stubs

None.

## Threat Flags

None. The planted files hold only the run-unique text and live in the throwaway run folder; the helper refuses an empty state folder.

## Self-Check: PASSED

- `tests/host/lib-login.sh` exists.
- Commits `967d312` and `958e05e` exist on `chore/phase-06-test-diet`.
