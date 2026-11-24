---
created: 2026-11-24
title: Audit which frontmatter fields the practice masters should allow
area: best-practices
source: Phase 10.1 execution, a merged skill used disable-model-invocation (2026-11-24)
---

The generator refuses every frontmatter key it does not know. That is on purpose: a new key stops the generator instead of being silently dropped. Phase 10.1 found the first one, `disable-model-invocation`, when the `pre-pr-review` skill came in from main, and it was allowed.

Before the next agent (Phase 10.2, OpenCode) adds another output format, make one list of fields instead of finding them one by one:

- Read the Agent Skills spec (agentskills.io) and the skill and rule docs of every agent we generate for: Claude Code, Cursor, OpenCode.
- Sort each field into: allow and pass through, map to another agent's field, or refuse on purpose (with the reason).
- Candidates for skills include `license`, `compatibility`, `metadata`, `allowed-tools`, `user-invocable`, `argument-hint` and `model`. For rules, `description` (see the todo on rule descriptions).
- Allow only the fields a practice needs today; keep the list of the others with their decision, so the next refused key has a ready answer.
