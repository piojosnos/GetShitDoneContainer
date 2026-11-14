---
phase: 07
review: 07-REVIEW.md
titles: json
findings:
  - id: WR-01
    severity: warning
    disposition: fixed
    title: "H-25 failure message tells the user to rebuild the wrong images"
  - id: WR-02
    severity: warning
    disposition: fixed
    title: "A leaked `SBX_IMAGE_TAG=test` silently moves a real sandbox onto the test images"
  - id: IN-01
    severity: info
    disposition: open
    title: "The `:local\\b` guard blocks testing the default tag on real Compose"
  - id: IN-02
    severity: info
    disposition: open
    title: "H-03 image check is a substring match"
  - id: IN-03
    severity: info
    disposition: fixed
    title: "The tag allow-list is written in two places with no drift check"
  - id: IN-04
    severity: info
    disposition: open
    title: "`run_build_without_docker` depends on build.sh's exact first output and tool set"
open: 3
total: 6
recorded: 2026-11-14T05:11:13.497Z
---

# Phase 07: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| WR-01 | warning | fixed | quick 261114-9ma (aa45f08) |
| WR-02 | warning | fixed | quick 261114-9ma (5d1eccb) |
| IN-01 | info | open | - |
| IN-02 | info | open | - |
| IN-03 | info | fixed | PR #41 review (8b11423) |
| IN-04 | info | open | - |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
