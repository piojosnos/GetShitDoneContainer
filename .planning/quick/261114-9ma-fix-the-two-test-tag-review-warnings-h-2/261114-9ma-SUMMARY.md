---
phase: quick-261114-9ma
plan: 01
subsystem: host-scripts
tags: [sbx-lib, image-tag, host-test, docs]
requires: []
provides:
  - "check_image_tag names any accepted tag other than local on stderr"
  - "H-25 version-record hint points at ./host-test.sh"
affects: [bin/sbx-lib.sh, build.sh, tests/selftest/sbx/image-tag.sh, tests/host/h25-images-match-versions.sh, README.md, tests/README.md]
key-files:
  created: []
  modified:
    - bin/sbx-lib.sh
    - tests/selftest/sbx/image-tag.sh
    - tests/host/h25-images-match-versions.sh
    - build.sh
    - README.md
    - tests/README.md
decisions:
  - "Notice goes to stderr, once, inside check_image_tag; build.sh reaches it through the shared library"
  - "No marker variable; sbx-upgrade on the test tag prints two notice lines (its own and build.sh's)"
  - "Notice prints only after the allow-list matched, so it can only echo a known tag"
status: complete
commits: 2
plan_head_before: c2baa5a06ca8646127fe307387940221a5cd6c46
plan_head_after: aa45f08570b2321098890bc45ea031a2af7ead09
actuals:
  tokens: 6000
  tasks: 2
  commits: 2
---

# Phase quick-261114-9ma Plan 01: Test-tag review warnings Summary

One stderr line now names a non-local `SBX_IMAGE_TAG` in every `sbx-*` script and `build.sh`, from a single implementation in `check_image_tag`, and the H-25 version-record hint points at `./host-test.sh`.

## Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Name a non-local image tag on stderr (tracer, TDD) | 5d1eccb | bin/sbx-lib.sh, tests/selftest/sbx/image-tag.sh |
| 2 | Point H-25 hint at ./host-test.sh, document the notice | aa45f08 | tests/host/h25-images-match-versions.sh, build.sh, README.md, tests/README.md |

RED was confirmed first: only the two new notice expectations failed before the library change. The image-tag self-test now has 22 PASS lines and no FAIL.

## Planning decisions

- **Channel is stderr.** `case_build_tag` compares `build.sh` stdout exactly, and `sbx-*` stdout is what users and scripts read. Host checks run `sbx-*` through `run_sbx`, which keeps stderr in its own `.err` log and only substring-greps it, so no host check needed a change. `sbx_error` already uses stderr.
- **Neutral suites.** `start_group` unsets `SBX_IMAGE_TAG`, so `entry.sh` and `start.sh` see no notice even with the test tag exported. Only `case_tag_picks_the_image` needed a change: it now sends stderr to its own file so the exact stdout compare survives.
- **sbx-upgrade prints two notice lines** on the test tag (one from itself, one from the `build.sh` child). Each names its own program. Suppressing the second would need a marker variable, which was ruled out.
- **No echo of raw input.** The notice prints only after the tag matched `knownImageTagList`; a refused tag keeps its single error line and no notice.

## Deviations from Plan

None. The plan was executed as written.

## Verification

- `bash tests/guard/run-all.sh`: All rules hold.
- `bash tests/selftest/sbx/run-all.sh`, plain and with `SBX_IMAGE_TAG=test` exported: All cases pass.
- `bash tests/selftest/entrypoint/run-all.sh`: All cases pass.
- Notice text appears on exactly one non-comment line of `bin/sbx-lib.sh`; no non-ASCII and no review or planning IDs in the touched files.

## For the user (Mac)

Run `./host-test.sh`, then read `host-test.log`. Every step should end OK (H-25 included). A `.err` log of an `sbx-*` step (for example `h28-add.err`) should start with `sbx-add: using the test images because SBX_IMAGE_TAG=test; ...`, and the build log should hold the `build.sh` line. Then, with `SBX_IMAGE_TAG` unset in a normal shell, `sbx-list` should print no notice.

## Known Stubs

None.

## Threat Flags

None.

## Self-Check: PASSED

Commits 5d1eccb and aa45f08 exist; all six modified files present.
