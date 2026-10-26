---
created: 2026-10-24
title: sbx-claude waits 5 seconds when nothing is linked, also in non-interactive use
area: claude
source: .planning/phases/02.2-best-practices-from-git-editable-from-any-sandbox/02.2-REVIEW.md (IN-04)
---

File: `claude/bin/sbx-claude:23`.

`sbx-claude -p "..."` or `sbx-claude --version` in a script or pipeline gets the no-clone banner on stderr and a 5 second delay each time. H-27 relies on the warning text, so any change must keep that working.

Suggested fix: sleep only when stdin and stderr are terminals, and print the warning either way.

```bash
if [ -t 0 ] && [ -t 2 ]; then
  sleep 5
fi
```

H-27 runs with stdin from `/dev/null`, so it still sees the warning.
