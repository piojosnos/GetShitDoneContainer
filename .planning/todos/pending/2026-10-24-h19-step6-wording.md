---
created: 2026-10-24
title: H-19 step 6 says Claude must refuse, but Claude rightly edits the real file in the clone
area: tests
source: .planning/phases/02.2-best-practices-from-git-editable-from-any-sandbox/02.2-UAT.md (test 1)
---

Files: `tests/host/manual/h19-bundle-behaviour.sh:87` and `:207-209`.

In the attended run on 2026-10-24, Claude saw that `~/.claude/skills/merged` is a link and edited `skills/merged/SKILL.md` in the clone by its real path, as `SANDBOX.md` says to. It never tried the denied path, so step 6 printed FAIL although the behaviour is the intended one. The deny itself is proven by H-18.

Suggested fix:

- Reword step 6 and its question: "Claude did not write through `~/.claude/skills`; it refused, or edited the real file in the clone".
- Or drop step 6 from H-19 and leave the deny to H-18.
