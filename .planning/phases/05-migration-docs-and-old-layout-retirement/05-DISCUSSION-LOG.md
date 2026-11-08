# Phase 5: Migration, Docs, and Old-Layout Retirement - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the alternatives considered.

**Date:** 2026-11-08
**Phase:** 05-migration-docs-and-old-layout-retirement
**Areas discussed:** Migration approach, Docs layout, Recipe shape, This dev sandbox, Old layout removal, Threat model host git, Verification

---

## Migration approach (before the formal discussion)

| Option | Description | Selected |
|--------|-------------|----------|
| Fresh start | sbx-add, move code, log in again; lose resume and ccusage history | |
| Copy-in recipe in docs | About 8 cp/mv lines per sandbox; keeps login, sessions, usage | ✓ |
| Migration script | One command, but more shell to write and test | |

**User's choice:** Recipe. "I don't want a complex migration script, I cannot stomach more shell, more running, testing." Fine with migrating all 4 by hand "as long as you give me a solid, clean, simple readme that is easy to follow, copy/pasting commands."

## Docs layout

| Option | Description | Selected |
|--------|-------------|----------|
| SANDBOX.md becomes README.md, separate MIGRATION.md | One main doc; one-time recipe out of the way | ✓ |
| Migration as a README section | Everything in one file | |

**User's choice:** Recommended. "Make sure SANDBOX (new README) is an incredible simple, streamlined, easy to read, schematic, document."

## Recipe shape

| Option | Description | Selected |
|--------|-------------|----------|
| Copy into new folder, variables at top, carry state, skip caches, 3 checks at end | Old folder is the rollback | ✓ |
| Move in place | No duplicate disk use, no rollback | |

**User's choice:** Recommended.

## This dev sandbox

| Option | Description | Selected |
|--------|-------------|----------|
| Separate Mac tools clone, migrate last | sbx-add refuses a folder holding the repo the Mac runs | ✓ |

**User's choice:** Recommended.

## Old layout removal

| Option | Description | Selected |
|--------|-------------|----------|
| Delete ClaudeCode/ and OpenCode/, last step after all 4 migrated | Git history keeps them | ✓ |
| Keep OpenCode/ | Until the next milestone | |

**User's choice:** Recommended.

## Threat model: host git

| Option | Description | Selected |
|--------|-------------|----------|
| Document as a rule | No new code | ✓ |
| Host git wrapper, Edit deny, separate git dir | New code | |

**User's choice:** Document.

## Verification

| Option | Description | Selected |
|--------|-------------|----------|
| User migrates the smallest sandbox; README points at host-test.sh for DOC-04 | No new tests | ✓ |

**User's choice:** Recommended.

## Claude's Discretion

- README and MIGRATION.md structure and wording, within the simplicity bar.
- cp vs rsync; how the tools clone goes on PATH.

## Deferred Ideas

- 10 pending script/test todos stay pending (they add shell work the phase rules out).
