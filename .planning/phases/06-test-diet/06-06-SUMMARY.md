---
phase: 06-test-diet
plan: 06
subsystem: testing
tags: [bash, host-tests, phase-gate, mac-run]

requires: ["06-01", "06-02", "06-03", "06-04", "06-05"]
provides:
  - "a green dev-sandbox gate: guard, sbx self-test, entrypoint self-test, host check lists, reference sweeps"
  - "a passing unattended Mac run of ./host-test.sh with 26 host checks and 0 failed steps"
affects: [phase 07]

actuals:
  tokens: 0
  tasks: 2
  commits: 0
plan_head_before: 2009f04374e2e9beed7c3bff4050f35f33d79363
plan_head_after: 2009f04374e2e9beed7c3bff4050f35f33d79363

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: []

key-decisions:
  - "No file changed in this plan; it only records the gate and the Mac run"

requirements-completed: [DIET-01, DIET-02, DIET-03, DIET-04, DIET-05]

coverage:
  - id: D1
    description: "Dev-sandbox gate: guard 17 rules, sbx self-test 121 cases, entrypoint self-test 43 cases, 26 listed host checks, sweeps empty"
    requirement: DIET-05
    verification:
      - kind: other
        ref: "bash tests/guard/run-all.sh; bash tests/selftest/sbx/run-all.sh; bash tests/selftest/entrypoint/run-all.sh; list-consistency loop; git grep sweeps"
        status: pass
    human_judgment: false
  - id: D2
    description: "On the Mac, ./host-test.sh runs unattended and passes: 26 passed, 0 failed, 0 not run; 0 step(s) failed"
    requirement: DIET-03
    verification:
      - kind: other
        ref: "host-test.log from the Mac run, read in the repo root"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-11-13
status: complete
---

# Phase 6 Plan 06: Phase gate and Mac run Summary

**The test diet passes end to end: the dev-sandbox suites and sweeps are green, and `./host-test.sh` on the Mac ran unattended with 26 host checks passed and `0 step(s) failed.`**

## Task 1: dev-sandbox gate (run by the orchestrator, no file changed)

| Check | Result |
|-------|--------|
| `bash tests/guard/run-all.sh` | ends `All rules hold.`, 17 PASS |
| `bash tests/selftest/sbx/run-all.sh` | ends `All cases pass.`, 121 PASS |
| `bash tests/selftest/entrypoint/run-all.sh` | ends `All cases pass.`, 43 PASS |
| host check lists in `tests/host/run-all.sh` | 26 checks, none missing, none unlisted |
| `bash -n` on `host-test.sh`, `clean.sh`, `tests/host/*.sh` | clean |
| deleted-name sweep outside `.planning` | empty |
| Claude, Anthropic, Maven sweep in `tests`, `host-test.sh`, `README.md` | empty |
| added lines against `main` | no non-ASCII, no planning IDs, no dash punctuation in Markdown |
| ROADMAP and REQUIREMENTS wording on stand-in docker | already say none is left (no planning edit) |

## Task 2: Mac run (checkpoint, user replied "Done, all looks green")

Read from `host-test.log` in the repo root:

- First heading `== context`; `branch chore/phase-06-test-diet, commit 2009f04`; `Docker Compose version v2.40.0-desktop.1`. The line "Docker Compose v2 or newer is required" is absent (0 matches), so the preflight passed silently.
- `Summary: 26 passed, 0 failed, 0 not run`; no `FAIL` line anywhere (0 matches).
- `PASS: H-13` (five variables set, no `~/.local/share/claude`, no `~/.local/bin/claude`).
- `PASS: H-14` (wrappers, hooks and settings root-owned and read-only to sandbox; clone is the one additional directory).
- `PASS: H-15` (`state/claude` links into the clone; the container reads it through `~/.claude/rules`).
- `PASS: H-09` (a file in the best-practices clone and a fake credentials file and session file survived the rebuild; one bind mount).
- `PASS: H-28` (`sbx-stop returned in under 10 s`).
- `PASS: H-29` (`sbx-upgrade` kept its files and the fake credentials and session files and one bind mount).
- sbx self-test in the Mac shell (`/bin/bash` 3.2): `All cases pass.`, no hang.
- Guard in `sbx-hosttest` and in the Mac shell: `All rules hold.` (both).
- Entrypoint self-test in `sbx-hosttest`: `All cases pass.`
- Build warnings: no `InvalidDefaultArgInFrom` warning.
- All ten steps `OK`; the log ends `0 step(s) failed.`
- The user confirmed no `sbx-down`, `sbx-noimage`, `sbx-one` or `sbx-broken` container exists afterwards, so no self-test case reached the real daemon.

## Deviations from Plan

None. The plan changed no file and ran as written. `commits: 0` is correct: there are no code changes in this plan.

## Follow-ups

- H-17's `check_offline_gsd` still checks the GSD sync offline. It is kept on purpose: it tests our start hook, which a later milestone phase replaces.
- The one-FROM guard rule reads the Dockerfile, not the built image (accepted in plan 02).

## Known Stubs

None.

## Threat Flags

None. No file changed. T-06-15 held (the log names the branch and commit tested); T-06-16 held (no self-test container appeared on the real daemon).

## Self-Check: PASSED

- `host-test.log` ends `0 step(s) failed.` and holds `Summary: 26 passed, 0 failed, 0 not run`.
- `git status --short -- . ':!.planning'` shows no tracked change from this plan.
