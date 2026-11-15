---
phase: 08
review: 08-REVIEW.md
titles: json
findings:
  - id: WR-03
    severity: warning
    disposition: fixed
    title: "a check that returns something other than a CheckResult still crashes the runner"
  - id: IN-09
    severity: info
    disposition: fixed
    title: "one failing entry marks the whole folder and drops its siblings"
  - id: WR-01
    severity: warning
    disposition: fixed
    title: "scan_owned_state still raises on a folder that lists but cannot be searched"
  - id: WR-02
    severity: warning
    disposition: fixed
    title: "a malformed CHECK_LIST still crashes the whole runner"
  - id: IN-01
    severity: info
    disposition: deferred
    title: "the owner fix hint is also printed for unreadable folders it cannot fix"
  - id: IN-02
    severity: info
    disposition: deferred
    title: "the hint hardcodes the image tag and the container name pattern"
  - id: IN-03
    severity: info
    disposition: deferred
    title: "an unreadable settings file is reported as \"not valid JSON\""
  - id: IN-04
    severity: info
    disposition: deferred
    title: "the H-34 \"after\" run asserts only that one check stopped failing"
  - id: IN-05
    severity: info
    disposition: deferred
    title: "root_run leaves an unnamed container behind when it times out"
open: 0
total: 9
recorded: 2026-11-14T23:13:51.467Z
---

# Phase 08: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| WR-03 | warning | fixed | a63844b, 9cd424b: a check that returns something other than a CheckResult is that check's own FAIL with the rebuild fix, plan 08-13 |
| IN-09 | info | fixed | 41cad9a, 4621eb0: only a PermissionError names the folder as unreadable, any other entry error surfaces as the runner's raised FAIL, and the relative folder path is computed once, plan 08-13 |
| WR-01 | warning | fixed | 6c1e974, 8fe8562: a folder that lists but cannot be searched is named with (unreadable) and gets the Mac owner fix, plan 08-12 (not in the current review) |
| WR-02 | warning | fixed | 72e8daf, 5d4ef02: a CHECK_LIST that is not a list of checks is that file's load FAIL with the rebuild fix, plan 08-12 (not in the current review) |
| IN-01 | info | deferred | Phase 10: needs a call on the hint for an unreadable folder the sandbox user owns (skip it or give it a chmod hint); in the 2026-11-14 selfcheck-review-follow-ups todo (not in the current review) |
| IN-02 | info | deferred | Phase 10: the image tag has to reach the container through compose.yml, which this gap closure leaves alone; in the same todo (not in the current review) |
| IN-03 | info | deferred | Phase 10: message wording in claude.py and cursor.py, best fixed together with their tests; in the same todo (not in the current review) |
| IN-04 | info | deferred | Phase 10: H-34 is a bash host check that Phase 10 rewrites in Python (HOST-01, HOST-05); in the same todo (not in the current review) |
| IN-05 | info | deferred | Phase 10: the same bash host check rewrite; in the same todo (not in the current review) |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
