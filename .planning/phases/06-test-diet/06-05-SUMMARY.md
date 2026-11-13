---
phase: 06-test-diet
plan: 05
subsystem: testing
tags: [bash, host-tests, manual-helpers-removed, unattended-suite]

requires: ["06-04"]
provides:
  - "no tests/host/manual/; no interactive helper and no test Claude login anywhere in the suite"
  - "no_compromised_gsd_package without the deleted folder's glob, still scanning every remaining test and support file"
  - "print_next_block prints the cleanup command only"
affects: [06-06, host-test.sh, tests/host/run-all.sh]

actuals:
  tokens: 9000
  tasks: 2
  commits: 2
plan_head_before: 9df2b27d81b6ccc46f019d6a756f7f19b9e65014
plan_head_after: 8bb95ae9c7309fbad8650d7f8fe26958bcfefb57

tech-stack:
  added: []
  patterns:
    - "Folder deletion and the guard glob that names it land in one commit, so no commit leaves the guard red"

key-files:
  created: []
  modified:
    - tests/guard/supply-chain.sh
    - host-test.sh
    - tests/host/run-all.sh
    - tests/host/h31-sbx-shell.sh
    - tests/host-checklist.md
    - tests/README.md
    - README.md
    - clean.sh
  deleted:
    - tests/host/manual/h07-login.sh
    - tests/host/manual/h09-rebuild-resume.sh
    - tests/host/manual/h13-doctor.sh
    - tests/host/manual/h16-gsd-bump.sh
    - tests/host/manual/h19-bundle-behaviour.sh
    - tests/host/manual/h29-upgrade-resume.sh
    - tests/host/manual/h31-jump-in.sh
    - tests/host/manual/lib-manual.sh

key-decisions:
  - "Only the manual folder's glob left no_compromised_gsd_package; every other path and glob on its line is byte for byte as before"
  - "The H-31 checklist bullet now says BSD script on this Mac did not give sbx-shell a terminal and asks for the FAIL line and the log it names"

requirements-completed: [DIET-01]

coverage:
  - id: D1
    description: "tests/host/manual/ is gone in the same commit as its guard glob, and the guard stays green with no_compromised_gsd_package printing PASS"
    requirement: DIET-01
    verification:
      - kind: other
        ref: "bash tests/guard/run-all.sh (All rules hold.); git show --name-only of the deleting commit lists tests/guard/supply-chain.sh; grep -F of the remaining globs verbatim"
        status: pass
    human_judgment: false
  - id: D2
    description: "No step of host-test.sh or tests/host/*.sh waits for keyboard input, and the runner, host-test.sh and H-31 name no helper"
    requirement: DIET-01
    verification:
      - kind: other
        ref: "bash -n on the three edited files; negative greps for read -p, /dev/tty, [y/N], require_terminal, helper, tests/host/manual"
        status: pass
    human_judgment: false
  - id: D3
    description: "The checklist, tests/README.md, README.md and clean.sh describe an unattended suite with no helpers and no test Claude login"
    requirement: DIET-01
    verification:
      - kind: other
        ref: "git grep for every helper name outside .planning prints nothing; negative greps for helper, test Claude login and claude -p/update/doctor/auth in the docs; bash -n clean.sh"
        status: pass
    human_judgment: false
  - id: D4
    description: "On the Mac, ./host-test.sh ends with the Next block printing the cleanup command only, and the run never waits for input"
    verification: []
    human_judgment: true
    rationale: "Needs the Mac and Docker Desktop; Docker is not available in the dev sandbox. Proven in the final plan's Mac run"

duration: 8min
completed: 2026-11-13
status: complete
---

# Phase 6 Plan 05: Manual helpers deleted Summary

**`tests/host/manual/` and its eight scripts are gone together with the one guard glob that named them; the runner, `host-test.sh`, H-31 and the docs no longer mention a helper, a test Claude login or anything that waits for a person.**

## Performance

- **Duration:** about 8 min
- **Completed:** 2026-11-13
- **Tasks:** 2
- **Files:** 8 modified, 8 deleted

## Accomplishments

- One commit deletes the folder and removes `tests/host/manual/*.sh` from `no_compromised_gsd_package`. The rule still scans `tests/host/*.sh`, `tests/host/support/*.*`, the bundle fixtures and `tests/selftest`, and prints PASS.
- `host-test.sh` says `--keep` leaves the test sandbox up to look around after a failure. `print_next_block` prints `Cleanup when you are done:` plus the command, or the no-run-folder line; the Claude login sentence and the pointer to the manual folder are gone.
- H-31's two BSD `script` failure messages end after the log path.
- The checklist lost the Manual helpers section and rows H-07 and H-19; H-31 lists `h31-sbx-shell.sh` only, run automatic. The leaving-the-sandbox and last What-it-does bullets, the H-31 reading-a-failure bullet, Clean up and Record your results follow the code.
- `tests/README.md` has a single `tests/host/` row and section, an unattended Where, and a Does-not-catch that says no check runs Claude and H-09 and H-29 prove planted login files survive.
- `README.md` points the Verify section at the checklist for what each check proves and how to read a failure; the Free disk space bullet no longer promises a test Claude login. `clean.sh` banner for `remove_test_runs` is the same three-line shape as the others.

## Task Commits

1. **Task 1: Delete tests/host/manual/ with its guard glob; drop every code pointer to the helpers (tracer)** `22f8390` (test)
2. **Task 2: Remove the helpers from the checklist, the READMEs and clean.sh** `8bb95ae` (docs)

**Plan metadata:** committed separately (docs: complete plan)

## Deviations from Plan

### Plan verify command overreach (not a code deviation)

**1. [Scope] The first Task 1 grep matches archived planning harness files**
- **Found during:** Task 1 verification
- **Issue:** `git grep -n -E 'tests/host/manual|manual/h[0-9]' -- '*.sh'` has no `:!.planning` exclusion, so it matches three archived v1.0 harness scripts under `.planning/milestones/`. The plan's own wording is "no file outside .planning names a manual helper".
- **Action:** ran the same grep with `':!.planning'`; it prints nothing. The archived scripts are history and were left alone.

Otherwise the plan was executed as written.

## Verification

- `bash tests/guard/run-all.sh`: PASS (`All rules hold.`, `PASS: no_compromised_gsd_package`), after each task
- `bash -n host-test.sh tests/host/run-all.sh tests/host/h31-sbx-shell.sh clean.sh`: PASS
- `bash tests/selftest/entrypoint/run-all.sh` and `bash tests/selftest/sbx/run-all.sh`: PASS (`All cases pass.`)
- Remaining-glob `grep -F` and `test ! -e tests/host/manual`: PASS
- Same-commit check (the deleting commit lists `tests/guard/supply-chain.sh`): PASS
- `! grep -nE 'read -p|/dev/tty|\[y/N\]|require_terminal' host-test.sh tests/host/*.sh`: PASS
- Runner list-consistency loop (every listed check file exists): PASS
- `git diff --summary` shows no lost exec bit

## Mac-only checks (not run here)

- `./host-test.sh`: the run ends with the Next block showing only the cleanup command; nothing prompts. Covered by the final plan's Mac run.

## Known Stubs

None.

## Threat Flags

None. The change removes scripts and text; T-06-13 holds (only the deleted folder's glob left the scan list, the rule still passes).

## Self-Check: PASSED

- `tests/host/manual` is absent.
- Commits `22f8390` and `8bb95ae` exist on `chore/phase-06-test-diet`.
