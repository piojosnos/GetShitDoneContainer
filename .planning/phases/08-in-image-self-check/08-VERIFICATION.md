---
phase: 08-in-image-self-check
verified: 2026-11-15T00:40:00Z
status: passed
score: 4/4 must-haves verified
covered_files:
  - .planning/phases/08-in-image-self-check/08-01-PLAN.md
  - .planning/phases/08-in-image-self-check/08-01-SUMMARY.md
  - .planning/phases/08-in-image-self-check/08-02-PLAN.md
  - .planning/phases/08-in-image-self-check/08-02-SUMMARY.md
  - .planning/phases/08-in-image-self-check/08-03-PLAN.md
  - .planning/phases/08-in-image-self-check/08-03-SUMMARY.md
  - .planning/phases/08-in-image-self-check/08-04-PLAN.md
  - .planning/phases/08-in-image-self-check/08-04-SUMMARY.md
  - .planning/phases/08-in-image-self-check/08-05-PLAN.md
  - .planning/phases/08-in-image-self-check/08-05-SUMMARY.md
  - .planning/phases/08-in-image-self-check/08-06-PLAN.md
  - .planning/phases/08-in-image-self-check/08-06-SUMMARY.md
  - .planning/phases/08-in-image-self-check/08-07-PLAN.md
  - .planning/phases/08-in-image-self-check/08-07-SUMMARY.md
  - .planning/phases/08-in-image-self-check/08-08-PLAN.md
  - .planning/phases/08-in-image-self-check/08-08-SUMMARY.md
  - .planning/phases/08-in-image-self-check/08-09-PLAN.md
  - .planning/phases/08-in-image-self-check/08-09-SUMMARY.md
  - .planning/phases/08-in-image-self-check/08-10-PLAN.md
  - .planning/phases/08-in-image-self-check/08-10-SUMMARY.md
  - .planning/phases/08-in-image-self-check/08-11-PLAN.md
  - .planning/phases/08-in-image-self-check/08-11-SUMMARY.md
  - .planning/phases/08-in-image-self-check/08-12-PLAN.md
  - .planning/phases/08-in-image-self-check/08-12-SUMMARY.md
  - .planning/phases/08-in-image-self-check/08-13-PLAN.md
  - .planning/phases/08-in-image-self-check/08-13-SUMMARY.md
  - base/selfcheck/sbx-selfcheck
  - base/selfcheck/sbx_selfcheck.py
  - base/selfcheck/shared_checks.py
  - claude/selfcheck/claude.py
  - cursor/selfcheck/cursor.py
  - tests/host/h34-selfcheck.sh
covered_digest: "v2:sha256:112031c5d5578d0d7a011182df823f5ddfba51325b44320021ab5a9100a1e8c2"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: passed
  previous_score: 4/4
  gaps_closed:
    - "WR-01: scan_owned_state raised PermissionError for a folder that lists but cannot be searched; it now names the folder '(unreadable)' with the Mac owner fix (plan 08-12)"
    - "WR-02: a checks file with a malformed CHECK_LIST killed the runner; it is now that file's load FAIL (plan 08-12)"
    - "WR-03: a check returning something other than a CheckResult killed the runner; it is now that check's own FAIL (plan 08-13)"
    - "IN-09: any entry stat error marked the whole folder unreadable and dropped its siblings; only PermissionError does that now (plan 08-13)"
  gaps_remaining: []
  regressions: []
deferred: []
advisory:
  - finding: "The Mac run of 2026-11-14 predates plans 08-12 and 08-13, so the exact runner and shared-checks files now in the image have not been through a Mac run"
    category: other
    reason: "The edits touch only error paths. A healthy sandbox takes the same path as before, counts (41, 12, 10; 53 and 51) and the owner fix text are unchanged, h34-selfcheck.sh, the Dockerfiles and run-all.sh are untouched since the Mac run, and the image build py_compiles both files. Covered by 202 pytest tests plus the live reproductions below. The next routine ./host-test.sh run picks the new code up; no extra Mac run is needed to close the phase."
    evidence_status: "pytest and live reproduction here; Mac re-run not required"
  - finding: "IN-01 to IN-05 are deferred to Phase 10 (owner fix hint for unreadable folders the sandbox user owns, hardcoded image tag in the hint, 'not valid JSON' wording, H-34 'after' run count, unnamed root container on timeout)"
    category: other
    reason: "Hygiene and wording; recorded in 08-REVIEW-DISPOSITION.md as deferred with reasons and in the pending todo 2026-11-14-selfcheck-review-follow-ups.md. None contradicts a criterion."
    evidence_status: "ledger shows open: 0"
---

# Phase 8: In-image self-check Verification Report

**Phase Goal:** One command inside the image tells whether a sandbox is set up right, and the host run asks it instead of probing piece by piece. It doubles as the sandbox doctor: each failure comes with its fix.
**Verified:** 2026-11-15
**Status:** passed
**Re-verification:** Yes, after gap closure plans 08-12 and 08-13 (the previous passed report was stale because they changed covered source)

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP success criterion) | Status | Evidence |
|---|-----------------------------------|--------|----------|
| 1 | `sbx-selfcheck` prints one PASS or FAIL line per named check; base ships the runner and shared checks, each agent image adds its checks file to a fixed folder; no SKIP | VERIFIED | `outcome_lines` emits only `PASS: name: detail` or `FAIL: name: detail` plus an indented `fix:` line; grep for "skip" in the runner finds nothing. `base/Dockerfile:241-246` installs launcher, runner and shared checks and links `/usr/local/bin/sbx-selfcheck`; `claude/Dockerfile:65` and `cursor/Dockerfile:56` copy their file into `/etc/sbx/selfcheck.d` and py_compile it; `collect_checks` globs that folder. Imported lists hold 41, 12 and 10 checks (53 and 51 per agent). After 08-12 and 08-13 no input can end the run without lines: a malformed `CHECK_LIST` is a `load-NAME` FAIL, a check returning `None` is `FAIL: check1: returned NoneType instead of a CheckResult`, an empty agent folder is the `load-agent-checks` FAIL. Reproduced live in one run: three FAIL lines, the summary `3 checks, 3 failed`, exit 1. |
| 2 | One host check (H-34) runs `sbx-selfcheck` via `docker exec` in a Claude and a Cursor test sandbox, fails on any FAIL or a wrong count; H-01, H-04, H-05, H-13, H-14, H-15, H-22, H-30 deleted; H-06, H-12, H-25 keep only the Mac parts | VERIFIED | `tests/host/h34-selfcheck.sh` runs `docker exec ... sbx-selfcheck`, classifies exit status against FAIL lines and compares the `^(PASS\|FAIL): ` count with `expectedClaudeCount=53` and `expectedCursorCount=51`, equal to the imported lists. `tests/host/` holds no h01, h04, h05, h13, h14, h15, h22 or h30 file and `run-all.sh` and `host-test.sh` name none of them. `git diff 9ec0c81 HEAD` shows no change to `tests/host`, any Dockerfile or `run-all.sh`, so the Mac run still describes this harness. Mac `host-test.log` (22:02 on 2026-11-14, after the last change to the check lists): `PASS: H-34 ... 53 ... 51`, `Summary: 19 passed, 0 failed, 0 not run`. |
| 3 | `./host-test.sh` makes a throwaway root certificate with `openssl`, builds it into the test base image, the self-check finds it in the system bundle and Java `cacerts`; no certificate is committed | VERIFIED | `tests/host/run-all.sh:237` runs `openssl req -x509 -newkey rsa:2048 -nodes ...` into a temp folder; the build trusts `build-ca.pem`. `git ls-files` lists no `.pem`, `.crt`, `.cer` or `.key`. Mac log line 206 records the certificate path and SHA-256 and the H-34 PASS text says it was found in both stores in both sandboxes. The certificate checks and `run-all.sh` are unchanged since that run. |
| 4 | Each FAIL line carries a fix hint, with the Mac command when the fix is on the Mac; no skill wraps the self-check | VERIFIED | `failed()` rejects an empty hint; `run_check` turns both a raised exception and a wrong return type into a FAIL with the rebuild hint, so no FAIL line lacks a hint. `owner_fix_hint` prints the throwaway root container `chown` as a Mac command. Live run here: a mode 444 state folder gave `sub1/folder1 (unreadable)` with that Mac owner fix, not the generic bug hint. Mac log: planted root-owned folder gave `53 checks, 1 failed`, the owner fix line, then `53 checks, 0 failed` after running it. No selfcheck skill exists under `.claude/skills`. |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

### Gap Plans 08-12 and 08-13 Re-check

| Finding | Status | Evidence |
|---------|--------|----------|
| WR-01 (mode 444 folder raised PermissionError) | CLOSED | `mark_unreadable_folder` is called from the listing failure and the entry stat `PermissionError` branch of `scan_owned_state`; a tolerated GSD sync folder in that state stays tolerated. Live reproduction above. RED commit 6c1e974 older than fix 8fe8562. |
| WR-02 (`CHECK_LIST = None` killed the runner) | CLOSED | `is_check_list` plus the validated `module_check_list`; live: `FAIL: load-a2 ... not a list of checks`, other lines and summary still printed. RED 72e8daf before fix 5d4ef02. |
| WR-03 (check returning `None` crashed) | CLOSED | `run_check` has an `isinstance(result, CheckResult)` guard. Live: `FAIL: check1: returned NoneType instead of a CheckResult`. RED a63844b before fix 9cd424b. |
| IN-09 (non-permission entry error mislabelled the folder) | CLOSED | The entry handler is `except PermissionError` only; any other `OSError` reaches `run_check` and prints as the named `raised ...` FAIL; `relative_dir` is computed once per walk step. RED 41cad9a before fix 4621eb0. |

The H-34 plant is a root-owned mode 700 folder directly under `state/`. It takes the listing-failure branch (`OSError` on `scandir`), which keeps the same wording and the same owner fix as before 08-12, so the Mac round trip still describes the shipped behaviour for that shape.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `base/selfcheck/sbx-selfcheck` | launcher | VERIFIED | linked into `/usr/local/bin` by `base/Dockerfile` |
| `base/selfcheck/sbx_selfcheck.py` | runner | VERIFIED | `run_selfcheck`, `run_check` (exception and return type guards), `is_check_list`; exits 1 on any FAIL |
| `base/selfcheck/shared_checks.py` | shared checks | VERIFIED | 41 checks; `scan_owned_state` and `mark_unreadable_folder` |
| `claude/selfcheck/claude.py` | Claude checks | VERIFIED | 12 checks, copied and compiled by `claude/Dockerfile` |
| `cursor/selfcheck/cursor.py` | Cursor checks | VERIFIED | 10 checks, copied and compiled by `cursor/Dockerfile` |
| `tests/host/h34-selfcheck.sh` | host check | VERIFIED | unchanged since the Mac run; wired through `run-all.sh` |
| `tests/selftest/selfcheck/*` | pytest harness | VERIFIED | 202 tests pass |
| `.planning/todos/pending/2026-11-14-selfcheck-review-follow-ups.md` | IN-01 to IN-05 for Phase 10 | VERIFIED | exists |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `claude/Dockerfile`, `cursor/Dockerfile` | `/etc/sbx/selfcheck.d` | `COPY --chmod=644` plus `py_compile` | WIRED |
| `collect_checks` | `/etc/sbx/selfcheck.d/*.py` | glob, import, `is_check_list`, `CHECK_LIST` | WIRED |
| `run_selfcheck` | `run_check` | every result is a real `CheckResult` before `result.passed` and `outcome_lines` | WIRED |
| `scan_owned_state` | `mark_unreadable_folder` | listing failure and entry `PermissionError` | WIRED |
| `root_owned_state_result` | `owner_fix_hint` | `failed(detail, owner_fix_hint(state_dir))` | WIRED |
| `h34-selfcheck.sh` | `sbx-selfcheck` in both containers | `docker exec` | WIRED |
| `run-all.sh` | test base image | `build-ca.pem` build input | WIRED (Mac log) |

### Data-Flow Trace (Level 4)

Not applicable: the checks read live system state (files, mounts, `keytool`, `stat`), not rendered or stored data.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Self-check tests | `uv run pytest tests/selftest -q` | 202 passed | PASS |
| Guard rules | `bash tests/guard/run-all.sh` | "All rules hold." | PASS |
| Check list sizes | import the three lists | 41, 12, 10 | PASS |
| WR-01, WR-02, WR-03 through the runner | `run_selfcheck` with a mode 444 state folder, a `None`-returning check and `CHECK_LIST = None` | three named FAIL lines with fixes, summary `3 checks, 3 failed`, exit 1, no traceback | PASS |
| In-image run, certificate, owner fix round trip | Mac `host-test.log` and `../selfcheck-gate.log` (Docker not available here) | 19 passed, 0 failed; H-34 53 and 51 checks, 0 failed; owner fix before 1 failed, after 0 | PASS (log evidence) |

Does the Mac evidence still stand? Yes for the host harness, the certificate and the check counts: none of `tests/host`, the Dockerfiles, `run-all.sh`, `claude.py` or `cursor.py` changed after it. The runner and `shared_checks.py` did change, but only on error paths (non-permission entry errors, a wrong return value, a malformed list); a healthy sandbox and the planted mode 700 folder take the paths the Mac run already exercised, with the same text. The image build compiles both files, so a syntax slip would stop the build. A fresh Mac run is not needed to call the phase achieved; the next routine `./host-test.sh` will run the new bytes.

### Probe Execution

SKIPPED: the phase declares no `probe-*.sh` scripts.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|--------------|-------------|--------|----------|
| CHECK-01 | 08-01, 08-03, 08-04 to 08-13 | one PASS or FAIL line per named check, base holds runner and shared checks, agents add theirs | SATISFIED | criterion 1 |
| CHECK-02 | 08-02, 08-04, 08-06, 08-07, 08-09, 08-11 | one host check via `docker exec`, no FAIL, expected counts, in-container parts deleted | SATISFIED | criterion 2 |
| CHECK-03 | 08-02, 08-05, 08-07, 08-11 | throwaway `openssl` certificate built into the test base image, found in both stores | SATISFIED | criterion 3 |
| CHECK-04 | 08-01, 08-03 to 08-08, 08-10 to 08-13 | doctor: each FAIL has a fix hint, Mac command where needed, no skill | SATISFIED | criterion 4 |

All four IDs appear in plan frontmatter and in REQUIREMENTS.md (lines 25-28 checked, traceability lines 83-86 Complete). No orphaned Phase 8 requirement.

### Plan Prohibitions (08-12, 08-13)

| Prohibition | Result |
|-------------|--------|
| No check added or removed; counts 41, 12, 10 hold | Held: lists import at 41, 12, 10; H-34 still 53 and 51 |
| No change to owner fix text, settings messages, image tag handling or `h34-selfcheck.sh` | Held: `git diff 9ec0c81 HEAD` touches no `tests/host` file; the owner fix text is unchanged in the diff |
| No `.planning` file and code file in one commit | Held: the eight commits above each touch one side only |

Judgment-tier, checked against the diff; no unresolved prohibition.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| none | | no TBD, FIXME or XXX in the phase sources or tests | | |

### Human Verification Required

None. The review ledger `08-REVIEW-DISPOSITION.md` shows WR-01 to WR-03 and IN-09 fixed with commit hashes, IN-01 to IN-05 deferred with reasons, `open: 0`. No behavior-dependent truth lacks a test.

### Gaps Summary

All four success criteria hold. Plans 08-12 and 08-13 closed the last review findings: the doctor no longer crashes on a folder it can list but not search, a malformed checks file, a check that returns the wrong type, or an odd entry error, and each case prints a named FAIL with a fix. Check counts, the owner fix text and the host harness are unchanged from the Mac run of 2026-11-14, so that evidence still stands for criteria 2 to 4. One housekeeping note for the orchestrator: the Phase 8 checkbox in `.planning/ROADMAP.md` (line 40) is still unchecked, although the phase detail reads 13/13 plans executed.

---

_Verified: 2026-11-15_
_Verifier: Claude (gsd-verifier)_
