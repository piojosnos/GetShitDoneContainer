---
phase: 05-migration-docs-and-old-layout-retirement
plan: 04
subsystem: infra
tags: [retirement, guard, host-tests, docs]
status: complete

requires:
  - phase: 05-migration-docs-and-old-layout-retirement
    provides: README.md and MIGRATION.md on origin/main, all four old sandboxes moved
provides:
  - ClaudeCode/, OpenCode/ and tests/host/coexistence.sh removed from the repo (kept in git history)
  - a guard with 18 rules (the old-layout rule is gone) and a host run without the coexistence step
  - test docs that count 18 guard rules and H-00 to H-33 only
affects: [05-05]

key-decisions:
  - "Retire now: the user confirmed all four old sandboxes run on the new layout and the docs PR is merged"
  - "bin/sbx-list and H-32 are untouched: their cc_ handling stays true while old stopped containers sit on the Mac"

requirements-completed: [SCR-08]

actuals:
  tokens: 8100
  tasks: 3
  commits: 2

plan_head_before: adf1bf39b82f8f66cc7b666f993fe0c50f1a5b7a
plan_head_after: c4e987927c851fa01f3b207b143a799a20ecade8
---

# Phase 5 Plan 04: Retire the old layout Summary

The old ClaudeCode/ and OpenCode/ layout and the one guard rule, one host step and the helpers that only protected it are deleted; the other 18 guard rules and all three self-test suites still pass.

## Decision

Decision: retire (2026-11-08). The user's words: "Retire now". All four old sandboxes run on the new layout (this repo's own moved last) and the docs PR is merged (origin/main holds MIGRATION.md, checked with `git cat-file -e origin/main:MIGRATION.md`).

## Commits

| Task | Commit | Message |
|---|---|---|
| 2 | 95bebbb | chore: retire the old ClaudeCode and OpenCode layout |
| 3 | c4e9879 | docs: drop the coexistence check from the test docs |

Both sit on `chore/retire-old-layout`, cut from origin/main (adf1bf3). Nothing is pushed.

The last commit on main that still holds ClaudeCode/ and OpenCode/ is adf1bf3 (for the plan 05 PR description).

## What changed

- Removed: the 7 files of `ClaudeCode/`, the 3 files of `OpenCode/`, `tests/host/coexistence.sh`.
- `tests/guard/isolation.sh`: banner ends "data kept"; `OLD_LAYOUT_COMMIT` and `old_layout_untouched` are gone; `run_rules` ends with `host_scripts_keep_sandbox_data || exit 1`.
- `tests/host/run-all.sh` (still 100755): no `finalCheckList`, no `record_old_layout`; `remainingList` is the fatal check plus the three lists; Main ends with `run_sandbox_checks` then `finish "not reached"`.
- `tests/host/lib-docker.sh`: `snapshot_old_containers` and `snapshot_old_folders` removed; `claude_pin` kept.
- `tests/README.md`: 18 guard rules; host row reads "H-00 to H-33 against real Docker".
- `tests/host-checklist.md`: Coexistence row and bullet removed.
- `host-test.sh` (still 100755): comment reads "H-00 to H-33; builds both images first".

## Verification

| Check | Result |
|---|---|
| Task 2 verify, first command (removed paths, symbols, banners, mode, bash -n, shellcheck, no stale references) | exit 0 |
| Task 2 verify, second command (guard rehearsal: 18 PASS lines, each named rule passing, ends "All rules hold."; guard, sbx and entrypoint self-tests end "All cases pass.") | exit 0 |
| Task 3 verify (doc strings, modes, ASCII only, no tracked file outside .planning, .claude and MIGRATION.md names the old layout, guard ends "All rules hold.") | exit 0 |

shellcheck and hadolint are installed at /usr/local/bin; the rehearsal PATH entry `/tmp/sbx-linters/bin` does not exist and was harmless, as the plan expected. The host (real Docker) run was not performed here (no Docker in this sandbox); plan 05 owns the Mac run.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. No new network, auth, file-access or schema surface; the change only deletes files and checks.

## Next

Ready for 05-05 (the gate, the PR, the Mac run). Follow-up for plan 05: `.claude/CLAUDE.md` still describes the old layout and stays out of this code PR.

## Self-Check: PASSED

- ClaudeCode/, OpenCode/ and tests/host/coexistence.sh: absent from disk and from `git ls-files`.
- Commits 95bebbb and c4e9879 exist on `chore/retire-old-layout`.
- `git rev-list --count adf1bf3..HEAD` = 2, matching `commits: 2`.
