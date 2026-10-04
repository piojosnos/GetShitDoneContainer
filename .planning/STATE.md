---
gsd_state_version: "1.0"
current_phase: 1
current_phase_name: Two-Mount Claude Sandbox
status: planning
stopped_at: Phase 01.1 complete, ready to plan Phase 1
last_updated: "2026-10-04T02:12:14.112Z"
last_activity: 2026-10-04
last_activity_desc: Phase 01.1 complete, transitioned to Phase 1
state_head: 6fc034deda52348f1bf761964c16c2e5cc47011d
progress:
  total_phases: 9
  completed_phases: 1
  total_plans: 8
  completed_plans: 8
  percent: 11
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-30)

**Core value:** Rebuilding the image must reliably deliver new or updated tools into a project sandbox without losing the agent's login, settings, or history, and without the host mount hiding anything the image provides.
**Current focus:** Phase 01.1 — Automated host tests (INSERTED)

## Current Position

Phase: 1 — Two-Mount Claude Sandbox
Plan: Not started
Status: Ready to plan
Last activity: 2026-10-04 — Phase 01.1 complete, transitioned to Phase 1

Progress: [█░░░░░░░░░] 11%

## Performance Metrics

**Velocity:**
- Total plans completed: 4
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01.1 | 4 | - | - |

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
| Phase 01 P04 | 2 min | 1 tasks | 2 files |
| Phase 01.1 P01 | 10 min | 3 tasks | 9 files |
| Phase 01.1 P02 | 15 min | 3 tasks | 11 files |
| Phase 01.1 P03 | 8 min | 2 tasks | 5 files |
| Phase 01.1 P04 | 35min | 3 tasks | 1 files |

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
- [Phase 01]: 01-04: Host verification (H-00..H-13) DEFERRED by user to Phase 2 (not approved, not run); Phase 1 verified statically only
- [Phase 01.1]: 01.1-01: H-00 passes for Compose major 2 or higher (releases jumped from 2.x to 5.x), run_timeout polls so no sleeping orphan holds a captured pipe, and the never-delete guard exempts only the printed cleanup line
- [Phase 01.1]: Coexistence writes only logs/old-containers.after, never the baseline; with no baseline it checks git alone (git only; no baseline)
- [Phase 01.1]: H-10 always ends with the real sandbox up and folds a failed restart into its FAIL line; H-08 recreates only after its first half passes
- [Phase 01.1]: Manual helpers put the terminal guard before sourcing lib.sh, because host_init already makes a docker call
- [Phase 01.1]: H-09 helper re-asserts the test sandbox after compose_up, before opening Claude
- [Phase 01.1]: H-10 passed on the Mac (Compose 2.40.0-desktop.1 honors create_host_path false); no compose.yml change, env_file sentinel follow-up not needed

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 1]: Docker Desktop bind-mount ownership (the git "dubious ownership" issue) is inferred from community reports. Check it on the real Mac
- [Phase 1]: Until Phase 3 there are no scripts, so the sandbox runs from a documented `docker compose` command
- [Phase 2]: Confirm on the Mac that `DISABLE_UPDATES=1` really disables Claude's self-update (via `claude doctor`), and that ccusage's native binary is executable (chmod) on arm64
- [Phase 5]: Decide whether SCR-08 ("remove whole-home-mount layout") also covers the out-of-scope `OpenCode/` directory, or whether it stays for the next milestone
- Phase 1 host verification H-00..H-13 + coexistence unrun (user deferred to Phase 2, 2026-10-01). Carry in: H-10 env_file-sentinel trigger, H-12 installed version == 2.1.285 pin, compose/Docker Desktop versions

### Roadmap Evolution

- Phase 01.1 inserted after Phase 1: Best-practices bundle baked into the image (stopgap) (URGENT)
- Phase 02.1 inserted after Phase 2: Best-practices from git, editable from any sandbox
- Phase 6 added: Automated checks (CI): run tests/guard.sh on every PR push, from the PR #1 review

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-10-04T02:03:25.646Z
Stopped at: Phase 01.1 complete, ready to plan Phase 1
Resume file: None
