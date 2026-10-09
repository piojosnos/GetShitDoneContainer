---
phase: 02-pinned-toolchain-gsd-and-ccusage
plan: 09
subsystem: infra
tags: [docker, mac-verification, phase-gate, maven, ccusage, gsd, versions-env]

requires:
  - phase: 02-pinned-toolchain-gsd-and-ccusage
    provides: "plans 01 to 08: versions.env and build.sh, the toolchain base image, state caches, baked GSD with its start hook, baked ccusage, host checks H-22 to H-25"
provides:
  - "Phase gate: the full Linux suite green and the Mac run at 25 passed, 0 failed, 0 not run, with the attended GSD bump passing"
  - "Phase 1 findings WR-03 and IN-03 recorded fixed"
  - "02-VALIDATION.md with one verification row per task of plans 01 to 09"
  - "Maven pinned at 3.9.11 after the Mac run showed 3.9.16 fails on the Docker Desktop mount"
affects: [phase-02-verification, phase-02.1, phase-03]

actuals:
  tokens: 8918
  tasks: 3
  commits: 6

tech-stack:
  added: []
  patterns:
    - "Every npm call inside a build step exports NPM_CONFIG_CACHE=/tmp/npm-cache, and the last RUN of each Dockerfile fails when files sit under the mount point"
    - "A pin changed after approval is recorded as a dated change in 02-PINS.md"

key-files:
  created:
    - .planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-09-SUMMARY.md
  modified:
    - .planning/phases/01-two-mount-claude-sandbox/01-REVIEW-DISPOSITION.md
    - .planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-VALIDATION.md
    - versions.env
    - base/Dockerfile
    - claude/Dockerfile
    - SANDBOX.md
    - tests/guard/isolation.sh
    - tests/host/h23-caches-survive-recreate.sh
    - tests/host/manual/h07-login.sh

key-decisions:
  - "MAVEN_VERSION 3.9.11: Maven 3.9.12 and later cannot download into a local repository on the Docker Desktop for Mac mount; the user approved the change"
  - "WR-03 and IN-03 are fixed, because H-22 and H-25 passed on the Mac"
  - "The Java TLS and cacerts concern from plan 03 is closed: Maven Central downloads over HTTPS worked in the sandbox"

patterns-established:
  - "Mac-found defects become guard rules or host checks so the same mistake fails on Linux next time"

requirements-completed: [IMG-01, IMG-03, IMG-04, IMG-07, TOOL-01, TOOL-02, TOOL-03, USE-01]

coverage:
  - id: D1
    description: "Every Linux suite passes on the final code commit and every versions.env pin equals an approved row of 02-PINS.md"
    requirement: IMG-03
    verification:
      - kind: unit
        ref: "full Linux suite (bash -n, guard, guard/entrypoint/host/bundle self-tests) on 96e4f8b and again on 26fd13e"
        status: pass
    human_judgment: false
  - id: D2
    description: "The unattended Mac run of tests/host/run-all.sh ends with 25 passed, 0 failed, 0 not run, and the guard holds under macOS bash"
    requirement: IMG-01
    verification:
      - kind: integration
        ref: "bash tests/host/run-all.sh on the Mac, 2026-10-09"
        status: pass
      - kind: integration
        ref: "bash tests/guard/run-all.sh on macOS bash: All rules hold."
        status: pass
    human_judgment: false
  - id: D3
    description: "The attended GSD bump to 1.16.0 syncs the new GSD, keeps the login, and claude --continue resumes the earlier session"
    requirement: TOOL-02
    verification:
      - kind: manual_procedural
        ref: "bash tests/host/manual/h07-login.sh, then bash tests/host/manual/h16-gsd-bump.sh on the Mac"
        status: pass
    human_judgment: true
    rationale: "Whether the earlier conversation resumed is judged by a person looking at a real claude.ai login"
  - id: D4
    description: "Phase 1 findings WR-03 and IN-03 recorded fixed; 02-VALIDATION.md has a row for every task of plans 01 to 09"
    verification:
      - kind: other
        ref: "row checks of plan 09 task 3 on 01-REVIEW-DISPOSITION.md and 02-VALIDATION.md"
        status: pass
    human_judgment: false

duration: not recorded (spans the Mac run and its fix rounds on 2026-10-09)
completed: 2026-10-09
status: complete
commits: 6
plan_head_before: 15d33d89b1b720a0cb28c9488f7267a9b2aa40bd
plan_head_after: 96e4f8b5956435fc21b487a6e63c8d9c569e425a
---

# Phase 2 Plan 09: Phase gate Summary

**The Mac run of the pinned toolchain, GSD and ccusage images ended at 25 passed, 0 failed, 0 not run after five rounds of fixes (npm cache under the mount point, Maven 3.9.16 on the virtiofs mount, the login helper), and the attended GSD bump to 1.16.0 kept the login and the session.**

## Performance

- **Duration:** not recorded; the plan ran across a Linux gate, a blocking Mac checkpoint with several fix rounds, and the recording step
- **Started:** not recorded
- **Completed:** 2026-10-09
- **Tasks:** 3 (one tracer, one blocking-human checkpoint, one recording task)
- **Files modified:** 12 files in the six code and pin-record commits made under this plan, plus the three records written here

## Accomplishments

- The final Linux gate is green: syntax check of every script, the guard, and the guard, entrypoint, host and bundle self-tests.
- The Mac run proved the whole phase on real Docker Desktop: toolchain, caches, GSD sync, ccusage and the image-versus-pin comparison (25 of 25 checks).
- The attended GSD bump passed: GSD 1.16.0 reached `state/claude` and the start log, no `npx` or `@latest` appeared, the login survived and `claude --continue` resumed the earlier session.
- The Mac found four real defects that no Linux check could see; each was fixed, covered by a guard rule or host check, and re-verified on the Mac.
- WR-03 and IN-03 of Phase 1 are recorded fixed, and `02-VALIDATION.md` maps all 20 tasks of plans 01 to 09 to their checks.

## Gate (Task 1)

Task 1 was first satisfied before the Mac run and re-run here on the final commits.

Linux suite on `96e4f8b` (the commit the Mac run used) and again on `26fd13e` (see Issues Encountered):

| Runner | Last line | PASS lines at 96e4f8b |
|---|---|---|
| `bash -n` on every script | no output, `BASHN_OK` | n/a |
| `bash tests/guard/run-all.sh` | `All rules hold.` | 40 |
| `bash tests/selftest/guard/run-all.sh` | `All cases pass.` | 92 |
| `bash tests/selftest/entrypoint/run-all.sh` | `All cases pass.` | 73 |
| `bash tests/selftest/host/run-all.sh` | `All cases pass.` | 501 |
| `bash tests/selftest/bundle/run-all.sh` | `All cases pass.` | 111 |

Branch checks. The plan expected a separate code branch. Work stayed on `chore/planning-phase-02-plan`, which holds both kinds of commit, so the checks ran over the 20 code commits and 10 planning commits since the merge base with `origin/main` (`6ede9b4`):

- Every commit is code-only or `.planning/`-only. Mixed commits: 0.
- Paths changed by the code commits, up to `96e4f8b`: `.dockerignore`, `SANDBOX.md`, `base/Dockerfile`, `build.sh`, `claude/Dockerfile`, `claude/start.d/05-gsd`, `compose.yml`, `versions.env` and 43 files under `tests/`. No path outside the plan's list.
- `ClaudeCode/`, `OpenCode/`, `README.md` and `best-practices/` are untouched since the merge base.
- No code commit message holds a planning ID, a phase number, `.planning` or an AI attribution trailer.
- `build.sh` and `claude/start.d/05-gsd` are mode 100755.
- Every `versions.env` pin equals an approved row of `02-PINS.md`: UBUNTU_IMAGE, TEMURIN_IMAGE, UV_IMAGE, NODE_VERSION, GH_VERSION, MAVEN_VERSION (3.9.11, the recorded change of 2026-10-09), CLAUDE_CODE_VERSION, GSD_CORE_VERSION and CCUSAGE_VERSION.
- Test-first record: every `tdd="true"` task (01-T2, 03-T2, 04-T2, 05-T2, 07-T2, 08-T1, 08-T2) and tracer 06-T1 records a failing run before the change and a passing run after. No gap.

## Mac run (Task 2)

Environment: Docker Desktop 4.48.0 (207573), Compose 2.40.0-desktop.1. The user ran the commands on 2026-10-09 in the repo folder on the Mac.

Run history, in order:

| Run | Result | Cause and fix |
|---|---|---|
| 1 | Base build stopped: `No space left on device` | Docker Desktop disk full. An environment issue, not a code defect; the user freed space. |
| 2 | 24 of 25; H-25 FAILED | The Claude image held `state/cache/npm/_logs/...-debug-0.log` (root-owned) under `/home/sandbox/workspace`. In the ccusage step `npm root -g` ran after a one-command `NPM_CONFIG_CACHE=/tmp/npm-cache` prefix, so npm used the image's cache under the mount point. Fixed in `0bb646c` and `fd12a33`. |
| 3 | Maven failed in the sandbox | Maven 3.9.16 failed with `java.io.IOException: Input/output error` and `Failed to delete tracking file ...lastUpdated` with `~/.m2` linked to `state/m2` on the virtiofs mount. Fixed by pinning 3.9.11 (`b8ccbca`, `98d4acc`, `c9cd95d`). |
| 4 | Attended bump said `No conversation found to continue` | `h07-login.sh` never asked for a message, so there was no conversation. Fixed in `96e4f8b`. |
| Final | `Summary: 25 passed, 0 failed, 0 not run`, exit 0 | All checks green. |

Lines of note from the final run, verbatim:

- H-22: "Node 24.21.0, uv 0.12.21, Temurin 21.0.12 and Maven 3.9.11 are native and at their pins"
- H-23: "... and a Maven download of junit 4.13.2 reached state/m2 and survived it"
- H-25: "the images match versions.env (GSD 1.15.0, ccusage 20.0.26), nothing sits under the mount point, and a build without build.sh stops naming the missing pin"

Guard on macOS bash: `All rules hold.` (39 rules at the time of the run; a 40th, `images_leave_the_mount_point_empty`, is counted above and was not part of that macOS run).

Attended helpers:

- `h07-login.sh`: 3 PASS (login files in `state/claude`, `loggedIn` true, no `~/.claude.json` at home).
- `h16-gsd-bump.sh` with `GSD_CORE_VERSION` set to 1.16.0 (the approved bump target):
  - PASS: GSD 1.16.0 in `state/claude` and in the start log, no `npx` or `@latest`.
  - PASS: `loggedIn` still true after the bump.
  - PASS: `claude --continue` resumed the earlier session (confirmed by the user on the re-run).
- `versions.env` was restored afterwards (and the images rebuilt with `./build.sh`).

No FAIL, NOT RUN or SETUP line remains from the final run. The FAIL of run 2 (H-25) is recorded above and belongs to IMG-03 and IMG-04.

### Mac assumptions M1 to M12

| ID | Result | Evidence |
|---|---|---|
| M1 | Confirmed | H-25: a build of `base/Dockerfile` without `build.sh` stops naming the missing pin |
| M2 | Confirmed | Both builds passed; undeclared pins gave warnings only (the run's build) |
| M3 | Confirmed | ripgrep, python3-pip and python3-venv installed on the pinned `ubuntu:24.04` (the run's build) |
| M4 | Confirmed | H-22: `java` and `mvn` run from the copied Temurin tree, also in a login shell |
| M5 | Confirmed | `# check=skip=InvalidDefaultArgInFrom` and `COPY --chmod=644` built with Docker Desktop's built-in frontend (the run's build) |
| M6 | Confirmed | Every `compose_up` and H-16 passed: `up --wait` returns early and `pgrep -x sleep` sees the command after the hooks finish |
| M7 | Confirmed | H-17 and H-16: the GSD installer synced into `state/claude` within the 60 s and 120 s limits |
| M8 | Confirmed | H-15 and H-18 passed with GSD's hooks and skills in `state/claude` |
| M9 | Confirmed | H-24: the ccusage binary runs for the sandbox user |
| M10 | Confirmed | H-22: ELF bytes `b7 00` read as AArch64 |
| M11 | Confirmed | `mvn -v` ran at build time while `~/.m2` pointed nowhere (the run's build) |
| M12 | Confirmed | The bump helper restarts explicitly and H-09 passed; the SANDBOX.md bump steps recreate the container on the rebuilt image |

Extra Mac items from earlier plans: the Java TLS and `cacerts` concern from plan 03 is closed. The Maven Central download of `junit 4.13.2` over HTTPS worked, which also answers the plan 03 question about a dangling `cacerts` link.

## Requirements

All eight phase requirements are proven on the Mac:

| Requirement | Proven by |
|---|---|
| IMG-01 | H-22 (Node, uv, Temurin and Maven native and at their pins) and H-23 (a real Maven download over HTTPS); the run's build for the Linux tools (M3) |
| IMG-03 | H-25 (images match `versions.env`; a build without `build.sh` stops naming the pin), the guard rule `versions_are_pinned`, every pin approved in `02-PINS.md`, the attended bump |
| IMG-04 | H-25 and the attended bump: one changed line in `versions.env` plus `./build.sh` delivered GSD 1.16.0 |
| IMG-07 | H-23: npm, uv and Maven caches survive a recreate, including the junit jar in `state/m2` |
| TOOL-01 | H-13 (no Claude copy in `~/.local`, self-update off) and H-25 (images equal the pins) |
| TOOL-02 | H-16 (stale GSD restored, user files spared), H-17 (GSD synced offline) and the attended bump |
| TOOL-03 | H-17: a start with `--network none` syncs GSD, and its output names no `npx` or `@latest` |
| USE-01 | H-24: ccusage reports a planted transcript from `state/claude` |

The STATE.md blocker "confirm ccusage's native binary is executable (chmod) on arm64" is resolved: H-24 passed on the Mac.

## Task Commits

Task 1 and Task 2 produced no commit of their own (a gate run and a user checkpoint). The commits made under this plan fixed what the Mac run found:

1. **Task 2, run 2 (npm cache under the mount point):** `0bb646c` (fix), `fd12a33` (fix)
2. **Task 2, run 3 (Maven on the mount):** `b8ccbca` (fix), `98d4acc` (docs, planning only), `c9cd95d` (test)
3. **Task 2, run 4 (login helper):** `96e4f8b` (test)
4. **Task 3: records and validation map:** the planning commit that holds this SUMMARY (`docs(02-09)`)

## Files Created/Modified

- `base/Dockerfile`, `claude/Dockerfile` - every npm step exports `NPM_CONFIG_CACHE=/tmp/npm-cache`; the last RUN of each file fails when files sit under the mount point and lists them
- `tests/guard/isolation.sh`, `tests/selftest/guard/sandbox-rules.sh` - guard rules `npm_builds_keep_their_cache_out_of_the_mount` (whole RUN steps) and `images_leave_the_mount_point_empty`, with planted-violation cases
- `versions.env`, `SANDBOX.md` - Maven 3.9.11 and a troubleshooting row for the Input/output error
- `tests/host/h23-caches-survive-recreate.sh`, its self-test and `tests/selftest/host/support/fake-docker` - H-23 runs a real `mvn dependency:get` of junit 4.13.2 into `state/m2` and checks the jar survives
- `tests/host/manual/h07-login.sh`, `tests/host-checklist.md` - the login helper asks for one message
- `.planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-PINS.md` - MAVEN_VERSION row and change record
- `.planning/phases/01-two-mount-claude-sandbox/01-REVIEW-DISPOSITION.md` - WR-03 and IN-03 fixed
- `.planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-VALIDATION.md` - verification map, flags and sign-off

## Decisions Made

- **Maven 3.9.11.** Diagnosis on the Mac: 3.9.16 with the repository in `/tmp` worked; 3.9.11 (Maven Resolver 1.9.24) with the repository on the mount worked. 3.9.12 and later bundle Resolver 1.9.25 or newer, whose tracking file change fails on the Docker Desktop mount. The user approved ("Yes, go with 1"). The pin stays until a newer release passes the Maven download in H-23.
- **WR-03 and IN-03 fixed.** H-22 and H-25 passed on the Mac, so per the Phase 1 deferral reason both close.
- **Planning files are committed here.** The plan text said to leave `.planning/` files uncommitted. The orchestrator instead asked for one planning-only commit on the current branch and splits the branches later.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Build-time npm cache and debug log landed under the mount point**
- **Found during:** Task 2 (Mac run 2, H-25)
- **Issue:** In the ccusage step `npm root -g` ran after a one-command `NPM_CONFIG_CACHE=/tmp/npm-cache` prefix, so npm fell back to the image's cache under `/home/sandbox/workspace`. The image then held root-owned files under the mount point.
- **Fix:** Every npm RUN exports `NPM_CONFIG_CACHE=/tmp/npm-cache`. The guard rule `npm_builds_keep_their_cache_out_of_the_mount` now checks whole RUN steps. New rule `images_leave_the_mount_point_empty` requires the last RUN of each Dockerfile to end with an emptiness check that lists offending files.
- **Files modified:** `base/Dockerfile`, `claude/Dockerfile`, `tests/guard/isolation.sh`, `tests/selftest/guard/sandbox-rules.sh`
- **Verification:** guard and guard self-test green on Linux; H-25 passed on the Mac
- **Committed in:** `0bb646c`, `fd12a33`

**2. [Rule 1 - Bug] Maven 3.9.16 fails to write its tracking files on the Docker Desktop mount**
- **Found during:** Task 2 (Mac run 3)
- **Issue:** `java.io.IOException: Input/output error` and `Failed to delete tracking file ...lastUpdated` with `~/.m2` linked to `state/m2`. No Linux check can see this, and plan 03's smoke test made no download.
- **Fix:** Pin Maven 3.9.11 (user approved), record the change in `02-PINS.md`, add a SANDBOX.md troubleshooting row, and make H-23 run a real `mvn dependency:get` of junit 4.13.2 into `state/m2` so a later bump is caught.
- **Files modified:** `versions.env`, `SANDBOX.md`, `02-PINS.md`, `tests/host/h23-caches-survive-recreate.sh`, its self-test, `tests/selftest/host/support/fake-docker`, `tests/host-checklist.md`
- **Verification:** H-23 passed on the Mac with the junit jar surviving the recreate
- **Committed in:** `b8ccbca`, `98d4acc`, `c9cd95d`

**3. [Rule 1 - Bug] The login helper never asked for a message**
- **Found during:** Task 2 (first attended bump run: `No conversation found to continue`)
- **Issue:** Without a message there is no conversation, so `claude --continue` had nothing to resume.
- **Fix:** `h07-login.sh` asks the user to send one message.
- **Files modified:** `tests/host/manual/h07-login.sh`, `tests/host-checklist.md`
- **Verification:** the re-run resumed the session, confirmed by the user
- **Committed in:** `96e4f8b`

### Orchestrator-directed process changes

**4.** Work stayed on `chore/planning-phase-02-plan`; the plan's `feat/phase-02-pinned-toolchain` branch does not exist here and the branch checks ran per commit instead of per branch. The planning files are committed (see Decisions Made).

### Environment issue

**5.** Mac run 1 stopped with `No space left on device` during the base build (Docker Desktop disk full). Not a code defect; the user freed space and re-ran.

---

**Total deviations:** 3 auto-fixed (3 Rule 1), 1 process change, 1 environment issue
**Impact on plan:** Every fix was needed for a green Mac run, and each became a guard rule or host check so Linux catches the same mistake next time. The Maven pin change needed and received user approval. No scope creep.

## Issues Encountered

- **A code commit landed during this recording step.** `26fd13e` (`feat(host): clean.sh frees Docker disk space and removes leftover host-test runs`, by the user, after the Mac run) adds `clean.sh` at the repo root and touches `SANDBOX.md`, `tests/guard/host-tests.sh` and `tests/guard/lib.sh`. It is the answer to the full-disk problem of run 1. `clean.sh` is not on the plan's list of expected paths, is mode 100755, passes `bash -n` and the whole Linux suite (same last lines as above), and has a clean commit message. It was not part of the Mac run (25 of 25 ran on `96e4f8b`), so it has no Mac proof. It is not counted in `commits:` above.
- The earlier pin table row for Maven 3.9.16 and plan 03's text still mention 3.9.16 in their own history; `02-PINS.md` records the change.

## Known Stubs

None. The commits under this plan contain no hardcoded empty values, placeholders or unwired data.

## Threat Flags

None. The fixes shrink existing surface (nothing left under the mount point); no new endpoint, auth path or trust-boundary file access was added.

## User Setup Required

None. The test Claude login lives in the Mac run folder; run-all.sh prints the cleanup command that removes it (T-02-35).

## Next Phase Readiness

- Phase 2 is ready for verification: all eight requirements are proven on the Mac.
- Before the code PR: decide whether `26fd13e` (`clean.sh`) belongs in it, and run `bash tests/host/run-all.sh` once more on the Mac if it does, since it changed `SANDBOX.md` and two guard files.
- Pushing and merging stay with the user; nothing was pushed.

---
*Phase: 02-pinned-toolchain-gsd-and-ccusage*
*Completed: 2026-10-09*

## Self-Check: PASSED
