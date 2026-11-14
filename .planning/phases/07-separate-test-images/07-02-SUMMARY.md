---
phase: 07-separate-test-images
plan: 02
subsystem: testing
tags: [bash, host-test, image-tag, guard, shellcheck]

requires:
  - phase: 07-separate-test-images
    provides: SBX_IMAGE_TAG read by the sbx-* scripts, Compose and build.sh (plan 01)
provides:
  - host-test.sh and host_init pin SBX_IMAGE_TAG=test unconditionally and export it
  - BASE_IMAGE and CLAUDE_IMAGE globals (sbx-base:test, sbx-claude:test) used by every host check
  - H-03 assertion that Compose renders the Claude test image
  - guard rule host_tests_never_name_the_local_tag (19 rules)
affects: [07-03 Mac gate]

actuals:
  tokens: 4900
  tasks: 3
  commits: 3

plan_head_before: 775ad4b1a203d6d530fa4dcaa2cdfa610347205d
plan_head_after: d3718313a330001b7c5cd3284b6df132621a7be2

tech-stack:
  added: []
  patterns:
    - "tag assigned plainly (never a default-value expansion) and exported in both the entry script and the shared init, so a caller's value cannot steer the run"
    - "image names held in uppercase globals set by host_init, not exported, so shellcheck sees them as assigned"

key-files:
  created: []
  modified:
    - host-test.sh
    - tests/host/lib.sh
    - tests/host/run-all.sh
    - tests/host/h01-native-arch.sh
    - tests/host/h03-variable-interpolation.sh
    - tests/host/h12-plain-run-refused-pin-installed.sh
    - tests/host/h17-start-offline-and-failing-hook.sh
    - tests/host/h22-toolchain-in-base.sh
    - tests/host/h25-images-match-versions.sh
    - tests/host/h27-bundle-clone-and-publish.sh
    - tests/host/h29-sbx-upgrade.sh
    - tests/host/h30-version-line.sh
    - tests/host/h33-sbx-rm.sh
    - tests/guard/isolation.sh

key-decisions:
  - "The tag is assigned as SBX_IMAGE_TAG=\"test\" (quoted) because shellcheck SC2209 warns on the bare word test, which would fail the guard's shellcheck rule"
  - "BASE_IMAGE and CLAUDE_IMAGE are uppercase and unexported; build.sh never sees them"
  - "H-25's bare Claude build passes the test base as BASE_IMAGE so it neither uses a local image nor falls back to a registry"
  - "No before/after comparison of the local image IDs is added; that look belongs to the Mac gate"

requirements-completed: [IMG-01, IMG-02]

coverage:
  - id: D1
    description: "./host-test.sh and host_init set and export SBX_IMAGE_TAG=test even when the caller exports another value"
    requirement: "IMG-02"
    verification:
      - kind: other
        ref: "SBX_IMAGE_TAG=local bash -c '. tests/host/lib.sh && host_init && env' prints sbx-base:test, sbx-claude:test and SBX_IMAGE_TAG=test"
        status: pass
    human_judgment: false
  - id: D2
    description: "The linter stand-ins hold the literal test base image; the context step names the three test images; H-03 checks the Compose image line"
    requirement: "IMG-01"
    verification:
      - kind: other
        ref: "make_linter_standin probe with the tag unset in the caller; grep checks on host-test.sh and h03"
        status: pass
    human_judgment: false
  - id: D3
    description: "No host test file names a local tag, and the guard fails any that does"
    requirement: "IMG-02"
    verification:
      - kind: other
        ref: "bash tests/guard/run-all.sh#host_tests_never_name_the_local_tag"
        status: pass
      - kind: other
        ref: "scratch copy with a local tag added to host-test.sh and h01 makes the rule print FAIL naming both files"
        status: pass
    human_judgment: false
  - id: D4
    description: "A real ./host-test.sh run builds, checks and leaves side by side the test images and the local images"
    requirement: "IMG-01"
    verification: []
    human_judgment: true
    rationale: "Docker is not available in the dev sandbox; the run is proven on the Mac in the Mac gate plan"

duration: 4min
completed: 2026-11-14
status: complete
---

# Phase 7 Plan 02: Test run on the test tag Summary

**./host-test.sh and host_init now pin SBX_IMAGE_TAG=test, every host check, stand-in and Compose assertion reads the test images, and a new guard rule keeps every local tag out of the host test files.**

## Performance

- **Duration:** about 4 min
- **Started:** 2026-11-14T04:50:49Z
- **Completed:** 2026-11-14T04:55:00Z
- **Tasks:** 3
- **Files modified:** 14

## Accomplishments

- `host-test.sh` assigns and exports the tag right after `cd`, before the `main | tee` pipeline. The context step logs `images: sbx-base:test, sbx-claude:test and sbx-cursor:test`. `linter_versions` and `make_linter_standin` use the test base; the stand-in gets the tag written into the file when it is made, so it does not depend on the variable at run time.
- `host_init` sets and exports the tag too, and sets `BASE_IMAGE` and `CLAUDE_IMAGE`. `run-all.sh` says `building the test images`. A caller that exports `local` still gets `test` (probe passes).
- H-03 gained `check_image_follows_the_tag`: the rendered Compose config must hold `image: sbx-claude:test`.
- H-01, H-12, H-17, H-22, H-25, H-27, H-29, H-30 and H-33 read their images from the two globals. H-25's bare Claude build gets `--build-arg "BASE_IMAGE=$BASE_IMAGE"`; the bare base build is unchanged. H-33 now proves `sbx-rm` keeps the test images.
- Guard rule `host_tests_never_name_the_local_tag` scans `host-test.sh` and `tests/host/*.sh` (comments included); the guard holds 19 rules.

## Task Commits

1. **Task 1: tag pinned in host-test.sh and host_init, images line, H-03 (tracer)** - `e5cb2ec` (feat)
2. **Task 2: H-01, H-12, H-17, H-22, H-25 on the test images** - `62afd87` (test)
3. **Task 3: H-27, H-29, H-30, H-33 and the guard rule** - `d371831` (test)

Tracer gate: the task verify (syntax, 18 PASS guard, host_init probe with `local` exported, stand-in text, wiring greps, no local tag) re-ran end to end after the task 1 edit; all passed, so expansion continued.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Quoted the tag assignment to satisfy shellcheck**
- **Found during:** Task 1
- **Issue:** `SBX_IMAGE_TAG=test` triggers shellcheck SC2209 (the word `test` looks like a command), so the guard rule `shellcheck_passes` failed on `host-test.sh` and `tests/host/lib.sh`.
- **Fix:** Assign `SBX_IMAGE_TAG="test"` in both places. The behavior is identical, the assignment is still plain and unconditional. The plan's literal greps for `SBX_IMAGE_TAG=test` were adapted to the quoted form.
- **Files modified:** `host-test.sh`, `tests/host/lib.sh`
- **Commit:** `e5cb2ec`

**2. [Style] Shortened banner titles to stay near 80 columns**
- Task 1 and task 3 header and banner lines were reworded slightly ("writes DIR/TOOL that runs TOOL in the test base"; the isolation header line). No behavior change.

**Total deviations:** 1 auto-fixed (1 blocking), 1 style note.
**Impact:** none on behavior or the plan's goals.

Notes on the plan's own checks: the acceptance line `grep -c 'docker build --progress=plain -f "$REPO_DIR/base/Dockerfile"'` printed 0 in this tool shell (the `grep` here is not the stock one); the same check with `grep -cF` prints 1.

## Issues Encountered

None.

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. The register's mitigations are in place: the tag is assigned plainly in `host-test.sh` and `host_init` (T-07-05), the guard rule and the scratch-copy negative test cover T-07-06, H-25 passes the test base (T-07-07), and the log names the test images (T-07-08).

## Verification Results

- `bash tests/guard/run-all.sh`: All rules hold, 19 PASS lines including `host_tests_never_name_the_local_tag`.
- `bash tests/selftest/sbx/run-all.sh`: All cases pass, including `registry: a claude entry maps to sbx-claude:local`; `tests/selftest/sbx/entry.sh` is unchanged against `main`.
- `grep -nE ':local\b' host-test.sh tests/host/*.sh` prints nothing; 26 host checks remain; no `env -i` in the host libraries.
- Not run here: a real `./host-test.sh` run (no Docker in the dev sandbox); proven on the Mac in the Mac gate plan.

## Next Phase Readiness

Ready for the Mac gate plan: `./host-test.sh` on the Mac should build and check the `:test` images alongside the `:local` ones and leave the `:local` images untouched.

## Self-Check: PASSED

All 14 modified files exist; commits `e5cb2ec`, `62afd87` and `d371831` exist and carry the plan scope.
