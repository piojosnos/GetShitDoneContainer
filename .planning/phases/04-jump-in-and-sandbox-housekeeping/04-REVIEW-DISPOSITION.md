---
phase: 04
review: 04-REVIEW.md
titles: json
findings:
  - id: WR-01
    severity: warning
    disposition: open
    title: "H-31 greps for \"TTY\" but SANDBOX.md says newer Docker prints a different message"
  - id: WR-02
    severity: warning
    disposition: open
    title: "`sbx-rm` cannot clean up the entries `sbx-list` reports as broken"
  - id: WR-03
    severity: warning
    disposition: open
    title: "`sbx-shell` and `sbx-start` blame a missing image when Docker is simply not running"
  - id: WR-04
    severity: warning
    disposition: open
    title: "`sbx-rm` takes down a running sandbox with no confirmation and the default 10 s stop timeout"
  - id: WR-05
    severity: warning
    disposition: open
    title: "H-33 volume and container snapshots can pass vacuously when Docker errors"
  - id: IN-01
    severity: info
    disposition: open
    title: "Guard for `sbx-rm` is a pattern list with holes"
  - id: IN-02
    severity: info
    disposition: open
    title: "`sbx-list` finds containers by label but `sandbox_is_running` and `runs_older_image` find them by name"
  - id: IN-03
    severity: info
    disposition: open
    title: "H-33 moves the test sandbox folder with no cleanup path"
  - id: IN-04
    severity: info
    disposition: open
    title: "The failed-entry-delete branch of `sbx-rm` has no test"
  - id: IN-05
    severity: info
    disposition: open
    title: "`warn_sessions_close` writes a warning to stdout"
open: 10
total: 10
recorded: 2026-11-07T23:45:47.296Z
---

# Phase 04: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| WR-01 | warning | open | - |
| WR-02 | warning | open | - |
| WR-03 | warning | open | - |
| WR-04 | warning | open | - |
| WR-05 | warning | open | - |
| IN-01 | info | open | - |
| IN-02 | info | open | - |
| IN-03 | info | open | - |
| IN-04 | info | open | - |
| IN-05 | info | open | - |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
