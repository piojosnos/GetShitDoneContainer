---
phase: 08-in-image-self-check
plan: 02
subsystem: testing
tags: [bash, host-test, openssl, docker, selfcheck]

requires:
  - phase: 08-01
    provides: the sbx-selfcheck runner and its PASS or FAIL line format
provides:
  - H-34, the host check that runs sbx-selfcheck in a Claude and a Cursor test sandbox
  - a throwaway test root certificate, made or reused by run-all.sh and built into the test images
  - the pinned expected counts, 51 for Claude and 49 for Cursor
affects: [08-03, 08-04, 08-05, 08-06, 08-07]

actuals:
  tokens: 4200
  tasks: 2
  commits: 2
plan_head_before: 7ddd85b02ce8563d6f8d3b92c6f87de58d03ac91
plan_head_after: b0b0bfe4cf64f71be8030ea868453d71024e4487

tech-stack:
  added: []
  patterns:
    - "Expected check counts are constants in the host check, so a check that silently disappears fails the run"
    - "The root certificate is matched by its SHA-256 fingerprint, never by a certificate count, so a caller's own proxy root may sit next to it"
    - "A second sandbox started by a host check is removed before the check reports, whatever happened before"

key-files:
  created:
    - tests/host/h34-selfcheck.sh
  modified:
    - tests/host/lib-docker.sh
    - tests/host/run-all.sh

key-decisions:
  - "The certificate step lives in run-all.sh (the only user of the make step); test_root_ca_file and cert_fingerprint live in lib-docker.sh because run-all.sh and H-34 both use them"
  - "H-34 finds the certificate by its fixed path, so no variable is exported to it"
  - "The build file holds the caller's SBX_CA_CERT first, one empty line, then the test root"

requirements-completed: [CHECK-02, CHECK-03]

coverage:
  - id: D1
    description: "make_test_root_cert and prepare_root_certificates make or reuse the root, delete its key, build the caller's root first and the test root second, and export SBX_CA_CERT before the first build"
    requirement: CHECK-03
    verification:
      - kind: other
        ref: "certificate probe in the dev sandbox with real openssl: 1 certificate and 0 key files without a caller root, 2 certificates with the caller's first, test root reused, invalid file made again"
        status: pass
    human_judgment: false
  - id: D2
    description: "check_selfcheck_output reports exactly one problem for 52 or 50 expected lines, one per FAIL line with its fix line, one per missing fingerprint, and a count mismatch plus both certificate lines for empty output"
    requirement: CHECK-02
    verification:
      - kind: other
        ref: "fixture probe: problem counts 0 1 2 3 4 4 7, and the FAIL problem carries its fix line"
        status: pass
    human_judgment: false
  - id: D3
    description: "H-34 runs in both agents' test sandboxes on real Docker, and the Cursor test sandbox is gone afterwards"
    requirement: CHECK-02
    verification:
      - kind: other
        ref: "bash tests/guard/run-all.sh (19 PASS, shellcheck_passes, host_tests_never_name_the_local_tag)"
        status: pass
    human_judgment: true
    rationale: "Docker is not available in the dev sandbox; the two-sandbox run and the certificate build are proven on the Mac in plan 07"

duration: 4 min
completed: 2026-11-14
status: complete
---

# Phase 8 Plan 02: Host check H-34 and the throwaway test root Summary

**run-all.sh makes or reuses a throwaway root certificate (key deleted at once) and builds it into the test images next to any proxy root of the caller; H-34 runs sbx-selfcheck in a Claude and a self-managed Cursor test sandbox and fails on a FAIL line, a wrong exit status, a count other than 51 or 49, or a missing root fingerprint.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-11-14T18:28:00Z
- **Completed:** 2026-11-14T18:33:00Z
- **Tasks:** 2
- **Files:** 3 (1 created, 2 modified)

## Accomplishments

- `tests/host/lib-docker.sh`: `test_root_ca_file` prints `${TMPDIR:-/tmp}/sbx-hosttest-root-ca/root-ca.pem`; `cert_fingerprint` prints the SHA-256 fingerprint as uppercase hex without colons, and nothing for a missing or invalid file.
- `tests/host/run-all.sh`: `make_test_root_cert` (umask 077, folder mode 700, key removed before and after `openssl req`, certificate reused while valid for another day) and `prepare_root_certificates` (build file `build-ca.pem` beside the certificate, caller's `SBX_CA_CERT` first, exported). It runs after `create_bundle_clone` and before `build_all_images`, so H-09 and H-29 builds inherit it. `h34-selfcheck.sh` is the last `sandboxCheckList` entry.
- `tests/host/h34-selfcheck.sh` (mode 100644): `expectedClaudeCount=51`, `expectedCursorCount=49`; plants a git identity and a fake login file with a run-unique text; `run_timeout 120 docker exec ... sbx-selfcheck`; exit-status check against the lines; count, FAIL and fingerprint check; the Cursor sandbox is added, cloned into, started and removed through the real `sbx-add`, `sbx-start` and `sbx-rm` with a registry inside the run folder, and `remove_cursor_sandbox` runs right before `report_check`.

## Task Commits

1. **Task 1: the test root reaches the build, H-34 reads the Claude sandbox (tracer)** - `6f5b173`
2. **Task 2: H-34 starts, checks and removes a Cursor test sandbox** - `b0b0bfe`

## Verification

- Guard: "All rules hold.", 19 PASS lines including `shellcheck_passes` and `host_tests_never_name_the_local_tag`; `bash -n` on the three files.
- Certificate probe (real openssl, `TMPDIR` in a temp folder): `1 0 1 2 reused 1 remade 1`, as required.
- Fixture probe: problem counts `0 1 2 3 4 4 7` for 51 good, 52, 50, a FAIL line, a missing fingerprint, an empty fingerprint and empty output; the FAIL problem carries its fix line.
- Structure checks: constants exact, `run_timeout 120 docker exec "$1" sbx-selfcheck` present, certificate step between the bundle clone and the build, `export SBX_CA_CERT` present, no GNU-only construct, H-34 is mode 100644, no `.pem`, `.crt` or `.key` tracked, no `docker` stand-in, `tests/selftest/sbx` unchanged.
- Acceptance: `openssl req` appears once, `rm -f "$keyFile"` twice, 11 functions in H-34, `cursorAdded` three times, no `:local` text.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Shellcheck warned about two globals set by a library**
- **Found during:** Task 2
- **Issue:** `sbxDir` and `sbxStatus` are set by `lib-sbx.sh`, so shellcheck reported SC2154 in the new Cursor functions and the guard failed.
- **Fix:** declared `sbxDir=""` and `sbxStatus=0` in the globals block, as H-28 does.
- **Files modified:** tests/host/h34-selfcheck.sh
- **Commit:** b0b0bfe

### Plan check not reproducible as written

Two plan checks compare against `main` (`git diff --quiet main -- build.sh host-test.sh base claude cursor` and `git diff --name-only main -- tests/selftest`). On this branch they fail because plan 01's commits (the self-check runner, Dockerfile blocks, `tests/selftest/selfcheck/`) are ahead of the stale local `main`. This plan changes none of those paths; the intent was confirmed with `git diff --quiet HEAD -- build.sh host-test.sh base claude cursor tests/selftest` (clean). No action needed.

A comment in H-34 that said "a timeout" tripped the plan's no-GNU-`timeout` grep; it was reworded to "a stop by run_timeout".

**Total deviations:** 1 auto-fixed (blocking lint), 1 plan check noted. **Impact:** none on scope.

## Issues Encountered

None.

## Known Stubs

None. The counts 51 and 49 are pinned ahead of the lists: until plans 03, 05 and 06 fill the check lists up to them, H-34 fails with a count message. That is the intended tripwire, not a stub.

## Threat Flags

None. The surface (a throwaway root trusted only by the `:test` images, a second sandbox started inside H-34) is covered by the plan's threat model.

## Next Phase Readiness

Ready for 08-03. The real two-sandbox run and the certificate build into the test images are proven on the Mac in plan 07 (Docker is not available in the dev sandbox).

## Self-Check: PASSED

- Files exist: tests/host/h34-selfcheck.sh, tests/host/lib-docker.sh, tests/host/run-all.sh.
- Commits exist: 6f5b173, b0b0bfe.
