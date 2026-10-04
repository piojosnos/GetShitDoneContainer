---
phase: 01
review: 01-REVIEW.md
titles: json
findings:
  - id: WR-01
    severity: warning
    disposition: open
    title: "The entrypoint's \"project folder is missing\" check is defeated by `working_dir`"
  - id: WR-02
    severity: warning
    disposition: open
    title: "`create_host_path: false` is known to be ignored, and `base/Dockerfile` says the opposite"
  - id: WR-03
    severity: warning
    disposition: open
    title: "Claude Code install has no integrity verification; Node and gh checksums share an origin with the artifacts"
  - id: IN-01
    severity: info
    disposition: open
    title: "Entrypoint message says \"bind mount\" but only checks for a mount point"
  - id: IN-02
    severity: info
    disposition: open
    title: "`compose.yml` does not enforce an absolute `SBX_DIR`"
  - id: IN-03
    severity: info
    disposition: open
    title: "Base image and apt packages are not pinned by digest"
  - id: IN-04
    severity: info
    disposition: open
    title: "Entrypoint reports a raw `mkdir` error when `state/` is not writable"
open: 7
total: 7
recorded: 2026-10-04T02:22:33.919Z
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
