# Phase 1: Two-Mount Claude Sandbox - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-30
**Phase:** 01-two-mount-claude-sandbox
**Areas discussed:** Repo layout & naming, Phase 1 image contents, Running without scripts, State folder shape

---

## Repo layout & naming

| Option | Description | Selected |
|--------|-------------|----------|
| Top-level base/ claude/ | base/, claude/, compose.yml at the repo root; already the final shape after Phase 5 | ✓ |
| Under one sandbox/ dir | Everything new under sandbox/; easier to tell old from new, but needs a move later | |

| Option | Description | Selected |
|--------|-------------|----------|
| sbx | sbx-<name>, sbx-base:local, sbx-claude:local | ✓ |
| gsd-sbx | Longer, more explicit in docker ps | |

| Option | Description | Selected |
|--------|-------------|----------|
| No: sbx-<name> | One container per project; agent is a registry field | ✓ |
| Yes: sbx-claude-<name> | Room for several agents per project | |

---

## Phase 1 image contents

| Option | Description | Selected |
|--------|-------------|----------|
| npm, pinned now | npm -g @anthropic-ai/claude-code@<ver>, DISABLE_UPDATES=1; needs Node 24 | ✓ |
| Native installer, as today | curl \| bash, unpinned | |

| Option | Description | Selected |
|--------|-------------|----------|
| Ubuntu 24.04 + git/gh/curl + Node 24 | Minimal; the toolchain comes in Phase 2 | ✓ |
| Full toolchain now | Adds JDK/Maven/Python/uv in Phase 1 | |

| Option | Description | Selected |
|--------|-------------|----------|
| No GSD until Phase 2 | Phase 1 is a layout test bed | ✓ |
| Manual npx into state | Documented one-time install | |
| Bake + sync already | Pulls TOOL-02 forward | |

---

## Running without scripts

| Option | Description | Selected |
|--------|-------------|----------|
| Inline env vars | SBX_NAME=… SBX_DIR=… docker compose up -d | ✓ |
| Per-sandbox .env file | --env-file foo.env | |

**Notes:** The user asked what the most future-proof way was to get a registry you call by name. Answer: `compose.yml` only uses `${SBX_NAME}` / `${SBX_DIR}`, so inline vars now and a Phase 3 registry env file passed with `--env-file` are interchangeable. Also: put `name:` and `container_name` inside `compose.yml`, and mark the variables as required. Caveat: exported shell vars override env-file values.

| Option | Description | Selected |
|--------|-------------|----------|
| sleep infinity + docker exec | init: true; many shells; exiting a shell never stops the container | ✓ |
| tty bash, like today | bash as PID 1 | |

**Notes:** The user confirmed this matches today's workflow (start, attach multiple shells, bring it down). The only internal difference is a clean, fast stop.

| Option | Description | Selected |
|--------|-------------|----------|
| Refuse to start, clear error | Catches SBX_DIR typos | ✓ |
| Let Docker create them | Silent empty sandbox on typo | |

---

## State folder shape

| Option | Description | Selected |
|--------|-------------|----------|
| state/shell/bash_history | Directory mount, HISTFILE | ✓ |
| Inside state/claude/ | No extra mount; mixes concerns | |

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, both under state/ | GH_CONFIG_DIR → state/gh, GIT_CONFIG_GLOBAL → state/git/config | ✓ |
| Git identity only | Redo gh auth after recreate | |
| Neither for now | LAY-03 only | |

---

## Claude's Discretion

- One state/ mount vs. per-subdirectory mounts; whether shell/gh/git subdirectories are auto-created
- Entrypoint shape and when to introduce entrypoint.d/
- HISTFILE wiring and history-append behavior across concurrent shells
- Node 24 install method and the exact Claude Code pin
- Where the Phase 1 usage and verification steps are documented

## Deferred Ideas

None.
