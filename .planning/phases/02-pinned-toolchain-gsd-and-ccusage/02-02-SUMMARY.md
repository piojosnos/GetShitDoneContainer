---
phase: 02-pinned-toolchain-gsd-and-ccusage
plan: 02
subsystem: supply-chain
tags: [pins, digests, npm-provenance, package-legitimacy, approval-gate]

requires:
  - phase: 02-pinned-toolchain-gsd-and-ccusage
    provides: versions.env and build.sh, so a new pin is one line (plan 01)
provides:
  - 02-PINS.md with ten rows, all approved 2026-10-09, plus a recorded approval
  - index digests for the Ubuntu, Temurin and uv images, read from their registries
  - the GSD pin (1.15.0) and the attended bump target (1.16.0)
affects: [02-03, 02-05, 02-06, 02-07, 02-09]

actuals:
  tokens: 4500
  tasks: 2
  commits: 0

tech-stack:
  added: []
  patterns:
    - "A pin may enter versions.env only from a 02-PINS.md row whose Status reads approved YYYY-MM-DD"

key-files:
  created:
    - .planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-PINS.md
  modified: []

key-decisions:
  - "GSD_CORE_VERSION stays 1.15.0 (12 days old); GSD_BUMP_TARGET stays 1.16.0, used only by the attended bump test and never written into versions.env"
  - "UV_IMAGE stays 0.12.21 with digest sha256:a7aed3216253ee804de3e2d8afa5073baa1a177335345d43845cd4165e43b711; 0.12.23 was not chosen"
  - "Claude Code stays at 2.1.285 although newer releases exist, because it was approved in Phase 1 and carried"

requirements-completed: []

coverage:
  - id: D1
    description: "02-PINS.md holds one row per pin plus GSD_BUMP_TARGET, each with value, publish date, provenance or checksum source and lookup method"
    requirement: IMG-03
    verification:
      - kind: other
        ref: "Task 1 automated verify: ten rows present, three image rows carry a 64 hex digest, npm view resolves the four pinned npm versions"
        status: pass
    human_judgment: false
  - id: D2
    description: "The user approved every row at a blocking-human checkpoint and the approval is recorded with its date"
    requirement: TOOL-01
    verification:
      - kind: other
        ref: "Task 2 automated verify: every row's Status matches approved YYYY-MM-DD"
        status: pass
    human_judgment: true
    rationale: "Package legitimacy is a human judgment; the user's answer is quoted in this SUMMARY and in 02-PINS.md."

duration: not recorded (the tracer ran before the checkpoint; the approval pass took a few minutes)
completed: 2026-10-09
status: complete
commits: 0
plan_head_before: ddbfb0f03e5032ae4e79a9b754b661077b86545e
plan_head_after: ddbfb0f03e5032ae4e79a9b754b661077b86545e
---

# Phase 2 Plan 02: Pin table resolved and approved Summary

**Every Phase 2 pin (three images by index digest, three tarballs, four npm packages, and the GSD bump target) was resolved from its authority and approved by the user on 2026-10-09; plans 03, 05, 07 and 09 may now copy values from 02-PINS.md.**

## Performance

- **Duration:** not recorded; Task 1 ran in the earlier session, the approval pass in this one
- **Completed:** 2026-10-09
- **Tasks:** 2 (1 tracer, 1 blocking-human checkpoint)
- **Files modified:** 1 (created, in the phase folder only)

## The user's answer

At the blocking-human checkpoint the user replied:

> "approved"

That means every row is approved with no swaps: `GSD_CORE_VERSION` 1.15.0, `GSD_BUMP_TARGET` 1.16.0, `UV_IMAGE` 0.12.21 with its digest. The approval, its date and these choices are recorded in the "Approval record" section of 02-PINS.md.

## Accomplishments

- Task 1 resolved all ten rows from their authorities: Docker Hub and ghcr.io for the image index digests (each index lists arm64 and amd64), upstream checksum files for Node, gh and Maven, `npm view` for publish time, provenance, repository and install scripts of the npm packages. Every research value was unchanged.
- The package-legitimacy check was run twice. By `name@version` it answers SLOP for everything because it reads the whole string as a name; by name, no package got SLOP, and the only SUS reason is `too-new` (plus `no-repository` for Claude Code, already approved in Phase 1).
- Task 2 set all ten Status cells to `approved 2026-10-09` and added the approval record. The automated verify passes for all ten rows, and no row reads `proposed`.

## Task Commits

No code commit exists for either task. Task 1 left 02-PINS.md uncommitted by design; this plan's files (02-PINS.md, this SUMMARY, STATE.md, ROADMAP.md) go into one planning-only `docs(02-02)` commit.

## Files Created/Modified

- `.planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-PINS.md`: the approved pin table, the legitimacy check output, notes for the reviewer, and the approval record

## Decisions Made

- GSD pin 1.15.0 with bump target 1.16.0, as proposed.
- uv 0.12.21, as proposed.
- Checksum files that share an origin with their tarballs stay as decided; per-architecture hashes in `versions.env` remain an additive option for later.

## Deviations from Plan

### Orchestrator-directed changes

**1. [Branching] No `feat/phase-02-pinned-toolchain` branch; work stays on `chore/planning-phase-02-plan`**
- The plan says to stay on the feature branch and leave its files uncommitted. The dispatch said to stay on the current planning branch and commit 02-PINS.md, the SUMMARY, STATE.md and ROADMAP.md together in one planning-only commit. Followed the dispatch.

None otherwise; the plan executed as written.

## Issues Encountered

None.

## Known Stubs

None.

## Threat Flags

None. The plan installs nothing and adds no endpoint or file access; it is the mitigation for T-02-05, T-02-06, T-02-07 and T-02-SC.

## Requirements

`IMG-03`, `TOOL-01`, `TOOL-02` and `USE-01` are declared by this plan, but each is also declared by later plans of the phase that have no SUMMARY yet (03, 05, 06, 07, 08, 09). None is marked complete here.

## Next Phase Readiness

- Plans 03, 05 and 07 copy each new value from the approved rows of 02-PINS.md into `versions.env`. `GSD_BUMP_TARGET` is never copied; plan 06 uses it for the attended bump test.
- Nothing blocks plan 03.

## Self-Check: PASSED

- FOUND: .planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-PINS.md with ten `approved 2026-10-09` rows and no `proposed` row
- No code commits were made by this plan, so none are claimed (`commits: 0`, HEAD unchanged at ddbfb0f)

---
*Phase: 02-pinned-toolchain-gsd-and-ccusage*
*Completed: 2026-10-09*
