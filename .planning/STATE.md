---
gsd_state_version: "1.0"
current_phase: "01.5"
current_phase_name: Host test fixes (INSERTED)
status: executing
stopped_at: Completed 01.5-04-PLAN.md
last_updated: "2026-10-07T05:59:15.012Z"
last_activity: 2026-10-07
last_activity_desc: Phase 01.5 execution started
state_head: 9935f82b1da5e3f5ea5ea3831cf5403697e43da0
progress:
  total_phases: 12
  completed_phases: 5
  total_plans: 39
  completed_plans: 32
  percent: 42
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-10-06)

**Core value:** Rebuilding the image must reliably deliver new or updated tools into a project sandbox without losing the agent's login, settings, or history, and without the host mount hiding anything the image provides.
**Current focus:** Phase 01.5 — Host test fixes (INSERTED)

## Current Position

Phase: 01.5 (Host test fixes (INSERTED)) — EXECUTING
Plan: 5 of 11
Status: Ready to execute
Last activity: 2026-10-07 — Phase 01.5 execution started

Progress: [████████████████████] 28/28 plans ([████░░░░░░] 42%)

## Performance Metrics

**Velocity:**
- Total plans completed: 28
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01.1 | 4 | - | - |
| 1 | 4 | - | - |
| 01.2 | 6 | - | - |
| 01.3 | 6 | - | - |
| 01.4 | 8 | - | - |

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
| Phase 01.2 P01 | 9 min | 2 tasks | 11 files |
| Phase 01.2 P02 | 14 min | 2 tasks | 9 files |
| Phase 01.2 P03 | 5 min | 2 tasks | 5 files |
| Phase 01.2 P04 | 6 min | 2 tasks | 5 files |
| Phase 01.2 P05 | 8 min | 2 tasks | 10 files |
| Phase 01.2 P06 | 25 min | 2 tasks | 7 files |
| Phase 01.3 P01 | 17 min | 2 tasks | 7 files |
| Phase 01.3 P02 | 15 min | 2 tasks | 6 files |
| Phase 01.3 P03 | 8 min | 2 tasks | 5 files |
| Phase 01.3 P04 | 15 min | 2 tasks | 6 files |
| Phase 01.3 P06 | 13 min | 2 tasks | 4 files |
| Phase 01.3 P05 | 12 min | 2 tasks | 5 files |
| Phase 01.4 P01 | 5 min | 2 tasks | 10 files |
| Phase 01.4 P02 | 7 min | 3 tasks | 15 files |
| Phase 01.4 P03 | 13 min | 3 tasks | 13 files |
| Phase 01.4 P04 | 5 min | 3 tasks | 11 files |
| Phase 01.4 P05 | 10 min | 3 tasks | 11 files |
| Phase 01.4 P06 | 15 min | 3 tasks | 12 files |
| Phase 01.4 P07 | 12 min | 2 tasks | 6 files |
| Phase 01.4 P01.4-08 | 35 min | 2 tasks | 1 files |
| Phase 01.5 P01 | 12 min | 3 tasks | 10 files |
| Phase 01.5 P02 | 14 min | 2 tasks | 14 files |
| Phase 01.5 P03 | 25 min | 3 tasks | 9 files |
| Phase 01.5 P04 | 20 min | 2 tasks | 11 files |

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
- [Phase 01]: Re-verified 5/5 against the one-mount layout, using the Phase 1.1 Mac run (01-UAT.md) as the host evidence; marked complete 2026-10-04
- [Phase 01.2]: Start hook folder /etc/sbx/start.d runs in name order and fails fast with its own [sbx] ERROR line (no die() compose hint); sync list file is .best-practices-skills; both images build from the repo root with an allowlist .dockerignore
- [Phase 01.2]: Bundle conflicts resolved AGENTS.md first, then newest memory; superseded merge-confirmation text dropped
- [Phase 01.2]: GSD ship/pr-branch non-default-target caveat lives in the GSD workflow section of git-workflow.md
- [Phase 01.2]: H-17 runs in the no-sandbox stage on its own $RUN/h17 folder, so the running test sandbox state is never touched — A failing or odd start hook must not disturb the sandbox the other checks share
- [Phase 01.2]: The failing-hook container uses CLAUDE_CONFIG_DIR=/proc/no-such-dir so the real hook exits 1 without any test-only code path — mkdir under set -e fails there; the hook and entrypoint stay unchanged
- [Phase 01.2]: Start hook needed no change: all refresh, safety and failure scenarios passed against the existing hook
- [Phase 01.2]: H-16 runs right after H-08 in the restart chain (h08, h16, h11, h09, h10)
- [Phase 01.2]: Managed settings hold exactly four Edit deny entries (rules, skill list, each bundle skill); guard rule managed_settings_cover_bundle keeps them in step with the bundle
- [Phase 01.2]: H-14 reads owners and modes with find -printf inside the container, so the host portability rule on stat -c needs no exception
- [Phase 01.2]: H-18 runs in the sandbox stage and is droppable; the fake API protocol from research needed no change at the pinned Claude
- [Phase 01.2]: PR #9 review: rules made project-neutral; java.md split into java.md (*.java) and freemarker.md (*.ftl), no pom.xml glob; project-specific path/URL rule left to its own project; migration prompt in prompts/consolidate-memories.md
- [Phase 01.2]: Script layout rule (80-column section banners, functions, Main / Entry Point) and shared-library rule added to shell.md; new scripts follow it, the rest is Phases 1.3 and 1.4
- [Phase 01.2]: Security: threats_open 0; non-executable start hook skip (WR-04) accepted as AR-01 and scheduled in Phase 1.3
- [Phase 01.3]: Host test libraries stay flat files next to lib.sh; the frozen selftest copies only tests/host/*.sh and reaches make_run_dir, claude_pin, expected_arch through lib.sh
- [Phase 01.3]: Code is moved verbatim during the layout phase; prove.sh (identical output against baseline 0a58e7d) is the gate for every later plan
- [Phase 01.3]: 01.3-02: remove_leftover_test_container calls fatal itself on both failure paths so the run-all.sh Main block stays a flat list of calls
- [Phase 01.3]: 01.3-02: H-02 starts baseCount at 0 so its eagerly expanded PASS text cannot abort with an unbound variable
- [Phase 01.3]: H-04 stays one block with no functions (single assertion); file-based tr sites in Coexistence and grep -Fl in H-01 kept as written
- [Phase 01.3]: restart_test_sandbox lives in lib-sandbox.sh because H-08 and H-16 carried identical code and messages; H-09 and H-11 sentinel loops stay local
- [Phase 01.3]: 01.3-06: the entrypoint stops at the first non-executable start hook (after earlier hooks ran), behind a BASH_SOURCE source guard; no env override of hookDir
- [Phase 01.3]: 01.3-05: lib-manual.sh lives in tests/host/manual/ (the guard forbids read and tty flags in tests/host/*.sh); the attended helpers start with lib-manual.sh, require_terminal, then lib.sh and host_init
- [Phase 01.4]: 01.4-01: entrypoint suite output is byte-identical to the old script; prove.sh uses exact mode for entrypoint and sorted case lines for guard, bundle and host; make_work_folder resolves the physical path only after the traps are installed
- [Phase 01.4]: Bundle self-test cases moved byte for byte; helpers got banners; guard file list and host checklist name tests/selftest/bundle
- [Phase 01.4]: The fake docker is its own file with every retained knob in one header table; only the three knobs no case sets are dropped, so no self-test case is dropped
- [Phase 01.4]: fake-transcript.sh builds both fake transcripts under fresh state folders instead of removing old ones, so its only removal is the sbx-fake14 case branch
- [Phase 01.4]: Plan 04 moves host sections by locating each by its echo header (baseline line numbers shifted after plan 03) and rewrites groupList in final relative order each task
- [Phase 01.4]: The Mac runner's end-of-run text names the cleanup command and tests/host/manual/; the helpers are no longer listed as an ordered pass (plan 05)
- [Phase 01.4]: The planning-id guard rule scans tests/selftest/host/ instead of the removed tests/host-selftest.sh (plan 05); plan 06 keeps the new folder in that path list
- [Phase 01.4]: Guard split: the old guard sourced tests/guard/lib.sh until it was removed, so every rule function and constant was defined exactly once at each step and rules.sh could prove bodies byte for byte against the baseline
- [Phase 01.4]: Guard path lists: no_compromised_gsd_package and host_tests_have_no_planning_ids scan tests/selftest/*.sh, tests/selftest/*/*.sh and tests/selftest/*/support/*; 14 planted violations prove every location is still scanned
- [Phase 01.4]: The host checks run against real Docker on the Mac; run-all.sh passing is the gate and the manual helpers are diagnostic tools
- [Phase 01.4]: Backlog 999.1 closed by the diagnostic-helper decision; retiring the slim fake docker is backlog 999.2
- [Phase 01.4]: 01.4-08: the Mac run of tests/host/run-all.sh (19 passed, 0 failed, 0 not run) and the guard on stock bash is the real-Docker gate; only the run from the code worktree at a821736 counts
- [Phase 01.5]: 01.5-01: code branch fix/phase-01.5-host-test-fixes is cut from main at 79d819b (PR #13 merge); the code PR targets main
- [Phase 01.5]: 01.5-01: negative assertions (lacks_text, lacks_match) and guard scan helpers (nowhere_matches, host rules) fail closed on missing input; guard self-test suite is tests/selftest/guard/; a truncating redirect stays allowed by the delete rule
- [Phase 01.5]: Suite-list self-test cases assert exit status 1, so a missing rule group (status 127) cannot satisfy a failing-guard case
- [Phase 01.5]: plant_block added beside plant_lines: contiguous planted lines are needed to test a missing blank line
- [Phase 01.5]: grep -P guard term matches as a whole word so pgrep -P is allowed (host side tree kill uses pgrep -P only)
- [Phase 01.5]: Sandbox identity is split: loose rule for cleanup (mount or its parent named sbx-hosttest-*), strict rule before a check acts (mount folder name equals RUN name)
- [Phase 01.5]: Plan 04: compose guard regex is compose([[:space:]].*)?[[:space:]]-f[[:space:]] so a plain 'docker compose -f' call is matched; DOCKER_HOST and DOCKER_CONTEXT stay set and are printed, not unset (D-12)

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 1]: Until Phase 3 there are no scripts, so the sandbox runs from a documented `docker compose` command
- [Phase 2]: Confirm that ccusage's native binary is executable (chmod) on arm64 (DISABLE_UPDATES was confirmed by `claude doctor` in the Phase 1.1 Mac run)
- [Phase 5]: Decide whether SCR-08 ("remove whole-home-mount layout") also covers the out-of-scope `OpenCode/` directory, or whether it stays for the next milestone
- [Phase 1]: Re-review left 7 findings open (WR-01: the missing-project-folder check in base/sbx-entrypoint cannot fire because compose working_dir creates the folder; WR-02: base/Dockerfile comment overclaims create_host_path; WR-03: Claude Code has no integrity hash). See 01-REVIEW-DISPOSITION.md
- [Phase 1]: SC3 says rebuild with `--no-cache`; the Mac run did not record it. One run of `bash tests/host/manual/h09-rebuild-resume.sh --no-cache` would confirm
- [Phase 1.1]: Code review left 14 findings open (CR-01: run_timeout does not stop a docker call behind a shell function; WR-01..08 robustness). See 01.1-REVIEW-DISPOSITION.md
- [Phase 1.2]: Code review left 13 findings open (WR-01..03 are bugs in the ported pr-reply and merged skills; WR-04 was fixed in Phase 1.3; WR-05 deny negative control fits Phase 1.4). See 01.2-REVIEW-DISPOSITION.md
- [Phase 1.3]: Code review left 4 findings open (WR-02: run_timeout does not stop a shell function it wraps, same as the Phase 1.1 CR-01 and planned for Phase 1.5; IN-01..03 style and self-test coverage). See 01.3-REVIEW-DISPOSITION.md
- [Phase 1.4]: Code review left 11 findings open (see 01.4-REVIEW-DISPOSITION.md). Follow-ups for Phase 1.5 or a quick task: WR-01 a group program missing from a run-all list never runs; WR-02 and WR-06 `nowhere_matches` and the `lacks_*` helpers fail open when a file is missing or unreadable; WR-05 SANDBOX.md overclaims what a passing `run-all.sh` proves
- [Phase 1.4]: Open note: the user's Mac `git status` listed 10 files as modified in the code worktree while the sandbox shows it clean; cause pending

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 261005-7zj | Start hooks: refuse non-regular entries and check bad hooks in H-17 | 2026-10-05 | 6664206 | [261005-7zj-start-hooks-refuse-non-regular-entries-a](./quick/261005-7zj-start-hooks-refuse-non-regular-entries-a/) |

### Roadmap Evolution

- Phase 01.1 inserted after Phase 1: Best-practices bundle baked into the image (stopgap) (URGENT)
- Phase 02.1 inserted after Phase 2: Best-practices from git, editable from any sandbox
- Phase 6 added: Automated checks (CI): run tests/guard.sh on every PR push, from the PR #1 review
- Phase 01.3 inserted after Phase 1.2: Shell script layout (banners, functions, entry point in every script), from the PR #9 review
- Phase 01.4 inserted after Phase 1.3: Test suite refactor (real Docker instead of the fake, simplify, split into units), from the PR #9 review; Phase 1.3 narrowed to the non-test scripts
- Phase 01.5 inserted after Phase 1.4: Host test fixes (open Phase 1 and 1.1 review findings, proven with real Docker), from the Phase 1.3 discussion

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-10-07T05:59:14.882Z
Stopped at: Completed 01.5-04-PLAN.md
Resume file: None
