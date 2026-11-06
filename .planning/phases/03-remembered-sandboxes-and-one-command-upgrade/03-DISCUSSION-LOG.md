# Phase 3: Remembered Sandboxes and One-Command Upgrade - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the alternatives considered.

**Date:** 2026-11-06
**Phase:** 03-remembered-sandboxes-and-one-command-upgrade
**Areas discussed:** Registry, Scripts and location, Stop and upgrade semantics, Version printout

All four areas were presented at once in prose, each with a recommendation; the user answered per area.

---

## Registry

| Option | Description | Selected |
|--------|-------------|----------|
| One file per sandbox in `~/.config/sbx/sandboxes/<name>` | `SBX_DIR=` and `SBX_AGENT=claude`, read line by line, outside every sandbox mount | ✓ |
| Registry inside the repo | Agent-writable, because the repo is checked out inside a sandbox mount | |
| One shared table file | Harder with bash 3.2 and paths with spaces | |

**User's choice:** One file per sandbox at `~/.config/sbx/sandboxes/<name>`.
**Notes:** Sub-picks taken as recommended (user did not object): refuse an already registered name; create the host folder when missing.

---

## Scripts and location

| Option | Description | Selected |
|--------|-------------|----------|
| `sbx-add`, `sbx-start`, `sbx-stop`, `sbx-upgrade` in `bin/` on `PATH`, shared `bin/sbx-lib.sh` | Phase 4 commands go next to them | ✓ |
| Scripts at the repo root next to `build.sh` | Fewer folders, one flat list | |

**User's choice:** Agreed with the `bin/` layout.

---

## Stop and upgrade semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Stop = `docker compose stop` (container kept) | Fits Phase 4's remove and list commands | ✓ |
| Stop = `docker compose down` | Removes the container | |
| Upgrade recreates without asking, prints a warning line | User ran it on purpose | ✓ |
| Upgrade asks before killing open sessions | | |

**User's choice:** Stop keeps the container; `sbx-upgrade <name>` rebuilds and recreates that sandbox, killing its shells and Claude sessions.

---

## Version printout

| Option | Description | Selected |
|--------|-------------|----------|
| A. Ask each tool at every shell open | About 2 to 3 seconds per shell (Java, Maven) | |
| B. Write versions to a file at build time, print it | Instant; build smoke tests keep it correct | ✓ |
| One line | Short, shown at every shell | ✓ |
| Small block, one tool per line | | |

**User's choice:** B, single line.
**Notes:** The first explanation was too dense; the user asked for a simpler one, which led to the A/B table.

## Claude's Discretion

- Script wording, version file location and shell hook, whether `sbx-start` waits for start hooks, `build.sh` option pass-through, how host checks isolate the registry.

## Deferred Ideas

None.
