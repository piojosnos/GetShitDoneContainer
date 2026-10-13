---
phase: 02-pinned-toolchain-gsd-and-ccusage
plan: 06
subsystem: testing
tags: [host-tests, h16, gsd, compose-up, fake-docker, attended-helper, sandbox-docs]

requires:
  - phase: 02-pinned-toolchain-gsd-and-ccusage
    provides: the pinned GSD install and the 05-gsd start hook, fake-gsd and the fake docker that runs every start hook (plan 05)
provides:
  - wait_for_start_hooks in tests/host/lib-sandbox.sh, and a compose_up that returns only after the start hooks have finished
  - H-16 extended to plant a stale GSD, a settings key and a session transcript, and to require GSD back at the pin with the user's files unchanged
  - tests/host/manual/h16-gsd-bump.sh, the attended helper for a real GSD pin bump with a logged-in sandbox
  - fake docker answers for pgrep -x sleep (knobs FAKE_START_POLLS, FAKE_STOPS_AT_START) and for node -e
  - SANDBOX.md "GSD" section and two troubleshooting rows; checklist row and fifth helper
affects: [02-07, 02-08, 02-09]

actuals:
  tokens: 6000
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "compose_up waits for the container command (sleep), which the entrypoint execs only after the last start hook, so no check reads state/claude mid-sync"
    - "An attended helper never edits a tracked file: the user changes the pin and the helper prints how to put it back"

key-files:
  created:
    - tests/host/manual/h16-gsd-bump.sh
  modified:
    - tests/host/lib-sandbox.sh
    - tests/selftest/host/support/fake-docker
    - tests/selftest/host/units.sh
    - tests/host/h16-sync-refreshes-and-spares.sh
    - tests/selftest/host/h16-sync-refreshes-and-spares.sh
    - tests/host-checklist.md
    - SANDBOX.md
    - tests/host/run-all.sh

key-decisions:
  - "The wait polls pgrep -x sleep inside the container instead of adding a compose healthcheck, because a healthcheck would touch Phase 1 files"
  - "H-16 no longer plants a gsd-* skill as a user file: GSD owns that prefix, and SANDBOX.md tells users to name their own skills otherwise"
  - "The settings key is planted by node inside the container, because the host has no JSON tool the guard allows"
  - "requirements-completed stays empty and TOOL-02 and TOOL-03 stay pending, because plans 02-08 and 02-09 declare them and have no SUMMARY yet"

patterns-established:
  - "A fake docker exec handler that must return a non-zero status returns it explicitly, because fake_exec ends with return 0"

requirements-completed: []

coverage:
  - id: D1
    description: "compose_up returns only after the start hooks have finished (a running sleep in the container); it fails at once when the sandbox stops during its start, and after SBXTEST_START_SECONDS when the hooks never finish"
    requirement: TOOL-02
    verification:
      - kind: unit
        ref: "bash tests/selftest/host/units.sh (5 'lib: compose_up' cases)"
        status: pass
      - kind: manual_procedural
        ref: "run-all.sh on the Mac (plan 09): the real entrypoint execs sleep only after the last hook"
        status: unknown
    human_judgment: false
  - id: D2
    description: "H-16 plants a stale GSD (VERSION 0.0.0 and a hand edit in a skills/gsd-* skill), a settings key, a session transcript, a user skill, a memory and a CLAUDE.md, restarts, and passes only when GSD is at the pin with the edit undone and every user file and the settings key unchanged"
    requirement: TOOL-02
    verification:
      - kind: unit
        ref: "bash tests/selftest/host/h16-sync-refreshes-and-spares.sh (26 PASS lines; no-sync, drops-settings, never-synced and clobber cases fail as they should)"
        status: pass
      - kind: manual_procedural
        ref: "H-16 in bash tests/host/run-all.sh on the Mac (plan 09), against the real gsd-core installer"
        status: unknown
    human_judgment: false
  - id: D3
    description: "tests/host/manual/h16-gsd-bump.sh does the real pin bump with a Claude login: waits while the user changes GSD_CORE_VERSION, rebuilds, restarts, checks state/claude, gsd-tools, the start log (no npx, no @latest) and claude auth status, asks whether claude --continue resumed, and prints how to put the pin back; it edits no file"
    requirement: TOOL-02
    verification:
      - kind: other
        ref: "bash -n, tests/guard/host-tests.sh, docs.sh, planning-ids.sh and supply-chain.sh pass; the helper cannot run on Linux (needs a terminal, Docker and a login)"
        status: pass
      - kind: manual_procedural
        ref: "bash tests/host/manual/h07-login.sh, then bash tests/host/manual/h16-gsd-bump.sh on the Mac (plan 09)"
        status: unknown
    human_judgment: true
    rationale: "Needs Docker on the Mac and a real Claude login; resuming a session is judged by a person"
  - id: D4
    description: "SANDBOX.md explains what a start does to GSD in state/claude, that a failed sync stops the start, and that GSD is upgraded only by changing its pin and rebuilding; the checklist and run-all.sh header name the new helper and SBXTEST_START_SECONDS"
    requirement: TOOL-02
    verification:
      - kind: other
        ref: "acceptance greps on SANDBOX.md, tests/host-checklist.md and tests/host/run-all.sh; tests/guard/docs.sh checklist_lists_every_host_check"
        status: pass
    human_judgment: true
    rationale: "Whether the prose is clear to a maintainer is a reading judgment"

duration: not recorded
completed: 2026-10-09
status: complete
commits: 2
plan_head_before: 92bf28775e0f82e3c2d5a6d2cc477776520fc9a1
plan_head_after: ae3f53a820c91c4870f9553f2d46d16220768888
---

# Phase 2 Plan 06: Stale GSD restored by a restart, with an attended pin bump helper Summary

**compose_up now waits for the start hooks (a running `sleep` in the container), H-16 proves a restart puts a stale GSD back at the pin while the user's settings key, sessions, memories, skills and CLAUDE.md stay, and `manual/h16-gsd-bump.sh` does the real GSD pin bump with a logged-in sandbox; SANDBOX.md gains a GSD section.**

## Performance

- **Duration:** not recorded
- **Completed:** 2026-10-09T04:14:50Z (approximate; the start time was not captured)
- **Tasks:** 2
- **Files modified:** 9 (1 created, 8 modified)

## Accomplishments

- `wait_for_start_hooks` polls `docker exec sbx-hosttest pgrep -x sleep` once a second for `SBXTEST_START_SECONDS` (default 120). It returns 1 at once with a "stopped during its start" message when the container is no longer running, and with a "did not finish within N s" message when time runs out. `compose_up` calls it after a successful `up --wait` and appends its output to the same log, so every host check and the runner read `state/claude` only after the last hook.
- H-16 plants a stale `gsd-core/VERSION` (`0.0.0`), a hand edit in the first `skills/gsd-*` skill, a settings key (written by node inside the container), a session transcript, a user skill, a memory and a CLAUDE.md. After the restart `check_gsd_refreshed` requires VERSION to equal `GSD_CORE_VERSION` and the edit to be gone, and `check_user_files_spared` requires every user file and the settings key to be unchanged. The old `gsd-h16-sample` user skill is gone from both the check and its self-test.
- The attended helper `tests/host/manual/h16-gsd-bump.sh` checks a login exists, waits while the user sets `GSD_CORE_VERSION` to the approved bump target, rebuilds through `build_images`, restarts, then checks `state/claude/gsd-core/VERSION`, `gsd-tools runtime-identity --raw`, the start log (`[sbx] GSD NEW synced`, no `npx`, no `@latest`) and `claude auth status`, asks whether `claude --continue` resumed, and prints `git checkout -- versions.env` and `./build.sh`. It writes nothing in the repo.
- SANDBOX.md has a `## GSD` section (what a start does in `state/claude`, `gsd-*` ownership, a failed sync stops the start, upgrade only by pin and rebuild, the second Claude binary under `/usr/local/lib`), two troubleshooting rows, and a "Verify a new build" sentence naming the GSD bump helper.

## TDD record (Task 1 tracer)

Red, before any library, fake or check change (new self-test cases only):

```
bash tests/selftest/host/units.sh
FAIL: lib: compose_up asked pgrep three times
FAIL: lib: compose_up fails when the start hooks never finish
FAIL: lib: compose_up fails at once when the sandbox stops during its start
FAIL: lib: compose_up asked pgrep once before it gave up on the stopped sandbox

bash tests/selftest/host/h16-sync-refreshes-and-spares.sh
FAIL: H-16: the settings key survives
FAIL: H-16: the session transcript survives
FAIL: H-16: the stale GSD version is named
FAIL: H-16: a sync that drops the user's settings fails
FAIL: H-16: the lost settings key is named
FAIL: H-16: a sandbox where GSD never synced fails
FAIL: H-16: the missing GSD is named
```

Green, after the changes: `units.sh` prints no FAIL (5 `lib: compose_up` PASS lines), and `h16-sync-refreshes-and-spares.sh` prints 26 PASS lines and no FAIL (the six named GSD cases all pass).

Tracer gate: the tracer `<verify>` (units, H-16 self-test, runner-healthy, runner-failures, guard host-tests) was re-run end to end and passed before Task 2 started.

## Task Commits

1. **Task 1: restart restores a stale GSD and spares user files; compose_up waits for the start hooks** - `f01c796` (test)
2. **Task 2: attended GSD bump helper; GSD in SANDBOX.md** - `ae3f53a` (feat)

**Plan metadata:** committed separately with STATE.md and ROADMAP.md (docs).

## Files Created/Modified

- `tests/host/lib-sandbox.sh` - `wait_for_start_hooks`; `compose_up` waits for it
- `tests/selftest/host/support/fake-docker` - `pgrep -x sleep` answers, `FAKE_START_POLLS`, `FAKE_STOPS_AT_START`, `node -e` exec
- `tests/selftest/host/units.sh` - `case_compose_up_waits`
- `tests/host/h16-sync-refreshes-and-spares.sh` - the GSD part of H-16
- `tests/selftest/host/h16-sync-refreshes-and-spares.sh` - self-test cases for it
- `tests/host/manual/h16-gsd-bump.sh` - the attended GSD bump helper
- `tests/host-checklist.md`, `SANDBOX.md`, `tests/host/run-all.sh` - docs and the `SBXTEST_START_SECONDS` header line

## Decisions Made

- The wait is a host-library poll of `pgrep -x sleep`, not a compose healthcheck: it covers both the GSD hook and the bundle hook and touches no Phase 1 file.
- H-16 stops planting a `gsd-*` user skill, because GSD owns that prefix and removes a `gsd-*` skill it does not ship.
- `requirements-completed` stays empty and TOOL-02 and TOOL-03 stay pending: plans 02-08 and 02-09 also declare them and have no SUMMARY yet.

## Deviations from Plan

### Execution-environment adjustments (orchestrator instructions, not defects)

- The plan names the branch `feat/phase-02-pinned-toolchain` and says to leave the SUMMARY uncommitted. This run stayed on `chore/planning-phase-02-plan` and committed the SUMMARY together with STATE.md and ROADMAP.md in a planning-only commit; the orchestrator splits code and planning commits onto their branches at the end. No branch or origin/main ancestry check was run.

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fake docker exec handlers dropped their exit status**
- **Found during:** Task 1 (green step; the compose_up cases still failed after the fake was written)
- **Issue:** `fake_exec` ends with `return 0`, so `exec_pgrep_sleep` returning 1 never reached the caller and `FAKE_START_POLLS` had no effect.
- **Fix:** the `pgrep -x sleep` and `node -e` cases return the handler's status explicitly (`...; return $? ;;`).
- **Files modified:** `tests/selftest/host/support/fake-docker`
- **Verification:** the four failing compose_up cases pass.
- **Committed in:** f01c796

---

**Total deviations:** 1 auto-fixed (1 bug in the new fake code, found before the commit), plus the orchestrator branch and SUMMARY adjustments.
**Impact on plan:** none on scope.

## Issues Encountered

None beyond the fake exit-status bug above. The full Linux suite takes longer than the 120 s foreground limit (the host self-test run-all is the slow part), so it was run in the background and read afterwards.

## Verification run

Full Linux suite after each task (bash -n on every script, then `tests/guard/run-all.sh`, `tests/selftest/guard`, `tests/selftest/entrypoint`, `tests/selftest/host`, `tests/selftest/bundle`): every suite ended "All rules hold." or "All cases pass." Task 2 also ran `bash -n tests/host/manual/h16-gsd-bump.sh`, `tests/guard/host-tests.sh`, `docs.sh`, `planning-ids.sh` and `supply-chain.sh`: all pass.

Acceptance criteria re-run:

- Task 1: `wait_for_start_hooks()` appears once; `pgrep -x sleep` once; `SBXTEST_START_SECONDS` 3 times; `gsd-h16-sample` 0 in both H-16 files; `check_gsd_refreshed` 2 times; 5 `PASS: lib: compose_up` lines (needs at least 4); the six named H-16 self-test cases print 6 PASS lines.
- Task 2: helper exists; `require_terminal` 1; `build_images manual-gsd-bump` 1; `git checkout -- versions.env` 1; `h16-gsd-bump.sh` 4 times in the checklist (needs at least 3); `## GSD` once in SANDBOX.md; `gsd-local-patches` 2; `h16-gsd-bump.sh` 1 in SANDBOX.md; `SBXTEST_START_SECONDS` once in run-all.sh.

Not run here (Docker is not available in the dev sandbox): H-16 against the real image, the real `pgrep -x sleep` ordering, and the attended helper. They go to the Mac run in plan 09.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required. For the Mac run in plan 09: `bash tests/host/manual/h07-login.sh`, then `bash tests/host/manual/h16-gsd-bump.sh` with `GSD_CORE_VERSION` set to the approved bump target (1.16.0) when asked; afterwards `git checkout -- versions.env` and `./build.sh`.

## Next Phase Readiness

- Ready for plan 02-07. The host library now guarantees the start hooks have finished before any check reads `state/claude`, and H-16 and the helper cover TOOL-02 end to end once plan 09 runs them on the Mac.
- Open for the Mac run: confirm `pgrep -x sleep` sees the command in the real container, that the real installer restores a stale `gsd-core/VERSION` and a hand-edited `skills/gsd-*` skill as the planning check on 2026-10-08 found, and that `node` in the container reads `CLAUDE_CONFIG_DIR`.

---
*Phase: 02-pinned-toolchain-gsd-and-ccusage*
*Completed: 2026-10-09*

## Self-Check: PASSED

- FOUND: tests/host/manual/h16-gsd-bump.sh, tests/host/lib-sandbox.sh, tests/host/h16-sync-refreshes-and-spares.sh, SANDBOX.md, tests/host-checklist.md
- FOUND commits: f01c796, ae3f53a
