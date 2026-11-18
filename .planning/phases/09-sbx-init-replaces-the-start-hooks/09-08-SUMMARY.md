---
phase: 09-sbx-init-replaces-the-start-hooks
plan: 08
subsystem: infra
tags: [bash, host-scripts, sbx-init, compose]

requires:
  - phase: 09-sbx-init-replaces-the-start-hooks
    provides: sbx-init as the replacement for the start hooks (plan 01)
provides:
  - the sandbox name rule held in bin/sbx-lib.sh, independent of base/
  - bring_up_sandbox and sbx-upgrade without a readiness poll
  - sbx-start, sbx-upgrade and sbx-shell texts that point at sbx-init
affects: [09-09, 09-13]

actuals:
  tokens: 4000
  tasks: 2
  commits: 2
plan_head_before: c7902bb4b8a11d76924c64ca8a8b9e208b42ff2e
plan_head_after: 0f71504c9def091344358bc945913e68bc8cef91

tech-stack:
  added: []
  patterns:
    - "Host scripts carry their own name rule; nothing in bin/ reads base/"

key-files:
  created: []
  modified:
    - bin/sbx-lib.sh
    - bin/sbx-upgrade
    - bin/sbx-start
    - bin/sbx-shell
    - tests/selftest/sbx/add.sh

key-decisions:
  - "The name rule values were copied verbatim from the start library, so every refusal text is unchanged"
  - "The reminder to run sbx-init is printed by the host scripts, which never run sbx-init themselves"

patterns-established:
  - "The repo-overlap self-test runs the host scripts from a copy of bin/ alone, which proves they need nothing from base/"

requirements-completed: [INIT-03]

coverage:
  - id: D1
    description: "bin/sbx-lib.sh sets the name rule and reserved names; no host script sources base/sbx-start-lib.sh"
    requirement: INIT-03
    status: covered
    evidence: "sbx self-test: 150 cases pass, including the repo-overlap case run from a bin/-only copy"
  - id: D2
    description: "Nothing in bin/ waits for start hooks; sbx-start and sbx-upgrade tell the user to run sbx-init"
    requirement: INIT-03
    status: covered
    evidence: "grep for wait_until_ready, startLimitSeconds, pgrep and start hooks prints 0 in each file; guard run-all.sh ends with All rules hold."
  - id: D3
    description: "docker compose up -d --wait returns once the container runs (no healthcheck), so nothing else waits"
    requirement: INIT-03
    status: not-run
    evidence: "Needs Docker; Mac run of H-28, H-29 and H-31 in plan 09-13"
---

# Phase 9 Plan 08: Host side without the start library Summary

**The host scripts hold the sandbox name rule themselves, no longer poll for start hooks, and tell the user to run sbx-init in the sandbox shell.**

## Performance

- **Tasks:** 2 (tracer, auto)
- **Commits:** 2

## Accomplishments

- `nameRulePattern`, `nameRuleText` and `reservedNameList` now live in `bin/sbx-lib.sh`, copied verbatim; `read_start_variable` and `load_name_rule` are gone.
- `case_repo_overlap` runs from a copy of `bin/sbx-*` alone, so a host script that reached into `base/` would fail the self-test.
- `wait_until_ready` and `startLimitSeconds` are deleted; `bring_up_sandbox` ends after `up -d --wait`, and `sbx-upgrade` ends after its recreate.
- `sbx-start` and `sbx-upgrade` print a line to run `sbx-init`; the `sbx-shell` header says the same. The last two `sbx-upgrade` lines (runs on the new images, tool versions) are unchanged.

## Task Commits

1. Task 1 (tracer): `98baa1f` refactor(09-08): host lib holds the sandbox name rule itself
2. Task 2: `0f71504` feat(09-08): drop the start-hook readiness poll and point at sbx-init

The tracer gate: the sbx self-test passed with 150 cases after Task 1, before expansion into Task 2.

## Verification

- `bash tests/selftest/sbx/run-all.sh`: `All cases pass.`, 150 PASS lines (after both tasks).
- `bash tests/guard/run-all.sh`: `All rules hold.`
- Acceptance greps all print 0 for the removed names; `up -d --wait` and `up -d --force-recreate --wait` each appear once.

## Deviations from Plan

None. The plan was executed as written.

## Known Stubs

None.

## Threat Flags

None.

## Next Phase Readiness

Plan 09-09 can delete `base/sbx-start-lib.sh` without breaking a host script. The Mac check that `up --wait` returns without a healthcheck (assumption A2) is covered by plan 09-13.

## Self-Check: PASSED

- bin/sbx-lib.sh, bin/sbx-upgrade, bin/sbx-start, bin/sbx-shell, tests/selftest/sbx/add.sh exist.
- Commits 98baa1f and 0f71504 exist.
