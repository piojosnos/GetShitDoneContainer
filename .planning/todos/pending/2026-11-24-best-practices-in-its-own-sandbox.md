---
created: 2026-11-24
title: Develop the best-practices repo in its own sandbox
area: best-practices
source: User request during Phase 10.1 execution (2026-11-24)
---

Today the best-practices clone is changed from the sandbox of this repo, so one phase commits to two repos. Once the shape of `generated/<agent>/` is settled, practices work no longer needs this repo.

Give the best-practices repo its own sandbox with its own GSD planning, branches and PRs. Do it after Phase 10.1.1, which still changes the linker here and the generated output there together.

Points to settle:
- The sandbox name cannot be `best-practices` (a reserved name); pick another, for example `practices`.
- That sandbox works on a project clone of the repo, apart from the clone whose `generated/` its agent loads, so a half-finished edit never changes the practices the agent itself follows.
