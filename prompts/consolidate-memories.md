# Consolidate a project's memories with the bundle

Use this once, when you move an existing project into an sbx sandbox. The project's old memories and `CLAUDE.md` often repeat rules the bundle now ships. This prompt makes Claude sort them out, and it changes nothing until you approve.

How to use it:

1. Start the sandbox for the project and open Claude in the project folder.
2. Paste the prompt below.
3. Review the sorted list Claude shows, adjust it, then say go.
4. Turn the "general, not in the bundle" items into a PR to `best-practices/` in this repo.

## Prompt

```text
This project now runs in a sandbox that ships standing rules and skills. Some of them
came from this project's own memories. I want each piece of guidance to live in exactly
one place.

1. Read every file in ~/.claude/rules/ and every SKILL.md under ~/.claude/skills/ that
   is listed in ~/.claude/.best-practices-skills. These are the bundle; never edit them.
2. Read all of your memories for this project, the project's CLAUDE.md (repo root and
   .claude/CLAUDE.md, if present) and ~/.claude/CLAUDE.md.
3. Sort every memory and every CLAUDE.md item into one of these groups:
   - Covered: the bundle already says it (same meaning, even if worded differently).
     Plan to remove it.
   - Project-specific: true only for this project (its modules, paths, tools, quirks).
     Keep it where it is.
   - General, not in the bundle: would help any project, but no bundle rule covers it.
     Keep it for now and list it as a candidate bundle rule.
   - Conflicting: it disagrees with a bundle rule. Do not resolve it yourself.
4. Show me one table per group: the item, where it lives, and for Covered the bundle
   file that covers it. Then stop and wait.
5. Only after I approve: remove the Covered items and update any memory index. Leave
   everything else untouched.
```
