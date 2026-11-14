---
phase: 08-in-image-self-check
plan: 04
subsystem: testing
tags: [bash, host-test, docs, guard, selfcheck]

requires:
  - phase: 08-01
    provides: the sbx-selfcheck runner, its output format and the pytest suite
  - phase: 08-02
    provides: H-34 and the reused throwaway root certificate
provides:
  - eight host probes and the toolchain probe deleted; 19 host checks remain
  - H-06, H-12 and H-25 slimmed to what needs the Mac
  - the guard's compromised-package rule reading the self-check sources
  - README, tests README, host checklist and MIGRATION describing sbx-selfcheck, H-34, the test root and the pytest suite
affects: [08-05, 08-06, 08-07]

actuals:
  tokens: 21000
  tasks: 3
  commits: 3
plan_head_before: 6327c4ea4cc1617afe22736126055a05ae9d69e1
plan_head_after: 32d9894be9c06ad2bed583f4cf4cc0571a189dba

tech-stack:
  added: []
  patterns:
    - "A host check keeps only what needs the Mac; everything the container can say about itself is an sbx-selfcheck check"
    - "The guard scans new source folders by explicit *.py globs, never by a folder name"

key-files:
  created: []
  modified:
    - tests/host/run-all.sh
    - tests/host/lib-docker.sh
    - tests/guard/supply-chain.sh
    - tests/host/h06-git-on-mac-repo.sh
    - tests/host/h12-plain-run-refused.sh
    - tests/host/h25-images-match-versions.sh
    - tests/host/h26-isolation-by-inspect.sh
    - tests/guard/isolation.sh
    - host-test.sh
    - .hadolint.yaml
    - README.md
    - tests/README.md
    - tests/host-checklist.md
    - MIGRATION.md

key-decisions:
  - "Probe deletion and the guard glob change land in one commit, so the compromised-package rule never fails or goes blind in between"
  - "H-06 and H-12 are renamed (h06-git-on-mac-repo.sh, h12-plain-run-refused.sh) so the file names say what they still prove; H-25 keeps its name"
  - "host-test.sh changes only its host_checks comment; it does not run pytest and has no H-01 check"

requirements-completed: [CHECK-02, CHECK-04]

coverage:
  - id: D1
    description: "H-01, H-04, H-05, H-13, H-14, H-15, H-22, H-30 and the toolchain probe are deleted, run-all.sh lists 19 existing checks, expected_arch is gone"
    requirement: CHECK-02
    verification:
      - kind: command
        ref: "ls tests/host/h*.sh count is 19; every file in the three run-all.sh lists exists; no test names a deleted check"
        status: pass
    human_judgment: false
  - id: D2
    description: "H-06, H-12 and H-25 keep only git on a Mac-made repo, the refused plain docker run, the versions.env comparison and the bare build refusal"
    requirement: CHECK-02
    verification:
      - kind: command
        ref: "bash -n on the three scripts; greps for the removed functions; guard, entrypoint and sbx self-tests pass"
        status: pass
    human_judgment: true
    rationale: "The slimmed checks run against real Docker only on the Mac (./host-test.sh); the dev sandbox has no Docker"
  - id: D3
    description: "no_compromised_gsd_package scans the self-check sources, tests, pyproject.toml and uv.lock, and the guard still holds 19 rules"
    requirement: CHECK-02
    verification:
      - kind: command
        ref: "bash tests/guard/run-all.sh: 19 PASS, All rules hold; a scratch copy with gsd-build planted in shared_checks.py prints FAIL: no_compromised_gsd_package"
        status: pass
    human_judgment: false
  - id: D4
    description: "The four docs describe sbx-selfcheck, H-34, the throwaway root and the pytest suite with no deleted check ID, no dash punctuation and no planning ID"
    requirement: CHECK-04
    verification:
      - kind: command
        ref: "doc greps for required sections and rows, deleted IDs, non-ASCII, dashes and planning IDs in the added lines"
        status: pass
    human_judgment: true
    rationale: "Whether the docs read well and match their neighbours is a reader's call"

duration: 20 min
completed: 2026-11-14
status: complete
---

# Phase 8 Plan 04: Retire the probes the self-check replaces, and document it Summary

**Eight host probes and the toolchain probe are gone, H-06, H-12 and H-25 test only what needs the Mac, the guard's compromised-package rule now reads the self-check sources, and the README, tests README, host checklist and MIGRATION describe `sbx-selfcheck`, H-34, the reused test root and the pytest suite.**

## Performance

- **Duration:** 20 min
- **Completed:** 2026-11-14
- **Tasks:** 3
- **Files:** 14 modified or renamed, 9 deleted

## Accomplishments

- Task 1: `git rm` of H-01, H-04, H-05, H-13, H-14, H-15, H-22, H-30 and `tests/host/support/toolchain-probe.sh`; `sandboxCheckList` is now H-06, H-26, H-34; `expected_arch` removed from `lib-docker.sh` (`pin_of`, `claude_pin` and the certificate helpers stay); the support glob left the compromised-package scan in the same commit and `base/selfcheck/sbx-selfcheck`, the three `selfcheck/*.py` globs, `tests/selftest/selfcheck/*.py`, `pyproject.toml` and `uv.lock` joined it.
- Task 2: `h06-git-on-mac-repo.sh` (only `git status` in the container), `h12-plain-run-refused.sh` (one plain `docker run`), `h25-images-match-versions.sh` (record and bare builds); both renames are recorded as renames; the run lists name the new files; four comments (H-26 header, `managed_settings_deny_skill_edits`, the `host_checks` banner, DL3066) point at H-34 or `sbx-selfcheck`.
- Task 3: README gets "Check a sandbox", H-34 rows in "Verify a new build", the extra-root row and bullet, the certificate note in "Free disk space", the "Behind a company HTTPS proxy" paragraph, the image-table and Scripts mentions and a troubleshooting row. `tests/README.md` gets the selfcheck suite row and section, the certificate sentence, the reworded guard Where row and the H-34 rows. `tests/host-checklist.md` is now H-03 to H-34 with 19 table rows, the H-34 row, the failure note and the cleanup bullet. `MIGRATION.md` "Check" gets step 4.
- The guard still holds 19 rules; the entrypoint and sbx self-tests pass.

## Task Commits

1. **Task 1: delete the eight probes and the toolchain probe, guard scans the self-check sources** - `efe18ea`
2. **Task 2: slim H-06, H-12 and H-25, comments follow** - `07981ef`
3. **Task 3: docs** - `32d9894`

## Where each dropped assertion went

| Dropped from | Assertion | Now |
|---|---|---|
| H-01 | native architecture, platform-warning scan | dropped on purpose (builds run natively, the small emulation risk is accepted) |
| H-05 | a file written in the container reaches the Mac | dropped; H-06, H-08, H-09 already prove the mount |
| H-04, H-05, H-13, H-14, H-22, H-30 and the H-06 identity and safe.directory lines | in-container facts | `sbx-selfcheck` checks (plans 03, 05, 06), proven by H-34 |
| H-15 | the container reads the clone's rule equal to the Mac's | H-16 reads the rule through `state/claude/rules` after a Mac edit |
| H-25 | tool versions, nothing under the mount point | tools: H-34; mount point: the smoke test of every Dockerfile already fails the build |
| H-12 | the pinned Claude is installed | H-34 (CLI version check) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Verify defect] Task 2's `docker run` count check cannot pass as written**
- **Found during:** Task 2
- **Issue:** `grep -v '^[[:space:]]*#' tests/host/h12-plain-run-refused.sh | grep -c 'docker run'` expects 1, but the specified `report_check H-12` text ("a plain docker run was not refused", "a plain docker run is refused") and the existing failure message ("a plain docker run must exit 1 ...") also contain the phrase, so the count is 3.
- **Fix:** kept the wording the plan prescribes and checked the intent instead: `grep -c 'docker run --rm'` over the non-comment lines is 1, so the script makes one `docker run`.
- **Files modified:** none
- **Commit:** n/a

**2. [Wording] "Removed:" bullet in "Free disk space"**
- **Found during:** Task 3
- **Issue:** appending "and `sbx-hosttest-root-ca`, the test root certificate, which the next run makes again" in the middle of a comma list read badly.
- **Fix:** reworded to "the test root certificate `sbx-hosttest-root-ca` (the next run makes it again)" as one list item. `clean.sh` already removes it: its `sbx-hosttest-*` glob matches the folder, so no script change was needed.
- **Files modified:** README.md
- **Commit:** 32d9894

### Folded review nits

- IN-01 (isolation comment blaming the old layout): needs no edit; `grep -n 'lost data' tests/guard/isolation.sh` finds nothing.
- IN-02 (guard Where wording): settled in `tests/README.md`; the todo `2026-11-08-retirement-review-nits.md` moved to `.planning/todos/completed/` in the SUMMARY commit.

**Total deviations:** 1 auto-fixed (a defective verify command), 1 wording choice. **Impact:** none on scope.

## Issues Encountered

None.

## Verification

- 19 `tests/host/h*.sh` files; every file named in the three run lists exists and the lists hold 19 checks.
- `bash tests/guard/run-all.sh`: 19 PASS, "All rules hold."; the scratch copy with `gsd-build` planted in `base/selfcheck/shared_checks.py` makes the rule print FAIL.
- `bash tests/selftest/entrypoint/run-all.sh` and `bash tests/selftest/sbx/run-all.sh`: "All cases pass."
- `git diff` of `host-test.sh` against the plan's start: exactly one comment line changed, no pytest.
- Doc greps: required sections and rows present; no deleted check ID, old ID range or old guard wording; no non-ASCII, dash punctuation or planning ID in the added lines; no file with "skill" in its name changed.
- Not run here (no Docker): `./host-test.sh` on the Mac, which exercises the slimmed H-06, H-12 and H-25 and H-34.

## Known Stubs

None.

## Threat Flags

None. The change removes tests and edits docs and comments; the scan list of the compromised-package rule grew (T-08-12, proven by the planted-name scratch copy).

## Next Phase Readiness

Ready for 08-05 and 08-06 (the Claude and Cursor checks that bring H-34's counts to 51 and 49). The first Mac run of `./host-test.sh` after those plans is the real proof of the slimmed checks.

## Self-Check: PASSED

- Files exist: tests/host/h06-git-on-mac-repo.sh, tests/host/h12-plain-run-refused.sh, tests/host/h25-images-match-versions.sh, tests/host/run-all.sh, tests/guard/supply-chain.sh, README.md, tests/README.md, tests/host-checklist.md, MIGRATION.md; the nine deleted files are gone.
- Commits exist: efe18ea, 07981ef, 32d9894.
