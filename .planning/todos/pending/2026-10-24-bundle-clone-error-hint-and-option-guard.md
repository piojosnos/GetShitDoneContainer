---
created: 2026-10-24
title: sbx-best-practices-clone blames authentication for every clone failure and passes the URL without --
area: claude
source: .planning/phases/02.2-best-practices-from-git-editable-from-any-sandbox/02.2-REVIEW.md (IN-03)
audit_acknowledged:
  milestone: v1.0
  at: 2026-11-12
---

File: `base/bin/sbx-best-practices-clone:22-24`.

Any `git clone` failure (no network, a dangling symlink at `SBX_BEST_PRACTICES_DIR` that `-e` does not see, a read-only mount, a bad URL) prints "A private repo needs sbx-gh-login first." The real git error is above it, but the hint points at the wrong fix. The URL and directory are also passed as bare arguments; a value starting with `-` would be read as an option. The URL comes from the image, so this is hardening, not an exploit.

Suggested fix:

- `git clone -- "$BEST_PRACTICES_REPO_URL" "$SBX_BEST_PRACTICES_DIR"`.
- Phrase the message as "cannot clone ...; if the repo is private, run sbx-gh-login first".
- Test existence with `[ -e "$SBX_BEST_PRACTICES_DIR" ] || [ -L "$SBX_BEST_PRACTICES_DIR" ]`.
