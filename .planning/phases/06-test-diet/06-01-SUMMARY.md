---
phase: 06-test-diet
plan: 01
subsystem: testing
tags: [bash, selftest, docker, sbx]

requires: []
provides:
  - "sbx self-test with no docker stand-in: start_group points DOCKER_HOST at a missing socket"
  - "121 refusal and Docker-not-answering cases in tests/selftest/sbx/ (down from 230)"
affects: [06-02, host-test.sh]

actuals:
  tokens: 17682
  tasks: 3
  commits: 3
plan_head_before: a0629f012b263b9b40a92f6f2e5f93d35f931aed
plan_head_after: 3a8f9acd9ba1c13c21d729af4a0b32953f846162

tech-stack:
  added: []
  patterns:
    - "Self-tests reach Docker only through DOCKER_HOST=unix:///nonexistent with DOCKER_CONTEXT unset"

key-files:
  created: []
  modified:
    - tests/selftest/sbx/lib.sh
    - tests/selftest/sbx/start.sh
    - tests/selftest/sbx/upgrade.sh
    - tests/selftest/sbx/shell.sh
    - tests/selftest/sbx/list.sh
    - tests/selftest/sbx/add.sh
    - tests/selftest/sbx/entry.sh
    - tests/selftest/sbx/rm.sh
    - tests/selftest/sbx/fix-modes.sh
    - tests/README.md

key-decisions:
  - "Deletions only: kept cases keep their labels and assertions; only the runner changed (run_sbx_scripted to run_sbx, refused_before_* to refused_cleanly)"
  - "The Bad_Name rm case now asserts the name-rule text, which proves the order without a call log"
  - "The noimage registration stays in shell.sh because the kept Docker-not-answering run uses that sandbox"

requirements-completed: [DIET-05]

coverage:
  - id: D1
    description: "No docker stand-in remains under tests/selftest; start_group exports DOCKER_HOST=unix:///nonexistent and unsets DOCKER_CONTEXT"
    requirement: DIET-05
    verification:
      - kind: unit
        ref: "bash tests/selftest/sbx/run-all.sh (All cases pass., 121 PASS, 0 FAIL); grep for stand-in helper names under tests/selftest prints nothing"
        status: pass
    human_judgment: false
  - id: D2
    description: "The four Docker-not-answering cases pass on the real failure (sbx-start, sbx-shell, sbx-rm broken entry, sbx-list)"
    requirement: DIET-05
    verification:
      - kind: unit
        ref: "bash tests/selftest/sbx/run-all.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: "tests/README.md describes the sbx self-test as it now is"
    requirement: DIET-05
    verification:
      - kind: other
        ref: "grep -n DOCKER_HOST tests/README.md"
        status: pass
    human_judgment: false
  - id: D4
    description: "The sbx self-test step of ./host-test.sh finishes OK under /bin/bash 3.2 on the Mac without hanging on the missing socket"
    verification: []
    human_judgment: true
    rationale: "Needs the Mac and its Docker CLI; Docker is not available in the dev sandbox"

duration: 2min
completed: 2026-11-13
status: complete
---

# Phase 6 Plan 01: sbx self-test with no stand-in docker Summary

**The sbx self-test now runs the real bin/ scripts with DOCKER_HOST pointing at a socket that does not exist; the fence and the scripted fake docker are gone, and 109 Docker-dependent cases were deleted (230 to 121).**

## Performance

- **Duration:** 2 min
- **Started:** 2026-11-13T08:09:11Z
- **Completed:** 2026-11-13T08:11:18Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments

- `start_group` exports `DOCKER_HOST=unix:///nonexistent` and unsets `DOCKER_CONTEXT`, with no PATH change and no fence, so the real docker binary cannot reach a daemon from any case.
- `make_scripted_docker`, the `set_standin_*` helpers, `reset_standin_calls`, `appears_before`, `run_sbx_scripted`, `run_sbx_in_terminal` and `no_docker_call` are deleted from `tests/selftest/sbx/lib.sh`.
- Each group keeps only refusals before Docker and Docker-not-answering cases; every group still prints PASS lines (add 48, entry 19, fix-modes 17, upgrade 5, start 3, shell 9, list 2, rm 18), so `run-all.sh` needed no change.
- `tests/README.md` section for the sbx self-test matches the code.

## Task Commits

1. **Task 1: Point Docker at a missing socket in start_group; trim start.sh (tracer)** - `1765fd5` (test)
2. **Task 2: Trim shell.sh and list.sh; drop the no-docker-call line from add.sh and entry.sh** - `bc58c1f` (test)
3. **Task 3: Trim rm.sh; delete the scripted fake from lib.sh; update tests/README.md** - `3a8f9ac` (test)

**Plan metadata:** committed separately (docs: complete plan)

## Files Created/Modified

- `tests/selftest/sbx/lib.sh` - start_group with the missing socket; stand-in helpers deleted
- `tests/selftest/sbx/start.sh` - `case_docker_down` plus the shared wording case
- `tests/selftest/sbx/shell.sh` - refusals and the Docker-not-answering run
- `tests/selftest/sbx/list.sh` - usage case and the failed docker ps case
- `tests/selftest/sbx/rm.sh` - usage, refusals, broken-entry refusals, new name-rule expect
- `tests/selftest/sbx/add.sh`, `entry.sh`, `fix-modes.sh`, `upgrade.sh` - final no-docker-call expect removed
- `tests/README.md` - sbx self-test section rewritten

## Decisions Made

See key-decisions. The tracer (Task 1) was verified end to end by the full sbx suite before the other groups were converted.

## Deviations from Plan

None - plan executed exactly as written. Two cosmetic touches inside the plan's scope: the lib.sh file header and one start_group comment line were shortened to stay within 80 columns.

## Verification

- `bash tests/selftest/sbx/run-all.sh`: PASS (ends `All cases pass.`, 121 PASS lines, 0 FAIL lines)
- Per group PASS counts: add 48, entry 19, fix-modes 17, upgrade 5, start 3, shell 9, list 2, rm 18: PASS
- `DOCKER_CONTEXT=foo bash tests/selftest/sbx/start.sh`: PASS (the context is unset by start_group)
- `grep -rnE` for the stand-in helper names, call logs and fence folders under `tests/selftest`: no hits
- `bash tests/guard/run-all.sh`: PASS (`All rules hold.`, shellcheck covers the edited files)
- Mac step of `./host-test.sh` under `/bin/bash` 3.2: not run here (no Docker in the dev sandbox); left as a backstop for the user

## Known Stubs

None.

## Threat Flags

None.

## Self-Check: PASSED

- Commits `1765fd5`, `bc58c1f` and `3a8f9ac` exist on `chore/phase-06-test-diet`.
- All ten files in `files_modified` exist and were changed by these commits.
