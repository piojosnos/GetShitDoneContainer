# Phase 6: Test diet - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log keeps the alternatives considered.

**Date:** 2026-11-13
**Phase:** 06-test-diet
**Areas discussed:** persistence proxies, trimmed checks, sbx self-test without the scripted fake, `--keep`

---

## Persistence proxies

| Option | Description | Selected |
|--------|-------------|----------|
| Plant in H-09 and H-29 | Beside the existing sentinels, one shared helper | ✓ |
| New H-34 | Own recreate and upgrade; one more slow cycle | |

**User's choice:** recommended.

## Trimmed checks (H-13, H-15, H-16, H-23)

| Option | Description | Selected |
|--------|-------------|----------|
| Keep our-setup parts | Env vars and paths, link read, relink and user files, cache folders and marker | ✓ |

**User's choice:** recommended.

## sbx self-test without the scripted fake

| Option | Description | Selected |
|--------|-------------|----------|
| Keep refusal cases with the fence | Cases that refuse before Docker stay, fence proves no call | |
| Delete the four groups | Start, shell, list, rm self-tests gone | |
| Keep refusal cases, no fence | `DOCKER_HOST=unix:///nonexistent`, no mock at all | ✓ |

**User's choice:** no fence at all; keep it simple.
**Notes:** The user asked for a plain explanation, then whether tests should always use real Docker, then how the fence is injected (a mock first on PATH, not a wrapper). They rejected any Docker mock. Changes roadmap criterion 1 and DIET-05.

## `--keep`

| Option | Description | Selected |
|--------|-------------|----------|
| Keep, reworded | Leave the sandbox up to look around after a failure | ✓ |
| Drop | Its stated purpose was the manual helpers | |

**User's choice:** recommended.

## Claude's Discretion

- Sorting the self-test cases; guard rule shape; H-11 into H-28; doc updates.

## Deferred Ideas

- A `docker` wrapper or a dry-run flag to prove no Docker call; Phase 10.
