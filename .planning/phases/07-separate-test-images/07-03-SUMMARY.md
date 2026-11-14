---
phase: 07-separate-test-images
plan: 03
subsystem: testing
tags: [docs, host-test, image-tag, mac-gate]

requires:
  - phase: 07-separate-test-images
    provides: SBX_IMAGE_TAG in build.sh, Compose and the sbx scripts (plan 01); host-test on the test tag and the guard rule (plan 02)
provides:
  - README, tests README and host checklist describe SBX_IMAGE_TAG, the test images and what clean.sh removes
  - green dev-sandbox gate recorded (19 guard rules, 143 sbx cases, 58 entrypoint cases)
  - Mac gate passed: host-test.log shows 26 passed on the test images, :local images untouched
affects: [phase 8]

actuals:
  tokens: 2500
  tasks: 3
  commits: 1

plan_head_before: 5e22598016a4a6a026d4073558da5ca73ae2c741
plan_head_after: 32c6c62a02db266bda7055a688c1f16154d96767

tech-stack:
  added: []
  patterns:
    - "docs name the test images and the default tag in the same places the code reads them"

key-files:
  created: []
  modified:
    - README.md
    - tests/README.md
    - tests/host-checklist.md
    - clean.sh
    - tests/host/lib-docker.sh

key-decisions:
  - "clean.sh keeps its code: docker image prune -a -f already removes unused :test and :local images, so only its comment and the docs changed"
  - "The :local image IDs are compared by hand on the Mac, never by a step in the suite"

requirements-completed: [IMG-01, IMG-02]

coverage:
  - id: D1
    description: "README, tests README and host checklist document SBX_IMAGE_TAG, the host-test images, the raw compose tag, the 19 guard rules and what clean.sh removes under both tags"
    requirement: "IMG-01"
    verification:
      - kind: other
        ref: "task 1 verify blocks (grep of each specified sentence, guard 19 PASS, ASCII, no planning ID, no dash punctuation)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every dev-sandbox suite passes and the change set is exactly the 25 planned files"
    requirement: "IMG-02"
    verification:
      - kind: other
        ref: "bash tests/guard/run-all.sh (19 PASS); bash tests/selftest/sbx/run-all.sh (143 PASS, also with SBX_IMAGE_TAG=test and SBX_CA_CERT exported); bash tests/selftest/entrypoint/run-all.sh (58 PASS); task 2 layout and sweep commands"
        status: pass
    human_judgment: false
  - id: D3
    description: "On the Mac, ./host-test.sh builds and checks the test images and passes"
    requirement: "IMG-01"
    verification:
      - kind: manual_procedural
        ref: "host-test.log: images line names the three test images; Summary: 26 passed, 0 failed, 0 not run; ends 0 step(s) failed.; PASS: H-03 names sbx-claude:test; PASS: host_tests_never_name_the_local_tag (Mac shell and sandbox)"
        status: pass
    human_judgment: false
  - id: D4
    description: "A test run leaves the :local images and the sandbox list unchanged, and the default tag stays local"
    requirement: "IMG-02"
    verification:
      - kind: manual_procedural
        ref: "image-gate.log: both sbx-list outputs identical; docker image ls shows the :local images created 3 hours ago next to :test images created 5 to 6 minutes ago; both bogus refusals print 'must be local or test'; compose-gate.log renders image: sbx-claude:local with the tag unset"
        status: pass
    human_judgment: true
    rationale: "The before and after docker image inspect IDs were not captured (see Issues Encountered); the unchanged :local images rest on the image ages and the identical sbx-list outputs, which a person accepted at the gate"

duration: 25min
completed: 2026-11-14
status: complete
---

# Phase 7 Plan 03: Docs and Mac gate Summary

**The docs now say that SBX_IMAGE_TAG picks the image tag and that ./host-test.sh builds its own sbx-*:test images, and on the Mac a full run passed (26 passed, 0 failed) beside :local images that were not rebuilt.**

## Performance

- **Duration:** about 25 min, including the wait at the Mac gate
- **Started:** 2026-11-14T05:00:00Z
- **Completed:** 2026-11-14T05:07:00Z
- **Tasks:** 3 (task 3 is the Mac checkpoint)
- **Files modified:** 5

## Accomplishments

- `README.md`: a `SBX_IMAGE_TAG` bullet in "Build the images", a sentence that `./host-test.sh` never replaces the `:local` images and that the test images stay between runs, the `:local` default in the raw compose note, and `clean.sh` removing unused images under both tags.
- `tests/README.md` and `tests/host-checklist.md`: the run on the test images, 19 guard rules (the tag hand-offs and `host_tests_never_name_the_local_tag`), the new self-test coverage, and the H-03, H-25, H-30 and H-33 rows.
- `clean.sh` and `tests/host/lib-docker.sh`: comments only; the prune line is unchanged.

## Task Commits

1. **Task 1: Docs and comments for the image tag and the test images** - `32c6c62` (docs)
2. **Task 2: Dev-sandbox gate** - no commit (read-only)
3. **Task 3: Mac gate** - no commit (checkpoint, approved)

## Dev-sandbox gate (task 2)

| Check | Result |
|---|---|
| `bash tests/guard/run-all.sh` | `All rules hold.`, 19 PASS, both named rules present |
| `bash tests/selftest/sbx/run-all.sh` | `All cases pass.`, 143 PASS |
| same with `SBX_IMAGE_TAG=test SBX_CA_CERT=/nonexistent/ca.pem` | `All cases pass.`, 143 PASS |
| `bash tests/selftest/entrypoint/run-all.sh` | `All cases pass.`, 58 PASS |
| changed code files vs `main` | exactly the 25 planned files |
| host checks | 26 |
| versions.env, Dockerfiles, sbx-add, sbx-upgrade, entry.sh, supply-chain.sh | unchanged |
| mode changes; `image-tag.sh` mode | none; 100644 |
| `:local` names in bin, build.sh, compose.yml, host-test.sh, tests/host | none |
| image removal in the test harness | none |
| mixed `.planning/` and code commits | none |
| ASCII, planning-ID and dash sweeps | empty |

## Mac gate (task 3)

Read from `host-test.log` and `../image-gate.log` (and `../compose-gate.log`) after the user ran the steps.

- `host-test.log`: `images: sbx-base:test, sbx-claude:test and sbx-cursor:test`; `Summary: 26 passed, 0 failed, 0 not run`; ends `0 step(s) failed.`; the H-03 PASS line says Compose renders `sbx-claude:test`; `PASS: host_tests_never_name_the_local_tag` appears twice (Mac shell and sandbox).
- `image-gate.log`: the two `sbx-list` outputs are identical; `docker image ls` lists `sbx-base`, `sbx-claude` and `sbx-cursor` with `:local` created 3 hours ago and `:test` created 5 to 6 minutes ago; `build.sh` and `sbx-list` both refuse `bogus` with `SBX_IMAGE_TAG must be local or test, not 'bogus'`; the `clean.sh` dry run lists rows of both tags.
- `compose-gate.log` (a re-run without the grep): `image: sbx-claude:local` with the tag unset.

## Deviations from Plan

None - plan executed exactly as written for the code and docs. The Mac gate evidence has two gaps, below.

## Issues Encountered

Two gate captures did not land, so the evidence is weaker than the plan asked for:

1. **No `docker image inspect` lines in `image-gate.log`** (steps 2 and 4). The `:local` image IDs were therefore not compared before and after. The unchanged `:local` images rest on `docker image ls` (the `:local` images were created 3 hours ago, before the run; the `:test` ones 5 to 6 minutes ago) and on the identical `sbx-list` marks. This shows the run did not rebuild or retag them; it is not an ID-by-ID comparison.
2. **The two Compose `config | grep 'image:'` lines were empty in `image-gate.log`** (step 5). A re-run without the grep (`compose-gate.log`) shows `image: sbx-claude:local` for the unset tag. The `SBX_IMAGE_TAG=test` render was not captured at the gate; the H-03 PASS line in `host-test.log` covers it.

Neither gap hides a failure: no check reported a problem. The deliverable D4 above carries `human_judgment: true` for this reason.

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. The register's mitigations held: the gate ran none of `./clean.sh --yes`, `./build.sh` with the tag unset or `sbx-upgrade` (T-07-10), and `host-test.log` and `image-gate.log` stay out of git (T-07-11).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 7 has all three plans done. Remaining by hand: the code commits (`aa30879`, `4a0ead9`, `e5cb2ec`, `62afd87`, `d371831`, `32c6c62`) go onto a `feat/` branch cut from the updated `main` and a PR against `main`, pushed only with the user's go.

## Self-Check: PASSED

`README.md`, `tests/README.md`, `tests/host-checklist.md`, `clean.sh` and `tests/host/lib-docker.sh` exist; commit `32c6c62` exists and carries the plan scope; the task 1 verify commands and the task 2 gate commands exit 0.

---
*Phase: 07-separate-test-images*
*Completed: 2026-11-14*
