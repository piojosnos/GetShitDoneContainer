---
phase: 05-migration-docs-and-old-layout-retirement
plan: 02
subsystem: docs
tags: [docs, readme, threat-model, quick-start]
status: complete

requires:
  - phase: 05-migration-docs-and-old-layout-retirement
    provides: README.md as the one main doc, MIGRATION.md
provides:
  - README.md rewritten as one short guide (396 lines) with a Quick start, a Threat model and a Verify table
affects: [05-03, 05-04, 05-05]

actuals:
  tokens: 21000
  tasks: 3
  commits: 3
plan_head_before: f26228028690dc565176189fc6a732be5f2e9c4e
plan_head_after: 2ba23b53cb44d29296e708a9d216b21ca9e2c9ae

tech-stack:
  added: []
  patterns: ["one fact in one place, rare detail at the bottom", "Verify table that maps each question to existing host checks"]

key-files:
  created: []
  modified: [README.md]

key-decisions:
  - "Quick start is the first H2, eight steps from the tools clone to sbx-claude"
  - "Raw Docker commands and the start refusals sit below the daily-use sections, above Troubleshooting"
  - "The Threat model states the rules without a timing exception, because an agent can plant a hook while Mac-side git or an IDE runs"

requirements-completed: []

duration: 25 min
completed: 2026-11-08
---

# Phase 5 Plan 02: README rewrite Summary

README.md is now one schematic guide: a Quick start table at the top, the layout, the scripts, the upgrade flow that starts from the pin in `versions.env`, a Threat model that lists what is not isolated, and a Verify table that points at the existing host checks. All 32 troubleshooting symptoms and every fact string of the old guide survive.

## Accomplishments

- Task 1 (tracer): `## Quick start` table of eight steps (tools clone, PATH line, `sbx-add`, `sbx-upgrade`, `sbx-shell`, then `sbx-gh-login`, `sbx-bundle-clone`, `sbx-claude` in the sandbox), directly before "What the images hold".
- Task 2: full rewrite into the fixed H2 order, 368 lines (old guide 476 plus the quick start). The start refusals and hook errors moved to "Safety checks", the raw commands and the image-only smoke test to "Raw Docker commands". No old-layout name remains except the MIGRATION.md bullet and the one troubleshooting row, whose fix now reads Follow "After the checks" in MIGRATION.md.
- Task 3: `## Threat model` (isolated / not isolated table, planted-file list, rules with no timing exception) between "Usage reports (ccusage)" and "Verify a new build"; the Verify section is now a four-row table (H-09 and `h29-upgrade-resume.sh`, H-25 and H-30, H-24, H-05) with `./host-test.sh`, linking `tests/host-checklist.md` and `tests/README.md`; an intro bullet points at the threat model. Final length 396 lines.

## Task Commits

| Task | Commit | Message |
|---|---|---|
| 1 | f5d3ddc | docs: add a quick start to the README |
| 2 | cd4d40d | docs: rewrite the README as one short guide |
| 3 | 2ba23b5 | docs: add the threat model and the verify table |

## Deviations from Plan

None - plan executed exactly as written.

Notes (not deviations):
- The Task 2 sandbox content was reduced by merging bullets and turning a few one-line code blocks (`sbx-start`, `sbx-list`, `sbx-rm`, `sbx-add`, `./build.sh`) into inline commands to reach the 370 line cap; the sample `sbx-list` output block was dropped and its status words are explained in bullets.
- In this dev sandbox the linters resolve, so the guard ended `All rules hold.` after each task.

## Verification

- Task 1, 2 and 3 automated checks: all pass (H2 order, named H3s, line caps 370 then 400, no prose line over 260 characters, 32 of 32 symptom cells, every fact string, every script in `bin/` and `claude/bin/`, no old-layout name, file/script/cross-reference checks on README.md and MIGRATION.md, no dash or planning ID, ASCII only).
- The guard (`tests/guard/run-all.sh`) ends `All rules hold.`
- Not run here: nothing needs Docker. The user's own read on the Mac is the final judge of "simple and schematic".

## Known Stubs

None.

## Threat Flags

None.

## Issues Encountered

None.

## Next Phase Readiness

Ready for plan 03. README.md keeps the `Troubleshooting and known limits` and `Best-practices bundle` headings that other files link to.

## Self-Check: PASSED

- README.md and 05-02-SUMMARY.md exist.
- Commits f5d3ddc, cd4d40d and 2ba23b5 exist on chore/phase-05-work.
