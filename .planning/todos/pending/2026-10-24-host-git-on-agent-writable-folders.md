---
created: 2026-10-24
title: Host git on agent-writable project folders needs its own design
area: security
source: .planning/phases/02.2-best-practices-from-git-editable-from-any-sandbox/02.2-REVIEW.md (CR-01, follow-up)
---

Running git, or an IDE's git integration, on the Mac in `$SBX_DIR/$SBX_NAME` executes hooks and config the agent can plant in the folder's `.git`: `.git/hooks/*`, and config such as `core.fsmonitor`, `core.pager`, `diff.external`, `credential.helper`, `core.sshCommand`. That breaks "Agents never run on the host".

The best-practices clone is now covered by documentation (never run git on it from the Mac; use the sandbox and the PR on GitHub). The project folder has the same exposure, and it was accepted so far as the cost of a bind mount. It needs a decision of its own.

Options to weigh:

- Document the same rule for the project folder (git only inside the sandbox).
- Deny the Edit tool on `.git/**` of the project and the clone in the managed settings (defense in depth only; Bash can still write there).
- Give the user a host wrapper that runs git with the executable config neutralised, for example `git -c core.fsmonitor=false -c core.hooksPath=/dev/null`.
- Keep a separate git dir outside the mount (`--separate-git-dir`) so the agent cannot write it.
