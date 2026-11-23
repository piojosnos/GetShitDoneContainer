---
created: 2026-11-23
title: A reusable script that restores the exec bit after edits in a bind mount
area: tooling
source: Best-practices audit during Phase 10.1 planning (2026-11-23)
---

Files edited from inside a sandbox on a Docker Desktop bind mount can lose their exec bit on the Mac (mode 755 becomes 644). Today the fix is done by hand from `git diff --summary`, as a project memory note describes.

Write one reusable script that finds the tracked files whose mode dropped from 755 to 644 (from `git diff --summary`) and restores the exec bit. Ship it in the sandbox image so it is ready in every sandbox, and point the memory note at it. Python, per the project rule for anything with logic.
