---
created: 2026-10-24
title: Bundle hook silently deletes a user skill that shares a bundle skill's name
area: claude
source: .planning/phases/02.2-best-practices-from-git-editable-from-any-sandbox/02.2-REVIEW.md (WR-01)
---

File: `claude/start.d/10-best-practices:44` and `:70`.

`link_bundle` runs `rm -rf "$configDir/skills/$skillName"` for every skill in the clone, and `remove_old_links` does the same for every name in `.best-practices-skills`. Neither checks that the target is a symlink. A real skill folder with the same name (the user's own, or a bundle skill copied and customised) is deleted with no backup and no message. A later pull that adds a bundle skill with a name the user already uses has the same effect. `SANDBOX.md` promises that your own skills are never touched.

Suggested fix: only remove what the hook itself created, and refuse to overwrite anything else.

```bash
if [ -e "$target" ] && [ ! -L "$target" ]; then
  echo "[sbx] ERROR: $target exists and is not a link; move it away or rename the bundle skill." >&2
  exit 1
fi
rm -f "$target"
ln -s "../../../best-practices/skills/$skillName" "$target"
```

Apply the same link test in `remove_old_links` (`rm -f` for links, skip real folders with a warning). Keep the upgrade-from-copies migration working (`case_upgrade_from_copies` in `tests/selftest/entrypoint/bundle-hook.sh`): a name listed in `.best-practices-skills` stays replaceable.
