---
phase: 08
review: 08-REVIEW.md
titles: json
findings:
  - id: WR-01
    severity: warning
    disposition: open
    title: "scan_owned_state still raises on a folder that lists but cannot be searched"
  - id: WR-02
    severity: warning
    disposition: open
    title: "a malformed CHECK_LIST still crashes the whole runner"
  - id: IN-01
    severity: info
    disposition: open
    title: "the owner fix hint is also printed for unreadable folders it cannot fix"
  - id: IN-02
    severity: info
    disposition: open
    title: "the hint hardcodes the image tag and the container name pattern"
  - id: IN-03
    severity: info
    disposition: open
    title: "an unreadable settings file is reported as \"not valid JSON\""
  - id: IN-04
    severity: info
    disposition: open
    title: "the H-34 \"after\" run asserts only that one check stopped failing"
  - id: IN-05
    severity: info
    disposition: open
    title: "root_run leaves an unnamed container behind when it times out"
open: 7
total: 7
recorded: 2026-11-14T22:18:38.004Z
---

# Phase 08: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| WR-01 | warning | open | - |
| WR-02 | warning | open | - |
| IN-01 | info | open | - |
| IN-02 | info | open | - |
| IN-03 | info | open | - |
| IN-04 | info | open | - |
| IN-05 | info | open | - |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
