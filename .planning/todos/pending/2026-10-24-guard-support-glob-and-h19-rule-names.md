---
created: 2026-10-24
title: Guard glob narrowed to tests/host/support/*.*, and H-19 hard-codes external rule file names
area: tests
source: .planning/phases/02.2-best-practices-from-git-editable-from-any-sandbox/02.2-REVIEW.md (IN-06)
---

Files: `tests/guard/supply-chain.sh:14`, `tests/host/manual/h19-bundle-behaviour.sh:75` and `:161`.

`tests/host/support/*` became `tests/host/support/*.*`, so an extensionless file added under `tests/host/support/` is no longer scanned for the compromised package name. Separately, H-19 hard-codes `rules/communication.md` and `rules/best-practices.md` of the external bundle repo; a rename there fails H-19 with a message that blames the clone, not the helper.

Suggested fix:

- Use `tests/host/support/*` plus the two `bundle/` globs, or `find`.
- In H-19, derive the rule file from the clone (the first always-on rule) instead of naming it, as `h18-scope-and-deny.sh:63-70` does.
