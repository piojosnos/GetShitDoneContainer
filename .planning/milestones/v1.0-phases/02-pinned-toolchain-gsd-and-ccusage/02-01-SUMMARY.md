---
phase: 02-pinned-toolchain-gsd-and-ccusage
plan: 01
subsystem: build
tags: [docker, bash, versions-env, build-script, supply-chain, guard]

requires:
  - phase: 01-sandbox-image-and-compose
    provides: base and claude Dockerfiles with pinned ARG defaults, the guard, the host tests and the fake docker
provides:
  - versions.env as the only place versions live (Ubuntu image, Node, gh, Claude Code)
  - build.sh building sbx-base:local then sbx-claude:local with every pin passed to both builds
  - Dockerfiles without version defaults and with a missing-pin stop in each RUN that uses a pin
  - /etc/sbx/versions.env in the claude image as a record of the pins
  - guard rule versions_are_pinned rewritten around versions.env
  - host tests that build through build.sh and read pins through pin_of and claude_pin
  - build-wiring self-test group
  - SANDBOX.md build, rebuild and bump sections
affects: [02-02, 02-03, 02-04, 02-05, 02-06, 02-07, 02-08, 02-09, phase-03]

actuals:
  tokens: 7074
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "versions.env sourced under set -a; names from grep -oE '^[A-Z_]+'; bare --build-arg NAME so Docker reads the exported value"
    - "ARG NAME declared right above the RUN that uses it, with a ': \"${NAME:?NAME is not set; build with ./build.sh}\"' guard as the RUN's first command"
    - "fake docker logs build args and context folder to FAKE_STATE/build-args.log"

key-files:
  created:
    - versions.env
    - build.sh
    - tests/selftest/host/build-wiring.sh
  modified:
    - base/Dockerfile
    - claude/Dockerfile
    - .dockerignore
    - tests/guard/supply-chain.sh
    - tests/guard/bundle-wiring.sh
    - tests/guard/lib.sh
    - tests/guard/host-tests.sh
    - tests/host/lib-docker.sh
    - tests/host/h12-plain-run-refused-pin-installed.sh
    - tests/selftest/host/support/fake-docker
    - tests/selftest/host/units.sh
    - tests/selftest/host/runner-healthy.sh
    - tests/selftest/host/runner-failures.sh
    - tests/selftest/host/run-all.sh
    - tests/selftest/guard/sandbox-rules.sh
    - tests/selftest/guard/host-rules.sh
    - tests/selftest/bundle/claude-probe.sh
    - SANDBOX.md
    - compose.yml

key-decisions:
  - "versions.env keeps UBUNTU_IMAGE=ubuntu:24.04 by tag in this plan; the digest waits for the approval in plan 02"
  - "build.sh sources ./versions.env (with the ./) so bash never searches PATH for it"
  - "No syntax= line in base/Dockerfile: it would pull a Dockerfile frontend image by a moving tag at every build"
  - "ARG BASE_IMAGE=sbx-base:local is the only ARG with a default, because it names the local base tag, not a version"
  - "A build with no versions.env or no pins stops in build.sh before any docker build runs"

patterns-established:
  - "One pin, one place: a new tool is one versions.env line plus one ARG NAME above its RUN; build.sh never changes"
  - "Guard fails closed on versions.env: bad line, duplicate name, non x.y.z version, bad image reference, dead pin, undeclared ARG"

requirements-completed: [IMG-03, IMG-04]

coverage:
  - id: D1
    description: "versions.env holds the four existing pins and the Dockerfiles carry no version default"
    requirement: IMG-03
    verification:
      - kind: unit
        ref: "bash tests/guard/supply-chain.sh#versions_are_pinned"
        status: pass
      - kind: unit
        ref: "bash tests/selftest/guard/sandbox-rules.sh#supply chain cases"
        status: pass
    human_judgment: false
  - id: D2
    description: "build.sh builds the base then the claude image, passes every pin to both, runs from any folder, forwards extra arguments and stops on a missing or empty versions.env or a failed base build"
    requirement: IMG-04
    verification:
      - kind: unit
        ref: "bash tests/selftest/host/build-wiring.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: "Host tests build through build.sh and read pins from versions.env"
    requirement: IMG-03
    verification:
      - kind: unit
        ref: "bash tests/selftest/host/run-all.sh"
        status: pass
    human_judgment: false
  - id: D4
    description: "Real Docker: a bare build stops and names the missing pin, the directive silences the FROM check, COPY --chmod writes /etc/sbx/versions.env as root mode 644, and a bump reaches the sandbox"
    requirement: IMG-03
    verification: []
    human_judgment: true
    rationale: "Docker is not available in the dev sandbox; these claims are proven on the Mac by the host run in plan 09 (H-25)."
  - id: D5
    description: "SANDBOX.md says to build with ./build.sh and explains the bump and add-a-tool steps"
    requirement: IMG-04
    verification:
      - kind: unit
        ref: "bash tests/guard/docs.sh"
        status: pass
    human_judgment: true
    rationale: "Wording and readability of the docs are for a reviewer; the guard checks only the forbidden phrases."

duration: 9min
completed: 2026-10-08
status: complete
commits: 3
plan_head_before: 7bb30e4b5485032f18583bcf3cc7ee5a51d8bef1
plan_head_after: 972e8859e83b976296b3c2ce24505d9f5f72fe78
---

# Phase 2 Plan 01: Pins in versions.env, built by build.sh Summary

**Every existing pin (Ubuntu image, Node, gh, Claude Code) now lives only in versions.env; build.sh sources it and passes each name as a bare --build-arg to both Dockerfiles, which carry no version defaults, and the guard, host tests, fake docker and docs all follow.**

## Performance

- **Duration:** 9 min, measured from the first file written (the start time was not recorded before reading the plan)
- **Started:** 2026-10-08T18:04:21Z (first file written)
- **Completed:** 2026-10-08T18:13:00Z
- **Tasks:** 3 (1 tracer, 1 TDD, 1 docs)
- **Files modified:** 22 (3 created, 19 modified)

## Accomplishments

- `versions.env` is the single place for `UBUNTU_IMAGE`, `NODE_VERSION`, `GH_VERSION` and `CLAUDE_CODE_VERSION`; `build.sh` builds `sbx-base:local` then `sbx-claude:local`, with extra arguments forwarded to both builds.
- Both Dockerfiles lost their version defaults. Each pin has an `ARG NAME` right above its `RUN`, and that `RUN` opens with a guard that stops with `<NAME> is not set; build with ./build.sh`. The claude image ends with `COPY --chmod=644 versions.env /etc/sbx/versions.env` as a record.
- The guard rule `versions_are_pinned` fails closed on a bad line, a duplicate name, a version that is not x.y.z, a bad image reference, an ARG default, an undeclared ARG, a dead pin and a FROM that does not take its image from a pin. `SANDBOX_FILES` and the portability rule now also cover `versions.env` and `build.sh`.
- The host tests build through `build.sh` (one `<prefix>-images.log` per call) and read pins with `pin_of` and `claude_pin`. The new `build-wiring.sh` group proves the `build.sh` contract against the fake docker.
- `SANDBOX.md` builds and rebuilds with `./build.sh` and has a new "Bump a version or add a tool" section.

## Task Commits

1. **Task 1: Tracer, every existing pin travels from versions.env through build.sh** - `37e2442` (feat)
2. **Task 2: build.sh proven against the fake docker, guard rules proven by planted violations** - `8b051bb` (test)
3. **Task 3: docs say to build with ./build.sh and how to bump a pin** - `972e885` (docs)

**Plan metadata:** committed separately on this branch as `docs(02-01)` (SUMMARY, STATE, ROADMAP, REQUIREMENTS).

### TDD record for Task 2

- Red run (cases written, fake docker and lib.sh not yet changed): 6 failing cases. In `build-wiring.sh`: "Docker sees each pin's value from versions.env", "runs from any folder with the repo root as context", "a caller's environment never overrides a pin", "a new pin reaches both builds with no change to build.sh". In `sandbox-rules.sh`: "supply chain: a floating image tag fails". In `host-rules.sh`: "the portability rule also reads build.sh". The other cases already passed because Task 1 had rewritten `versions_are_pinned`.
- Green run (after `fake_build` logging, `SANDBOX_FILES` and `host_tests_are_portable` changes): all three groups exit 0 with no FAIL line.

## Files Created/Modified

- `versions.env` - the four pins, grouped `# sbx-base` and `# sbx-claude`, with a header that says it is sourced by bash
- `build.sh` - check_versions_file, load_versions, collect_build_args, build_image; base first, then claude
- `base/Dockerfile`, `claude/Dockerfile` - defaults removed, per-tool `ARG` and missing-pin guard, directive on line 1 of the base, pin record as the last claude instruction
- `.dockerignore` - lets `versions.env` into the build context
- `tests/guard/supply-chain.sh`, `bundle-wiring.sh`, `lib.sh`, `host-tests.sh` - rewritten pin rule, COPY flags and `--from`, wider file lists
- `tests/host/lib-docker.sh` - `build_images` through `build.sh`, `pin_of`, `claude_pin` from `versions.env`
- `tests/selftest/host/support/fake-docker` - logs build args and context to `build-args.log`, pin read from `versions.env`
- `tests/selftest/host/build-wiring.sh` (new), `units.sh`, `runner-healthy.sh`, `runner-failures.sh`, `run-all.sh` - self-test updates
- `tests/selftest/guard/sandbox-rules.sh`, `host-rules.sh` - planted-violation cases for the pin rules and `build.sh` portability
- `SANDBOX.md`, `compose.yml`, `tests/host/h12-plain-run-refused-pin-installed.sh`, `tests/selftest/bundle/claude-probe.sh` - docs and header text

## Decisions Made

- Followed the plan as written for the pins, the `./versions.env` source form, the missing-pin guard text and the `# check=skip=InvalidDefaultArgInFrom` directive without a `# syntax=` line.
- The fake docker logs a build's args and context before it applies `FAKE_BUILD_FAIL`, so a failed build still shows what it received.

## Deviations from Plan

### Orchestrator-directed changes

**1. [Branching] Code committed on `chore/planning-phase-02-plan`, not on `feat/phase-02-pinned-toolchain`**
- **Found during:** Task 1 (branch step)
- **Issue:** The plan says to cut `feat/phase-02-pinned-toolchain` from `origin/main`. The dispatch for this run said to stay on the current branch, create or switch none, and keep code commits and `.planning/` commits in separate commits so they can be split into separate PRs later.
- **Fix:** Followed the dispatch. The three code commits (`37e2442`, `8b051bb`, `972e885`) touch no `.planning/` file; the planning files go in one separate `docs(02-01)` commit. The Task 1 acceptance criteria that name the branch (`git rev-parse --abbrev-ref HEAD` and `git merge-base --is-ancestor origin/main HEAD`) are therefore not met by design.
- **Follow-up:** Before the PR, move the three code commits onto a branch cut from an updated `main` (for example by cherry-picking them).

**2. [Close-out] SUMMARY committed, not left uncommitted**
- The plan says to leave the SUMMARY uncommitted for the orchestrator. The dispatch asked for it to be written and committed, in a planning-only commit.

### Auto-fixed Issues

**1. [Rule 2 - Missing critical] Empty COPY source no longer reported as a missing file**
- **Found during:** Task 1 (bundle_reaches_build_context)
- **Issue:** With the new COPY parsing, a Dockerfile whose only COPY lines use `--from` yields an empty source list, and the loop would report `COPY source  does not exist`.
- **Fix:** Skip an empty source line in the loop.
- **Files modified:** `tests/guard/bundle-wiring.sh`
- **Committed in:** `37e2442`

---

**Total deviations:** 1 auto-fixed (1 Rule 2), 2 orchestrator-directed process changes
**Impact on plan:** No change to the delivered behavior. The branch change needs a cherry-pick before the code PR.

## Issues Encountered

- Two acceptance greps that use `grep -x` or a trailing `$` with a literal `$` in the pattern print `0` on this machine's GNU grep: `grep -cx 'FROM ${UBUNTU_IMAGE}' base/Dockerfile` and the `SANDBOX_FILES` line check in `tests/guard/lib.sh`. GNU grep reads the `$` inside the pattern as an anchor. The lines are exactly right: `grep -cxF 'FROM ${UBUNTU_IMAGE}' base/Dockerfile` and `grep -cF 'SANDBOX_FILES="$BASE $CLAUDE $COMPOSE $ENTRY versions.env build.sh"' tests/guard/lib.sh` both print `1`. This is a defect in the plan's wording of the checks, not in the code.
- Docker does not run in this sandbox, so no real `docker build` was run (see Known Gaps).

## Verification Results

- Full Linux suite after each task: exit 0. The last lines: guard "All" rules pass, each self-test suite "All cases pass."
- `bash tests/selftest/host/build-wiring.sh`: 10 `PASS: build.sh:` lines, no FAIL.
- `bash tests/selftest/guard/sandbox-rules.sh`: 13 `PASS: (supply chain|bundle wiring):` lines; `host-rules.sh`: 1 `PASS: host rules: the portability rule also reads build.sh`.
- `bash tests/guard/docs.sh` and `bash tests/guard/planning-ids.sh`: pass.
- Task 1 acceptance criteria other than the two branch checks: pass (the `FROM` count passes with `grep -F`, see Issues Encountered).
- Task 2 acceptance criteria: pass (the `SANDBOX_FILES` count passes with `grep -F`).
- Task 3 acceptance criteria: pass.

## Known Gaps (Mac run, plan 09)

Not provable here, no Docker: that a bare `docker build` stops and names the missing pin; that BuildKit accepts the `# check=skip=InvalidDefaultArgInFrom` directive without a `# syntax=` line and treats unconsumed build args as a warning; that `COPY --chmod=644 versions.env /etc/sbx/versions.env` gives a root-owned mode 644 file equal to `versions.env`; that a real pin bump reaches the sandbox with login and history intact.

## Known Stubs

None.

## Threat Flags

None. `build.sh` sourcing `versions.env` is the surface the plan's threat model already lists (T-02-01); T-02-02 to T-02-04 are mitigated by the guard and the RUN guards, and no new package is installed (T-02-SC).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02 can add new pins by one `versions.env` line plus one `ARG NAME` above the installing `RUN`; `build.sh`, the guard's adjacency check and the fake docker already handle them.
- The digest for `UBUNTU_IMAGE` and the new tool pins wait for the human approval in plan 02.
- Before the code PR, the three code commits need to move onto a branch cut from an updated `main`.

## Self-Check: PASSED

- FOUND: versions.env, build.sh, tests/selftest/host/build-wiring.sh, base/Dockerfile, claude/Dockerfile, tests/guard/supply-chain.sh, tests/host/lib-docker.sh
- FOUND commits: 37e2442, 8b051bb, 972e885
- build.sh is recorded as mode 100755

---
*Phase: 02-pinned-toolchain-gsd-and-ccusage*
*Completed: 2026-10-08*
