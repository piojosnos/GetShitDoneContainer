---
created: 2026-10-16
title: Shell diet second PR (approved re-scan cuts)
area: tests
source: .planning/phases/02.1-shell-diet/02.1-RESCAN.md
---

Plan and ship the second code PR from Phase 2.1's re-scan, on a branch cut from main after PR #20 merges.

Scope: the 18 rows marked `approved 2026-10-15` in `02.1-RESCAN.md` (R-01, R-02, R-04 to R-13, R-15 to R-20). R-03 and R-14 are rejected. About 1020 lines, 50 of them shipped; brings shipped shell to about 700 (the restated Phase 2.1 goal).

Also fold in the deferred review findings from `02.1-REVIEW-DISPOSITION.md`: WR-03 (planted failures for three guard rules) and WR-04 (Mac-shell step ignores both linter rules by name). WR-01, WR-02, WR-05 are R-17, R-20, R-19.

After editing executables in the sandbox, run the exec-bit fix on the Mac before testing (`git diff --summary` mode changes), then `./host-test.sh`.
