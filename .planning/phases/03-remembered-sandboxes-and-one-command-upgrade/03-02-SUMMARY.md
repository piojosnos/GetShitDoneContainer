---
phase: 03-remembered-sandboxes-and-one-command-upgrade
plan: 02
subsystem: infra
tags: [bash, docker-compose, sbx-upgrade, guard, selftest, host-tests]

requires:
  - phase: 03-remembered-sandboxes-and-one-command-upgrade
    provides: bin/sbx-lib.sh (registry reader, run_compose, wait_until_ready), sbx self-test and host harness from plan 01
provides:
  - bin/sbx-upgrade NAME [BUILD_OPTION...] (build, recreate one sandbox, wait)
  - sandbox_is_running in bin/sbx-lib.sh
  - guard rule host_scripts_keep_sandbox_data (19 rules) and bin/* in the pipe-to-shell scan
  - docker-free refusal cases for sbx-upgrade
  - host check H-29 and the attended helper h29-upgrade-resume.sh
affects: [03-03 version line appended to sbx-upgrade, 03-04 gate and Mac run]

actuals:
  tokens: 11800
  tasks: 3
  commits: 3
plan_head_before: 978416efacd76b0efef2a7b671431f9fd631b0e4
plan_head_after: a05a5876f3c1cff6c5dd879fa1aa553ccfcf165a

tech-stack:
  added: []
  patterns:
    - "build.sh runs as its own process in an if-not condition; the recreate is reached only on success"
    - "up -d --force-recreate --wait on project sbx-NAME is the only compose call; the bind mount and every file stay"
    - "a grep guard over bin/* keeps delete, prune, kill, take-down and the volumes option out of the host scripts"

key-files:
  created:
    - bin/sbx-upgrade
    - tests/selftest/sbx/upgrade.sh
    - tests/host/h29-sbx-upgrade.sh
    - tests/host/manual/h29-upgrade-resume.sh
  modified:
    - bin/sbx-lib.sh
    - tests/guard/isolation.sh
    - tests/guard/supply-chain.sh
    - tests/selftest/guard/sandbox-rules.sh
    - tests/host/run-all.sh
    - tests/host-checklist.md

key-decisions:
  - "The open-sessions warning prints before the build and says 'after the build', so it is true whether or not the build succeeds"
  - "Options after the name go to build.sh unchanged, so --no-cache reaches both builds"
  - "The data guard is one grep rule over bin/*; no second rule for what bin/ sources"

requirements-completed: [SCR-03]

coverage:
  - id: D1
    description: "sbx-upgrade NAME builds both images, recreates only sbx-NAME with up -d --force-recreate --wait, waits for the start hooks and ends with the 'runs on the new images' line"
    requirement: "SCR-03"
    verification:
      - kind: integration
        ref: "tracer command (stand-in docker records: container build build compose exec; both builds carry --no-cache)"
        status: pass
    human_judgment: false
  - id: D2
    description: "A failed build exits non-zero, prints 'the build failed; sbx-NAME was left as it was' and makes no compose call"
    requirement: "SCR-03"
    verification:
      - kind: integration
        ref: "tracer command (failing stand-in build: no 'docker compose' line recorded)"
        status: pass
    human_judgment: false
  - id: D3
    description: "A bad or unregistered name, a missing project folder and a missing state folder stop sbx-upgrade before build.sh runs, with no docker call"
    requirement: "SCR-03"
    verification:
      - kind: unit
        ref: "tests/selftest/sbx/upgrade.sh#sbx-upgrade: a missing state folder is refused before the build"
        status: pass
    human_judgment: false
  - id: D4
    description: "Guard rule host_scripts_keep_sandbox_data refuses delete, prune, kill, take-down words and the volumes option in bin/*; the pipe rule scans bin/*"
    requirement: "SCR-03"
    verification:
      - kind: unit
        ref: "tests/selftest/guard/sandbox-rules.sh#host scripts: a compose take-down in sbx-stop fails"
        status: pass
      - kind: unit
        ref: "tests/selftest/guard/sandbox-rules.sh#host scripts: a delete in sbx-upgrade fails"
        status: pass
    human_judgment: false
  - id: D5
    description: "On real Docker: one new container, other sbx containers and the volume list unchanged, files in NAME/, state/ and state/claude kept, one bind mount, a stopped sandbox ends up running, login and claude --continue survive"
    requirement: "SCR-03"
    verification: []
    human_judgment: true
    rationale: "H-29 and the helper need the Mac's Docker and a Claude login; both are written and linted here and run in plan 04"

duration: 20min
completed: 2026-11-06
status: complete
---

# Phase 3 Plan 02: sbx-upgrade, the Data Guard and the Mac Proof Summary

**`sbx-upgrade NAME [BUILD_OPTION...]` validates the name, entry and folders, runs build.sh as its own step, then recreates only that sandbox with `up -d --force-recreate --wait`; a guard rule keeps every destructive word out of `bin/`, and H-29 plus an attended login helper are ready for the Mac run.**

## Performance

- **Duration:** about 20 min
- **Completed:** 2026-11-06T20:18Z
- **Tasks:** 3 (Task 1 tracer, Task 2 TDD, Task 3 auto)
- **Files modified:** 10 (4 created, 6 modified)

## Accomplishments

- `bin/sbx-upgrade` (100755, 69 lines) with `warn_if_running`, `run_build`, `recreate_sandbox`; `sandbox_is_running` added to `bin/sbx-lib.sh`.
- Docker-free self-test group `tests/selftest/sbx/upgrade.sh`: six cases; the sbx self-test now has 60 PASS lines and ends `All cases pass.`
- Guard rule `host_scripts_keep_sandbox_data` plus `bin/*` in `no_pipe_to_shell_installers`; rehearsal guard ends `All rules hold.` with 19 PASS lines.
- H-29 (`tests/host/h29-sbx-upgrade.sh`, 242 lines) in the chain after H-28, the helper `tests/host/manual/h29-upgrade-resume.sh` (149 lines), checklist row, helper command and helper table row. Neither has run (no Docker here); both run in plan 04.

## Task Commits

1. **Task 1: Tracer, sbx-upgrade builds, then recreates one sandbox** - `e2795de` (feat)
2. **Task 2: Refusals before the build and the data guard** - `ce283eb` (test)
3. **Task 3: H-29, the attended helper, runner and checklist** - `a05a587` (test)

**Plan metadata:** not committed. The plan says to leave this SUMMARY and every other `.planning/` file uncommitted for the orchestrator.

## Evidence

- **Tracer, recorded call order (good run):** `container build build compose exec`. Both builds `docker build --no-cache -f base/Dockerfile ...` and `... claude/Dockerfile ...`. Compose line: `docker compose --env-file /dev/null -p sbx-demo -f REPO/compose.yml up -d --force-recreate --wait | SBX_DIR=<registered folder with a space>`. Last stdout line: `sbx-upgrade: sbx-demo runs on the new images`.
- **Tracer, failing build:** exit non-zero, `the build failed; sbx-demo was left as it was` on stderr, the running warning on stdout, no `docker compose` line recorded.
- **sbx self-test:** 60 PASS lines, `All cases pass.`; the six new cases are the named `sbx-upgrade:` cases.
- **Guard self-test new lines (all PASS, group ends `All cases pass.`):**
  - `host scripts: a clean copy passes the data rule`
  - `host scripts: a compose take-down in sbx-stop fails`
  - `host scripts: a delete in sbx-upgrade fails`
  - `supply chain: a download piped to sh in an sbx host script fails`
  - `supply chain: the old GSD package in bin/sbx-lib.sh fails`
- **Rehearsal guard:** `PASS: host_scripts_keep_sandbox_data`, 19 PASS lines, `All rules hold.` The entrypoint self-test still ends `All cases pass.`
- **RED proof (Task 2):** before the rule existed, the clean-copy case and both plant cases failed on `FAIL: host scripts: ...` (the target assertions), and the sbx-host-script pipe plant failed because `bin/*` was not scanned. After the rule and the list change they pass.
- **shellcheck (warning level)** clean for the new and changed files in all three tasks; no non-ASCII; comments at most 80 columns.
- **Line counts:** `bin/*` 549 (sbx-add 168, sbx-lib.sh 245, sbx-start 34, sbx-stop 33, sbx-upgrade 69); `tests/guard/*.sh` 562 plus `tests/selftest/guard/*.sh` 373 (935 together); `tests/host/h29-sbx-upgrade.sh` 242; `tests/host/manual/h29-upgrade-resume.sh` 149.
- **Not verified here:** H-29 and the helper (need the Mac's Docker, and a Claude login for the helper); `/bin/bash` 3.2 behaviour of the new scripts (this sandbox has bash 5.3). Both belong to plan 04.

## Decisions Made

- The warning says "after the build, recreating it will close ..." and prints before the build, so the user can still stop the run.
- `--force-recreate` because a cached build keeps the image id and a plain `up` would keep the old container.
- The helper restores the test sandbox when its add or start step fails, so a failed prepare does not leave the shared test sandbox down.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] shellcheck SC2154 on repoDir in bin/sbx-upgrade**
- **Found during:** Task 1 (verify command 2)
- **Issue:** `repoDir` is set by the sourced library; shellcheck at warning level flags it.
- **Fix:** a file-level `# shellcheck disable=SC2154` with a one-line reason before `set -eu`, the same form as `bin/sbx-stop`.
- **Files modified:** bin/sbx-upgrade
- **Committed in:** e2795de

**2. [Rule 3 - Blocking] Two banner lines the plan wrote were over 80 columns**
- **Found during:** Task 2 (verify command 2 checks comments at most 80 columns)
- **Issue:** the plan's isolation.sh title line (87 columns), its rule banner (82) and the `case_host_script_rule` banner (84) break the 80-column check it also demands.
- **Fix:** shortened wording: `no socket` instead of `no Docker socket`; `bin/ has no delete, prune, kill or take-down`; `a planted take-down or delete`.
- **Files modified:** tests/guard/isolation.sh, tests/selftest/guard/sandbox-rules.sh
- **Committed in:** ce283eb

**3. [Rule 2 - Missing critical] Helper restores the test sandbox on a failed prepare**
- **Found during:** Task 3
- **Issue:** the helper takes the shared test sandbox down in `prepare`; a failure in add or start would leave it down for later checks.
- **Fix:** `restore_test_sandbox h29m` before `return 1` in those two branches.
- **Files modified:** tests/host/manual/h29-upgrade-resume.sh
- **Committed in:** a05a587

---

**Total deviations:** 3 auto-fixed (2 Rule 3, 1 Rule 2)
**Impact on plan:** none on behavior; output lines match the plan's wording.

## TDD Gate Compliance

Task 2 is `tdd="true"`. The cases were written first and run against the tree before the rule and the list change existed (RED: the named host-script and pipe cases printed `FAIL`), then the rule made them pass. The plan asks for a single commit for the four files, so the RED and GREEN states are one commit (`ce283eb`), not separate `test` and `feat` commits.

## Edge Coverage Note

The plan's flagged assumption stands: two `sbx-upgrade` runs at once, or an upgrade while another sandbox starts, are not handled. No file is lost in either case.

## Issues Encountered

None beyond the deviations above.

## Known Stubs

None.

## Threat Flags

None. No new network endpoint, auth path or schema; `sbx-upgrade` adds one `docker compose up` call on the existing call shape, covered by the plan's threat model.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 03 can append the version line to `bin/sbx-upgrade` after its last `echo`.
- H-29 and the helper wait for the Mac run in plan 04, along with H-28 and the bash 3.2 run of the self-test.

## Self-Check: PASSED

- Created files exist: `bin/sbx-upgrade`, `tests/selftest/sbx/upgrade.sh`, `tests/host/h29-sbx-upgrade.sh`, `tests/host/manual/h29-upgrade-resume.sh` found on disk.
- Commits `e2795de`, `ce283eb`, `a05a587` found in `git log`; `git rev-list --count 978416e..HEAD` is 3.
- Re-ran at the end: tracer, sbx self-test (60 PASS), guard self-test, rehearsal guard (19 PASS, All rules hold.), entrypoint self-test.

---
*Phase: 03-remembered-sandboxes-and-one-command-upgrade*
*Completed: 2026-11-06*
