---
phase: 01
review: 01-REVIEW.md
titles: json
findings:
  - id: WR-01
    severity: warning
    disposition: open
    title: "\"History is shared between all open shells\" is not delivered by `history -a` alone"
  - id: WR-02
    severity: warning
    disposition: open
    title: "H-06 overwrites the user's persistent git identity with \"T\""
  - id: WR-03
    severity: warning
    disposition: open
    title: "Claude Code install has no integrity verification, and the Node and gh checksums come from the same origin as the artifacts"
  - id: IN-01
    severity: info
    disposition: open
    title: "Entrypoint cannot tell a bind mount from tmpfs or a named volume, but its message and the docs claim it can"
  - id: IN-02
    severity: info
    disposition: open
    title: "Orphaned section comment in base/Dockerfile"
  - id: IN-03
    severity: info
    disposition: open
    title: "SANDBOX.md misdescribes the SBX_NAME rule"
  - id: IN-04
    severity: info
    disposition: open
    title: "Hardcoded base commit in the static checker will fail on any later legitimate edit"
open: 7
total: 7
recorded: 2026-10-01T18:48:50.911Z
---

# Phase 01: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| WR-01 | warning | open | - |
| WR-02 | warning | open | - |
| WR-03 | warning | open | - |
| IN-01 | info | open | - |
| IN-02 | info | open | - |
| IN-03 | info | open | - |
| IN-04 | info | open | - |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
