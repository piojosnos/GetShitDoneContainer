---
phase: 03-remembered-sandboxes-and-one-command-upgrade
source: 03-REVIEW.md
updated: 2026-11-07
counts:
  fixed: 4
  deferred: 5
  open: 0
---

# Phase 3 code review disposition

| Finding | Severity | Disposition | Where |
|---------|----------|-------------|-------|
| CR-01 | blocker | fixed | ae1763f; proven on the Mac (self-test "the repo folder" group, host-test.log at eb04e2c) |
| WR-01 | warning | fixed | 2bb1261; self-test "sbx-start when the container disappears" |
| WR-02 | warning | fixed | addc6cd; self-test "sbx-start on a running sandbox", H-28 no false warning on the Mac |
| WR-03 | warning | fixed | 841ba8c; self-test "one folder under another name", letter-case case PASS on APFS |
| IN-01 | info | deferred | the "never delete" guard is a grep with gaps; follow-up |
| IN-02 | info | deferred | sbx-stop says "is stopped" for a sandbox never created; follow-up |
| IN-03 | info | deferred | one stray file in the registry folder blocks every sbx-add; follow-up |
| IN-04 | info | deferred | the pgrep readiness probe can pass early; follow-up |
| IN-05 | info | deferred | mac_sbx_selftest leaves its temp folder after an interrupt; follow-up |

Also fixed after the Mac run: eb04e2c, the shellcheck SC2154 note in bin/sbx-start that the fix for WR-02 needed.
