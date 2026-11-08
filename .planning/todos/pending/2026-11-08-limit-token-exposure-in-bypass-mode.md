---
created: 2026-11-08
title: Limit what a leaked token costs when Claude runs with permissions bypassed
area: security
source: conversation during the Phase 5 migration test
---

Things to think about. No work is decided yet.

With `sbx-claude --dangerously-skip-permissions`, Claude can read and send out every token in `state/`: the Claude login (`state/claude/.credentials.json`), the gh token (`state/gh/hosts.yml`, plain text) and `state/git/config`. Deny rules do not help: Bash can still read the files. A process running as `sandbox` cannot be kept from a file `sandbox` can read, and Claude must read its own login.

Options, from cheapest:

| Option | What it buys | Cost |
|---|---|---|
| B. Fine-grained GitHub token per sandbox (one repo, contents and pull requests only, short expiry) instead of the broad `gh auth login` token | A leak reaches one repo until the token expires | README recipe; token made on github.com |
| A. No gh token in the sandbox; push and open PRs from the Mac | The gh token is never in `state/`; fits "every push needs the user's go" | Push and `gh pr create` move to the Mac; `sbx-bundle-clone` needs another way to clone |
| C. Outbound network allowlist (Anthropic, GitHub, npm) | Stops sending tokens to arbitrary hosts; GitHub stays a channel | Project-sized; against keeping the scripts small |
| Claude login | Cannot be hidden from Claude; a leak spends the subscription until logged out on claude.ai | Accept |

Leaning: B first (docs only), A for sandboxes that do not need gh inside, C only as its own phase.
