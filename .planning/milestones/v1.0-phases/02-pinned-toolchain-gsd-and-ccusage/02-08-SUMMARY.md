---
phase: 02-pinned-toolchain-gsd-and-ccusage
plan: 08
subsystem: host-tests
tags: [host-tests, h25, h13, fake-docker, versions-env, missing-pin, self-update]

requires:
  - phase: 02-pinned-toolchain-gsd-and-ccusage
    provides: versions.env with all pins, the Claude image with /etc/sbx/versions.env, GSD and ccusage baked in, fake docker with build and exec handlers (plans 01 to 07)
provides:
  - host check H-25 (tests/host/h25-images-match-versions.sh), no-sandbox stage, with its self-test group
  - H-13 also fails when ~/.local/bin/claude exists in the container home
  - fake docker answers for the image checks (record, GSD identity, ccusage version, workspace listing), a bare build, and the ~/.local/bin/claude test, with six knobs
affects: [02-09]

actuals:
  tokens: 5100
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "A host check that needs only the images reads facts with docker run --entrypoint TOOL and compares them with pin_of"
    - "A build without build.sh is proven by building the Dockerfile with no build args and no tag and reading the log in the run folder"

key-files:
  created:
    - tests/host/h25-images-match-versions.sh
    - tests/selftest/host/h25-images-match-versions.sh
  modified:
    - tests/host/h13-env-and-no-self-update.sh
    - tests/selftest/host/h13-env-and-no-self-update.sh
    - tests/selftest/host/support/fake-docker
    - tests/host/run-all.sh
    - tests/selftest/host/run-all.sh
    - tests/host-checklist.md
    - tests/selftest/host/runner-healthy.sh
    - tests/selftest/host/runner-failures.sh

key-decisions:
  - "H-25 accepts any of TEMURIN_IMAGE, UV_IMAGE or UBUNTU_IMAGE in the bare base build log, because the order BuildKit reports a blank FROM pin in is not documented"
  - "The bare builds use --progress=plain and log to h25-bare-*.log, which H-01's platform scan does not read, and their command lines start with build --progress=plain, which the runner's build-count cases do not match"
  - "H-13 keeps claude --version equal to the pin out of its scope; that stays H-12's job"

patterns-established:
  - "fake_bare_build: a build with neither a build arg nor a tag fails with the Dockerfile's own message and writes no state"

requirements-completed: []

coverage:
  - id: D1
    description: "H-25 passes only when /etc/sbx/versions.env in sbx-claude:local equals versions.env, gsd-tools runtime-identity names @opengsd/gsd-core at the pin, ccusage --version is the pin, and /home/sandbox/workspace in the image is empty; each failure mode is reported by name"
    requirement: IMG-03
    verification:
      - kind: unit
        ref: "bash tests/selftest/host/h25-images-match-versions.sh (15 PASS lines)"
        status: pass
      - kind: manual_procedural
        ref: "H-25 in bash tests/host/run-all.sh on the Mac (plan 09), against the real images"
        status: unknown
    human_judgment: false
  - id: D2
    description: "H-25 builds base/Dockerfile and claude/Dockerfile once each without build args and without a tag and requires each build to stop, the base build naming a missing image pin and the Claude build printing the missing-pin message"
    requirement: IMG-03
    verification:
      - kind: unit
        ref: "bash tests/selftest/host/h25-images-match-versions.sh (bare builds run without build args or tag; FAKE_BARE_BUILD_OK=1 fails)"
        status: pass
      - kind: manual_procedural
        ref: "H-25 on the Mac (plan 09): BuildKit names the empty FROM variable (research assumption A2)"
        status: unknown
    human_judgment: false
  - id: D3
    description: "H-13 fails when ~/.local/bin/claude exists in the container home and reports an exec that could not run as could not check"
    requirement: TOOL-01
    verification:
      - kind: unit
        ref: "bash tests/selftest/host/h13-env-and-no-self-update.sh (a self-installed Claude in ~/.local/bin fails)"
        status: pass
      - kind: manual_procedural
        ref: "H-13 in bash tests/host/run-all.sh on the Mac (plan 09)"
        status: unknown
    human_judgment: false

duration: about 25 min (approximate; the start time was not captured at plan start)
completed: 2026-10-09
status: complete
commits: 2
plan_head_before: 482c800cfe48fa349e9f909091e8ebdb9b65efbc
plan_head_after: 44f998aef6a23da1011e273b0c84830c2d2350cf
---

# Phase 2 Plan 08: H-25 images match versions.env, and H-13 refuses a Claude copy in ~/.local Summary

**Host check H-25 compares the image's /etc/sbx/versions.env, GSD identity, ccusage version and an empty mount point with the pins, and builds both Dockerfiles without build.sh to prove they stop naming the missing pin; H-13 also fails on a self-installed ~/.local/bin/claude.**

## Performance

- **Duration:** about 25 min (approximate)
- **Completed:** 2026-10-09
- **Tasks:** 2
- **Files modified:** 10 (2 created, 8 modified)

## Accomplishments

- `tests/host/h25-images-match-versions.sh` (H-25) sits in the no-sandbox stage of `run-all.sh`, after H-21. It has `require_run_folder`, `check_record` (writes `logs/h25-image-versions.env` and diffs it with `versions.env`), `check_tool_versions` (GSD identity line and `ccusage PIN`), `check_workspace_empty` and `check_bare_builds` (writes `logs/h25-bare-base.log` and `logs/h25-bare-claude.log`).
- The fake docker answers `--entrypoint cat|gsd-tools|ccusage|ls` runs and treats a build with no build arg and no tag as a bare build that fails with the Dockerfile's message and leaves `FAKE_STATE/built` alone. New knobs: `FAKE_RECORD_STALE`, `FAKE_GSD_IDENTITY`, `FAKE_CCUSAGE_VERSION`, `FAKE_WORKSPACE_BAKED`, `FAKE_BARE_BUILD_OK`, `FAKE_LOCAL_BIN_EXISTS`.
- H-13 reads a second `test ! -e` status for `~/.local/bin/claude` and `check_no_local_bin_copy` reports 1 as an existing copy and any other status as could not check; `FAKE_EXEC_RC` applies to both folder tests.
- The checklist title and IDs bullet read H-00..H-25, the H-25 row is added, and the H-13 row says no Claude copy sits in `~/.local`. `runner-healthy.sh` expects 25 PASS lines and `PASS: H-25`; both `runner-failures.sh` summaries read 24 passed, 1 failed.

## TDD record

Task 1, red, with the self-test group and all wiring in place but neither the check nor the fake answers written:

```
bash tests/selftest/host/h25-images-match-versions.sh
FAIL: H-25: images that match versions.env pass
FAIL: H-25: prints PASS: H-25
FAIL: H-25: the record read from the image is kept in the run folder
FAIL: H-25: the bare base build log is kept in the run folder
FAIL: H-25: the bare Claude build log is kept in the run folder
FAIL: H-25: the record is read from the Claude image
FAIL: H-25: both bare builds run without build args and without a tag
FAIL: H-25: one bare build is the base Dockerfile and one the Claude Dockerfile
PASS: H-25: a bare build is not counted as a build of the images   (vacuous before the check existed)
FAIL: H-25: a stale record fails
FAIL: H-25: a GSD that is not the pin fails
FAIL: H-25: a ccusage that is not the pin fails
FAIL: H-25: files under the mount point fail
FAIL: H-25: a build that does not stop without build.sh fails
FAIL: H-25: no run folder fails
```

Task 1, green, after the check and the fake answers: the same command prints 15 `PASS: H-25:` lines and no FAIL (exit 0). `runner-healthy.sh`, `runner-failures.sh`, `tests/guard/host-tests.sh`, `docs.sh` and `suites.sh` pass.

Task 2, red, with only the new case added:

```
bash tests/selftest/host/h13-env-and-no-self-update.sh
FAIL: H-13: a self-installed Claude in ~/.local/bin fails
```

(all other lines PASS). Task 2, green: all 9 lines PASS, including `PASS: H-13: a self-installed Claude in ~/.local/bin fails`, and the exec-could-not-run cases still pass.

Tracer gate (Task 1): the tracer `<verify>` (the group, the two runner suites and the three guards, then the full Linux suite) was run after the eight files changed and ended "All rules hold." / "All cases pass." with exit 0 before Task 2 started.

## Task Commits

1. **Task 1: tracer, host check H-25 proves the images carry exactly the pins of versions.env and refuse a build without build.sh** - `0012af4` (test)
2. **Task 2: H-13 also refuses a self-installed Claude copy in ~/.local/bin** - `44f998a` (test)

**Plan metadata:** committed separately with STATE.md and ROADMAP.md (docs).

## Files Created/Modified

- `tests/host/h25-images-match-versions.sh` - H-25
- `tests/selftest/host/h25-images-match-versions.sh` - its self-test group (15 cases)
- `tests/host/h13-env-and-no-self-update.sh` - `localBinStatus`, `check_no_local_bin_copy`, header and pass text
- `tests/selftest/host/h13-env-and-no-self-update.sh` - the `~/.local/bin` case
- `tests/selftest/host/support/fake-docker` - four run answers, `fake_bare_build`, the `.local/bin/claude` exec case, header lines, six knobs
- `tests/host/run-all.sh`, `tests/selftest/host/run-all.sh` - run list and group list
- `tests/host-checklist.md`, `tests/selftest/host/runner-healthy.sh`, `tests/selftest/host/runner-failures.sh` - rows, title, counts

## Decisions Made

- H-25 accepts any one of the three FROM pin names in the bare base build log, because BuildKit's reporting order for blank FROM variables is not documented (research assumption A2, to be confirmed on the Mac).
- The bare builds log under `h25-bare-*` names and start with `build --progress=plain`, so H-01's platform scan and the runner's `build -f` / `build --no-cache` counts are unaffected.
- A `docker run --entrypoint ls` that exits non-zero is reported as a separate problem (could not list), so a missing image does not read as an empty folder.

## Deviations from Plan

### Execution-environment adjustments (orchestrator instructions, not defects)

- The plan names the branch `feat/phase-02-pinned-toolchain` and says to leave the SUMMARY uncommitted. This run stayed on `chore/planning-phase-02-plan`, committed the two code tasks there, and commits this SUMMARY with STATE.md and ROADMAP.md in a planning-only commit; the orchestrator splits code and planning commits onto their branches at the end. No branch or origin/main ancestry check was run. No commit message carries an AI attribution trailer, as instructed.

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Separate problem for a failed workspace listing**
- **Found during:** Task 1
- **Issue:** The plan says the listing must exit 0 and print nothing; one combined message would call a failed `docker run` (for example a missing image) an image that holds files.
- **Fix:** `check_workspace_empty` adds `could not list /home/sandbox/workspace in the image (exit N)` for a non-zero status and the "holds files" problem only for a non-empty listing.
- **Files modified:** tests/host/h25-images-match-versions.sh
- **Commit:** 0012af4

**Total deviations:** 1 auto-fixed (1 Rule 2), plus the orchestrator branch and SUMMARY adjustments.
**Impact on plan:** none; the extra problem text only separates two failure causes.

## Issues Encountered

None. The full Linux suite exceeds the 120 s foreground limit when the host self-test run-all is included, so it was run with a longer timeout and read afterwards.

## Verification run

Full Linux suite after each task (bash -n on every script, then `tests/guard/run-all.sh`, `tests/selftest/guard`, `tests/selftest/entrypoint`, `tests/selftest/host`, `tests/selftest/bundle`): every suite ended "All rules hold." or "All cases pass.", exit 0, no FAIL line.

Acceptance criteria re-run:

- Task 1: `# Depends on:` count 1 and `h25-images-match-versions.sh` in `run-all.sh` count 1; `docker build --progress=plain -f` count 2 (needs at least 1); `CLAUDE_CODE_VERSION is not set; build with ./build.sh` count 1; 15 `PASS: H-25:` lines (needs at least 10); checklist title `# Host checklist (H-00..H-25)` and one `| H-25 |` row; `healthy run has 25 PASS lines` prints 1; the red and green runs are recorded above.
- Task 2: `check_no_local_bin_copy` count 2; `.local/bin/claude` count 6 (needs at least 2); the named PASS line prints 1; `no Claude copy sits in` prints 1.

Not run here (Docker is not available in the dev sandbox): H-25 and H-13 against the real images, and BuildKit's wording for a blank FROM variable. They go to the Mac run in plan 09.

## Known Stubs

None.

## Threat Flags

None. The plan adds test code only; its threats (T-02-29 to T-02-32, T-02-SC) are mitigated by H-25 and H-13 as listed in the plan's threat model, to be confirmed on the Mac.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for plan 02-09. IMG-03, IMG-04 and TOOL-01 stay pending: other plans of the phase also declare them and have no SUMMARY yet (`requirements.ready-ids` reported 0 of 3 ready), so they are not marked complete here.
- Open for the Mac run (plan 09): that BuildKit names the empty variable when a FROM pin is missing (research A2; if it does not, build.sh needs its own check for the three FROM pins and H-25 should say so), that the Claude bare build prints `CLAUDE_CODE_VERSION is not set; build with ./build.sh` from the first RUN, and that `/etc/sbx/versions.env`, `gsd-tools runtime-identity --raw`, `ccusage --version` and the empty `/home/sandbox/workspace` match in the real image.

---
*Phase: 02-pinned-toolchain-gsd-and-ccusage*
*Completed: 2026-10-09*

## Self-Check: PASSED

- FOUND: tests/host/h25-images-match-versions.sh, tests/selftest/host/h25-images-match-versions.sh, tests/host/h13-env-and-no-self-update.sh, tests/selftest/host/support/fake-docker
- FOUND commits: 0012af4, 44f998a
