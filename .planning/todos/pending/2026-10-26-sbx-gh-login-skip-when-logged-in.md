---
created: 2026-10-26
title: sbx-gh-login runs the whole gh device login again when gh is already logged in
area: claude
source: .planning/phases/02.2-best-practices-from-git-editable-from-any-sandbox/02.2-UAT.md (test 3)
---

Files: `claude/bin/sbx-gh-login:51`.

In the 2026-10-26 UAT run, the first `sbx-gh-login` logged in and asked for the git name and email as intended. A second run started a new device login (new one-time code) instead of noticing the existing login, so the user pressed Ctrl-C and the "set values are left alone" path was never reached (`set -e` stops before `ask_git_setting`).

gh also prints two harmless warnings in the container: no clipboard tool for the code, and no browser to open the URL.

Suggested fix:

- Run `gh auth login` only when `gh auth status --hostname github.com` fails; always run `gh auth setup-git` and the identity questions.
- Optionally say in the script's first line of output to open the URL on the Mac and type the code, so the two gh warnings read as expected.
