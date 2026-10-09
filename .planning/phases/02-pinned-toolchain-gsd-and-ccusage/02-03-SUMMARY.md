---
phase: 02-pinned-toolchain-gsd-and-ccusage
plan: 03
subsystem: infra
tags: [docker, base-image, temurin, maven, uv, python, digest-pinning, host-check]

requires:
  - phase: 02-pinned-toolchain-gsd-and-ccusage
    provides: versions.env and build.sh, so a new pin is one line (plan 01)
  - phase: 02-pinned-toolchain-gsd-and-ccusage
    provides: approved pin table 02-PINS.md with image digests (plan 02)
provides:
  - base/Dockerfile with jdk and uv stages, one apt layer with the Linux tools and Python, the Temurin JDK, Maven checked against its .sha512, uv, JAVA_HOME and a build-time smoke test
  - versions.env with UBUNTU_IMAGE, TEMURIN_IMAGE and UV_IMAGE as tag plus @sha256 digest, and MAVEN_VERSION
  - guard rule versions_are_pinned that refuses an _IMAGE pin without a 64 hex digest
  - host check H-22 (toolchain native, at its pins, visible to a login shell) with probe, self-test group and fake docker answers
affects: [02-05, 02-07, 02-09]

actuals:
  tokens: 10500
  tasks: 2
  commits: 2

tech-stack:
  added: [eclipse-temurin 21.0.12 (image copy), Maven 3.9.16, uv 0.12.21 (image copy), python3 3.12 (apt)]
  patterns:
    - "Official-image stages (FROM pin AS name) that only hold files the final stage copies"
    - "One probe file run by bash -c in a throwaway container and bash -lc in the sandbox, read by a host check"

key-files:
  created:
    - tests/host/h22-toolchain-in-base.sh
    - tests/host/support/toolchain-probe.sh
    - tests/selftest/host/h22-toolchain-in-base.sh
  modified:
    - versions.env
    - base/Dockerfile
    - tests/guard/supply-chain.sh
    - tests/selftest/guard/sandbox-rules.sh
    - SANDBOX.md
    - tests/selftest/host/support/fake-docker
    - tests/host/run-all.sh
    - tests/selftest/host/run-all.sh
    - tests/host-checklist.md
    - tests/selftest/host/runner-healthy.sh
    - tests/selftest/host/runner-failures.sh

key-decisions:
  - "All three image pins carry tag plus index digest exactly as approved in 02-PINS.md; no value differed from the research expectation"
  - "The JDK is linked file by file into /usr/local/bin with a for loop in the Dockerfile RUN (ln -s fails on a name clash, so a collision with Node's bin stops the build)"
  - "H-22 finds Python by its version text (Python 3.) so its own code never names the command the portability rule bans"

patterns-established:
  - "Pin ARGs sit directly above the RUN that uses them; the apt layer has none"
  - "Fake docker answers a probe from the pins in versions.env, so a pin bump never needs a fake edit"

requirements-completed: []

coverage:
  - id: D1
    description: "base/Dockerfile builds FROM the digest-pinned Ubuntu image and copies the JDK and uv from digest-pinned images; Maven is checked against its .sha512; the build fails unless every tool reports its pin as the sandbox user"
    requirement: IMG-01
    verification:
      - kind: other
        ref: "Linux suite: guard versions_are_pinned and the acceptance greps on base/Dockerfile and versions.env"
        status: pass
      - kind: manual_procedural
        ref: "./build.sh on the Mac (plan 09); Docker is not available in the dev sandbox"
        status: unknown
    human_judgment: false
  - id: D2
    description: "The guard refuses an image pin without a 64 hex @sha256 digest"
    requirement: IMG-03
    verification:
      - kind: unit
        ref: "tests/selftest/guard/sandbox-rules.sh: supply chain: an image pin without a digest fails"
        status: pass
    human_judgment: false
  - id: D3
    description: "H-22 proves git, gh, Node, Python 3, uv, Temurin JDK and Maven are native, at their pins and visible to a login shell; every failure mode is caught"
    requirement: IMG-01
    verification:
      - kind: unit
        ref: "bash tests/selftest/host/h22-toolchain-in-base.sh (14 PASS lines)"
        status: pass
      - kind: manual_procedural
        ref: "H-22 in bash tests/host/run-all.sh on the Mac (plan 09)"
        status: unknown
    human_judgment: false

duration: not recorded
completed: 2026-10-09
status: complete
commits: 2
plan_head_before: e8b2e43c90e0e80a6dd4fbd2f2515791d2e16ebc
plan_head_after: ef27b56f4e56063f1404ff3aa58483f055db6fb3
---

# Phase 2 Plan 03: Toolchain in the base image Summary

**The shared base image now builds from digest-pinned Ubuntu, copies the Temurin 21 JDK and uv from digest-pinned images, installs Maven 3.9.16 checked against Maven Central's .sha512, and carries Python 3 and the common Linux tools; host check H-22 proves all of it on the Mac and its self-test proves every failure mode on Linux.**

## Performance

- **Duration:** not recorded
- **Completed:** 2026-10-09
- **Tasks:** 2 (1 tracer, 1 TDD auto)
- **Files modified:** 14 (3 created, 11 modified)

## Accomplishments

- `versions.env`: `UBUNTU_IMAGE`, `TEMURIN_IMAGE` and `UV_IMAGE` are tag plus `@sha256` digest (values copied from the approved rows of 02-PINS.md); `MAVEN_VERSION=3.9.16` added.
- `base/Dockerfile`: stages `jdk` and `uv`; one apt layer (no ARG above it) with ca-certificates curl git less procps xz-utils jq ripgrep unzip zip openssh-client make build-essential tzdata python3 python3-venv python3-pip; JDK copied to `/opt/java/openjdk` and linked into `/usr/local/bin`; Maven downloaded from Maven Central and verified with `sha512sum -c -` in the same RUN; `COPY --from=uv /uv /uvx /usr/local/bin/`; `JAVA_HOME` in the image ENV; a build-time smoke test as the sandbox user (node, gh, mvn and java against their pins, plus uv and python3).
- Guard: `versions_are_pinned` now requires `@sha256:` plus 64 hex on every `_IMAGE` pin, with a self-test case.
- `SANDBOX.md` has a "What the images hold" section.
- H-22 with its probe (`tests/host/support/toolchain-probe.sh`), self-test group (14 cases), fake docker answers and knobs (`FAKE_TOOL_ELF`, `FAKE_TOOL_MISSING`, `FAKE_TOOL_STALE`, `FAKE_JAVA_VENDOR`, `FAKE_LOGIN_MISSING`), checklist row and runner counts (22 PASS lines healthy; 21 passed, 1 failed in the failure summaries).

## TDD record (Task 2)

- **Red** (self-test group and its `run-all.sh` entry written first, no check, probe or fake answers yet): `bash tests/selftest/host/h22-toolchain-in-base.sh` exited 1 with 13 `FAIL:` lines (every case except the vacuous "base image is not blamed" negative check).
- **Green** (check, probe and fake answers added): the same command exits 0 with 14 `PASS: H-22:` lines and no `FAIL:`.

## Task Commits

1. **Task 1 (tracer): the JDK, Maven, uv, Python and Linux tools in the base image** - `ecddc4e` (feat)
2. **Task 2: H-22 checks the toolchain in the base image** - `ef27b56` (test; amended once to keep the probe's end marker to a single literal line)

The tracer feedback gate ran in interactive end-of-phase mode with an automated-only verify: the full Linux suite was re-run on the committed tracer state and passed before Task 2 started.

## Verification

Full Linux suite (bash -n over all scripts, guard, guard self-test, entrypoint self-test, host self-test, bundle self-test) passes after each task: `SUITE_RC=0`, "All cases pass." Task 2's own verify (`h22` group, `runner-healthy`, `runner-failures`, `guard/host-tests.sh`, `guard/docs.sh`, `guard/suites.sh`) passes. All acceptance greps in both tasks give the expected counts.

## Not verified here (Docker is not available in the dev sandbox)

Nothing in the Dockerfile was built. These are Mac assumptions for plan 09's run, as flagged in the plan:

- ubuntu:24.04 enables universe, so ripgrep, python3-pip and python3-venv install.
- The copied Temurin tree runs Maven and Java without fontconfig.
- A login shell keeps `/usr/local/bin` on PATH.
- ELF bytes `b7 00` mean AArch64.
- **Added risk to check:** the copied JDK tree may keep a `lib/security/cacerts` link that points at `/etc/ssl/certs/java/cacerts`, which this image does not create. The smoke test does not make a TLS call, so a dangling link would only show when Maven downloads from Maven Central (plan 09, or the first real project). If it does, the fix is to add `ca-certificates-java` to the apt layer or to relink `cacerts` to the JDK's bundled file.

## Deviations from Plan

### Orchestrator-directed changes

**1. [Branching] Work stayed on `chore/planning-phase-02-plan`; no `feat/phase-02-pinned-toolchain` branch**
- The dispatch said to stay on the current branch and skip the branch-name and origin/main ancestry checks. The orchestrator splits code and planning commits onto proper branches at the end. The two code commits touch no file under `.planning/`; the SUMMARY, STATE.md and ROADMAP.md go into a separate planning-only commit (the plan said to leave the SUMMARY uncommitted; the dispatch said to commit it).

### Auto-fixed Issues

**2. [Rule 1 - Bug] Probe end marker literal appeared twice in the probe file**
- **Found during:** Task 2 acceptance check (`grep -c PROBE-END` printed 2, plan expects 1).
- **Issue:** The header comment listed the marker by name as well as the final `echo`.
- **Fix:** The header now says "the end marker" instead of repeating the literal.
- **Files modified:** `tests/host/support/toolchain-probe.sh`
- **Commit:** `ef27b56` (amended into the Task 2 commit before any other work depended on it)

Otherwise the plan executed as written.

## Issues Encountered

An early heredoc used to create `tests/host/h22-toolchain-in-base.sh` ended at an inner `EOF` line of the file's own here-document and failed with a shell syntax error; the file was written again with the Write tool before any test ran. No effect on the result.

## Known Stubs

None.

## Threat Flags

None. No new endpoint, auth path or trust boundary beyond the threat model: T-02-09 (digests and the stricter guard), T-02-10 (Maven `.sha512` check in the same RUN) and T-02-12 (no pipe-to-shell; the JDK and uv come by `COPY --from`) are implemented. T-02-11 (unpinned apt) is stated in `SANDBOX.md` and the Dockerfile comment. No package-manager installs were run.

## Requirements

`IMG-01` and `IMG-03` are declared by this plan, but each is also declared by plan 09 (and `IMG-03` by 01, 02 and 08), which have no SUMMARY yet. Neither is marked complete here.

## Next Phase Readiness

- Plans 05 and 07 add their pins to `versions.env` and their ARGs to the Claude Dockerfile; the base now offers Node, Python, uv, JDK and Maven to them.
- Plan 09 runs `./build.sh` and `bash tests/host/run-all.sh` on the Mac; H-22 and the Mac assumptions above are the things to read first.

## Self-Check: PASSED

- FOUND: versions.env, base/Dockerfile, tests/host/h22-toolchain-in-base.sh, tests/host/support/toolchain-probe.sh, tests/selftest/host/h22-toolchain-in-base.sh
- FOUND commits: ecddc4e, ef27b56 (`git rev-list --count e8b2e43..HEAD` = 2)

---
*Phase: 02-pinned-toolchain-gsd-and-ccusage*
*Completed: 2026-10-09*
