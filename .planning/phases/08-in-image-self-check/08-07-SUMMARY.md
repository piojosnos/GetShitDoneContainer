---
phase: 08-in-image-self-check
plan: 07
subsystem: testing
tags: [selfcheck, host-test, gate, docker, certificates]

requires:
  - phase: 08-01
    provides: the runner, harness and Dockerfiles
  - phase: 08-02
    provides: H-34 and the throwaway root certificate
  - phase: 08-03
    provides: shared checks
  - phase: 08-04
    provides: probe deletions and docs
  - phase: 08-05
    provides: more shared checks
  - phase: 08-06
    provides: the Claude and Cursor agent checks
provides:
  - a green dev-sandbox gate for the whole phase (suites, counts, change set, sweeps)
  - a passing Mac run of ./host-test.sh with H-34 at 51 and 49 checks, 0 failed
  - proof that the throwaway root never reached the :local images
affects: [phase-08 verification, code PR]

actuals:
  tokens: 300
  tasks: 2
  commits: 1
plan_head_before: 0da90d82b485f43d9f84f392fbf752e2b8bb5e51
plan_head_after: 54b5c6a723002ad4f6e53a74e0f8a417395f0687

tech-stack:
  added: []
  patterns:
    - "The phase gate runs against origin/main as the diff base when local main is stale"

key-files:
  created: []
  modified:
    - tests/host/h34-selfcheck.sh

key-decisions:
  - "Assumption A3 (Cursor root-owned leftovers) did not trigger: no-root-owned-state passed in both test sandboxes, so GSD_SYNC_FOLDER_SET stays as it is"

patterns-established:
  - "Mac gate evidence lives in host-test.log (gitignored) and selfcheck-gate.log (outside the repo); neither is committed"

requirements-completed: [CHECK-01, CHECK-02, CHECK-03, CHECK-04]

coverage:
  - id: D1
    description: "every dev-sandbox suite passes and the lists, counts, change set and sweeps match the plans"
    requirement: CHECK-01
    verification:
      - kind: unit
        ref: "uv run pytest tests/selftest/selfcheck (178 passed)"
        status: pass
      - kind: integration
        ref: "tests/guard/run-all.sh, tests/selftest/sbx/run-all.sh, tests/selftest/entrypoint/run-all.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "on the Mac, H-34 runs sbx-selfcheck in a Claude and a Cursor test sandbox and finds the throwaway root in both stores"
    requirement: CHECK-02
    verification:
      - kind: manual_procedural
        ref: "./host-test.sh: Summary: 19 passed, 0 failed, 0 not run; 0 step(s) failed."
        status: pass
    human_judgment: true
    rationale: "Docker does not run in the dev sandbox; the user ran the gate on the Mac and approved it after the logs were read"
  - id: D3
    description: "the :local images are unchanged by the gate and no Cursor test container is left"
    requirement: CHECK-03
    verification:
      - kind: manual_procedural
        ref: "selfcheck-gate.log: same three image IDs before and after, 0 sbx-hosttest-cursor containers"
        status: pass
    human_judgment: true
    rationale: "Image IDs come from Docker Desktop on the Mac"
  - id: D4
    description: "no key is left in the certificate folder and the fingerprint in the INFO line equals openssl's"
    requirement: CHECK-04
    verification:
      - kind: manual_procedural
        ref: "selfcheck-gate.log: folder holds root-ca.pem and build-ca.pem only; fingerprint 0053FF10...225337 matches"
        status: pass
    human_judgment: true
    rationale: "The certificate folder is on the Mac"

duration: 40min
completed: 2026-11-14
status: complete
---

# Phase 8 Plan 7: Phase gate Summary

**Phase 8 closed: every dev-sandbox suite is green, and on the Mac `./host-test.sh` passes 19 host checks with H-34 at 51 (Claude) and 49 (Cursor) checks, 0 failed, and the `:local` images untouched.**

## Performance

- **Duration:** about 40 min of agent time plus the Mac run
- **Tasks:** 2 (one dev-sandbox gate, one Mac checkpoint)
- **Files modified:** 1 (one comment line in `tests/host/h34-selfcheck.sh`)

## Accomplishments

Task 1, dev-sandbox gate. The change set was compared against `origin/main` (6a1749a) because local `main` is stale.

| Gate | Result |
|---|---|
| `uv run pytest tests/selftest/selfcheck -q` | 178 passed |
| Guard | "All rules hold.", 19 PASS lines |
| sbx self-test | "All cases pass.", 150 PASS; also with `SBX_IMAGE_TAG=test` and `SBX_CA_CERT=/nonexistent/ca.pem` |
| Entrypoint self-test | "All cases pass.", 58 PASS |
| List sizes (shared, Claude, Cursor) | 39, 12, 10 |
| H-34 constants | `expectedClaudeCount=51`, `expectedCursorCount=49` |
| Host check files vs `run-all.sh` list | 19 files, 19 listed, all present |
| Code change set | exactly the 45 paths the plans name |
| Modes | `sbx-selfcheck` 100755, `h34-selfcheck.sh` 100644, no other mode change |
| Untouched | `versions.env`, `compose.yml`, `build.sh`, `bin/`, `clean.sh` |
| Commit hygiene | no commit mixes `.planning/` with code |
| Sweeps (ASCII, IDs, dashes, certificates and keys, pytest, H-01 remnants, skills) | all empty |

Task 2, Mac gate (user approved; logs read here).

`host-test.log`:
- `Summary: 19 passed, 0 failed, 0 not run` and the run ends `0 step(s) failed.`
- `PASS: H-34 ...` with `INFO: H-34 Claude test sandbox: sbx-selfcheck: 51 checks, 0 failed` and `INFO: H-34 Cursor test sandbox: sbx-selfcheck: 49 checks, 0 failed`
- `INFO: test root certificate:` with SHA-256 `0053FF108295AEE02A6070D3D5A1A62BEC821FB4C519E3B91434B00432225337`
- `PASS: H-32` and `PASS: H-33` after H-34
- the guard printed "All rules hold." twice, each with `PASS: no_compromised_gsd_package` (in sbx-hosttest and in the Mac shell)

`selfcheck-gate.log`:
- `sbx-base:local` (aa738f67...), `sbx-claude:local` (5cc1c6ac...) and `sbx-cursor:local` (c6eb0aba...) have identical IDs before and after
- the root CA folder holds `root-ca.pem` and `build-ca.pem` and no `.key`
- the openssl fingerprint equals the INFO line with colons removed
- 0 `sbx-hosttest-cursor` containers remain

Flagged assumptions: A3 did not trigger (`no-root-owned-state` passed in both sandboxes); A1, A5 and A6 held, since the root was made, the Cursor sandbox started within the wait and the fingerprint parsed. A2 (layer cache on a second run) was not exercised; the second run is optional.

## Task Commits

1. **Task 1: Dev-sandbox phase gate**: `54b5c6a` (fix, reworded one comment in `tests/host/h34-selfcheck.sh`)
2. **Task 2: Mac gate**: no file change, no commit

## Verification

All verify commands of Task 1 exited 0; the Mac acceptance criteria of Task 2 are met as listed above.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] A comment tripped the literal `pytest` sweep**
- **Found during:** Task 1 (the last sweep, `! grep -rn 'pytest' host-test.sh tests/host`)
- **Issue:** a comment on line 22 of `tests/host/h34-selfcheck.sh` held the word `pytest`, which the plan forbids in host checks
- **Fix:** reworded the comment to avoid the word
- **Files modified:** `tests/host/h34-selfcheck.sh`
- **Commit:** `54b5c6a`

The plan said Task 1 changes no file; this one-line comment edit was needed to make the sweep pass. The gate was re-run after it.

## Known Stubs

None.

## Threat Flags

None. T-08-24 held: the `:local` image IDs are identical before and after the run.

## Next Phase Readiness

Phase 8 is ready for verification. The code PR is prepared by hand: cherry-pick the code commits onto a `feat/` branch cut from the updated `main`, push only with the user's go, and open the PR against `main`. Planning files go in their own PR.

## Self-Check: PASSED

- `.planning/phases/08-in-image-self-check/08-07-SUMMARY.md` written
- commit `54b5c6a` exists
- `host-test.log` and `selfcheck-gate.log` read and match the figures above
