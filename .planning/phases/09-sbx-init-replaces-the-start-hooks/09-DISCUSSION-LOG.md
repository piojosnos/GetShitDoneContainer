# Phase 9: sbx-init replaces the start hooks - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the alternatives considered.

**Date:** 2026-11-16
**Phase:** 09-sbx-init-replaces-the-start-hooks
**Areas discussed:** Agent wrappers, Entrypoint, Init shape, Done detection, Bundle link clashes, Diagnostics

---

## Agent wrappers

| Option | Description | Selected |
|--------|-------------|----------|
| Warn and start (as planned) | Wrapper prints a warning when init has not run, starts the agent | |
| Fail, wrappers named `claude` and `cursor-agent` | Real binaries off the PATH, wrappers take their names | |
| Fail, wrappers keep `sbx-` names, add the agents folder to PATH before exec | Real binaries off the PATH; children of the agent still find them | ✓ |

**User's choice:** Wrappers fail when init has not run; keep the `sbx-` names and export the agents folder on the PATH inside the wrapper.
**Notes:** Only GSD's `/gsd-review` looks the CLIs up with `command -v`; subagents use the agent's own tool, not the CLI.

---

## Entrypoint

| Option | Description | Selected |
|--------|-------------|----------|
| Keep the fast checks, drop the hooks | Entrypoint still refuses a plain `docker run` | |
| Delete the entrypoint | Host scripts validate; init creates state folders; self-check reports a bad mount | ✓ |

**User's choice:** Simplify: each job 100% outside or 100% inside, never split.
**Notes:** H-12 goes with the entrypoint.

---

## Init shape

| Option | Description | Selected |
|--------|-------------|----------|
| Mirror the self-check | Base runner and shared steps, agent step files in a folder, same modularization and tests | ✓ |

**User's choice:** Mirror the self-check, also in modularization.

---

## Done detection

| Option | Description | Selected |
|--------|-------------|----------|
| Check the real state | Compare synced GSD version and links with the image and clone | |
| Marker in the container layer | Written when all steps pass; a recreate or upgrade wipes it | ✓ |

**User's choice:** Marker approach. A rerun always redoes the work (no "quick no-op"); the lock stays.
**Notes:** A marker in `state/` would outlive an upgrade and lie; the container layer does not.

---

## Bundle link clashes

| Option | Description | Selected |
|--------|-------------|----------|
| Bundle wins silently | Deletes a real folder with the name (today's bug) | |
| Replace only own links, FAIL on anything else | Own links found by where they point; list file goes | ✓ |
| Atomic swap of the link set | Not possible per name in a shared `skills/` folder | |

**User's choice:** Replace only own links, FAIL on a clash. No atomicity; a rerun repairs an interrupted run.
**Notes:** The lock is only against two concurrent `sbx-init` runs (`flock`), not against the agent.

---

## Diagnostics

| Option | Description | Selected |
|--------|-------------|----------|
| Init verifies its own results | Version check after sync, link precheck | |
| All verification in the self-check | Init acts and reports only; its last line says to run `sbx-selfcheck` | ✓ |

**User's choice:** All self validation goes to the self-check; init does not run it itself.

## Claude's Discretion

Folder and marker names, the shared result module, the GSD installer handling, the ownership walk, which host checks and self-test files change, doc updates.

## Deferred Ideas

None.
