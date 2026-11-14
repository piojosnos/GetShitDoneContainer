---
phase: 08-in-image-self-check
verified: 2026-11-14T23:00:00Z
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
  - base/selfcheck/sbx-selfcheck
  - base/selfcheck/sbx_selfcheck.py
  - base/selfcheck/shared_checks.py
  - claude/selfcheck/claude.py
  - cursor/selfcheck/cursor.py
  - tests/host/h34-selfcheck.sh
covered_digest: "v2:sha256:a59ee26d0adf9dc0ebfef7c731415e7ad45d5e4d8cb4241fe5c613aa093e7d1a"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/4
  gaps_closed:
    - "Each FAIL line carries a fix hint, with the Mac command when the fix is on the Mac (criterion 4): the no-root-owned-state hint is now a throwaway root container chown run on the Mac"
    - "scan_owned_state crashed on a root-owned mode 700 folder: it now catches OSError around scandir and names the folder with (unreadable)"
    - "A missing or empty agent checks folder gave a silent green: collect_checks now adds a load-agent-checks FAIL"
    - "bash and keytool resolved through PATH without a guard: tool-bash and tool-keytool checks added"
  gaps_remaining: []
  regressions: []
deferred: []
advisory:
  - finding: "WR-01: scan_owned_state raises PermissionError for a folder that can be listed but not searched (for example a root-owned mode 444 folder), so the runner prints the generic bug FAIL and rebuild hint instead of the owner fix"
    category: other
    reason: "Reproduced here. Narrow trigger; the run still fails closed with a FAIL line and a hint. Fix: catch OSError around entry.stat and record the folder as unreadable, plus a 0o444 test."
    evidence_status: "reproduced, not blocking"
  - finding: "WR-02: a checks file with CHECK_LIST = None (or any non-iterable) raises TypeError out of collect_checks and kills the runner with a traceback"
    category: other
    reason: "Reproduced here. Only a mis-authored agent file in the repo can trigger it, and pytest, the inventory test and H-34 all fail on it (nonzero exit, no count). Fix: validate CHECK_LIST in module_check_list and turn a bad list into a load FAIL."
    evidence_status: "reproduced, not blocking"
---

# Phase 8: In-image self-check Verification Report

**Phase Goal:** One command inside the image tells whether a sandbox is set up right, and the host run asks it instead of probing piece by piece. It doubles as the sandbox doctor: each failure comes with its fix.
**Verified:** 2026-11-14
**Status:** passed
**Re-verification:** Yes, after gap closure plans 08-08 to 08-11

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP success criterion) | Status | Evidence |
|---|-----------------------------------|--------|----------|
| 1 | `sbx-selfcheck` prints one PASS or FAIL line per named check; the base image ships the runner and shared checks, each agent image adds its checks file to a fixed folder; no SKIP | VERIFIED | `outcome_lines` in `base/selfcheck/sbx_selfcheck.py` emits only `PASS: name: detail` or `FAIL: name: detail` plus an indented `fix:` line; grep for SKIP in the runner finds nothing. `base/Dockerfile:241-246` installs the launcher, runner and shared checks and links `/usr/local/bin/sbx-selfcheck`. `claude/Dockerfile:65` and `cursor/Dockerfile:56` copy `claude.py` and `cursor.py` into `/etc/sbx/selfcheck.d`, which `collect_checks` globs. Imported lists have 41 shared, 12 Claude and 10 Cursor checks, so 53 and 51 per agent. The gap closure also made an empty agent folder a `load-agent-checks` FAIL, so an image with no agent file cannot print a green list. |
| 2 | One host check (H-34) runs `sbx-selfcheck` via `docker exec` in a Claude and a Cursor test sandbox, fails on any FAIL or a wrong count; H-01, H-04, H-05, H-13, H-14, H-15, H-22, H-30 deleted; H-06, H-12, H-25 keep only the Mac parts | VERIFIED | `tests/host/h34-selfcheck.sh` runs `docker exec ... sbx-selfcheck` (line 86), classifies exit status against FAIL lines (lines 93-110), and compares `grep -Ec '^(PASS\|FAIL): '` with `expectedClaudeCount=53` and `expectedCursorCount=51`, matching the imported lists. `tests/host/` holds no h01, h04, h05, h13, h14, h15, h22 or h30 file, and `run-all.sh` and `host-test.sh` do not mention them. h06, h12 and h25 remain at 53, 34 and 75 lines. Mac `host-test.log`: `PASS: H-34 ... 53 ... 51`, `Summary: 19 passed, 0 failed, 0 not run`, `0 step(s) failed`. |
| 3 | `./host-test.sh` makes a throwaway root certificate with `openssl`, builds it into the test base image, the self-check finds it in the system bundle and Java `cacerts`; no certificate is committed | VERIFIED | `tests/host/run-all.sh:237` runs `openssl req -x509 ... -nodes` into a folder under `$TMPDIR`, and `build-ca.pem` goes into the test base build (lines 255-256). `git ls-files` lists no `.pem`, `.crt`, `.cer` or `.key`. The shared checks cover the system bundle and Java `cacerts`. Mac log: INFO line with the certificate path and SHA-256, and the H-34 PASS text "found the test root certificate in the system bundle and Java cacerts" in both sandboxes. |
| 4 | Each FAIL line carries a fix hint, with the Mac command when the fix is on the Mac; no skill wraps the self-check | VERIFIED | `failed()` rejects an empty hint and `run_check` turns a raised exception into a FAIL with a rebuild hint, so no FAIL lacks a hint. The previous gap is closed: the old `chown -R sandbox:sandbox` hint is gone (grep finds none in base, claude, cursor or tests), and `owner_fix_hint` (`shared_checks.py:259`) now prints `on the Mac run: docker run --rm --network none -u root --entrypoint chown --volumes-from sbx-NAME sbx-base:local -R 1000:1000 STATE`. Real Docker confirms it: the Mac log shows the planted root-owned folder giving `53 checks, 1 failed`, the printed fix line, and `53 checks, 0 failed` after running it. No `.claude/skills` entry exists and the only `sbx-selfcheck` mentions in agent folders are the Dockerfile copy comments and a temp prefix constant. |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

### Previous Gap Re-check

| Gap from the previous report | Status | Evidence |
|------------------------------|--------|----------|
| no-root-owned-state hint was a sandbox-side chown that cannot succeed | CLOSED | `owner_fix_hint` is a Mac throwaway root container command; the old string is gone; the Mac round trip passed (1 failed before, 0 after). |
| WR-02 (old numbering): PermissionError on a root-owned mode 700 folder | CLOSED for that shape | `scan_owned_state` catches OSError around `os.scandir` and records `path (unreadable)`; H-34 plants exactly a root-owned mode 700 folder and the FAIL names it. A narrower shape remains (new WR-01 below). |
| WR-03 (old): shared-only green when no agent checks ran | CLOSED | `collect_checks` appends `load-agent-checks` FAIL when no agent check was collected. |
| WR-04 (old): bash and keytool resolved via PATH unguarded | CLOSED | `tool-bash` and `tool-keytool` checks exist; counts rose to 41, 53 and 51 consistently across pytest, README and H-34. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `base/selfcheck/sbx-selfcheck` | launcher | VERIFIED | linked into `/usr/local/bin` by `base/Dockerfile` |
| `base/selfcheck/sbx_selfcheck.py` | runner | VERIFIED | `run_selfcheck` runs every collected check, prints the summary, exits 1 on any FAIL |
| `base/selfcheck/shared_checks.py` | shared checks | VERIFIED | 41 checks in `CHECK_LIST` |
| `claude/selfcheck/claude.py` | Claude checks | VERIFIED | 12 checks, copied by `claude/Dockerfile` |
| `cursor/selfcheck/cursor.py` | Cursor checks | VERIFIED | 10 checks, copied by `cursor/Dockerfile` |
| `tests/host/h34-selfcheck.sh` | host check | VERIFIED | wired through `tests/host/run-all.sh`; Mac run PASS |
| `tests/selftest/selfcheck/*` | pytest harness | VERIFIED | part of the 190 passing tests |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `claude/Dockerfile`, `cursor/Dockerfile` | `/etc/sbx/selfcheck.d` | `COPY --chmod=644` plus `py_compile` | WIRED |
| `collect_checks` | `/etc/sbx/selfcheck.d/*.py` | glob, import, `CHECK_LIST` | WIRED |
| `root_owned_state_result` | `owner_fix_hint` | `failed(detail, owner_fix_hint(state_dir))` | WIRED |
| `h34-selfcheck.sh` | `sbx-selfcheck` in both containers | `docker exec` | WIRED |
| `run-all.sh` | test base image | `build-ca.pem` build input | WIRED (Mac log) |

### Data-Flow Trace (Level 4)

Not applicable beyond the above: the checks read live system state (files, mounts, `keytool`, `stat`), not rendered or stored data. The owner fix text is built from constants and the scanned folder.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Self-check, runner, inventory counts and hints | `uv run pytest tests/selftest -q` | 190 passed | PASS |
| Guard rules | `bash tests/guard/run-all.sh` | "All rules hold." | PASS |
| Check list sizes | import the three lists | 41, 12, 10 (53 and 51 per agent) | PASS |
| WR-01 reproduction | `scan_owned_state` on a mode 444 folder holding a file | `PermissionError` | reproduced |
| WR-02 reproduction | `run_selfcheck` with a file holding `CHECK_LIST = None` | `TypeError` | reproduced |
| In-image run, certificate, owner fix round trip | Mac `host-test.log` (Docker not available here) | 19 passed, 0 failed; H-34 53 and 51 checks, 0 failed; owner fix before 1 failed, after 0 | PASS (log evidence) |

### Probe Execution

SKIPPED: the phase declares no `probe-*.sh` scripts.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|--------------|-------------|--------|----------|
| CHECK-01 | 08-01, 08-04 to 08-07, 08-08 to 08-11 | one PASS or FAIL line per named check, base holds runner and shared checks, agents add theirs | SATISFIED | criterion 1 |
| CHECK-02 | 08-02, 08-03, 08-04, 08-06, 08-07, 08-09 | one host check via `docker exec`, no FAIL, expected counts, in-container parts deleted | SATISFIED | criterion 2 |
| CHECK-03 | 08-02, 08-04, 08-06, 08-07 | throwaway `openssl` certificate built into the test base image, found in both stores | SATISFIED | criterion 3 |
| CHECK-04 | 08-01, 08-03, 08-05 to 08-08, 08-10, 08-11 | doctor: each FAIL has a fix hint, Mac command where needed, no skill | SATISFIED | criterion 4 |

All four IDs appear in the plan frontmatter and in REQUIREMENTS.md (lines 25-28 checked, traceability lines 83-86 Complete). No orphaned Phase 8 requirement.

### Review Warnings Weighed

| ID | Verdict | Reasoning |
|----|---------|-----------|
| WR-01 | Advisory, fix soon | Reproduced. It needs a folder with read but no search permission (for example a root-owned mode 444 folder), which a root container does not normally create; the common root-created shapes (mode 755 with root-owned files, mode 700) are handled and proven on the Mac. In the odd shape the run still fails closed: a FAIL line prints with a hint, but the hint is the generic rebuild one, not the owner fix. Criterion 4 asks that each FAIL carry a fix hint, and it does; the quality of that hint is weaker in one rare case. Not a goal gap. |
| WR-02 | Advisory | Reproduced. Only a mis-authored file in `claude/selfcheck` or `cursor/selfcheck` can trigger it. It fails closed (traceback, nonzero exit, no `53 checks` summary), so pytest, the inventory test and H-34 all catch it before an image ships; it cannot give a false green. Criterion 1 is about the shipped checks, which load fine. A tidy-up, not a goal gap. |

Both are cheap to fix together (one `except OSError` branch plus one list validation, each with a test). The disposition file still shows all seven review findings as `open`; they should be triaged (fixed, skipped or deferred) before the phase is closed.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| none | | no TBD, FIXME or XXX in the phase sources or tests | | |

Info items IN-01 to IN-05 from the review (owner fix hint printed for unreadable folders it cannot fix, hardcoded image tag in the hint, unreadable settings file worded as "not valid JSON", H-34 "after" run not re-counting, unnamed root container on timeout) are hygiene and wording; none contradicts a criterion.

### Human Verification Required

None. The Docker-dependent evidence (H-34 counts, certificate in both stores, owner fix round trip, no leftover container, images unchanged) comes from the Mac run of 2026-11-14, which the orchestrator treats as the human-verified record. No behavior-dependent truth lacks a test.

### Gaps Summary

All four success criteria hold. The earlier criterion 4 defect (a sandbox-side chown hint that cannot work) is replaced by a Mac throwaway root container command, locked by unit tests and exercised end to end by H-34 on real Docker. The related crash, the silent shared-only green, and the unguarded bash and keytool lookups are also closed. Two new review warnings remain, both reproduced and both fail-closed edge cases, so they are advisory. Recommended follow-up (not blocking): fix WR-01 and WR-02 in one small plan, or record them as deferred in `08-REVIEW-DISPOSITION.md` with a reason.

---

_Verified: 2026-11-14_
_Verifier: Claude (gsd-verifier)_
