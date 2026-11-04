---
created: 2026-10-24
title: sbx-bundle-clone blames authentication for every clone failure and passes the URL without --
area: claude
source: .planning/phases/02.2-best-practices-from-git-editable-from-any-sandbox/02.2-REVIEW.md (IN-03)
---

File: `claude/bin/sbx-bundle-clone:22-24`.

Any `git clone` failure (no network, a dangling symlink at `SBX_BUNDLE_DIR` that `-e` does not see, a read-only mount, a bad URL) prints "A private repo needs sbx-gh-login first." The real git error is above it, but the hint points at the wrong fix. The URL and directory are also passed as bare arguments; a value starting with `-` would be read as an option. The URL comes from the image, so this is hardening, not an exploit.

Suggested fix:

- `git clone -- "$BUNDLE_REPO_URL" "$SBX_BUNDLE_DIR"`.
- Phrase the message as "cannot clone ...; if the repo is private, run sbx-gh-login first".
- Test existence with `[ -e "$SBX_BUNDLE_DIR" ] || [ -L "$SBX_BUNDLE_DIR" ]`.
