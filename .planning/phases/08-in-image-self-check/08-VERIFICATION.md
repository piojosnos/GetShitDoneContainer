---
phase: 08-in-image-self-check
verified: 2026-11-14T00:00:00Z
status: gaps_found
score: 3/4 must-haves verified
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
  - base/selfcheck/sbx-selfcheck
  - base/selfcheck/sbx_selfcheck.py
  - base/selfcheck/shared_checks.py
  - claude/selfcheck/claude.py
  - cursor/selfcheck/cursor.py
  - tests/host/h34-selfcheck.sh
covered_digest: "v2:sha256:14e9be6015b5ada4548b0b300c3cf6443794b8317ef3f5161a18086371a31e7b"
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "Each FAIL line carries a fix hint, with the Mac command when the fix is on the Mac (criterion 4)"
    status: partial
    reason: "The no-root-owned-state FAIL carries a hint, but it is a sandbox-side chown that cannot succeed, and the real fix is on the Mac. The pytest test locks the wrong hint in."
    artifacts:
      - path: "base/selfcheck/shared_checks.py"
        issue: "line 258: hint is 'in this sandbox run: chown -R sandbox:sandbox /home/sandbox/workspace/state'; the sandbox user has no root, cap_drop ALL and no-new-privileges (compose.yml:28-29), so chown on a root-owned path fails with Operation not permitted; MIGRATION.md line 137 states this"
      - path: "tests/selftest/selfcheck/test_sandbox_checks.py"
        issue: "asserts 'chown -R sandbox:sandbox' in result.hint, so the unit suite blesses the broken hint"
    missing:
      - "Replace the hint with a Mac command (throwaway root container chown, as documented in MIGRATION.md line 127) or an rm of the root-owned entries when they sit in a sandbox-owned folder; update the test assertion"
      - "Related (WR-02): scan_owned_state raises PermissionError on a root-owned mode 700 folder, so the same check reports 'raised PermissionError' with the generic rebuild hint instead of the path; catch OSError around scandir, record the folder as unreadable, add a test"
deferred: []
---

# Phase 8: In-image self-check Verification Report

**Phase Goal:** One command inside the image tells whether a sandbox is set up right, and the host run asks it instead of probing piece by piece. It doubles as the sandbox doctor: each failure comes with its fix.
**Verified:** 2026-11-14
**Status:** gaps_found
**Re-verification:** No, initial verification

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP success criterion) | Status | Evidence |
|---|-----------------------------------|--------|----------|
| 1 | `sbx-selfcheck` prints one PASS or FAIL line per named check; base image ships runner and shared checks; each agent image adds its checks file to a fixed folder; no SKIP | VERIFIED | `outcome_lines` in `base/selfcheck/sbx_selfcheck.py` emits only `PASS: name: detail` or `FAIL: name: detail` plus an indented `fix:` line; no SKIP outcome exists (grep for SKIP finds only the unrelated `SKIPPED_STATE_DIR_SET`). `base/Dockerfile:241-246` copies the launcher, library and shared checks to `/usr/local/lib/sbx-selfcheck` and links `/usr/local/bin/sbx-selfcheck`; `claude/Dockerfile:65` and `cursor/Dockerfile:56` copy `claude.py` / `cursor.py` into `/etc/sbx/selfcheck.d`, which `collect_checks` globs. Mac log: Claude 51 checks, Cursor 49 checks, all PASS. |
| 2 | One host check (H-34) runs `sbx-selfcheck` via `docker exec` in a Claude and a Cursor sandbox, fails on any FAIL or wrong count; H-01, H-04, H-05, H-13, H-14, H-15, H-22, H-30 deleted; H-06, H-12, H-25 slimmed | VERIFIED | `tests/host/h34-selfcheck.sh` runs `docker exec ... sbx-selfcheck` in both sandboxes, checks exit status against FAIL lines, and compares the line count with `expectedClaudeCount` / `expectedCursorCount` (51 / 49). `tests/host/` holds no h01, h04, h05, h13, h14, h15, h22 or h30 file and `run-all.sh` and `host-test.sh` do not reference them. h06, h12 and h25 remain as 53, 34 and 75 line scripts. `host-test.log`: `PASS: H-34 ... 51 ... 49`, `Summary: 19 passed, 0 failed, 0 not run`. |
| 3 | `./host-test.sh` makes a throwaway root cert with `openssl`, builds it into the test base image, self-check finds it in the system bundle and Java `cacerts`; no certificate committed | VERIFIED | `tests/host/run-all.sh:237` runs `openssl req -x509 ... -out root-ca.pem` in a run folder under `$TMPDIR`; `build-ca.pem` is passed to the test base build. `git ls-files` lists no `.pem`, `.crt`, `.cer` or `.key`. `shared_checks.py` has `system_bundle_result` and `java_cacerts_result` (keytool against `-cacerts`) for `/usr/local/share/ca-certificates`. Mac log: INFO line with the fingerprint, H-34 PASS text "found the test root certificate in the system bundle and Java cacerts in both"; `selfcheck-gate.log` shows the `:local` image IDs unchanged and the cert folder outside the repo. |
| 4 | Each FAIL line carries a fix hint, with the Mac command when the fix is on the Mac; no skill wraps the self-check | PARTIAL (gap) | `failed()` raises on an empty hint, so every FAIL line has one (26 `failed(` sites; `run_check` also converts a raised exception into a FAIL with a rebuild hint). Mac-side hints use `mac_hint` (`sbx-upgrade`, `sbx-stop`/`sbx-start`, `sbx-shell`). No skill wraps the command. Defect: the `no-root-owned-state` hint tells the sandbox user to run a `chown` that cannot work, while the fix belongs on the Mac (see Gaps). |

**Score:** 3/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `base/selfcheck/sbx-selfcheck` | launcher | VERIFIED | 24 lines, linked into `/usr/local/bin` |
| `base/selfcheck/sbx_selfcheck.py` | runner library | VERIFIED | 676 lines, `run_selfcheck` iterates every check, prints summary |
| `base/selfcheck/shared_checks.py` | shared checks | VERIFIED | 844 lines, 39 checks declared |
| `claude/selfcheck/claude.py` | Claude checks | VERIFIED | 191 lines, 12 checks, copied by `claude/Dockerfile` |
| `cursor/selfcheck/cursor.py` | Cursor checks | VERIFIED | 147 lines, 10 checks, copied by `cursor/Dockerfile` |
| `tests/host/h34-selfcheck.sh` | host check | VERIFIED | wired through `tests/host/run-all.sh` |
| `tests/selftest/selfcheck/*` | pytest harness | VERIFIED | 178 passed in 3.18 s (run here) |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `claude/Dockerfile`, `cursor/Dockerfile` | `/etc/sbx/selfcheck.d` | `COPY --chmod=644` | WIRED |
| `sbx_selfcheck.collect_checks` | `/etc/sbx/selfcheck.d/*.py` | glob + import | WIRED |
| `h34-selfcheck.sh` | `sbx-selfcheck` in both containers | `docker exec` | WIRED |
| `run-all.sh` | test base image | `build-ca.pem` build input | WIRED (Mac run evidence) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Runner, checks and inventory counts | `uv run pytest tests/selftest/selfcheck -q` | 178 passed | PASS |
| Guard rules | `bash tests/guard/run-all.sh` | all PASS, "All rules hold." | PASS |
| In-image run, certificate, counts | Mac `./host-test.sh` log | 19 passed, 0 failed; 51 and 49 checks | PASS (log evidence, Docker not available here) |

### Requirements Coverage

| Requirement | Source Plans | Status | Evidence |
|-------------|--------------|--------|----------|
| CHECK-01 | 08-01, 08-04..08-07 | SATISFIED | criterion 1 |
| CHECK-02 | 08-02, 08-03, 08-04, 08-06, 08-07 | SATISFIED | criterion 2 |
| CHECK-03 | 08-02, 08-04, 08-06, 08-07 | SATISFIED | criterion 3 |
| CHECK-04 | 08-01, 08-03, 08-05, 08-06, 08-07 | PARTIAL | criterion 4; one hint cannot work (WR-01) |

All four IDs in the plan frontmatter appear in REQUIREMENTS.md (lines 25-28, marked complete) and in the traceability table (lines 83-86). No orphaned requirement for Phase 8. REQUIREMENTS.md already marks CHECK-04 complete; that should be revisited until the gap closes.

### Review Warnings Weighed

| ID | Verdict | Reasoning |
|----|---------|-----------|
| WR-01 | Defeats criterion 4 for one check | Confirmed against `shared_checks.py:258`, `compose.yml:28-29` and MIGRATION.md line 137. The hint exists but a user who follows it gets `Operation not permitted`. The goal says each failure comes with its fix. |
| WR-02 | Same area, advisory but fix together | On a root-owned mode 700 folder the check crashes into the generic rebuild hint and never names the path. The FAIL still prints, so criterion 4's letter holds, but the doctor value is lost on the exact case the check exists for. Reproducibility was reported by the reviewer; not re-run here. |
| WR-03 | Does not defeat a criterion | Criterion 1 asks that agent images add their file; both do, and H-34's count check (51 / 49) fails on the host if a file is missing. The in-sandbox green with only shared checks is a robustness weakness and a plausible doctor false negative, so worth fixing, but nothing in the four criteria is falsified. |
| WR-04 | Does not defeat a criterion | `bash` and `keytool` resolve through PATH without the "not under /home" guard. This weakens trust in two checks against an adversarial PATH, not the success criteria. Advisory. |

### Anti-Patterns Found

None blocking. No TBD, FIXME or XXX markers in the phase source files. Info items IN-01 to IN-08 from the review are style and hygiene; none touch a criterion.

### Human Verification Required

None. The Mac run already supplied the Docker-dependent evidence (H-34 counts, certificate in both stores). No behavior-dependent truth lacks a test.

### Gaps Summary

Three of four criteria hold with direct evidence in code, the local pytest and guard runs, and the Mac `host-test.log`. Criterion 4 has one concrete defect: the `no-root-owned-state` fix hint tells the user to run a command the sandbox cannot execute, and a unit test enforces the wrong text. Closing it is small: change the hint to a Mac command, make `scan_owned_state` tolerate an unreadable folder (WR-02), and update the two tests. Recommend including WR-03 in the same closure plan since it is a one-line runner change plus a test update, but it is not required by the criteria. The dispositions file shows all findings as open, so the closure plan should also record them.

---

_Verified: 2026-11-14_
_Verifier: Claude (gsd-verifier)_
