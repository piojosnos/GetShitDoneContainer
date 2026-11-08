# Phase 4: Jump-In and Sandbox Housekeeping - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the alternatives considered.

**Date:** 2026-11-07
**Phase:** 04-jump-in-and-sandbox-housekeeping
**Areas discussed:** Jump-in command shape, Older image on jump-in, List contents, Remove semantics

---

## Jump-in command shape

| Option | Description | Selected |
|--------|-------------|----------|
| `sbx-enter NAME [claude [ARGS...]]` | One command, shell or Claude, args passed to Claude | |
| Two commands (`sbx-shell`, a Claude launcher) | Each name says what it does | |
| `sbx-enter NAME --claude` | Flag form; awkward arg pass-through | |

**User's choice:** Separate, simpler commands; no Claude launcher at all. Open a shell, run `sbx-claude` in it.
**Notes:** This drops "optionally launching claude directly" from SCR-04 and success criterion 2; both were amended. Name `sbx-shell` proposed and taken.

---

## Older image on jump-in

| Option | Description | Selected |
|--------|-------------|----------|
| Enter as is, print a one-line hint | Keeps other sessions alive | |
| Recreate on the new image first | Newest tools, kills open sessions | |

**User's choice:** Enter as is, with no message. Show image age in the list instead.
**Notes:** User first asked what "older" means; clarified it is a previous build of `sbx-claude:local` (after `sbx-upgrade` of another sandbox), not the legacy `cc_*` layout.

---

## List contents

| Option | Description | Selected |
|--------|-------------|----------|
| Registered sandboxes plus an unregistered-leftovers section, older-image marker | Nothing hidden | ✓ |
| Registered sandboxes only | Simpler | |

**User's choice:** Recommended option.

---

## Remove semantics

| Option | Description | Selected |
|--------|-------------|----------|
| `sbx-rm NAME [--unregister]`, compose down, warning, no prompt | Nothing on disk can be lost | ✓ |
| Same, with a y/n prompt when running | More friction | |
| Refuse a running sandbox | Extra stop step | |

**User's choice:** Recommended option.

---

## Claude's Discretion

- Output layout and wording of the three scripts.
- Handling of an unreadable registry entry in the list, of `sbx-rm` with no container, and a cleanup hint for leftovers.
- How the host checks prove the scripts.

## Deferred Ideas

None.
