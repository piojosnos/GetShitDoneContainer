---
created: 2026-11-23
title: Optional description key in the practice rule masters
area: best-practices
source: Phase 10.1 planning, the master format pick (2026-11-23)
---

The rule masters in the best-practices repo use Claude's format: plain `.md` with one optional `paths:` list in the frontmatter. The generator accepts no other key, so Cursor rules come out with `globs` (from `paths`) and `alwaysApply` (true without `paths`), but no `description`.

Cursor uses `description` only in its "agent picks the rule by description" mode, which nothing needs today.

When a rule should load by description (in Cursor, or in a later agent with the same mode):

- allow an optional `description:` key in the rule masters (Claude ignores keys it does not know, so its output is unaffected);
- render it into the Cursor template, and into any other agent's template that has a matching field;
- decide how a rule with a `description` and no `paths` maps to `alwaysApply` in Cursor.
