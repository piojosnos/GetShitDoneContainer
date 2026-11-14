---
phase: 07-separate-test-images
verified: 2026-11-14T06:00:00Z
status: passed
score: 3/3 must-haves verified
covered_files:
  - .planning/phases/07-separate-test-images/07-01-PLAN.md
  - .planning/phases/07-separate-test-images/07-01-SUMMARY.md
  - .planning/phases/07-separate-test-images/07-02-PLAN.md
  - .planning/phases/07-separate-test-images/07-02-SUMMARY.md
  - .planning/phases/07-separate-test-images/07-03-PLAN.md
  - .planning/phases/07-separate-test-images/07-03-SUMMARY.md
  - README.md
  - bin/sbx-lib.sh
  - build.sh
  - clean.sh
  - compose.yml
  - host-test.sh
  - tests/guard/isolation.sh
  - tests/guard/start.sh
  - tests/host/lib.sh
  - tests/selftest/sbx/image-tag.sh
  - tests/selftest/sbx/lib.sh
covered_digest: "v2:sha256:ecabeae7eff4ba9e75591e649434243cb96253f7898c510d374bc9019dd97391"
behavior_unverified: 0
overrides_applied: 0
re_verification: false
advisory:
  - finding: "SC2 rests on image ages, not on a literal before/after ID pair"
    category: other
    reason: "image-gate.log holds one unlabeled set of image IDs, not a before and an after; the ages and the code audit make a replaced :local image implausible"
    evidence_status: "indirect, accepted at the Mac checkpoint"
  - finding: "WR-02 from 07-REVIEW.md: a leaked SBX_IMAGE_TAG=test in the user's shell moves a real sandbox onto the test images with no message"
    category: other
    reason: "By design (the allow-list accepts test); only the README warns. Not part of any success criterion."
    evidence_status: "code read, bin/sbx-lib.sh check_image_tag"
  - finding: "WR-01 from 07-REVIEW.md: tests/host/h25-images-match-versions.sh:35 still says 'rebuild with ./build.sh', which builds :local"
    category: other
    reason: "Misleading remedy text only; the check itself uses $CLAUDE_IMAGE"
    evidence_status: "line 35 read"
---

# Phase 7: Separate Test Images Verification Report

**Phase Goal:** A test run builds and checks its own images, so it never replaces the `sbx-base:local` and `sbx-claude:local` images the user's sandboxes run.
**Verified:** 2026-11-14
**Status:** passed
**Re-verification:** No, initial verification

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP success criterion) | Status | Evidence |
|---|-----------------------------------|--------|----------|
| 1 | `./host-test.sh` builds its own test tags and runs every host check against them; the log names the test tags; no host check names a `:local` tag | VERIFIED | `host-test.sh:254-255` assigns `SBX_IMAGE_TAG="test"` unconditionally and exports it; `tests/host/lib.sh:30-33` does the same and sets `BASE_IMAGE`/`CLAUDE_IMAGE` to the `:test` refs. `grep -rn ':local' host-test.sh tests/host/` returns nothing (rc 1). Mac `host-test.log` line 5: `images: sbx-base:test, sbx-claude:test and sbx-cursor:test`; H-03 "Compose renders sbx-claude:test"; `Summary: 26 passed, 0 failed, 0 not run`; `0 step(s) failed.`. The log's only `:local` lines (89, 90, 139, 140) are dockerless sbx self-test case names, not host checks. |
| 2 | On the Mac, the IDs of `sbx-base:local` and `sbx-claude:local` are the same before and after a full `./host-test.sh` run | VERIFIED (inferential, see note) | Structural: `build.sh` builds only `sbx-*:$imageTag` and passes `BASE_IMAGE=sbx-base:$imageTag`; every host `docker` call uses `$BASE_IMAGE`/`$CLAUDE_IMAGE`/`sbx-base:$SBX_IMAGE_TAG`; the guard rule `host_tests_never_name_the_local_tag` passes in the Mac log and here; the Mac self-test runs with no docker on PATH. Empirical: the run started 20:58 PST (04:58 UTC) and ended about 05:01; `docker image ls` at about 05:05 shows all three `:local` images created "3 hours ago" and the `:test` images "5-6 minutes ago". A rebuild or re-tag of a `:local` ref during the run would show a creation time inside the run window (or, on a full cache hit, keep the same ID); neither changes the ID. `sbx-list` output is identical before and after. |
| 3 | `build.sh`, `sbx-upgrade` and the user's sandboxes still build and run the `:local` tags; only a test run uses the test tags | VERIFIED | `check_image_tag` in `bin/sbx-lib.sh:62-76` and `build.sh:23-35`: `imageTag=${SBX_IMAGE_TAG:-local}`, unset and empty mean local, only `local test` accepted. `agentImage=sbx-$entryAgent:$imageTag` (sbx-lib.sh:200); `run_compose` hands the checked `$imageTag` to Compose (line 232); `compose.yml:15` is `sbx-${SBX_AGENT:-claude}:${SBX_IMAGE_TAG:-local}`. `ARG BASE_IMAGE=sbx-base:local` unchanged in both agent Dockerfiles; `versions.env` and all Dockerfiles untouched since the plan start. `compose-gate.log` renders `image: sbx-claude:local` with the tag unset; `image-gate.log` shows `build.sh` and `sbx-list` both refuse `bogus` naming `local or test`. Self-test (dockerless) covers unset, empty, test, refusal by every sbx-* script and by build.sh. |

**Score:** 3/3 truths verified (0 present, behavior-unverified)

Note on SC2: the literal pair "ID before, ID after" is not on disk. `image-gate.log` carries one unlabeled set of `docker image inspect` IDs (`sbx-base:local aa738f6795d2`, `sbx-claude:local 5cc1c6aca6f3`, `sbx-cursor:local c6eb0aba9919`), and the Summary and checkpoint already admit the missing second snapshot. I judge the criterion met anyway because the ages are close to conclusive: any build or re-tag that put a different image under a `:local` name would have reset its creation time to the run window, and the code and guard audit shows no path that could try. A reader who wants the literal proof can run `docker image inspect --format '{{.Id}}' sbx-base:local sbx-claude:local` before and after one more `./host-test.sh`, and compare with the IDs above; this is optional, not a gate.

### PLAN must-haves (merged; not reduced)

| Item | Status | Evidence |
|------|--------|----------|
| One variable `SBX_IMAGE_TAG`; allow-list local/test; error text `SBX_IMAGE_TAG must be local or test, not '<value>'` in sbx_init and build.sh before first build | VERIFIED | Code read; `image-tag.sh` self-test; bogus refusals in `image-gate.log` |
| Build order base then claude, cursor with `BASE_IMAGE=sbx-base:<tag>` | VERIFIED | `build.sh:185-191` |
| `run_compose` hands only the checked value | VERIFIED | `bin/sbx-lib.sh:232` |
| host-test.sh and host_init pin `test`; run-all.sh builds the `$SBX_IMAGE_TAG` images | VERIFIED | `host-test.sh:254`, `tests/host/lib.sh:30`, `run-all.sh:241` |
| H-25 builds claude/Dockerfile with the test base | VERIFIED | `h25...sh:100` passes `BASE_IMAGE=$BASE_IMAGE` |
| H-33: sbx-rm keeps test images | VERIFIED | `h33-sbx-rm.sh:280-285`; PASS in Mac log (line 225) |
| Guard holds 19 rules; sbx self-test at least 143 cases, passes also with `SBX_IMAGE_TAG=test SBX_CA_CERT` exported; entrypoint self-test passes | VERIFIED | Ran here: guard 19 PASS rc 0; sbx 143 PASS 0 FAIL rc 0 (also with the test env); entrypoint rc 0 |
| Exactly the 25 planned files changed; Dockerfiles, versions.env untouched | VERIFIED | `git diff --stat a98591f..HEAD` outside `.planning`: 25 files, none of them Dockerfiles or versions.env |
| Prohibition: no automated :local ID comparison added | VERIFIED | none in host-test.sh or tests/host |
| Prohibition: no clean.sh --yes, unset build.sh or sbx-upgrade in the gate | VERIFIED (judgment) | Gate logs hold only sbx-list, image ls, refusals, compose config |
| Prohibition: unset/empty tag never changes :local behavior | VERIFIED | code read plus self-test |

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `bin/sbx-lib.sh` | VERIFIED | `check_image_tag` called from `sbx_init`, used by `agentImage` and `run_compose` |
| `build.sh` | VERIFIED | twin check, three tags from `$imageTag` |
| `compose.yml` | VERIFIED | image line with both defaults |
| `tests/guard/start.sh`, `tests/guard/isolation.sh` | VERIFIED | `compose_image_follows_agent_and_tag` and `host_tests_never_name_the_local_tag` both PASS here and on the Mac |
| `tests/selftest/sbx/image-tag.sh`, `lib.sh` | VERIFIED | runs, passes; `start_group` unsets the tag and cert |
| `host-test.sh`, `tests/host/lib.sh`, H-03 | VERIFIED | exports present; H-03 asserts the test image |
| README, tests README, host-checklist, clean.sh comment | VERIFIED | changed per diff stat; clean.sh keeps `docker image prune -a -f` |
| `host-test.log`, `../image-gate.log` | present | on disk, not committed |

### Key Link Verification

| From | To | Status |
|------|----|--------|
| bin/sbx-lib.sh -> compose.yml (`SBX_IMAGE_TAG="$imageTag"`) | WIRED |
| build.sh -> agent Dockerfiles (`--build-arg BASE_IMAGE=sbx-base:$imageTag`) | WIRED |
| bin/sbx-upgrade -> build.sh (child inherits the checked, exported tag) | WIRED |
| host-test.sh -> tests/host/run-all.sh (exported tag inherited, set again in host_init) | WIRED |
| tests/guard/isolation.sh -> tests/host/ | WIRED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Guard | `bash tests/guard/run-all.sh` | 19 PASS, All rules hold | PASS |
| sbx self-test | `bash tests/selftest/sbx/run-all.sh` | 143 PASS, 0 FAIL | PASS |
| sbx self-test, caller env | `SBX_IMAGE_TAG=test SBX_CA_CERT=/nonexistent bash tests/selftest/sbx/run-all.sh` | All cases pass | PASS |
| Entrypoint self-test | `bash tests/selftest/entrypoint/run-all.sh` | All cases pass | PASS |
| No `:local` in host tests | `grep -rn ':local' host-test.sh tests/host/` | no match | PASS |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|--------------|-------------|--------|----------|
| IMG-01 | 07-01, 07-02, 07-03 | `./host-test.sh` builds its own test image tags and runs every host check against them | SATISFIED | SC1 evidence; Mac log 26 passed on `:test` |
| IMG-02 | 07-01, 07-02, 07-03 | A test run never replaces `sbx-base:local` or `sbx-claude:local` | SATISFIED | SC2 and SC3 evidence |

Both IDs appear in all three plans' `requirements` and are marked Complete in REQUIREMENTS.md (lines 20-21, 81-82). No orphaned requirements for Phase 7.

### Anti-Patterns Found

No TBD, FIXME or XXX markers in the modified files (not scanned for stubs beyond this; the phase is shell and YAML with no rendering path). No blockers.

### Code Review Findings (advisory, from 07-REVIEW.md; all still `open` in the disposition)

- WR-01: `h25-images-match-versions.sh:35` tells the user to rebuild with `./build.sh`, which builds `:local`. Message only.
- WR-02: a leaked `SBX_IMAGE_TAG=test` silently moves a real sandbox onto test images; the only protection is a README line. Design consequence of the allow-list, outside the three success criteria.
- IN-01 to IN-04: test-coverage and drift weaknesses (the default-tag Compose render is checked by grep only; H-03 uses a substring match; the allow-list is duplicated without a drift guard; `run_build_without_docker` is brittle).

None blocks the goal. Worth triaging before the next phase touches this code.

### Human Verification Required

None. The Mac checkpoint was already approved by the user on this evidence.

### Gaps Summary

No gaps. The goal holds: a test run builds, runs and checks only `:test` images, no host test names a `:local` tag, and the `:local` images, the `build.sh` default and the sandbox path are unchanged. The one soft spot is the missing literal before/after ID pair for SC2, covered above by the image ages and the structural audit.

---

_Verified: 2026-11-14_
_Verifier: Claude (gsd-verifier)_
