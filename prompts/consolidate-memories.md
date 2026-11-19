# Consolidate a project's memories with the best-practices repo

Use this once, when you move an existing project into an sbx sandbox. The project's old memories and `CLAUDE.md` often repeat rules the best-practices repo now ships. This prompt makes Claude sort them out, and it changes nothing until you approve.

How to use it:

1. Start the sandbox for the project and open Claude in the project directory.
2. Paste the prompt below.
3. Review the sorted list Claude shows, adjust it, then say go.
4. Turn the "general, not in the best-practices repo" items into a PR against the best-practices repo: edit the clone at `/home/sandbox/workspace/best-practices` on a branch (see [`README.md`](../README.md), "Best-practices clone").

## Prompt

```text
This project now runs in a sandbox that ships standing rules and skills. Some of them
came from this project's own memories. I want each piece of guidance to live in exactly
one place.

1. Read every file in ~/.claude/rules/ and every SKILL.md under ~/.claude/skills/ that
   is a link into the clone at /home/sandbox/workspace/best-practices. These are the
   best-practices rules and skills; do not edit them during this task.
2. Read all of your memories for this project, the project's CLAUDE.md (repo root and
   .claude/CLAUDE.md, if present) and ~/.claude/CLAUDE.md.
3. Sort every memory and every CLAUDE.md item into one of these groups:
   - Covered: the best-practices repo already says it (same meaning, even if worded
     differently). Plan to remove it.
   - Project-specific: true only for this project (its modules, paths, tools, quirks).
     Keep it where it is.
   - General, not in the best-practices repo: would help any project, but no
     best-practices rule covers it. Keep it for now and list it as a candidate
     best-practices rule.
   - Conflicting: it disagrees with a best-practices rule. Do not resolve it yourself.
4. Show me one table per group: the item, where it lives, and for Covered the
   best-practices file that covers it. Then stop and wait.
5. Only after I approve: remove the Covered items and update any memory index. Leave
   everything else untouched.
```
