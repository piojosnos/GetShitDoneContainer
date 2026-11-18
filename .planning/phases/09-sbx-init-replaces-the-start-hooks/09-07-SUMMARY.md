---
phase: 09-sbx-init-replaces-the-start-hooks
plan: 07
subsystem: infra
status: complete
tags: [docker, images, sbx-init, selfcheck, agents]

requires:
  - phase: 09-sbx-init-replaces-the-start-hooks
    provides: base/init runner and shared steps, claude/init and cursor/init step files (plans 02 to 04)
provides:
  - base image with sbx-init installed, /etc/sbx/init.d, /opt/sbx/agents/bin and no entrypoint
  - Claude and Cursor images that copy their own steps and keep the agent CLI off the PATH
  - self-check image roots and ownership rules aligned with the new layout
  - tests/selftest/init/test_init_inventory.py (step order, name rules, Dockerfile copy lines, compose)
affects: [09-09, 09-10, 09-11, 09-13]

actuals:
  tokens: 26000
  tasks: 3
  commits: 3
plan_head_before: 2884c06b2de33b8badceb7beb001e25928c3c5d9
plan_head_after: 69fe1ca05aa0e904f628dab69f8283cf9298a6e7

tech-stack:
  added: []
  patterns:
    - "agent images add steps under /etc/sbx/init.d/<agent> and compile them at build time, like selfcheck.d"
    - "the agent CLI is linked only from /opt/sbx/agents/bin; the smoke test runs it by full path and fails when the bare name is on the PATH"

key-files:
  created:
    - tests/selftest/init/test_init_inventory.py
  modified:
    - base/Dockerfile
    - claude/Dockerfile
    - cursor/Dockerfile
    - compose.yml
    - base/selfcheck/image_roots.py
    - base/selfcheck/image_ownership.py
    - tests/selftest/selfcheck/test_image_roots.py
    - tests/selftest/selfcheck/test_image_ownership.py

key-decisions:
  - "Claude Code stays installed with npm install -g into /usr/local; only its link moves, so the extra root certificate in /usr/local/etc/npmrc still applies"
  - "The base image makes /opt/sbx/agents/bin and lists /opt/sbx/agents in its roots; agent images only add their link"
  - "The per-agent test of the Dockerfile copy line is one parametrized test over claude and cursor"

patterns-established:
  - "A test pins the merged per-image step order by running the runner's own collect_steps on a copy of the agent folder"

requirements-completed: [INIT-01, INIT-03, INIT-04]

coverage:
  - id: D1
    description: "base image has no entrypoint and no start hook folder; installs sbx-init with modes 755/644, shared steps, /etc/sbx/init.d and /opt/sbx/agents/bin; py_compile on every init file"
    requirement: INIT-03
    status: covered
    evidence: "test_init_inventory.py base Dockerfile test; guard hadolint passes; image build is checked on the Mac in plan 09-13"
  - id: D2
    description: "claude and cursor-agent are linked only from /opt/sbx/agents/bin and the smoke tests fail when the bare name is on the PATH"
    requirement: INIT-04
    status: partial
    evidence: "Dockerfile lines grep-verified and hadolint clean; the real build and H-27 run on the Mac (docker is not available in the sandbox)"
  - id: D3
    description: "merged step order per image is pinned (Claude 4 steps, Cursor 5), file and step names follow the rules, no prefix repeats"
    requirement: INIT-01
    status: covered
    evidence: "uv run pytest tests/selftest/init/test_init_inventory.py: 14 pass"
  - id: D4
    description: "self-check roots are sbx-init, sbx-selfcheck, /etc/sbx, /opt/sbx/agents; both launchers must be executable; files in a step folder need no executable bit"
    requirement: INIT-01
    status: covered
    evidence: "uv run pytest tests/selftest/selfcheck tests/selftest/init: 422 pass"
---

# Phase 9 Plan 07: Images switch to sbx-init Summary

The images now start nothing: no entrypoint, no start hooks, `init: true` plus `sleep infinity`; `sbx-init` ships in the base with each agent's steps copied into `/etc/sbx/init.d/<agent>`, and `claude` and `cursor-agent` are reachable only through the root-owned `/opt/sbx/agents/bin`.

## What changed

| Area | Change |
|---|---|
| `base/Dockerfile` | Entrypoint, start library and start hook folder removed; sbx-init block (launcher 755, modules and shared steps 644, link at `/usr/local/bin/sbx-init`, `py_compile` of all of it); comments updated |
| `claude/Dockerfile` | Real binary linked at `/opt/sbx/agents/bin/claude`, npm link removed; steps into `/etc/sbx/init.d/claude` and compiled; smoke test by full path plus `! command -v claude` |
| `cursor/Dockerfile` | Same shape; the unpack RUN links `cursor-agent` into the agents folder; steps into `/etc/sbx/init.d/cursor`; smoke test by full path plus `! command -v cursor-agent` |
| `compose.yml` | Comments only (tini is PID 1, no entrypoint, the container only keeps running); the key diff against the phase start commit is empty |
| `image_roots.py`, `image_ownership.py` | New roots, `LAUNCHER_FILE_LIST`, `ImageRules.launcher_file_list`; hook folder rule removed |
| Tests | `test_init_inventory.py` new; roots and ownership tests updated, one test per behavior line |

## Commits

- `5f12886` feat(09-07): base image ships sbx-init with no entrypoint and claude leaves the PATH
- `dec9d63` feat(09-07): cursor image ships its steps and cursor-agent leaves the PATH
- `69fe1ca` feat(09-07): self-check image roots follow the sbx-init layout

## Verification

- `uv run pytest tests/selftest/init tests/selftest/selfcheck -q`: 422 passed
- `bash tests/guard/run-all.sh`: All rules hold (hadolint included)
- No Dockerfile names the entrypoint, the start library or `/etc/sbx/start.d`
- The tracer gate (automated verify only, interactive mode) was re-run after task 1 and passed before the Cursor image was changed

## Deviations from Plan

None. The plan executed as written.

## Authentication gates

None.

## Known Stubs

None.

## Threat Flags

None. The new folders (`/usr/local/lib/sbx-init`, `/etc/sbx/init.d`, `/opt/sbx/agents`) are the ones the plan's threat register covers (T-09-18); they are in the base roots, so the ownership and protected-paths checks walk them.

## Open items for later plans

- Docker is not available here: the image builds, the off-PATH behavior of both agents (RESEARCH A3 and A4) and `docker compose up -d --wait` with no entrypoint (A2) are shown on the Mac in plan 09-13.
- README.md, `.claude/CLAUDE.md`, `tests/README.md`, the guard globs (`HOOK_DIRS`, `SHELL_FILES`) and the host tests h17 still name the old entrypoint and start hooks; `base/sbx-entrypoint`, `base/sbx-start-lib.sh`, `*/start.d/` and `base/bin/sbx-link-bundle` are still in the repo (`base/bin/` is still copied whole, so `sbx-link-bundle` still ships). Plan 09-09 and later plans own those.

## Self-Check: PASSED

- FOUND: base/Dockerfile, claude/Dockerfile, cursor/Dockerfile, compose.yml, base/selfcheck/image_roots.py, base/selfcheck/image_ownership.py, tests/selftest/init/test_init_inventory.py
- FOUND commits: 5f12886, dec9d63, 69fe1ca
