---
phase: 07-separate-test-images
plan: 01
subsystem: infra
tags: [bash, docker-compose, image-tag, selftest, guard]

requires:
  - phase: 06-cursor-agent-image
    provides: sbx-cursor image, agent-picked compose image line, sbx self-test groups
provides:
  - SBX_IMAGE_TAG read by bin/sbx-lib.sh, compose.yml and build.sh (local default, test accepted, anything else refused)
  - build.sh builds sbx-base, sbx-claude and sbx-cursor under one tag, each agent on the base of its own tag
  - guard rule compose_image_follows_agent_and_tag
  - dockerless self-test group tests/selftest/sbx/image-tag.sh
affects: [07-02 test run on the test tag, 07-03 Mac gate]

actuals:
  tokens: 3100
  tasks: 2
  commits: 2

plan_head_before: a98591f1feb3ebf9fc2d93a88745d84477003c13
plan_head_after: 4a0ead90659ff961df82c56ea591beb15536a614

tech-stack:
  added: []
  patterns:
    - "one allow-list helper (check_image_tag) with a twin in the standalone build.sh, same list name, global and wording"
    - "dockerless build.sh self-test: run it with a PATH that links only dirname and grep"

key-files:
  created:
    - tests/selftest/sbx/image-tag.sh
  modified:
    - bin/sbx-lib.sh
    - build.sh
    - compose.yml
    - tests/guard/start.sh
    - tests/selftest/sbx/lib.sh

key-decisions:
  - "The tag check lives twice (bin/sbx-lib.sh and build.sh) instead of build.sh sourcing the library; build.sh stays standalone and one self-test text covers both"
  - "build_image renames its local imageTag to imageName so it does not shadow the new global imageTag"
  - "BASE_IMAGE stays out of versions.env and both agent Dockerfiles stay byte-exact; build.sh passes it as a build option"
  - "start_group unsets SBX_IMAGE_TAG and SBX_CA_CERT so ./host-test.sh can export both without moving the default-case expectations"

requirements-completed: [IMG-01, IMG-02]

coverage:
  - id: D1
    description: "SBX_IMAGE_TAG=test names sbx-base:test, sbx-claude:test and sbx-cursor:test in the sbx-* scripts, Compose and build.sh; unset or empty keeps the :local images"
    requirement: "IMG-02"
    verification:
      - kind: unit
        ref: "bash tests/selftest/sbx/image-tag.sh#case_tag_picks_the_image, case_build_tag"
        status: pass
      - kind: unit
        ref: "bash tests/selftest/sbx/run-all.sh#registry: a cursor entry maps to sbx-cursor:local"
        status: pass
    human_judgment: false
  - id: D2
    description: "Any other tag value is refused by every sbx-* script inside sbx_init and by build.sh before the first build"
    requirement: "IMG-01"
    verification:
      - kind: unit
        ref: "bash tests/selftest/sbx/image-tag.sh#case_tag_refusals, case_build_tag"
        status: pass
    human_judgment: false
  - id: D3
    description: "The guard checks the compose image line, both hand-offs and the base of each agent build"
    requirement: "IMG-01"
    verification:
      - kind: other
        ref: "bash tests/guard/run-all.sh#compose_image_follows_agent_and_tag"
        status: pass
    human_judgment: false
  - id: D4
    description: "Real docker builds of the three test images and the Compose rendering with the test tag"
    requirement: "IMG-01"
    verification: []
    human_judgment: true
    rationale: "Docker is not available in the dev sandbox; the builds are proven on the Mac in the Mac gate plan"

duration: 25min
completed: 2026-11-14
status: complete
---

# Phase 7 Plan 01: SBX_IMAGE_TAG tracer Summary

**One variable, SBX_IMAGE_TAG (local by default, test accepted, anything else refused), now names the images in bin/sbx-lib.sh, compose.yml and build.sh, with a guard rule and a dockerless self-test group pinning it down.**

## Performance

- **Duration:** about 25 min
- **Started:** not recorded
- **Completed:** 2026-11-14T04:50:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- `check_image_tag` (a twin in `bin/sbx-lib.sh` and `build.sh`) sets `imageTag` from `SBX_IMAGE_TAG`, accepts `local` and `test` only, and treats unset and empty as `local`. In `bin/` it runs inside `sbx_init`, so every `sbx-*` script refuses a bad value before it registers, creates or calls Docker. In `build.sh` it runs right after `cd`, before any output.
- `agentImage` and the `run_compose` hand-off follow the tag; `compose.yml` renders `sbx-${SBX_AGENT:-claude}:${SBX_IMAGE_TAG:-local}`. `run_compose` passes only the value the check accepted.
- `build.sh` builds `sbx-base:<tag>` first, then `sbx-claude:<tag>` and `sbx-cursor:<tag>`, each with `--build-arg BASE_IMAGE=sbx-base:<tag>`. Both agent Dockerfiles, `base/Dockerfile` and `versions.env` are untouched.
- Guard rule renamed to `compose_image_follows_agent_and_tag` and extended to the tag hand-off and the base of each agent build; the suite still holds 18 rules.
- New group `tests/selftest/sbx/image-tag.sh` adds 15 cases (143 PASS lines in all, 128 before): image names, empty means local, refusals by `sbx-add`, `sbx-list`, `sbx-fix-modes`, `sbx-rm`, `sbx-shell`, `sbx-start`, `sbx-stop` and `sbx-upgrade`, and build.sh naming and refusal run with a PATH that holds no docker.
- `start_group` unsets `SBX_IMAGE_TAG` and `SBX_CA_CERT`; the suite passes with both exported, as `./host-test.sh` will do.

## Task Commits

1. **Task 1: One tag path (tracer)** - `aa30879` (feat)
2. **Task 2: Dockerless self-test of the tag** - `4a0ead9` (test)

**Plan metadata:** the commit that adds this file (docs).

Tracer gate: verify re-run end to end after Task 1 (guard 18 PASS, library probes, dockerless build probes, order and wiring checks, mutation check of the guard, existing sbx self-test); all passed, so expansion continued.

## Files Created/Modified

- `bin/sbx-lib.sh` - `knownImageTagList`, `check_image_tag`, call in `sbx_init`, `agentImage` with the tag, `SBX_IMAGE_TAG` on the compose command
- `build.sh` - `knownImageTagList`, `check_image_tag`, three tags from `imageTag`, `BASE_IMAGE` on both agent builds, `build_image` local renamed to `imageName`
- `compose.yml` - image line follows the agent and the tag
- `tests/guard/start.sh` - renamed and extended compose rule
- `tests/selftest/sbx/image-tag.sh` - new dockerless group
- `tests/selftest/sbx/lib.sh` - `start_group` unsets the tag and the certificate

## Decisions Made

- Twin check in `build.sh` rather than sourcing the library (two copies are within the extract-at-three rule).
- `BASE_IMAGE` passed as a build option so `versions.env` and the Dockerfile ARG line stay as the supply-chain guard expects.
- Self-test cases set and clear the variable with `export` and `unset` (inside a command substitution where a value must not leak), never a prefix assignment before a shell function, for bash 3.2.

## Deviations from Plan

None in the code; the plan was executed as written.

Notes on the plan's own checks:

- The acceptance line `grep -c '^case_' tests/selftest/sbx/image-tag.sh` prints 3 counts the three case functions, but the Main block also calls each case at column 0 (the shape every group uses), so the literal command prints 6. `grep -c '^case_.*() {'` prints 3. No code change.
- Commit messages carry no co-author line, following the project and user rule against AI attribution.

**Total deviations:** 0 auto-fixed.
**Impact:** none.

## Issues Encountered

None.

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. The only new input is `SBX_IMAGE_TAG`, already covered by the plan's threat register (allow-list, checked before Compose or build, `pull_policy: never` kept).

## Verification Results

- `bash tests/guard/run-all.sh`: All rules hold, 18 PASS lines including `compose_image_follows_agent_and_tag`.
- `bash tests/selftest/sbx/run-all.sh`: All cases pass, 143 PASS lines; also passes with `SBX_IMAGE_TAG=test SBX_CA_CERT=/nonexistent/ca.pem` exported.
- `bash tests/selftest/entrypoint/run-all.sh`: All cases pass.
- Mutation checks: a scratch copy whose agent builds lost `BASE_IMAGE` makes the guard rule print FAIL; a scratch copy whose allow-lists accept `latest` makes the refusal cases print FAIL.
- Not run here: real `docker build` and Compose rendering (no Docker in the dev sandbox); proven on the Mac in the Mac gate plan.

## Next Phase Readiness

Ready for the next plan: the test run can set `SBX_IMAGE_TAG=test` and the real scripts, Compose and `build.sh` will stay off the `:local` images.

## Self-Check: PASSED

All six files exist; commits `aa30879` and `4a0ead9` exist; two commits carry the plan scope.
