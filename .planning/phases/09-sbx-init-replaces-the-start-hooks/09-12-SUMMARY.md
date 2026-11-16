---
phase: 09-sbx-init-replaces-the-start-hooks
plan: 12
subsystem: docs
tags: [docs, readme, sbx-init, migration, host-checklist]

requires:
  - phase: 09-sbx-init-replaces-the-start-hooks
    provides: sbx-init and its steps, the refusing wrappers, the agents folder, host checks H-16, H-27, H-34 and H-35
provides:
  - README first-run path and a "Set up a sandbox: sbx-init" section
  - README best-practices, GSD, self-check, safety, raw Docker and troubleshooting text that follows the code
  - MIGRATION.md notes for old copies and the stale list file
  - test docs that list the init suite, 20 guard rules and 17 host checks
affects: [09-13]

status: complete
actuals:
  tokens: 10200
  tasks: 3
  commits: 3
plan_head_before: be590c1aef46c2c2306d7e51fd544b329f425f01
plan_head_after: 88db1f41228aa8ded907cf55ec8eac4aef74bc7e

tech-stack:
  added: []
  patterns:
    - "docs state the code: every quoted line was checked against init_runner.py, the steps, the wrappers and bin/"

key-files:
  created: []
  modified:
    - README.md
    - MIGRATION.md
    - ZSCALER.md
    - prompts/consolidate-memories.md
    - tests/README.md
    - tests/host-checklist.md

key-decisions:
  - "New text says best-practices; the existing 'bundle' wording stays where a section was not rewritten"

requirements-completed: [INIT-01, INIT-03, INIT-04]

duration: 25min
completed: 2026-11-16
---

# Phase 9 Plan 12: Docs follow sbx-init Summary

**A user following the README now runs `sbx-init` before the agent; no user or test doc describes start hooks, the entrypoint, the start wait, the wrapper warning or the list file.**

## Accomplishments

- README quick start has nine rows (`sbx-init` between `sbx-shell` and `sbx-gh-login`, `sbx-bundle-clone` runs it again, Cursor login is `sbx-cursor login`). The image, scripts and start/enter sections describe a sleeping container, wrappers that refuse with `run sbx-init first`, and agents in `/opt/sbx/agents/bin` off the PATH.
- New README section "Set up a sandbox: sbx-init": step table for both agents (4 steps for Claude, 5 for Cursor), a full-pass and a no-clone example, the FAIL and last lines, rerun and relink, the run lock, the marker in the container layer (recreate or `sbx-upgrade` wipes it; stop and start keep it), and that `sbx-selfcheck` does the checking.
- Best-practices section has the clash rule (a name that is not a link into the clone is left and FAILs the step with a rename or move fix), the no-clone path, edit protection on `state/claude/skills/` only, and `sbx-init` as the relink. GSD, self-check (55 checks, new roots, two launchers), safety checks, raw Docker, the smoke test (`/opt/sbx/agents/bin/claude --version`) and troubleshooting rows follow the code.
- MIGRATION.md: first shell runs `sbx-init`; old copies or a real `rules` folder make the first run FAIL until moved; a stale `.best-practices-skills` file can be deleted by hand. ZSCALER.md and the memory prompt are updated the same way.
- tests/README.md lists the 20 guard rules with the two new ones, drops the entrypoint self-test, and adds `tests/selftest/init/`. tests/host-checklist.md goes to H-03 to H-35 (17 rows), drops H-12, H-17 and H-20, adds H-35 and rewrites H-16, H-27, H-31 and H-34, the chain line and the H-35 reading note.

## Task Commits

1. Task 1 (tracer): `9c3acf7`
2. Task 2: `1c7d4cb`
3. Task 3: `88db1f4`

## Deviations from Plan

- [Rule 1 - Bug] The H-31 row in tests/host-checklist.md still said sbx-shell "waits for its start hooks", which no longer happens (and tripped the task's own negative grep). Reworded to match `sbx-shell`.
- [Rule 1 - Bug] The plan said the issue 13602 paragraph should end with the self-check FAILing in such a container. The check that actually FAILs there is the project-folder check (the folder Docker creates is empty), so the sentence names the missing project folder.
- The README also gains one Upgrade bullet (a recreate by `sbx-upgrade` or by `sbx-start` on an older image wipes the init marker) and a Quick start renumbering to nine rows, both implied by the plan's facts.

## Verification

- Task negative greps, the ASCII sweep and the dash and planning ID sweep against `47ac48c` print nothing for all six files.
- `grep -c 'sbx-init' README.md` is 52; `grep -c '^| H-' tests/host-checklist.md` is 17; `bash tests/guard/run-all.sh` ends with `All rules hold.`
- The tracer gate (README path) was re-run end to end after the first commit: the same automated verify passed.

## Notes for the user (outside this plan)

- `.claude/CLAUDE.md` is stale on the entrypoint (`base/sbx-entrypoint`, `sbx-start-lib.sh`, start hooks `05-gsd` and `10-best-practices`, "Start Hooks" and "Entrypoint" rows, the Container Startup flow, `sbx-link-bundle`). It changes in its own PR.

## Known Stubs

None.

## Self-Check: PASSED

- Files edited exist: README.md, MIGRATION.md, ZSCALER.md, prompts/consolidate-memories.md, tests/README.md, tests/host-checklist.md.
- Commits found: 9c3acf7, 1c7d4cb, 88db1f4.
