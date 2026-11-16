---
created: 2026-11-15
title: Audit the tests regularly and remove what no longer earns its place
area: tests
source: PR review of the in-image self-check (H-34 owner fix round trip)
---

Tests that once answered an open question keep running after the answer is settled. Example: H-34 ran the owner fix round trip on every Mac run (about 100 lines and a throwaway root container) to prove a fixed recipe that pytest already pins; it was removed in review.

Do a test audit at the end of each milestone, before archiving it:
- For each host check, self-test case and pytest module, ask what failure it catches today that nothing cheaper (pytest, the guard) catches.
- Remove or shrink the ones that only re-prove a settled fact, test a library instead of our code, or duplicate another check.
- Prefer a fast check (pytest, a guard rule) over a Docker or Mac run when it covers the same failure.
- Record what was removed and why in the milestone summary.
