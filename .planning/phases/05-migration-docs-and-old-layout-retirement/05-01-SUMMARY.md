---
phase: 05-migration-docs-and-old-layout-retirement
plan: 01
subsystem: docs
tags: [docs, migration, guard, readme]
status: complete

requires:
  - phase: 04-gsd-bundle-and-ccusage
    provides: sbx-add, sbx-shell, sbx-rm, the new state layout the recipe fills
provides:
  - README.md as the one main doc (SANDBOX.md moved)
  - MIGRATION.md, a tested copy/paste recipe for one old sandbox
  - guard lists that scan README.md and MIGRATION.md
affects: [05-02, 05-03, 05-04, 05-05]

actuals:
  tokens: 11068
  tasks: 3
  commits: 3
plan_head_before: e050861a78bcf148f9fa1c5a90b157389db42d15
plan_head_after: db5114738e656dd4df1ed73edabbdad56fb4ba2b

tech-stack:
  added: []
  patterns: ["copy/paste recipe with set-once values and no # comments in bash blocks", "history folder name derived with LC_ALL=C sed 's/[^a-zA-Z0-9]/-/g'"]

key-files:
  created: [MIGRATION.md]
  modified: [README.md, tests/guard/isolation.sh, tests/guard/supply-chain.sh, tests/host-checklist.md, compose.yml, versions.env, base/sbx-start-lib.sh, prompts/consolidate-memories.md, tests/host/h23-caches-survive-recreate.sh]
  removed: [SANDBOX.md]

key-decisions:
  - "The recipe stops the old container with docker stop, not cc-down, so the old container stays as the rollback"
  - "PROJECT is a fifth set-once value so the stop and undo commands paste unchanged; ENC is derived, not typed"
  - "The history folder and the rename use the encoded name, because Claude Code replaces every non letter or digit with a hyphen"
  - "The gh credential helper path in .gitconfig is rewritten to /usr/local/bin/gh while copying"

requirements-completed: [DOC-01, DOC-02]

duration: 12 min
completed: 2026-11-08
---

# Phase 5 Plan 01: README as the one doc and the migration recipe Summary

README.md is now the sandbox guide (SANDBOX.md moved with git mv), every reference and both guard lists name it, and MIGRATION.md gives a dry-run-tested copy/paste recipe that moves one old sandbox (code, Claude login and sessions, ccusage history, gh login, git identity, bash history) into the new layout.

## Accomplishments

- Task 1 (tracer): `git rm` of the old-layout README.md, `git mv SANDBOX.md README.md`, H1 now `# sbx sandbox`, the side by side bullet removed. `old_layout_untouched` compares only `ClaudeCode` and `OpenCode`; `no_compromised_gsd_package` scans `README.md`; the host checklist links `../README.md` and keeps the `#troubleshooting-and-known-limits` anchor. Guard ends `All rules hold.` with 19 PASS lines; guard self-test ends `All cases pass.`
- Task 2: five one-line retargets (compose.yml, versions.env, base/sbx-start-lib.sh, prompts/consolidate-memories.md, tests/host/h23-caches-survive-recreate.sh). `git grep -n 'SANDBOX\.md' -- . ':!.planning'` prints nothing; shellcheck, `bash -n`, guard and entrypoint self-test pass.
- Task 3: MIGRATION.md with the 14 required headings, six set-once values, stop, copy, rename, optional repoint, register, three checks and the undo. README.md links it from the intro; the guard list now includes `MIGRATION.md`.
- Dry run on a fake old home (space in OLD and NEW, `CODE=My_Code.v2`): the extracted `## Move one sandbox` blocks run under `bash -eu`; code and dotfiles land in `NEW/mycode`, `.credentials.json` stays mode 600, the history folder is renamed to `-home-sandbox-workspace-mycode`, only the matching `.claude.json` key and `history.jsonl` lines are repointed, the gh helper reads `/usr/local/bin/gh`, and the checksum list of OLD is unchanged.

## Task Commits

| Task | Commit | Message |
|---|---|---|
| 1 | aac9757 | docs: make the sandbox guide the README |
| 2 | c94baf0 | docs: point every reference at README.md |
| 3 | db51147 | docs: add the migration recipe for old sandboxes |

## Deviations from Plan

None - plan executed exactly as written.

Notes (not deviations):
- The MIGRATION.md rollback bullet was reworded to "Answer `y` if `sbx-rm` asks", which is the plan's own wording.
- The `OLD_LAYOUT_COMMIT` constant in `tests/guard/isolation.sh` is unchanged (the plan keeps it); the plan's verify diffs against 2358987 for the file-level checks.

## Verification

- Task 1, 2 and 3 automated verify commands: all pass.
- Plan-level: rehearsal guard ends `All rules hold.` with 19 PASS lines after each task; `git grep -n 'SANDBOX\.md' -- . ':!.planning'` prints nothing.
- Not run here: nothing in this plan needs Docker. The first real migration on the Mac is plan 03.

## Known Stubs

None.

## Threat Flags

None.

## Issues Encountered

None.

## Next Phase Readiness

Ready for plan 02 (README rewrite). The README still carries the old section list; plan 02 rewrites it and must keep the `Troubleshooting and known limits` heading and the `Best-practices bundle` heading, which other files link to.

## Self-Check: PASSED

- MIGRATION.md and README.md exist; SANDBOX.md is gone.
- Commits aac9757, c94baf0 and db51147 exist on chore/phase-05-work.
