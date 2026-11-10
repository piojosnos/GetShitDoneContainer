---
phase: 05-migration-docs-and-old-layout-retirement
reviewed: 2026-11-08
depth: standard
status: issues_found
files_reviewed: 6
findings:
  critical: 0
  warning: 0
  info: 2
  total: 2
---

# Phase 5 code review

Scope: the six files edited on `chore/retire-old-layout` (`host-test.sh`, `tests/README.md`, `tests/guard/isolation.sh`, `tests/host-checklist.md`, `tests/host/lib-docker.sh`, `tests/host/run-all.sh`), diff base `origin/main`.

## Verification run

- No reference to a removed symbol or file is left in the six files or `tests/`.
- Guard: 18 PASS, "All rules hold." (matches "18 rules" in `tests/README.md`).
- Guard, entrypoint and sbx self-tests: "All cases pass."
- `bash -n` passes; `host-test.sh` and `tests/host/run-all.sh` stay 100755.
- No function in `tests/host/lib*.sh` or `tests/guard/lib.sh` became unused.
- "H-00 to H-33" agrees across `tests/README.md`, `tests/host-checklist.md` and `host-test.sh`.

## Critical issues

None.

## Warnings

None.

## Info

### IN-01: Comment still explains a rule by the retired layout

**File:** `tests/guard/isolation.sh:28`
**Issue:** The comment says volumes stay "because removing them is how the old layout lost data". The old layout is gone, so this is now a rationale-of-past-changes comment. `bin/sbx-list:22` and `tests/host/h32-sbx-list.sh:100` also name the old layout; both stay true while old `cc_` containers can exist on the Mac (kept on purpose by the plan).
**Fix:** State the reason on its own, for example: "volumes stay because they hold the sandbox's data, and a compose down with volumes would delete it."

### IN-02: "Old dev sandbox" in the guard row is ambiguous

**File:** `tests/README.md:25`
**Issue:** "Old dev sandbox or a Mac shell by hand without the linters" can now be read as the retired layout; it means a dev sandbox without shellcheck and hadolint.
**Fix:** Reword to "A dev sandbox without the linters, or a Mac shell by hand: ...".

_Reviewed: 2026-11-08, gsd-code-reviewer, standard depth_
