---
phase: 06-test-diet
plan: 04
subsystem: testing
tags: [bash, host-tests, compose-preflight, claude-checks-removed]

requires: ["06-02", "06-03"]
provides:
  - "host-test.sh require_compose_v2: Compose v2 preflight, first line of main"
  - "26 host checks (was 32); no host check drives Claude or checks GSD resync or Maven Central"
  - "H-28 check_stop times sbx-stop (10 s threshold), replacing H-11"
affects: [06-05, 06-06, host-test.sh]

actuals:
  tokens: 18800
  tasks: 3
  commits: 4
plan_head_before: f5a80f77d5fef9723f6bc72b806ea6ed2fe544dc
plan_head_after: e00e77c7024c7ee4356868148d69eaa98172eaf2

tech-stack:
  added: []
  patterns:
    - "Preflight as an early exit in main (left of the tee pipe), so the message lands in host-test.log"
    - "Check IDs keep their gaps; nothing is renumbered"

key-files:
  created: []
  modified:
    - host-test.sh
    - tests/host/run-all.sh
    - tests/host/h13-env-and-no-self-update.sh
    - tests/host/h15-bundle-linked-and-visible.sh
    - tests/host/h16-live-clone-and-restart.sh
    - tests/host/h23-caches-survive-recreate.sh
    - tests/host/h28-sbx-add-start-stop.sh
    - tests/host-checklist.md
    - tests/README.md
    - README.md
    - tests/guard/lib.sh
  deleted:
    - tests/host/h00-compose-v2.sh
    - tests/host/h02-claude-on-base.sh
    - tests/host/h11-stop-is-quick-and-safe.sh
    - tests/host/h18-scope-and-deny.sh
    - tests/host/h21-bad-name-refused.sh
    - tests/host/h24-ccusage-reports-usage.sh
    - tests/host/support/fake-claude-api.js

key-decisions:
  - "H-11 folds into H-28 as a timing of the user-facing sbx-stop; the container-kept and sentinel checks H-28 already had cover the rest"
  - "The preflight lives only in host-test.sh; a direct run of tests/host/run-all.sh does not check the Compose version and the checklist says so"
  - "H-17 stays untouched: it checks our start hook syncing GSD offline, which the plan scope (H-13, H-15, H-16, H-23) did not include"

requirements-completed: [DIET-02]

coverage:
  - id: D1
    description: "A missing Compose v2 stops host-test.sh at the preflight with the one-line message in host-test.log and no step heading after it"
    requirement: DIET-02
    verification:
      - kind: other
        ref: "scratch-copy probe from the plan (rc=1, message in log, no '== ' heading); a fake docker printing 2.29.1, v5.0.0 and 10.1.0 passes the parse, 1.29.2 fails it"
        status: pass
    human_judgment: false
  - id: D2
    description: "The runner lists 26 checks, every listed file exists, every h*.sh is listed, the chain order is unchanged, no fatal Compose slot remains"
    requirement: DIET-02
    verification:
      - kind: other
        ref: "list-consistency loop plus the 26-word count; greps for fatalCheck and run_compose_check"
        status: pass
    human_judgment: false
  - id: D3
    description: "H-02, H-18, H-21, H-24 and fake-claude-api.js are deleted; H-13, H-15, H-16 and H-23 keep only setup parts; docs name no deleted check"
    requirement: DIET-02
    verification:
      - kind: other
        ref: "bash -n on host-test.sh and tests/host/*.sh; bash tests/guard/run-all.sh (All rules hold.); negative greps for claude -p, claude update, ANTHROPIC_, maven-dependency-plugin, fake-claude; kept-parts check; checklist greps"
        status: pass
    human_judgment: false
  - id: D4
    description: "check_stop times sbx-stop and adds a problem at 10 s or more"
    requirement: DIET-02
    verification:
      - kind: other
        ref: "awk region check over check_stop for the 'stopSeconds -ge 10' test and two date +%s calls"
        status: pass
    human_judgment: false
  - id: D5
    description: "On the Mac, the trimmed H-13, H-15, H-16, H-23 and the extended H-28 print PASS in ./host-test.sh, and a Mac with Compose v2 passes the preflight"
    verification: []
    human_judgment: true
    rationale: "Needs the Mac and Docker Desktop; Docker is not available in the dev sandbox. Proven in the final plan's Mac run"

duration: 15min
completed: 2026-11-13
status: complete
---

# Phase 6 Plan 04: Host checks stop testing Claude Summary

**H-00 is now one `require_compose_v2` preflight in `host-test.sh`, five Claude-driving checks and the fake Claude API are deleted, H-11 is a stop timing inside H-28, and H-13, H-15, H-16 and H-23 keep only the parts that check our setup; the runner lists 26 checks.**

## Performance

- **Duration:** about 15 min
- **Completed:** 2026-11-13
- **Tasks:** 3 (plus the small `SHELL_FILES` comment fix)
- **Files:** 11 modified, 7 deleted

## Accomplishments

- `require_compose_v2` runs first in `main` and exits 1 with `Docker Compose v2 or newer is required; install Docker Desktop`. It is an early exit left of the tee pipe, so the message reaches `host-test.log` and no step heading, run folder or build follows.
- `h00-compose-v2.sh`, `fatalCheck` and `run_compose_check` are gone.
- `h02`, `h11`, `h18`, `h21`, `h24` and `tests/host/support/fake-claude-api.js` are deleted. The one-FROM rule is a guard rule; the name rule stays covered by the sbx-add self-test cases.
- `check_stop` in H-28 reads `date +%s` before and after `sbx-stop` and adds a problem at 10 s or more; the pass text says so.
- H-13 lost the `claude update` reply, H-15 the `claude -p /context` listing, H-16 the aged GSD, the GSD skill edit and the resync assertion (`pick_samples` became `require_clone`), H-23 the Maven Central download.
- Checklist rows and failure notes, the README Verify table and `tests/README.md` describe only the kept checks and say H-01 to H-33 with gaps.

## Task Commits

1. **Task 1: H-00 becomes the Compose preflight in host-test.sh (tracer)** `daa1b0a` (test)
2. **Task 2: Delete H-02, H-18, H-21, H-24 and the fake Claude API; fold H-11 into H-28** `6de1c31` (test)
3. **Task 3: Trim H-13, H-15, H-16 and H-23** `0407528` (test)
4. **Extra: state the real reason `SHELL_FILES` uses globs** `e00e77c` (chore)

**Plan metadata:** committed separately (docs: complete plan)

## Extra fix: `tests/guard/lib.sh` comment

The old comment said the globs exist because the guard self-test copy has no `.git`; that self-test is gone. The globs are still needed for another reason: the list names scripts without a `.sh` extension (`bin/*`, `base/sbx-entrypoint`, `tests/selftest/*/support/fake-gsd`), which a `git ls-files '*.sh'` list would miss, and the guard also runs by hand in a Mac shell with no repository assumption. The comment now says that. Code unchanged; the guard passes.

## Deviations from Plan

### Plan verify command overreach (not a code deviation)

**1. [Scope] The negative grep in Task 3 and the phase verification matches H-17**
- **Found during:** Task 3 verification
- **Issue:** the plan's pattern includes `gsd-core/VERSION`; `tests/host/h17-start-offline-and-failing-hook.sh` (`check_offline_gsd`) legitimately reads it to prove our start hook syncs GSD offline. H-17 is not in this plan's files and D-06 lists only H-13, H-15, H-16 and H-23.
- **Action:** left H-17 as is. Every other pattern in the grep, and the whole phase verification grep, print nothing.
- **Follow-up:** if the intent is that no host check asserts on the GSD sync at all, H-17's `check_offline_gsd` is the one place left; that is a separate decision.

Otherwise the plan was executed as written. The manual helpers `h13-doctor.sh` and `h16-gsd-bump.sh` and the checklist text about them are still listed; the plan leaves them to the next plan.

## Verification

- `bash -n host-test.sh tests/host/*.sh`: PASS
- `bash tests/guard/run-all.sh`: PASS (`All rules hold.`), after each task and after the extra fix
- `bash tests/selftest/entrypoint/run-all.sh` and `bash tests/selftest/sbx/run-all.sh`: PASS (`All cases pass.`)
- Preflight probe in a scratch copy (no docker): rc=1, message in the log, no `== ` heading: PASS
- Fake `docker compose version --short` output 2.29.1, v5.0.0, 10.1.0 pass the parse and 1.29.2 fails it: PASS
- List-consistency loop and the 26-check count: PASS
- Negative greps for `claude -p|update|doctor|auth`, `ANTHROPIC_*`, `maven-dependency-plugin`, `fake-claude` over `tests/host/*.sh`, `host-test.sh`, `README.md`: nothing printed

## Mac-only checks (not run here)

- `./host-test.sh`: the preflight passes on a Mac with Compose v2; H-13, H-15, H-16, H-23 and the extended H-28 print PASS (covered by the final plan's Mac run).

## Known Stubs

None.

## Threat Flags

None. No new network, auth or file surface; the change only removes checks.

## Self-Check: PASSED

- Deleted files are absent and the seven kept-part greps pass.
- Commits `daa1b0a`, `6de1c31`, `0407528` and `e00e77c` exist on `chore/phase-06-test-diet`.
