---
phase: 05-migration-docs-and-old-layout-retirement
plan: 03
subsystem: docs
tags: [gate, branch, mac-run, migration]
status: complete

requires:
  - phase: 05-migration-docs-and-old-layout-retirement
    provides: README.md, MIGRATION.md and the guard changes from plans 01 and 02
provides:
  - the final Linux gate record and the planning-ID scan (two false positives)
  - local branch chore/readme-and-migration with 14 docs and script commits on origin/main, not pushed
  - the first real migration of an old sandbox with MIGRATION.md, three checks passed, seven findings (five fixed in the docs PR)
  - bin/sbx-fix-modes and its self-test, added to the docs PR by the user's approval
  - the 05-VALIDATION rows for plans 01 to 03 and the host-git todo completed
affects: [the docs PR, 05-04, 05-05]

key-decisions:
  - "The Mac host checklist (./host-test.sh --keep and the h29 helper) is skipped in this plan by the user and deferred to plan 05, not passed"
  - "sbx-fix-modes joins the docs PR because the real migration showed the ownership fix resets the stored file modes"

requirements-completed: []

actuals:
  tokens: 5600
  tasks: 3
  commits: 9

plan_head_before: 8fa23cc00eda452d5352d324ab47fc33c68997b5
plan_head_after: ed52ad7282eb81bb839cb48f3266d7c0775a5237
---

# Phase 5 Plan 03: The docs gate and the first real migration Summary

**Every Linux check is green on the final docs tree, `chore/readme-and-migration` holds 14 commits on a fresh `origin/main` (not pushed), and the user moved a real old sandbox with MIGRATION.md: Claude started logged in, `/resume` listed the old sessions, `ccusage daily` showed earlier days, `git fetch` asked for no password. The Mac host checklist was skipped by the user and is deferred to plan 05.**

`commits: 9` is measured from `plan_head_before` to `plan_head_after`: the eight docs and script commits made on `chore/phase-05-work` during the Task 2 checkpoint (cherry-picked onto the docs branch) and one planning-only todo commit. The records of this plan are committed after this file.

## Gate

Final run on `chore/phase-05-work` at HEAD `ed52ad7`, `origin/main` = `2358987`. The docs branch tree equals HEAD outside `.planning`.

| Check | Result |
|---|---|
| `bash -n` on `build.sh clean.sh host-test.sh base/sbx-entrypoint base/sbx-start-lib.sh claude/start.d/* claude/bin/* bin/* tests/*/*.sh tests/*/*/*.sh` | no error |
| Guard without linters | exactly two FAIL lines: `FAIL: shellcheck_passes`, `FAIL: hadolint_passes` (last line `2 rule(s) broken.`) |
| Guard with the rehearsal linters (`/tmp/sbx-linters/bin`) | 19 `PASS:` lines, last line `All rules hold.` |
| `tests/selftest/guard/run-all.sh` | last line `All cases pass.` (158 PASS lines) |
| `tests/selftest/entrypoint/run-all.sh` | last line `All cases pass.` (60 PASS lines) |
| `tests/selftest/sbx/run-all.sh` | last line `All cases pass.` (230 PASS lines; 212 before `fix-modes.sh` added 18) |
| `wc -l README.md MIGRATION.md` | 399 and 192 (under the 400 line cap) |
| `git diff --quiet origin/main HEAD -- claude build.sh clean.sh .dockerignore ClaudeCode OpenCode .claude` | exit 0 (unchanged) |
| `git diff --name-only origin/main HEAD -- bin` | `bin/sbx-fix-modes` only (approved deviation, new file, mode 100755; its self-test `tests/selftest/sbx/fix-modes.sh` is 100755) |

The first Task 1 pass (HEAD `8fa23cc`) read: guard 19 PASS and `All rules hold.`, self-tests 158, 60 and 212 PASS, README 396 lines, MIGRATION 176 lines, accuracy checks printing nothing. The numbers above supersede it.

The Task 1 automated check "exactly eleven changed paths" no longer holds as written; see Deviations.

## Planning-ID scan

Regex: `\bD-[0-9]{2}\b|\b(SCR|DOC)-0[0-9]\b|\bT-05-|\b(SC|A|M|Z)[0-9]{1,2}\b|Phase [0-9]|CONTEXT\.md|RESEARCH\.md|\.planning` over the twelve added or modified paths outside `.planning` (the original ten plus `bin/sbx-fix-modes` and `tests/selftest/sbx/fix-modes.sh`). Two hits, both false positives, unchanged from the first pass:

| Hit | Why it is not a planning ID |
|---|---|
| `MIGRATION.md:48`: `sed 's/[^a-zA-Z0-9]/-/g'` | `Z0` inside the character class `a-zA-Z0-9` |
| `tests/guard/supply-chain.sh:39`: `grep -hE -A1 'curl|wget'` | `A1` is the grep `-A1` flag (context lines) |

The commit-message scan (`Co-Authored-By`, `Generated with`, `D-NN`, `SCR/DOC-0N`, `T-05-`, `Phase N`, `.planning`) over `git log origin/main..chore/readme-and-migration` prints nothing.

## Code commits and branch

| # | On chore/phase-05-work | On chore/readme-and-migration | Message |
|---|---|---|---|
| 1 | aac9757 | edba486 | docs: make the sandbox guide the README |
| 2 | c94baf0 | 1600f0b | docs: point every reference at README.md |
| 3 | db51147 | 63b5399 | docs: add the migration recipe for old sandboxes |
| 4 | f5d3ddc | 4210323 | docs: add a quick start to the README |
| 5 | cd4d40d | dc4e71c | docs: rewrite the README as one short guide |
| 6 | 2ba23b5 | f342c78 | docs: add the threat model and the verify table |
| 7 | 349f6a5 | b77a3d8 | docs: check the sandbox name in the migration recipe and note bypass mode |
| 8 | d939a5c | 1dc3ac6 | docs: fix state ownership after a migration and make the rules cleanup conditional |
| 9 | 0e1531d | b3b5764 | docs: fix ownership of the whole moved folder in a throwaway container |
| 10 | 02a4f7f | 1d2392e | docs: let the ownership fix reach read-only files such as git objects |
| 11 | a9536bc | 401900c | docs: add a temporary mode diagnostic to the migration recipe |
| 12 | 64e137a | 2b7cf98 | feat: add sbx-fix-modes to set file modes from git on the Mac and in the sandbox |
| 13 | dd78734 | 2f80424 | docs: use sbx-fix-modes in the migration recipe and the README |
| 14 | ed52ad7 | 40b81cf | fix: let sbx-fix-modes set the exact git mode on the Mac |

`0284d98` (`docs(todo): limit token exposure in bypass mode`) is a planning-only commit on `chore/phase-05-work` and is not on the docs branch. The temporary diagnostic of commit 11 is gone from the final tree (`grep -i diagnos MIGRATION.md README.md` prints nothing).

Branch checks, run again after the Mac findings:

- Branch tip: `40b81cf6ae0a72b22a7df4316872290dcd212350` (`40b81cf`), based on `origin/main` (`git merge-base --is-ancestor origin/main chore/readme-and-migration` succeeds).
- `git diff --quiet HEAD chore/readme-and-migration -- . ':(exclude).planning'` exits 0.
- `git diff --name-only --no-renames origin/main...chore/readme-and-migration`, thirteen paths: `MIGRATION.md`, `README.md`, `SANDBOX.md` (moved to README.md), `base/sbx-start-lib.sh`, `bin/sbx-fix-modes`, `compose.yml`, `prompts/consolidate-memories.md`, `tests/guard/isolation.sh`, `tests/guard/supply-chain.sh`, `tests/host-checklist.md`, `tests/host/h23-caches-survive-recreate.sh`, `tests/selftest/sbx/fix-modes.sh`, `versions.env`. No `.planning` path.
- `git ls-remote --heads origin chore/readme-and-migration` prints nothing. Nothing was pushed. `git config --get branch.chore/readme-and-migration.merge` is empty (no upstream). `git worktree list` holds no scratch worktree of this plan.

## Task 2: the Mac run

### Part A: host checklist (./host-test.sh --keep and the h29 helper)

SKIPPED by the user. Reason given: the docs PR changes no image or runtime behaviour beyond name retargets, and plan 05 runs the full Mac checklist anyway. Recorded as deferred to plan 05, not passed:

- `./host-test.sh --keep` expected `Summary: 33 passed, 0 failed, 0 not run`; not run in this plan.
- `tests/host/manual/h29-upgrade-resume.sh` not run; the h29 cleanup line (T-05-13) was therefore not needed.
- `/home/sandbox/h29m-05.log` does not exist and `host-test.log` was not read. The Docker Desktop and Compose versions are not recorded here.
- The affected 05-VALIDATION rows are marked deferred, not green (see Task 3).

### Part C: the first real migration

The user moved the old sandbox `StaticSiteGenerator` (old PROJECT and container from `cc-up.sh`) to the new layout: `NAME=static-site-generator`, new folder `/Users/demian/gsd-workspace/StaticSiteGenerator`. This is not this repo's own sandbox. Evidence is the user's report in conversation: `/home/sandbox/migrate-05.log` does not exist (the steps file expected it there), so no projects listing and no settings.json counts were captured.

| Check | User's answer |
|---|---|
| `sbx-claude` started with no login prompt | yes |
| `/resume` listed the old sessions | yes |
| `ccusage daily` showed days from before the move | yes |
| `git fetch --dry-run` asked for no password | yes |
| Optional recipe step 5 (the two sed lines on `.claude.json`) | not stated |

### Assumption rows

| ID | Assumption | Result | Evidence |
|---|---|---|---|
| A1 | `cp -Rp SRC/. DST/` copies dotfiles and contents the same on macOS as on Linux | confirmed for contents; modes and owners needed fixes | the three checks pass; finding 2 and 3 below show the copy keeps the old container's owner and mode in an attribute |
| A3 | the rollback keeps working after the new sandbox refreshed the login | not exercised | the user did not try the undo |
| A4 | the first start adds no second set of GSD hooks to a copied settings.json | not recorded | the two `grep -c '"command"'` counts were not captured (no `migrate-05.log`); open question 1 of the research stays open |
| A6 | `ccusage daily` shows the days from before the move | confirmed | third check, yes |
| A8 | `/resume` lists the old sessions without a transcript rewrite | confirmed | second check, yes |
| A10 | the optional sed lines keep `.claude.json` valid | not stated | the user did not report whether the optional step ran |
| Z1 | every block pastes into zsh without an error | not stated as a whole | none of the seven findings is a zsh syntax error; they are name, ownership and mode problems found by pasting the blocks |

### User's read of the docs

No notes on README.md or MIGRATION.md length or clarity were given beyond the findings below.

### Findings from the real move

Each was found during the real move. Fixes are in the docs PR unless marked open.

| # | Finding | Status |
|---|---|---|
| 1 | A NAME that breaks the sandbox name rule (the user used `StaticSiteGenerator`) was rejected only at step 6 by `sbx-add`, after copies already used the name | FIXED: step 1 now ends with a name check line (`b77a3d8`) |
| 2 | Docker Desktop on macOS keeps the container-side owner and mode of each bind-mounted file in the extended attribute `user.containers.override_stat` (uid:gid:mode). `cp -p` copied the old container's uid 1001, so private files (for example `.git/config`, mode 600) gave `Permission denied` to the new uid 1000. The Linux dry run cannot see this | FIXED: step 6 runs `chown -R 1000:1000` in a throwaway container (the sandbox drops all capabilities, so its root cannot chown); read-only files such as git objects are made writable for the chown and restored, because macOS refuses attribute writes on read-only files (`1dc3ac6`, `b3b5764`, `1d2392e`) |
| 3 | That chown resets the stored modes: many files showed 755 or 777 in the sandbox and git showed mode changes; a `chmod` inside the sandbox never reaches the Mac mode | FIXED: new host script `bin/sbx-fix-modes NAME` sets every git-tracked file to 644 or 755 as git committed, on the Mac and in the attribute; step 6 runs it; README documents it (scripts table, troubleshooting row). Verified on the Mac on the moved sandbox: `assemble.sh` and `generate.sh` 755, `README.md` 644 (`2b7cf98`, `2f80424`, `40b81cf`) |
| 4 | Something created `state/claude/sessions` as root in the new sandbox; unexplained | OPEN, harmless; no action |
| 5 | "After the checks" removed `@AGENTS.md` and `@code-conventions.md` lines unconditionally, but this sandbox had no `state/claude/CLAUDE.md` | FIXED: the cleanup runs only if the file exists and holds those lines (`1dc3ac6`) |
| 6 | `sbx-claude` passes arguments, including `--dangerously-skip-permissions`, and bypass mode exposes the tokens in `state/` | FIXED: README notes it and what it exposes (`b77a3d8`); hardening logged as `.planning/todos/pending/2026-11-08-limit-token-exposure-in-bypass-mode.md` (`0284d98`) |
| 7 | The moved project's own `.claude/settings.local.json` came along unchanged and held stale deny rules (`git checkout main`); the user's agent fixed it in that project | Observed, not a recipe issue |

### Gaps

No gap needs `/gsd-plan-phase 5 --gaps`: findings 1, 2, 3, 5 and 6 were fixed in the docs PR with the user's approval; 4 is open and harmless; 7 is not a recipe issue. Still unrecorded: A4 (hook counts), A10 (optional sed step), A3 (rollback). Plan 05 or the next migration can close them.

## Criteria

Proofs: **Linux** = a line of the Gate table; **Dry run** = the recipe run on a fake old home with spaces in the paths in plan 01 (the old folder's checksums did not change); **Mac** = the user's report of the real migration; **Deferred** = left to plan 05.

| Item | Proof |
|---|---|
| DOC-01 README matches the repo | Linux: accuracy checks print nothing, guard 19 PASS, README 399 lines. |
| DOC-02 migration documented | Dry run (plan 01), then the real move of `StaticSiteGenerator` with the three checks and the git fetch answered yes (Mac) |
| DOC-03 threat model | Linux: Threat model tokens check (plan 02 Task 3); README names `.git/hooks/*` and the five config keys |
| DOC-04 host checklist runs end to end | Deferred to plan 05: `./host-test.sh` (33 passed expected as `Summary: 33 passed, 0 failed, 0 not run`) and the h29 helper were not run in this plan. Not met yet |
| Roadmap 1 move with login and history | Mac: the three checks plus git fetch, yes |
| Roadmap 3 README explains layout, scripts, upgrade flow | Linux: H2 order and fact-string checks (plan 02); accuracy checks above |
| Roadmap 4 threat-model section | Linux, as DOC-03 |
| Roadmap 5 checklist runs end to end on the Mac | Deferred to plan 05 |
| D-01 no migration script, no new shell | DEVIATION: `bin/sbx-fix-modes` and its self-test were added with the user's approval, because the real move showed the need (finding 3). Everything else is copy/paste |
| D-02 SANDBOX.md becomes README.md | Linux: branch diff lists `SANDBOX.md` moved to `README.md` |
| D-03 README simple and schematic | Linux: line caps, symptom cells, tables; the user's final read is part of the plan 05 checks |
| D-04 recipe in MIGRATION.md | Linux: `MIGRATION.md` exists, 192 lines, linked from README |
| D-05 references point at README.md | Linux: `git grep SANDBOX.md` empty outside `.planning` (plan 01 Task 2) |
| D-06 copy, never move the old folder | Dry run: OLD checksums unchanged |
| D-07 variables set once | Dry run: blocks pasted unchanged under `bash -eu`; Mac: pasted by the user (Z1 above) |
| D-08 what is carried over | Mac: login, sessions, ccusage and git credentials carried over |
| D-09 order of commands | Mac: the real move found one ordering problem (finding 1), fixed by moving the name check to step 1 |
| D-10 three checks and the way back | Mac: three checks yes. The rollback itself was not exercised (A3) |
| D-11 example values from the roadmap | Linux: plan 01 doc checks |
| D-12 Mac tools clone for this dev sandbox | Linux: MIGRATION.md section present. Not exercised on the Mac for this repo's own sandbox |
| D-13 this sandbox migrated last | Not moved here; listed under Next |
| D-14, D-15 | plan 04 |
| D-16 threat model section | Linux, as DOC-03 |
| D-17 host git documented as a rule | Linux: README line 274 names the hooks and the five keys; the host-git todo moved to `.planning/todos/completed/` |
| D-18 acceptance by moving the smallest sandbox | Mac: `StaticSiteGenerator` moved, the three checks pass |
| D-19 existing checklist covers DOC-04 | Deferred to plan 05: the checklist exists but was not run here |

## Task 3: validation rows and todo

- 05-VALIDATION.md rows 05-01-T1 to 05-02-T3, 05-03-T1 and 05-03-T3 set to green. Row 05-03-T2 reads `deferred to 05-05 (migration green)`: the migration part passed, the Mac checklist part was not run. The Manual-Only row for the host checklist notes it as deferred. Rows for plans 04 and 05 stay pending; frontmatter stays `status: draft`.
- Host-git todo: README.md's Threat model names the planted git hooks and the five config keys (line 274), so `gsd-tools todo complete 2026-10-24-host-git-on-agent-writable-folders.md` ran. It moved from `.planning/todos/pending/` to `.planning/todos/completed/2026-10-24-host-git-on-agent-writable-folders.md`.
- DOC requirements are not marked complete: DOC-04 depends on the deferred Mac run, and the plan 05 gate decides the set.

## PR description draft

Title: `docs: one README for the sandbox, plus the migration recipe`

What changed:

- The sandbox guide becomes `README.md` and is rewritten as one short guide: a quick start, the layout and scripts, the upgrade flow, a threat model that lists what is not isolated, and a verify table.
- `MIGRATION.md` moves an old sandbox into the new layout by copy/paste: code, Claude login and sessions, ccusage history, gh login, git identity and shell history. The old folder is only read and the old container is only stopped, so it stays the way back.
- The recipe checks the sandbox name in step 1, before anything is copied, and fixes the ownership and file modes that Docker Desktop on macOS keeps in an extended attribute, so a moved folder works for the new user.
- New host script `bin/sbx-fix-modes NAME` sets every git-tracked file to 644 or 755 as git committed, on the Mac and in the sandbox. It comes with a self-test case, and the README lists it in the scripts table and in troubleshooting.
- The README notes that `sbx-claude` passes arguments through (including `--dangerously-skip-permissions`) and what tokens that exposes.
- Every reference points at `README.md` (compose.yml, versions.env, the start message in `base/sbx-start-lib.sh`, the memory prompt, the host checklist and one host test comment).
- The old-layout guard rule stops comparing the old `README.md`; the supply-chain rule scans `README.md` and `MIGRATION.md`.
- One start message in `base/` names `README.md`, so `sbx-upgrade` is needed to pick it up.

What you accept:

- Host git safety is a documented rule, not a control: an agent can plant hooks and git config keys that Mac-side git or an IDE then runs.
- Bypass mode exposes the tokens under `state/`; limiting that is logged as future work.
- The old layout stays in the repo and is removed in a later PR, after every sandbox has moved.
- One unexplained root-owned `state/claude/sessions` folder was seen once in a moved sandbox; it is harmless.

How it was verified:

- The Linux gate: `bash -n` on every script, the guard with and without linters, the three self-tests, README and MIGRATION accuracy checks.
- The recipe ran on a fake old home with spaces in the paths, and the old folder's checksums did not change.
- One real old sandbox was moved on the Mac with the recipe: Claude started logged in, `/resume` listed the old sessions, `ccusage daily` showed days from before the move, and `git fetch` asked for no password. `sbx-fix-modes` was checked on that sandbox (scripts 755, README 644).
- The full host checklist (`./host-test.sh`) was not run for this PR; it runs before the old layout is removed.

## Next

For the user, in this order:

1. Give the go to push `chore/readme-and-migration` and open its PR against `main` (the branch holds 14 commits; no gap blocks it).
2. Merge it on GitHub.
3. Run `git -C "$HOME/sbx-tools/GetShitDoneContainer" pull`.
4. Move the other old sandboxes with MIGRATION.md (it now includes `sbx-fix-modes`), this repo's own last (its closing section).
5. In the new sandbox of this repo, run `/gsd-execute-phase 5` to continue with the retirement (plan 04). Plan 05 runs the Mac checklist that this plan deferred (`./host-test.sh`, the h29 helper).

## Deviations from Plan

**1. [Approved by the user: scope] `bin/sbx-fix-modes` and its self-test joined the docs PR**
- **Found during:** Task 2, the real migration (finding 3).
- **Issue:** the ownership fix of finding 2 resets the stored modes, and a `chmod` in the sandbox never reaches the Mac mode.
- **Fix:** the user asked to add `bin/sbx-fix-modes` to this docs PR, so `chore/readme-and-migration` holds 14 commits (not 6) and 13 changed paths (not 11): also `bin/sbx-fix-modes` and `tests/selftest/sbx/fix-modes.sh`, with further fixes in `MIGRATION.md` and `README.md`.
- **Effect on the plan:** Task 1's automated check "exactly eleven paths" and the must-have "bin/ unchanged against origin/main" no longer hold as written. Re-verified instead: the branch is based on `origin/main`; its tree equals HEAD outside `.planning`; no commit message carries a planning ID or AI attribution; nothing is on origin; `claude/`, `build.sh`, `clean.sh`, `.dockerignore`, `ClaudeCode/`, `OpenCode/` and `.claude/` are unchanged; `bin/` differs by exactly the new file.
- **Commits:** `2b7cf98`, `2f80424`, `40b81cf` on the docs branch.

**2. [Skipped by the user: verification] The Mac host checklist was not run**
- **Plan said:** Task 2 runs `./host-test.sh --keep` and the h29 helper before the migration.
- **What happened:** the user skipped Part A, because the docs PR changes no image or runtime behaviour beyond name retargets and plan 05 runs the full checklist.
- **Effect:** DOC-04 and roadmap criterion 5 are not proven by this plan. The 05-VALIDATION rows are marked deferred, not green.

**3. [Rule 3: process] The migration log was not written**
- `/home/sandbox/migrate-05.log` does not exist, so the settings.json hook counts (A4) and the projects listing were not captured. The migration evidence is the user's report.

## Known Stubs

None.

## Threat Flags

None. `bin/sbx-fix-modes` is a host script that writes only the sandbox's own folder; it was reviewed by the guard (19 PASS) and its own self-test.

## Self-Check: PASSED

- 05-03-SUMMARY.md, 05-VALIDATION.md and `.planning/todos/completed/2026-10-24-host-git-on-agent-writable-folders.md` exist; the pending copy is gone.
- Docs branch commits `b77a3d8`, `1dc3ac6`, `b3b5764`, `1d2392e`, `401900c`, `2b7cf98`, `2f80424`, `40b81cf` exist on `chore/readme-and-migration`; the matching `349f6a5`, `d939a5c`, `0e1531d`, `02a4f7f`, `a9536bc`, `64e137a`, `dd78734`, `ed52ad7` exist on `chore/phase-05-work`.
