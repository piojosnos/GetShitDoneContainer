---
phase: 01-two-mount-claude-sandbox
plan: 01
subsystem: infra
tags: [docker, compose, ubuntu-24.04, node-24, claude-code, bind-mounts, bash]

requires: []
provides:
  - "base/Dockerfile: shared sbx-base:local image (ubuntu:24.04, checksum-verified Node 24.21.0, sandbox uid 1000, system safe.directory)"
  - "claude/Dockerfile: sbx-claude:local FROM the base, Claude Code 2.1.285 from npm, CLAUDE_CONFIG_DIR and DISABLE_UPDATES in image ENV"
  - "compose.yml: one-service sandbox sbx-${SBX_NAME} with workspace and state/claude directory binds"
  - "tests/static-check.sh: Docker-free static tier (pins, FROM chain, mount layout, cross-file wiring, forbidden patterns, coexistence)"
  - "SANDBOX.md: quick-start for build, start, enter, login, stop, rebuild"
affects: [01-02, 01-03, 01-04, phase-02, phase-03, phase-05]

plan_head_before: cb9b159020f6a13ffb07f4fae948c470acf1d784
plan_head_after: d4bd82b6cdd18e6b4e90412a4622b5dc250d41a8

actuals:
  tokens: 4000
  tasks: 3
  commits: 2

tech-stack:
  added: [ubuntu:24.04, "Node.js 24.21.0 (official tarball)", "@anthropic-ai/claude-code 2.1.285", docker compose v2]
  patterns:
    - "directory-only long-syntax bind mounts with create_host_path: false"
    - "image ENV (not entrypoint) for tool config dirs so docker exec shells see them"
    - "required-variable interpolation with ${VAR:?msg}"
    - "static check script with one check per line, appended by later plans"

key-files:
  created:
    - base/Dockerfile
    - claude/Dockerfile
    - compose.yml
    - tests/static-check.sh
    - SANDBOX.md
  modified: []

key-decisions:
  - "Pinned @anthropic-ai/claude-code at exactly 2.1.285 after human supply-chain approval (Task 1, 2026-10-01)"
  - "Home subdirectories are created with plain mkdir -p after USER sandbox, not install -d, so every level (including ~/.local) is sandbox-owned"
  - "SANDBOX.md added as the Phase 1 doc; root README.md stays untouched until Phase 5"

requirements-completed: [LAY-01, LAY-02, LAY-04, IMG-02, IMG-05, IMG-06]

coverage:
  - id: D1
    description: "Base image sbx-base:local and Claude image sbx-claude:local FROM it, pinned versions, no VOLUME, no sudo, last USER sandbox"
    requirement: "IMG-02"
    verification:
      - kind: other
        ref: "bash tests/static-check.sh (static tier only; no Docker in the dev sandbox)"
        status: pass
    human_judgment: true
    rationale: "Static greps prove the Dockerfile text, not that the images build on Apple Silicon. Mac-side builds are host checks H-01..H-04 in plan 01-04."
  - id: D2
    description: "compose.yml: sbx-${SBX_NAME} project and container, required SBX_NAME/SBX_DIR, init plus sleep infinity, workspace and state/claude directory binds, nothing mounted over /home/sandbox"
    requirement: "LAY-01"
    verification:
      - kind: other
        ref: "bash tests/static-check.sh (mount layout and cross-file wiring checks)"
        status: pass
    human_judgment: true
    rationale: "Compose behavior (up --wait, uid 1000 shell, login surviving recreate and --no-cache rebuild) needs Docker on the Mac; host checks H-05..H-09 in plan 01-04."
  - id: D3
    description: "SANDBOX.md quick-start that matches compose.yml and never asks down to remove volumes"
    requirement: "LAY-04"
    verification:
      - kind: other
        ref: "bash tests/static-check.sh (docs never remove volumes on down; docs use docker compose v2 only; quick-start builds the image compose runs)"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-10-01
status: complete
---

# Phase 1 Plan 01: Base, Claude image and compose tracer Summary

**Two-image Docker sandbox (ubuntu:24.04 base with checksum-verified Node 24.21.0, Claude Code 2.1.285 from npm) run by a compose file that mounts only `workspace/` and `state/claude/`, proven by a Docker-free static wiring check.**

## Performance

- **Duration:** about 10 min for this continuation (Task 2 commit, Task 3, close-out). Task 1 (human gate) and the Task 2 authoring ran in earlier executor sessions.
- **Completed:** 2026-10-01T18:37Z
- **Tasks:** 3 (1 human gate, 1 tracer, 1 doc task)
- **Files created:** 5

## Accomplishments

- Task 1 supply-chain gate: the human approved `@anthropic-ai/claude-code@2.1.285` on 2026-10-01 before any Dockerfile pinned it. Approved version: **2.1.285**.
- `base/Dockerfile` and `claude/Dockerfile` form a base-then-agent chain with no architecture override, no VOLUME, no sudo, and `USER sandbox` last in both. `/etc/gitconfig` sets `safe.directory *`.
- `compose.yml` starts `sbx-${SBX_NAME}` (project and container, no `-p`) with exactly two directory binds, both sourced under `${SBX_DIR}`; the `state/claude` target equals the image's `CLAUDE_CONFIG_DIR`, checked across files.
- `tests/static-check.sh` runs 36 checks without Docker and passes, including coexistence against commit 934e2c5 (`ClaudeCode/`, `OpenCode/`, `README.md` unchanged).
- `SANDBOX.md` documents build, export, mkdir, `docker compose up -d --wait`, `docker exec`, claude login, down, and rebuild, and the static tier guards it against data-deleting commands.

## Task Commits

1. **Task 1: Supply-chain gate** - no commit (gate, no files; human approved 2.1.285)
2. **Task 2: Tracer (base image, Claude image, compose, static check)** - `b4fd1de` (feat)
3. **Task 3: Quick-start doc and doc checks** - `d4bd82b` (docs)

**Plan metadata:** committed separately as `docs(01-01): complete ...` (SUMMARY, STATE, ROADMAP, REQUIREMENTS)

## Files Created/Modified

- `base/Dockerfile` - shared base image sbx-base:local
- `claude/Dockerfile` - Claude image sbx-claude:local FROM the base
- `compose.yml` - one-service sandbox with workspace and state/claude binds
- `tests/static-check.sh` - Docker-free static tier; later plans append checks
- `SANDBOX.md` - Phase 1 quick-start

## Decisions Made

- Pinned Claude Code to exactly 2.1.285 (human-approved), installed by root into `/usr/local` so no mount can hide it and updates only happen on rebuild.
- Created home subdirectories with `mkdir -p` after `USER sandbox` rather than `install -d` (planner deviation from RESEARCH Pattern 4): `install -d -o` would leave `~/.local` root-owned.
- Left root `README.md` untouched; the new layout is documented in `SANDBOX.md` until Phase 5.

## Deviations from Plan

None - plan executed exactly as written. The one operational event, a stop because HEAD was the protected `main`, was resolved by the orchestrator creating `feat/phase-01-two-mount-sandbox`; Task 2 files carried over unchanged and were re-verified before commit.

## Issues Encountered

- First executor stopped before committing Task 2 because HEAD was on `main`. Resolved by the human and orchestrator via a feature branch. No file changes were needed.
- `gsd_run query git.base-branch --is-protected` was empty when called through an unset shell function; re-run with the node wrapper it returned `false` for the feature branch.

## Authentication Gates

None. Task 1 was a package-legitimacy human gate, not an auth gate.

## Known Stubs

None.

## Threat Flags

None. No new surface beyond the plan's threat model (two binds under `${SBX_DIR}`, no socket, no sudo).

## User Setup Required

None. Mac-side builds and runtime checks are host checklist items in plan 01-04 (Docker is unavailable in the dev sandbox).

## Next Phase Readiness

- Ready for 01-02 (shell history, gh, git state mounts; extends compose volumes, Dockerfile ENV and the static check).
- Unproven until the Mac host checklist (01-04): native arm64 build, `up --wait`, uid 1000 shell, login surviving recreate and `--no-cache` rebuild, `claude --version` assertion in the build.

---
*Phase: 01-two-mount-claude-sandbox*
*Completed: 2026-10-01*

## Self-Check: PASSED

- FOUND: base/Dockerfile, claude/Dockerfile, compose.yml, tests/static-check.sh, SANDBOX.md
- FOUND commits: b4fd1de, d4bd82b (`git log --all --grep=01-01` returns 2)
- `bash tests/static-check.sh` ends with "All static checks passed"
- No attribution trailers in the task commits
