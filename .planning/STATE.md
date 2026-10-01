---
gsd_state_version: "1.0"
current_phase: 01
current_phase_name: Two-Mount Claude Sandbox
status: executing
stopped_at: Completed 01-03-PLAN.md
last_updated: "2026-10-01T18:42:48.125Z"
last_activity: 2026-09-30
last_activity_desc: Phase 01 execution started
state_head: 0cb93bb53d2f6b1ae16e28dbd41b2ffca2910b3a
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 4
  completed_plans: 3
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-30)

**Core value:** Rebuilding the image must reliably deliver new or updated tools into a project sandbox without losing the agent's login, settings, or history, and without the host mount hiding anything the image provides.
**Current focus:** Phase 01 — Two-Mount Claude Sandbox

## Current Position

Phase: 01 (Two-Mount Claude Sandbox) — EXECUTING
Plan: 4 of 4
Status: Ready to execute
Last activity: 2026-09-30 — Phase 01 execution started

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: -
- Trend: -

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 10 min | 3 tasks | 5 files |
| Phase 01 P02 | 2 min | 2 tasks | 4 files |
| Phase 01 P03 | 3 min | 2 tasks | 6 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: Vertical MVP. Phase 1 already delivers a usable two-mount Claude sandbox on the Mac (minimal base + Claude image + compose + persistent login), and later phases deepen it
- [Roadmap]: Script priority order is kept: remembered args + upgrade (Phase 3), then jump-in + list/cleanup (Phase 4)
- [Roadmap]: The old `ClaudeCode/` `cc-*` files stay in the repo until Phase 5, so the ~4 existing sandboxes keep working until the migration is documented
- [Roadmap]: Every success criterion is verified on the Mac, because Docker isn't available in the dev sandbox
- [Phase 01]: Pinned @anthropic-ai/claude-code at exactly 2.1.285 after human supply-chain approval (01-01 Task 1)
- [Phase 01]: Home subdirectories created with mkdir -p after USER sandbox (not install -d) so ~/.local is sandbox-owned
- [Phase 01]: Plan 01-02: history wired by image ENV only (HISTFILE plus PROMPT_COMMAND=history -a); git identity uses a state/git directory mount, never a single-file mount
- [Phase 01]: 01-03: entrypoint detects missing mounts with awk over /proc/self/mountinfo field 5 and SBX_MOUNTS lets agent images add targets; compose drops all caps with no-new-privileges

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 1]: Docker Desktop bind-mount ownership (the git "dubious ownership" issue) is inferred from community reports. Check it on the real Mac
- [Phase 1]: Until Phase 3 there are no scripts, so the sandbox runs from a documented `docker compose` command
- [Phase 2]: Confirm on the Mac that `DISABLE_UPDATES=1` really disables Claude's self-update (via `claude doctor`), and that ccusage's native binary is executable (chmod) on arm64
- [Phase 5]: Decide whether SCR-08 ("remove whole-home-mount layout") also covers the out-of-scope `OpenCode/` directory, or whether it stays for the next milestone

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-10-01T18:42:48.096Z
Stopped at: Completed 01-03-PLAN.md
Resume file: None
