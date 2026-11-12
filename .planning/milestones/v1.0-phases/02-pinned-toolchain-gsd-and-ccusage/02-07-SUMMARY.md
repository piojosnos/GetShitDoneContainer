---
phase: 02-pinned-toolchain-gsd-and-ccusage
plan: 07
subsystem: image
tags: [ccusage, claude-image, host-tests, h24, fake-docker, sandbox-docs]

requires:
  - phase: 02-pinned-toolchain-gsd-and-ccusage
    provides: the approved CCUSAGE_VERSION row in 02-PINS.md, the sandbox-stage host check shape, the fake docker with exec handlers (plans 02, 05, 06)
provides:
  - CCUSAGE_VERSION=20.0.26 in versions.env
  - ccusage in the Claude image, installed as root with optional dependencies kept, its native binary made executable at build time, and a build-time version check as the sandbox user
  - SANDBOX.md "Usage reports (ccusage)" section and the image table row naming GSD and ccusage
  - host check H-24 (tests/host/h24-ccusage-reports-usage.sh) with its self-test group
  - fake docker ccusage answers with knobs FAKE_CCUSAGE_EMPTY and FAKE_CCUSAGE_RC
affects: [02-08, 02-09]

actuals:
  tokens: 3700
  tasks: 2
  commits: 2

tech-stack:
  added: [ccusage 20.0.26 (npm, with @ccusage/ccusage-linux-arm64 as its platform binary)]
  patterns:
    - "A pinned npm tool is installed as root into /usr/local with NPM_CONFIG_CACHE=/tmp/npm-cache on the same line, and the smoke test RUN checks its version as the sandbox user"
    - "A host check that reads a tool's report plants a fixed-name fixture file with a run-unique ID and a fixed past date, so other checks' data never changes the numbers"

key-files:
  created:
    - tests/host/h24-ccusage-reports-usage.sh
    - tests/selftest/host/h24-ccusage-reports-usage.sh
  modified:
    - versions.env
    - claude/Dockerfile
    - SANDBOX.md
    - tests/selftest/host/support/fake-docker
    - tests/host/run-all.sh
    - tests/selftest/host/run-all.sh
    - tests/host-checklist.md
    - tests/selftest/host/runner-healthy.sh
    - tests/selftest/host/runner-failures.sh

key-decisions:
  - "The build adds the execute bit to ccusage's native binary as root with a glob, so the build fails when the binary is missing instead of failing at run time for the sandbox user"
  - "H-24 compares ccusage's stdout only and always passes --offline, so the run-time price lookup (kept as the default for users) never makes the check depend on the network"
  - "The ccusage fixture is one fixed file name overwritten each run with a run-unique session ID, so a stale file cannot pass and a second run does not double the totals"

patterns-established:
  - "check_report LABEL STATUS OUTPUT TEXT... in a host check: one problem for a non-zero status, one per missing fixed-string text"

requirements-completed: []

coverage:
  - id: D1
    description: "The Claude image installs ccusage at the pinned version as root with optional dependencies, chmods its native binary at build time, and fails the build unless ccusage --version prints the pin as the sandbox user"
    requirement: USE-01
    verification:
      - kind: other
        ref: "acceptance greps on versions.env and claude/Dockerfile (fixed-string forms); bash -n and the full Linux suite pass"
        status: pass
      - kind: manual_procedural
        ref: "docker build via ./build.sh on the Mac (plan 09): the glob finds the arm64 binary and ccusage --version matches"
        status: unknown
    human_judgment: false
  - id: D2
    description: "H-24 writes a one-message transcript into state/claude/projects and passes only when ccusage daily, monthly and session (offline, in the project folder, as the sandbox user) report 100, 200 and 300 tokens; empty reports, a ccusage that cannot run and a missing test sandbox each fail"
    requirement: USE-01
    verification:
      - kind: unit
        ref: "bash tests/selftest/host/h24-ccusage-reports-usage.sh (12 PASS lines)"
        status: pass
      - kind: manual_procedural
        ref: "H-24 in bash tests/host/run-all.sh on the Mac (plan 09), against the real ccusage and the real arm64 binary"
        status: unknown
    human_judgment: false
  - id: D3
    description: "SANDBOX.md tells the user how to run ccusage daily, monthly and session, that it reports only this sandbox, that --offline avoids the price lookup, and that start needs no network"
    requirement: USE-01
    verification:
      - kind: other
        ref: "grep -c '^## Usage reports (ccusage)$' SANDBOX.md prints 1; tests/guard/docs.sh passes"
        status: pass
    human_judgment: true
    rationale: "Whether the prose is clear to a maintainer is a reading judgment"

duration: about 15 min (approximate; the start time was not captured at plan start)
completed: 2026-10-09
status: complete
commits: 2
plan_head_before: 1f9acdde293facd67678878312a4b853cb275575
plan_head_after: 9ed529e959369c413986ceb598f243e041f77dcd
---

# Phase 2 Plan 07: ccusage baked in and proven by H-24 Summary

**The Claude image installs ccusage 20.0.26 from npm as root with its arm64 or x64 binary made executable at build time and a version check as the sandbox user; host check H-24 plants a one-message transcript in state/claude and requires ccusage daily, monthly and session to report 100, 200 and 300 tokens offline; SANDBOX.md explains the reports.**

## Performance

- **Duration:** about 15 min (approximate)
- **Completed:** 2026-10-09
- **Tasks:** 2
- **Files modified:** 11 (2 created, 9 modified)

## Accomplishments

- `versions.env` pins `CCUSAGE_VERSION=20.0.26`, the value approved in 02-PINS.md on 2026-10-09.
- `claude/Dockerfile` has a `# --- ccusage ---` block after the GSD block: `ARG CCUSAGE_VERSION`, a RUN that stops when the pin is missing, `NPM_CONFIG_CACHE=/tmp/npm-cache npm install -g "ccusage@${CCUSAGE_VERSION}"` (optional dependencies kept, so the platform binary arrives), `chmod 755` of `@ccusage/*/bin/ccusage` through a glob (the build stops when the glob finds nothing), then removal of the cache. The smoke test RUN also requires `ccusage --version` to equal `ccusage ${CCUSAGE_VERSION}` as the sandbox user. The versions.env COPY is still the last instruction.
- `SANDBOX.md`: the `sbx-claude:local` row names GSD and ccusage; a new `## Usage reports (ccusage)` section sits between "GSD" and "Safety checks" with the three commands, `--json`, the "this sandbox only" bullet, the `--offline` bullet and the "start needs no network" bullet.
- H-24 (`tests/host/h24-ccusage-reports-usage.sh`) sits in the sandbox stage of `run-all.sh`. The fake docker answers `ccusage daily|monthly|session` from the planted file and has the knobs `FAKE_CCUSAGE_EMPTY` and `FAKE_CCUSAGE_RC`. The checklist, `runner-healthy.sh` (24 PASS lines, `PASS: H-24`) and both `runner-failures.sh` summaries (23 passed) moved with it.

## TDD record (Task 2)

Red, with the self-test group and all wiring in place but neither the check nor the fake answers written:

```
bash tests/selftest/host/h24-ccusage-reports-usage.sh
FAIL: H-24: a report of the planted transcript passes
FAIL: H-24: prints PASS: H-24
FAIL: H-24: the transcript is in state/claude/projects with a run-unique session
FAIL: H-24: the daily report runs offline in the project folder
FAIL: H-24: the monthly report runs offline in the project folder
FAIL: H-24: the session report runs offline in the project folder
FAIL: H-24: the table report runs offline in the project folder
FAIL: H-24: a second run passes with one transcript file
FAIL: H-24: a report without the planted usage fails
FAIL: H-24: a ccusage that cannot run fails
FAIL: H-24: no test sandbox fails
FAIL: H-24: no test sandbox says to run run-all.sh first
```

Green, after the check and the fake answers: the same command prints 12 `PASS: H-24:` lines and no FAIL (exit 0). `runner-healthy.sh` and `runner-failures.sh` print no FAIL; `tests/guard/host-tests.sh`, `docs.sh` and `suites.sh` pass.

Tracer gate (Task 1): the tracer `<verify>` (the full Linux suite) was run after the three files changed and ended "All cases pass." with exit 0 before Task 2 started.

## Task Commits

1. **Task 1: tracer, the Claude image holds the pinned ccusage, executable for the sandbox user, and SANDBOX.md says how to use it** - `43a005c` (feat)
2. **Task 2: H-24 checks ccusage reports this sandbox's usage** - `9ed529e` (test)

**Plan metadata:** committed separately with STATE.md and ROADMAP.md (docs).

## Files Created/Modified

- `versions.env` - `CCUSAGE_VERSION`
- `claude/Dockerfile` - ccusage block and the extra smoke-test assertion
- `SANDBOX.md` - image row and the usage reports section
- `tests/host/h24-ccusage-reports-usage.sh` - H-24
- `tests/selftest/host/h24-ccusage-reports-usage.sh` - its self-test group
- `tests/selftest/host/support/fake-docker` - `exec_ccusage`, header lines, two knobs
- `tests/host/run-all.sh`, `tests/selftest/host/run-all.sh` - run list and group list
- `tests/host-checklist.md`, `tests/selftest/host/runner-healthy.sh`, `tests/selftest/host/runner-failures.sh` - row, title, counts

## Decisions Made

- The execute bit is added at build time as root with a glob over `@ccusage/*`, because the package ships the binary at mode 0644 and only its owner could add the bit at run time; the glob makes a missing platform package a build error.
- H-24 always passes `--offline` and reads stdout only, so the user-facing default price lookup (kept) cannot make the check depend on the network or on stderr notices.
- One fixed transcript file name overwritten each run, with a run-unique session ID and a fixed day (2020-01-07 12:00 UTC), so stale files cannot pass and transcripts written by other checks never change the numbers.

## Deviations from Plan

### Execution-environment adjustments (orchestrator instructions, not defects)

- The plan names the branch `feat/phase-02-pinned-toolchain` and says to leave the SUMMARY uncommitted. This run stayed on `chore/planning-phase-02-plan`, committed the two code tasks there, and commits this SUMMARY with STATE.md and ROADMAP.md in a planning-only commit; the orchestrator splits code and planning commits onto their branches at the end. No branch or origin/main ancestry check was run. No commit message carries an AI attribution trailer, as instructed.

### Auto-fixed Issues

None - plan executed exactly as written.

### Notes on the plan text

- Four Task 1 acceptance greps contain `$` and `*` and, run as written with basic regular expressions, print `0` although the lines exist. They were re-run as fixed-string matches (`grep -cF`) and print `1` each: the `npm install -g "ccusage@${CCUSAGE_VERSION}"` line, the `chmod 755 "$(npm root -g)"/ccusage/node_modules/@ccusage/*/bin/ccusage` line, and the `ccusage ${CCUSAGE_VERSION}` smoke test (the `CCUSAGE_VERSION is not set` and `versions.env` greps match as written). The Dockerfile content is the planned content; only the grep form was wrong.

**Total deviations:** 0 auto-fixed, plus the orchestrator branch and SUMMARY adjustments.
**Impact on plan:** none.

## Issues Encountered

None. The full Linux suite exceeds the 120 s foreground limit (the host self-test run-all is the slow part), so it was run in the background and read afterwards, as in the previous plans.

## Verification run

Full Linux suite after each task (bash -n on every script, then `tests/guard/run-all.sh`, `tests/selftest/guard`, `tests/selftest/entrypoint`, `tests/selftest/host`, `tests/selftest/bundle`): every suite ended "All rules hold." or "All cases pass.", exit 0, no FAIL line.

Acceptance criteria re-run:

- Task 1: `grep -c '^CCUSAGE_VERSION=' versions.env` prints 1 and the value equals the 02-PINS.md value (20.0.26); the `CCUSAGE_VERSION is not set; build with ./build.sh` grep prints 1; the other three Dockerfile greps print 1 as fixed strings (see the note above); `tail -n 1 claude/Dockerfile` prints `COPY --chmod=644 versions.env /etc/sbx/versions.env`; `grep -c '^## Usage reports (ccusage)$' SANDBOX.md` prints 1.
- Task 2: `# Depends on:` count 1 and `h24-ccusage-reports-usage.sh` in `run-all.sh` count 1; the daily command line count 1; 12 `PASS: H-24:` lines (needs at least 8); checklist title `# Host checklist (H-00..H-24)` and one `| H-24 |` row; `healthy run has 24 PASS lines` prints 1; the red and green runs are recorded above.

Not run here (Docker is not available in the dev sandbox): the image build, the `chmod` glob against the real package layout, `ccusage --version` as the sandbox user, and H-24 against the real ccusage. They go to the Mac run in plan 09.

## Known Stubs

None.

## Threat Flags

None. The new surface is the npm install of a pinned, approved package (T-02-26, T-02-SC) and the run-time price lookup that the plan accepts (T-02-27); both are in the plan's threat model.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for plan 02-08. USE-01 stays pending: plan 02-09 also declares it and has no SUMMARY yet, so the requirement is not marked complete here.
- Open for the Mac run (plan 09): that `./build.sh` finds `@ccusage/ccusage-linux-arm64/bin/ccusage` through the glob, that `ccusage --version` prints `ccusage 20.0.26` as the sandbox user (this closes the STATE.md blocker "confirm ccusage's native binary is executable on arm64"), and that H-24 passes against the real ccusage JSON shapes checked on 2026-10-08.

---
*Phase: 02-pinned-toolchain-gsd-and-ccusage*
*Completed: 2026-10-09*

## Self-Check: PASSED

- FOUND: versions.env, claude/Dockerfile, SANDBOX.md, tests/host/h24-ccusage-reports-usage.sh, tests/selftest/host/h24-ccusage-reports-usage.sh, tests/selftest/host/support/fake-docker
- FOUND commits: 43a005c, 9ed529e
