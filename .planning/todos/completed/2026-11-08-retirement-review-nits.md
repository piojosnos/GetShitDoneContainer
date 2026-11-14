---
created: 2026-11-08
title: Fix the two wording nits from the phase 5 code review
area: docs
source: .planning/phases/05-migration-docs-and-old-layout-retirement/05-REVIEW.md (IN-01, IN-02)
audit_acknowledged:
  milestone: v1.0
  at: 2026-11-12
resolves_phase: 6
---

Two info findings left out of the retirement PR on purpose; fold them into phase 5.1.

| ID | File | Change |
|---|---|---|
| IN-01 | `tests/guard/isolation.sh:28` | The comment says volumes stay "because removing them is how the old layout lost data". State the reason on its own, for example: "volumes stay because they hold the sandbox's data, and a compose down with volumes would delete it." |
| IN-02 | `tests/README.md:25` | "Old dev sandbox or a Mac shell by hand without the linters" now reads as the retired layout. Reword to "A dev sandbox without the linters, or a Mac shell by hand: ...". |

Leave `bin/sbx-list:22` and `tests/host/h32-sbx-list.sh:100` as they are while old `cc_` containers can still sit on the Mac.
