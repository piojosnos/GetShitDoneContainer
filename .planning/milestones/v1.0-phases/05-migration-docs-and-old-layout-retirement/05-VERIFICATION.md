---
phase: 05-migration-docs-and-old-layout-retirement
verified: 2026-11-08T08:29:39Z
status: passed
human_verification_waived: "2026-11-08: the user skipped the manual checks (\"we are not doing manual UAT\"); the 5 items stay listed below, unrun"
score: 5/7 must-haves verified
covered_files:
  - .planning/phases/05-migration-docs-and-old-layout-retirement/05-01-PLAN.md
  - .planning/phases/05-migration-docs-and-old-layout-retirement/05-01-SUMMARY.md
  - .planning/phases/05-migration-docs-and-old-layout-retirement/05-02-PLAN.md
  - .planning/phases/05-migration-docs-and-old-layout-retirement/05-02-SUMMARY.md
  - .planning/phases/05-migration-docs-and-old-layout-retirement/05-03-PLAN.md
  - .planning/phases/05-migration-docs-and-old-layout-retirement/05-03-SUMMARY.md
  - .planning/phases/05-migration-docs-and-old-layout-retirement/05-04-PLAN.md
  - .planning/phases/05-migration-docs-and-old-layout-retirement/05-04-SUMMARY.md
  - .planning/phases/05-migration-docs-and-old-layout-retirement/05-05-PLAN.md
  - .planning/phases/05-migration-docs-and-old-layout-retirement/05-05-SUMMARY.md
  - MIGRATION.md
  - README.md
  - bin/sbx-fix-modes
  - host-test.sh
  - tests/README.md
  - tests/guard/isolation.sh
  - tests/guard/supply-chain.sh
  - tests/host-checklist.md
  - tests/host/lib-docker.sh
  - tests/host/run-all.sh
covered_digest: "v2:sha256:3a478ddaef19b2966fa7b5c950755a432205c622f653e1e5bde7efe17474428c"
behavior_unverified: 0
overrides_applied: 0
gaps: []
deferred: []
human_verification:
  - test: "Run the login-survives-a-rebuild helper once on the Mac: ./host-test.sh --keep, then bash tests/host/manual/h29-upgrade-resume.sh"
    expected: "The helper ends PASS: Claude is logged in before and after sbx-upgrade and claude --continue resumes the session"
    why_human: "The automatic host run (32 passed) does not prove the login survives a rebuild: H-09 plants files and a memory, H-08 is bash history. Only the manual helper proves the login, and it was not run in this phase (the user skipped it in plan 03, plan 05 ran ./host-test.sh instead). Earlier evidence exists (Phase 3 ran the helper at 9abf603 with loggedIn true before and after), and this phase changed no image or runtime code, so the risk is low."
  - test: "Read README.md 'Threat model' and judge that it claims no isolation the sandbox lacks (judgment-tier prohibition, DOC-03)"
    expected: "Network, the tokens in state/ and files the Mac later runs are all stated as not isolated"
    why_human: "Autonomous LLM-judge verdict only (non-authoritative): the table at README.md lines 263 to 270 lists all three as 'Not isolated', so the verdict is no false isolation claim. Flagged: unverified-prohibition, human review recommended."
  - test: "Read the 'Rules' paragraph of README.md 'Threat model' for the concurrency edge"
    expected: "The rules hold whatever the timing, with no 'while the sandbox is stopped' exception"
    why_human: "Truth is tagged verification: backstop (non-inferable). Text is present at README.md line 278 ('They hold whatever the timing: an agent working while Mac-side git or an IDE runs can plant any of these at any moment.') but presence is not behavioral proof; abstained to a human."
  - test: "Read README.md and MIGRATION.md once for length and clarity (decision D-03, the user's judgment is the bar)"
    expected: "One short schematic guide; nothing to cut or move"
    why_human: "Plan 03 recorded no read of the docs by the user; simplicity is a judgment call."
  - test: "Confirm the other two moved sandboxes (email-intel, radio-practice) show login, /resume sessions and ccusage history"
    expected: "sbx-claude starts logged in, /resume lists old sessions, ccusage daily shows pre-move days"
    why_human: "Only static-site-generator has a recorded three-check report (user's words in conversation, 05-03-SUMMARY.md). For email-intel and radio-practice the evidence is the user's 'Retire now' decision, the sbx-list rows and a memory note. I observed directly that this repo's own sandbox passes (see Truth 1), so this item covers email-intel and radio-practice only (static-site-generator has its recorded report). Low risk, optional."
---

# Phase 5: Migration, Docs, and Old-Layout Retirement Verification Report

**Phase Goal:** The user's existing sandboxes run on the new layout with login and history intact. The repo contains only the new layout, and the README describes exactly what exists, including its security limits.
**Verified:** 2026-11-08T08:29:39Z
**Status:** human_needed
**Re-verification:** No, initial verification

The phase goal is not in user-story form although ROADMAP marks the phase `mode: mvp`; the plans record this and quote the goal verbatim, as earlier phases did. Standard goal-backward verification was applied. No gap blocks the goal; the status is `human_needed` only because of the flagged items above (one real evidence hole, the rest judgment items).

Docker is not available here. Mac proofs are taken from the user's run of `./host-test.sh` at c4e9879 (`host-test.log` read, ends `0 step(s) failed`, 32 PASS lines) and `sbx-list-05.log`.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC1: a sandbox moved with the README/MIGRATION steps keeps login, old sessions and ccusage history | VERIFIED | Recorded: static-site-generator moved with the recipe, three checks plus git fetch answered yes (05-03-SUMMARY.md). Observed directly in this repo's own moved sandbox (get-shit-done-container, moved last): `state/claude/.credentials.json` exists (mode 600); `state/claude/projects/-home-sandbox-workspace-get-shit-done-container/` holds 18 session `.jsonl` files plus memory, under the renamed `-home-sandbox-workspace-` path; `history.jsonl` present; `ccusage daily --offline` printed rows for 2026-10-08, 10-09 and later, i.e. pre-migration usage. `sbx-list-05.log` lists all four moved sandboxes registered. MIGRATION.md has the recipe (Once, Move one sandbox, Check, After the checks, If something is wrong, this repo last). |
| 2 | SC2: old `cc-*` scripts and whole-home-mount compose/entrypoint files are gone; every script, file and command README names exists; no phantom `cc-upgrade.sh` | VERIFIED | `ls ClaudeCode OpenCode` fails; `git ls-files` shows none of the 10 old files nor `tests/host/coexistence.sh`; `git grep` for ClaudeCode, OpenCode, cc-up/bash/down/upgrade, cc_ outside `.planning`, `.claude` and MIGRATION.md prints nothing; `cc-upgrade` appears in no tracked file. Every `sbx-*` name in README maps to `bin/` or `claude/bin/` (only `sbx-base`, `sbx-hosttest`, `sbx-tools` are image/dir names); every backticked repo path in README exists or is a documented runtime file under `state/`; every quoted cross-reference heading exists; README.md 399 lines, no prose line over 260. MIGRATION.md names `cc-up.sh`, `cc_gsd_*` on purpose (it describes the source layout of a move); the plan keeps it so. |
| 3 | SC3: README explains the two-mount layout, the `sbx-*` scripts and the upgrade flow (edit `versions.env`, one rebuild command) | VERIFIED | README.md opens with the layout table, then Quick start; the "Scripts" table covers all 8 `bin/` scripts and the 3 in-sandbox scripts; "Upgrade" states: change the pin in `versions.env`, then `sbx-upgrade NAME`. Facts checked against code: `cap_drop` and `no-new-privileges` in compose.yml, `useradd -u 1000` in base/Dockerfile, `/etc/sbx/start.d/10-best-practices` referenced by claude/bin. Compose and image files differ from the previous state only by a `SANDBOX.md` to `README.md` text retarget. |
| 4 | SC4: README has a short threat-model section covering what is isolated, credential exfiltration under skip-permissions, and planted files the Mac later runs | VERIFIED | README.md "Threat model" (lines 263 to 284): isolated/not-isolated table; `state/claude/.credentials.json`, `state/gh/hosts.yml`, `state/git/config` readable by Claude under `--dangerously-skip-permissions`; planted files `.git/hooks/*`, `core.fsmonitor`, `core.pager`, `diff.external`, `credential.helper`, `core.sshCommand`, `.idea/`, `.vscode/tasks.json`, `.vscode/launch.json`, `Makefile`, `package.json` scripts, `.mvn/`, `.envrc`; rules for git inside the sandbox and Mac-side git/IDE as running agent code. |
| 5 | SC5: a host-side verification checklist exists, runs end to end on the Mac, and confirms login survives a rebuild, versions match pins, ccusage works, home not hidden | UNCERTAIN | Checklist exists (`tests/host-checklist.md`, README "Verify a new build" table, no new file added). Mac `./host-test.sh`: `Summary: 32 passed, 0 failed, 0 not run`, 10 steps OK; it covers versions (H-25, H-30, pin digests), ccusage (H-24) and home not hidden (H-05). Login survives a rebuild is proven only by the manual helper `tests/host/manual/h29-upgrade-resume.sh`, not run in this phase. 05-05-SUMMARY.md's criteria map credits "H-08 login and history survive" to automatic checks, which overstates it: H-09 (automatic) covers files and a memory, H-08 is bash history. README itself states this correctly. Mitigation: Phase 3 verification records the helper PASS (loggedIn true before and after `sbx-upgrade`) and this phase changed no runtime file. Routed to human item 1. |
| 6 | Retirement follows the code: guard drops exactly one rule (18 remain), host run has no coexistence step, test docs count 18 rules and H-00 to H-33, `.claude/` untouched, nothing pushed | VERIFIED | I ran `bash tests/guard/run-all.sh`: 18 PASS lines, 0 FAIL, ends `All rules hold.` (shellcheck and hadolint installed here). `tests/selftest/{guard,entrypoint,sbx}/run-all.sh` each end `All cases pass.` `bash -n bin/sbx-fix-modes` ok. `host-test.sh`, `tests/host/run-all.sh`, `bin/sbx-fix-modes` are mode 100755. Branch `chore/retire-old-layout` is 2 commits on `origin/main` (adf1bf3), 17 changed paths, no `origin/chore/retire-old-layout`, `git diff HEAD -- .claude` empty, no `Co-Authored-By`/`Generated` in commit messages, no planning ID or `.planning` string in the touched files. |
| 7 | Concurrency edge (backstop): the threat-model rules hold whatever the timing, with no "while the sandbox is stopped" exception | UNCERTAIN (insufficient_spec) | Sentence present at README.md line 278. Non-inferable truth, abstained to a human (item 3). |

**Score:** 5/7 truths verified (0 present, behavior-unverified; 2 routed to human)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `README.md` | The one main doc with Threat model and Verify sections | VERIFIED | 399 lines, 21 H2 headings incl. Quick start, Upgrade, Threat model, Verify a new build |
| `MIGRATION.md` | Copy/paste recipe, 195 lines, linked from README line 12 | VERIFIED | No `#` comment lines inside bash blocks; ASCII only |
| `bin/sbx-fix-modes` | Added with user approval during the real move | VERIFIED | Executable, `bash -n` ok, listed in README scripts table and MIGRATION.md, own self-test `tests/selftest/sbx/fix-modes.sh` passes in the sbx suite |
| `tests/guard/isolation.sh` | No `old_layout_untouched`, banner "data kept" | VERIFIED | Guard 18 PASS |
| `tests/host/run-all.sh`, `tests/host/lib-docker.sh`, `tests/README.md`, `tests/host-checklist.md`, `host-test.sh` | Trimmed of the coexistence step, 18 rules, H-00 to H-33 | VERIFIED | 05-REVIEW.md: 0 critical, 0 warning, 2 info (both wording only); my guard and self-test runs agree |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| README.md | MIGRATION.md | link at line 12; "Follow 'After the checks'" row | WIRED | Heading `## After the checks` exists in MIGRATION.md |
| README.md | tests/host-checklist.md, tests/README.md, h29 helper | Verify table | WIRED | All three paths exist |
| prompts/consolidate-memories.md | README.md | names "Best-practices bundle" | WIRED | Heading `## Best-practices bundle` exists |
| tests/guard/supply-chain.sh | README.md, MIGRATION.md | file list | WIRED | `no_compromised_gsd_package` PASS |
| tests/host/run-all.sh | the Mac | `./host-test.sh` | WIRED | `host-test.log` read, 32 PASS lines |

### Data-Flow Trace (Level 4)

Not applicable: docs, shell scripts and tests render no dynamic data.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Guard holds without the old rule | `bash tests/guard/run-all.sh` | 18 PASS, 0 FAIL, `All rules hold.` | PASS |
| Guard self-test | `bash tests/selftest/guard/run-all.sh` | `All cases pass.` | PASS |
| Entrypoint self-test | `bash tests/selftest/entrypoint/run-all.sh` | `All cases pass.` | PASS |
| sbx self-test | `bash tests/selftest/sbx/run-all.sh` | `All cases pass.` | PASS |
| ccusage shows pre-migration days | `ccusage daily --offline` | rows from 2026-10-08 onward | PASS |
| README names no old-layout thing | `git grep` for old names outside `.planning`, `.claude`, MIGRATION.md | empty | PASS |

### Probe Execution

Step 7c: no `probe-*.sh` is declared or present. SKIPPED.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SCR-08 | 05-04, 05-05 | Old `cc-*` scripts and whole-home-mount layout removed from the repo | SATISFIED | Truth 2 and 6 |
| DOC-01 | 05-01, 05-02, 05-03, 05-05 | README describes new layout, scripts, upgrade flow; matches repo; no phantom `cc-upgrade.sh` | SATISFIED | Truth 2 and 3 |
| DOC-02 | 05-01, 05-03 | README/MIGRATION documents moving code, state (incl. `.claude.json`) and renaming the history path | SATISFIED | Truth 1; MIGRATION.md "What moves where"; note the steps live in MIGRATION.md, linked from README line 12, as decided in the plans |
| DOC-03 | 05-02, 05-03 | Threat-model section | SATISFIED (judgment item flagged) | Truth 4 |
| DOC-04 | 05-02, 05-03 | Host-side verification checklist for the Mac | SATISFIED with caveat | Truth 5; the login-survives-rebuild proof is the unrun manual helper |

Cross-check: `.planning/REQUIREMENTS.md` traceability maps exactly SCR-08, DOC-01, DOC-02, DOC-03, DOC-04 to Phase 5, and every ID appears in the PLAN frontmatter (05-01: DOC-01, DOC-02; 05-02: DOC-01, DOC-03, DOC-04; 05-03: DOC-01 to DOC-04; 05-04: SCR-08; 05-05: SCR-08, DOC-01). No orphaned requirement. CI-01 belongs to Phase 6.

### Prohibitions (must_haves.prohibitions)

| Prohibition | Tier | Status | Evidence |
|-------------|------|--------|----------|
| DOC-03: MUST NOT claim isolation the sandbox lacks | judgment | FLAGGED (unverified-prohibition, human review recommended) | LLM-judge, non-authoritative: no false claim found; network, tokens and planted files are listed as not isolated |
| DOC-01: MUST NOT name a nonexistent script/file/command or an old-layout name in README | test | Holds by my ad hoc check; enforcement is not wired | The plan's accuracy check was a one-off command, not a committed test, so by the fail-closed rule this is flagged rather than green. My own run found no violation. |
| DOC-04: MUST NOT add a new check, helper or test file for DOC-04 | test | Holds; enforcement not wired | No new DOC-04 file; the only added files are `bin/sbx-fix-modes` and its self-test, for the migration (approved deviation, not DOC-04) |
| DOC-02 / SCR-08: MUST NOT push, merge or open the docs/retirement PR | judgment | Holds | `origin/chore/retire-old-layout` does not exist; the docs branch was pushed and merged by the user (PRs 29 to 31), by the user's approval |
| SCR-08 / DOC-01: MUST NOT commit `.planning/` or `.claude/` in a code commit, carry planning IDs or AI attribution | test | Holds | Retirement diff has 17 paths, none under `.planning` or `.claude`; scan of touched files and commit messages is empty |
| DOC-02: MUST NOT ask the user to move this repo's own sandbox in plan 03 | judgment | Holds | 05-03-SUMMARY.md moved `StaticSiteGenerator`; this repo moved last |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| host-test.sh | 150, 172 | `XXXXXX` | Info | `mktemp` templates, not debt markers |
| tests/guard/isolation.sh | 28 | Comment cites the retired layout ("how the old layout lost data") | Info | 05-REVIEW.md IN-01; cosmetic |
| tests/README.md | 25 | "Old dev sandbox" is ambiguous | Info | 05-REVIEW.md IN-02; cosmetic |
| .claude/CLAUDE.md | 7, 19, 29 and more | Still describes `ClaudeCode/`, `cc-*` and the coexistence constraint | Warning | A generated project-context file, not layout. Out of scope for the code PRs by design (separate `.claude`-only PR); tracked in `.planning/todos/pending/2026-11-08-refresh-claude-md-for-the-new-layout.md`. No later roadmap phase covers it, so it stays a real follow-up. |

No TBD/FIXME debt markers in the files changed by the phase; no planning IDs in touched source.

### Human Verification Required

#### 1. Login survives a rebuild (SC5 / DOC-04)

**Test:** On the Mac, `./host-test.sh --keep`, then `bash tests/host/manual/h29-upgrade-resume.sh`.
**Expected:** Helper ends PASS: Claude logged in before and after `sbx-upgrade`, `claude --continue` resumes.
**Why human:** Needs a real Claude login on Docker. The automatic run does not prove this part. About 3 minutes.

#### 2. No false isolation claim (judgment prohibition, DOC-03)

**Test:** Read README.md lines 263 to 284.
**Expected:** Everything not isolated is stated as such.
**Why human:** Judgment-tier prohibition; my verdict is non-authoritative.

#### 3. Concurrency edge wording (backstop truth)

**Test:** Read README.md line 278.
**Expected:** No stopped-sandbox exception.
**Why human:** Non-inferable truth, presence is not proof.

#### 4. Docs read as short and schematic (D-03)

**Test:** Read README.md (399 lines) and MIGRATION.md (195 lines).
**Expected:** Nothing to cut or move.
**Why human:** The user's judgment is the bar; none was recorded.

#### 5. Other moved sandboxes (optional)

**Test:** In email-intel and radio-practice, run `sbx-claude`, `/resume`, `ccusage daily`.
**Expected:** Logged in, old sessions listed, pre-move days shown.
**Why human:** No per-sandbox report recorded for these two; this repo's own sandbox and static-site-generator are covered.

### Gaps Summary

No gaps. Every roadmap criterion is met in the codebase except that SC5's "login survives a rebuild" rests on earlier-phase evidence and an unrun helper, which makes the overall status `human_needed`, not `gaps_found`. Bookkeeping left for the orchestrator (not a code gap): ROADMAP.md still shows 3/5 plans for Phase 5 with 05-04 and 05-05 unchecked, and REQUIREMENTS.md still shows SCR-08 and DOC-01 to DOC-04 as `[ ]` / `Pending`. The retirement PR (`chore/retire-old-layout`) is local and unpushed, waiting for the user's go.

---

_Verified: 2026-11-08T08:29:39Z_
_Verifier: Claude (gsd-verifier)_

## Waiver

On 2026-11-08 the user declined the manual checks ("we are not doing manual UAT") and asked to close the phase. Status moved from human_needed to passed on that decision; no human item below was run. The open risk is item 1 (login survives a rebuild), last proven in Phase 3.
