---
created: 2026-10-24
title: Bundle hook is not atomic and verifies only the rules link
area: claude
source: .planning/phases/02.2-best-practices-from-git-editable-from-any-sandbox/02.2-REVIEW.md (WR-04)
---

File: `claude/start.d/10-best-practices:35-77`.

`remove_old_links` deletes the old links and the skill list first. `link_bundle` then creates the rules link, truncates and refills the list one skill at a time, and only at the end runs the `-ef` check on `rules`. If `ln` fails midway (`set -e`) or the check fails, the start stops with some skill links created and the list incomplete. The next start does not remove the unlisted links, so a skill later dropped from the clone leaves a dangling, unlisted link in `state/claude/skills` for good. Skill links are never verified; they are hard-coded to `../../../best-practices/...` and only resolve if `rules` does. The `-ef` check also comes after the work, not before it.

Suggested fix: verify before writing, and build the list in a temp file that replaces `.best-practices-skills` at the end.

```bash
[ -d "$bundleDir/rules" ] || ...
# after each ln:
[ -d "$configDir/skills/$skillName" ] || { echo "[sbx] ERROR: link for $skillName is broken" >&2; exit 1; }
# write names to "$skillList.new", then: mv "$skillList.new" "$skillList"
```

Alternative: create the new links first, then remove only the listed names that are no longer in the clone.
