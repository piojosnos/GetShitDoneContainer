---
phase: "05"
slug: "migration-docs-and-old-layout-retirement"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-08"
---

# Phase 05 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Plain bash suites (no framework) |
| **Config file** | none |
| **Quick run command** | `bash tests/guard/run-all.sh` |
| **Full suite command** | `./host-test.sh` (on the Mac) |
| **Estimated runtime** | ~30 seconds (guard suite) |

---

## Sampling Rate

- **After every task commit:** Run `bash tests/guard/run-all.sh`
- **After every plan wave:** Run `bash tests/selftest/sbx/run-all.sh` plus the one-off README accuracy check (see RESEARCH.md)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-T1 | 01 | 1 | DOC-01 | T-05-03, T-05-04 | only README.md leaves the old-layout pathspec; the supply-chain scan covers README.md | tracer (rename + guard) | SANDBOX.md untracked; README.md H1; pathspec line; guard list; checklist links; rehearsal guard 19 PASS; guard self-test | n/a | ⬜ pending |
| 05-01-T2 | 01 | 1 | DOC-01 | n/a | n/a | grep + lint | `git grep -n 'SANDBOX\.md' -- . ':!.planning'` empty; five exact lines; numstat 5 5; bash -n, shellcheck; guard; entrypoint self-test | n/a | ⬜ pending |
| 05-01-T3 | 01 | 1 | DOC-02 | T-05-01, T-05-02, T-05-04, T-05-05, T-05-06 | modes kept; OLD unchanged; quoted paths; docker stop keeps the rollback | dry run (fake old home) + doc checks | bash blocks of "Move one sandbox" run under bash -eu on a spaced fake home with CODE=My_Code.v2; checksum of OLD unchanged; headings and exact lines; no # in bash blocks; style; guard 19 PASS | n/a | ⬜ pending |
| 05-02-T1 | 02 | 2 | DOC-01 | T-05-10 | every named file and script exists | tracer (doc + accuracy) | Quick start first H2 with its eight commands; file, script and cross-reference checks; guard | n/a | ⬜ pending |
| 05-02-T2 | 02 | 2 | DOC-01 | T-05-10 | no old-layout name in README | doc checks | H2 order; at most 370 lines; no prose line over 260; 32 symptom cells of `git show 2358987:SANDBOX.md`; fact strings; env vars; scripts; upgrade flow; guard | n/a | ⬜ pending |
| 05-02-T3 | 02 | 2 | DOC-03, DOC-04 | T-05-07, T-05-08, T-05-09 | the doc states what is not isolated and the planted-file rules | doc checks | Threat model tokens; Verify table rows; at most 400 lines; style, ASCII, planning IDs; accuracy, script and cross-reference checks over README.md and MIGRATION.md | n/a | ⬜ pending |
| 05-03-T1 | 03 | 3 | DOC-01..04 | T-05-11, T-05-12 | no planning IDs or attribution on the docs branch | gate + git | full Linux suite; planning-ID scan; chore/readme-and-migration with exactly eleven paths, tree equals HEAD, not on origin | n/a | ⬜ pending |
| 05-03-T2 | 03 | 3 | DOC-02, DOC-04 | T-05-13, T-05-14 | test login removed by the cleanup; old sandbox only read | checkpoint (Mac) | `./host-test.sh --keep`: Summary 33 passed; `h29-upgrade-resume.sh` PASS; smallest sandbox moved, three checks pass; settings.json counts equal | n/a | ⬜ pending |
| 05-03-T3 | 03 | 3 | DOC-01..04 | n/a | n/a | records | rows set; criteria and Next recorded; host-git todo completed | n/a | ⬜ pending |
| 05-04-T1 | 04 | 4 | SCR-08 | T-05-15 | nothing deleted before the user's go | checkpoint (decision) | SUMMARY holds "Decision: retire" or "Decision: wait" | n/a | ⬜ pending |
| 05-04-T2 | 04 | 4 | SCR-08 | T-05-16 | exactly one guard rule and one host step removed | tracer (delete + guard) | old paths untracked; isolation.sh, run-all.sh, lib-docker.sh trimmed; run-all.sh 100755; bash -n, shellcheck; guard 18 named PASS; three self-tests | n/a | ⬜ pending |
| 05-04-T3 | 04 | 4 | SCR-08 | n/a | n/a | doc checks | tests/README.md 18 rules and H-00 to H-33; no Coexistence; host-test.sh comment and mode; old-layout scan empty; guard | n/a | ⬜ pending |
| 05-05-T1 | 05 | 5 | SCR-08, DOC-01 | T-05-19, T-05-20 | no planning IDs on the retirement branch; docs name nothing removed | gate + git | full Linux suite with 18 rules; old-layout scan; chore/retire-old-layout with exactly seventeen paths, tree equals HEAD, not on origin | n/a | ⬜ pending |
| 05-05-T2 | 05 | 5 | SCR-08 | T-05-18 | n/a | checkpoint (Mac) | `./host-test.sh`: Summary 32 passed; sbx-list shows the four moved sandboxes | n/a | ⬜ pending |
| 05-05-T3 | 05 | 5 | all | n/a | n/a | records | all rows set; criteria map SC1 to SC5, SCR-08, DOC-01 to DOC-04, D-01 to D-19; CLAUDE.md follow-up todo; .claude/ untouched | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Existing infrastructure covers all phase requirements: the guard, the three self-tests, `./host-test.sh` and `tests/host/manual/h29-upgrade-resume.sh` already exist; the recipe dry run and the README accuracy checks are one-off verify commands in the plans, never committed (no new shell, no new test).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| An old sandbox moved with MIGRATION.md keeps its login, sessions and ccusage history | DOC-02 | needs the user's real old sandbox, Docker and a Claude login on the Mac | plan 03 Task 2: move the smallest old sandbox; sbx-claude logged in, /resume lists old sessions, ccusage daily shows earlier days |
| The host checklist runs end to end and login survives a rebuild | DOC-04 | Docker exists only on the Mac; the helper needs a real login | plan 03 Task 2: `./host-test.sh --keep` (33 passed), then `bash tests/host/manual/h29-upgrade-resume.sh` |
| README.md reads as one short schematic guide | DOC-01 | the user's judgment is the bar (simple, streamlined) | plan 03 Task 2 step 5: the user reads README.md and MIGRATION.md and notes what to cut or move |
| Every old sandbox moved before the old layout is deleted | SCR-08 | only the user knows their sandboxes | plan 04 Task 1: decision checkpoint "retire" or "wait" |
| The host run passes without the old layout | SCR-08 | Docker exists only on the Mac | plan 05 Task 2: `./host-test.sh` (32 passed), sbx-list shows the moved sandboxes |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** {pending / approved YYYY-MM-DD}
