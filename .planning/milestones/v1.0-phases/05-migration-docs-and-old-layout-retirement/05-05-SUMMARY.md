---
phase: 05-migration-docs-and-old-layout-retirement
plan: 05
subsystem: infra
tags: [gate, branch, mac-run, retirement]
status: complete

requires:
  - phase: 05-migration-docs-and-old-layout-retirement
    provides: the two retirement commits of plan 04 on chore/retire-old-layout
provides:
  - the final Linux gate record for the retirement tree
  - the verified local branch chore/retire-old-layout, not pushed
  - the PR description draft
  - the Mac run without the old layout: 32 host checks passed, 0 failed, 0 not run
  - the filled validation map, the criteria map and the CLAUDE.md follow-up todo

requirements-completed: [SCR-08, DOC-01]

actuals:
  tokens: 6400
  tasks: 3
  commits: 0

plan_head_before: c4e987927c851fa01f3b207b143a799a20ecade8
plan_head_after: c4e987927c851fa01f3b207b143a799a20ecade8
---

# Phase 5 Plan 05: The retirement gate and the Mac run Summary

Every Linux check is green on the retirement tree, `chore/retire-old-layout` holds exactly plan 04's two commits on origin/main (17 changed paths, nothing pushed), and the Mac run without the old layout passed: `Summary: 32 passed, 0 failed, 0 not run`, every host-test.sh step OK, all five sandboxes registered.

This plan made no commits (`commits: 0`); the two code commits are plan 04's.

## Gate

Run in the repo root at HEAD `c4e9879` on `chore/retire-old-layout`; `origin/main` = `adf1bf3`.

| Check | Result |
|---|---|
| `bash -n` on `build.sh clean.sh host-test.sh base/sbx-entrypoint base/sbx-start-lib.sh claude/start.d/* claude/bin/* bin/* tests/*/*.sh tests/*/*/*.sh` | no error |
| Guard (`tests/guard/run-all.sh`; shellcheck and hadolint are at /usr/local/bin) | 18 `PASS:` lines, last line `All rules hold.` |
| `tests/selftest/guard/run-all.sh` | last line `All cases pass.` (158 PASS lines) |
| `tests/selftest/entrypoint/run-all.sh` | last line `All cases pass.` (60 PASS lines) |
| `tests/selftest/sbx/run-all.sh` | last line `All cases pass.` (230 PASS lines) |
| `wc -l README.md MIGRATION.md` | 399 and 195 |
| README and MIGRATION accuracy check (plan 02 Task 3, second command) | prints nothing, exit 0 |
| `git grep -nE 'ClaudeCode\|OpenCode\|cc-up\|cc-bash\|cc-down\|cc-upgrade\|[Cc]oexistence\|old_layout_untouched' -- . ':!.planning' ':!.claude' ':!MIGRATION.md'` | prints nothing (grep exit 1) |
| `git ls-files ClaudeCode OpenCode tests/host/coexistence.sh` | prints nothing |
| `git diff --quiet origin/main HEAD -- base claude bin compose.yml build.sh versions.env .dockerignore README.md MIGRATION.md .claude` | exit 0 (unchanged) |
| Task 1 first verify command, verbatim | exit 0 |

The 18 guard rules that print PASS: `no_docker_socket_or_privileges`, `host_scripts_keep_sandbox_data`, `shellcheck_passes`, `hadolint_passes`, `no_installs_at_container_start`, `start_hooks_have_two_digit_names`, `gsd_sync_runs_before_the_bundle`, `compose_starts_in_the_workspace`, `agent_image_keeps_base_state_folders`, `no_compromised_gsd_package`, `gsd_installs_only_the_official_package`, `no_pipe_to_shell_installers`, `installs_use_pins`, `no_floating_latest_versions`, `versions_file_has_one_pin_per_line`, `pins_are_exact`, `dockerfile_args_have_no_defaults`, `every_dockerfile_arg_is_pinned`.

## Planning-ID scan

Regex of plan 03 Task 1 step 2 over the six files that `git diff --name-only --no-renames --diff-filter=AMR origin/main...HEAD -- . ':(exclude).planning'` lists (`host-test.sh`, `tests/README.md`, `tests/guard/isolation.sh`, `tests/host-checklist.md`, `tests/host/lib-docker.sh`, `tests/host/run-all.sh`): no hit. Nothing to fix and no false positive to record.

## Code commits

| Commit | Message | `.planning/` or `.claude/` path | Planning ID or attribution in message |
|---|---|---|---|
| 95bebbb | chore: retire the old ClaudeCode and OpenCode layout | none (14 paths: the 10 old-layout files, `tests/host/coexistence.sh`, `tests/guard/isolation.sh`, `tests/host/lib-docker.sh`, `tests/host/run-all.sh`) | none |
| c4e9879 | docs: drop the coexistence check from the test docs | none (3 paths: `host-test.sh`, `tests/README.md`, `tests/host-checklist.md`) | none |

## Branch

- `git fetch origin` ran; `origin/main` = `adf1bf39b82f8f66cc7b666f993fe0c50f1a5b7a`. This is the last commit that holds `ClaudeCode/` and `OpenCode/`, and it holds `MIGRATION.md` (`git cat-file -e origin/main:MIGRATION.md` succeeds).
- `chore/retire-old-layout` is the current branch, `origin/main` is its ancestor, and `git log --oneline origin/main..HEAD` lists exactly 95bebbb and c4e9879. Branch tip: `c4e987927c851fa01f3b207b143a799a20ecade8`.
- `git branch --unset-upstream` reported that the branch has no upstream (already unset). `git ls-remote --heads origin chore/retire-old-layout` prints nothing: nothing is pushed.
- `git diff --name-only --no-renames origin/main...chore/retire-old-layout` lists exactly the 17 expected paths.
- No scratch worktree was created and none is registered for this branch.

## PR description draft

Title: `chore: retire the old ClaudeCode and OpenCode layout`

```
Removes the old layout now that every old sandbox runs on the new one.

What changed
- ClaudeCode/ and OpenCode/ are deleted (10 files).
- tests/host/coexistence.sh is deleted, with the host step that only checked the old layout stayed unchanged.
- The guard rule that kept the old layout unchanged is removed; the guard now has 18 rules.
- The helpers that only served that step are removed from tests/host/lib-docker.sh and tests/host/run-all.sh.
- The test docs and host-test.sh count 18 guard rules and H-00 to H-33.

Where the old files live
They stay in git history. The last commit that holds them is adf1bf39b82f8f66cc7b666f993fe0c50f1a5b7a, for example:

    git show adf1bf39b82f8f66cc7b666f993fe0c50f1a5b7a:ClaudeCode/docker-compose.yml

What you accept
Old containers kept on the Mac are no longer managed by any script here. Start one with plain docker start until you delete it.

How it was verified
- On Linux: bash -n on every script, the guard (18 PASS lines, "All rules hold."), the guard, entrypoint and sbx self-tests ("All cases pass."), the README and MIGRATION accuracy checks, and a scan that no tracked file outside MIGRATION.md names the old layout.
- On the Mac: ./host-test.sh with "Summary: 32 passed, 0 failed, 0 not run" and every step OK, and sbx-list showing the moved sandboxes registered on the new layout.
```


## Deviations from Plan

**1. [Process] Task 1 step 4 verified in place instead of building the branch in a worktree**
- **Reason:** the orchestrator ran plans 01 to 05 directly on `chore/retire-old-layout`, cut from the up-to-date `origin/main`, so the branch already holds exactly plan 04's two commits.
- **What was done instead:** no branch creation, no temporary worktree, no cherry-pick. `git fetch origin`; confirmed `origin/main` is an ancestor; `git branch --unset-upstream` (no upstream existed); `git ls-remote --heads origin chore/retire-old-layout` is empty; recorded the tip. The guard and the three self-tests ran in the main worktree (all green, above).
- **Effect on the second verify command:** its `git diff --quiet HEAD chore/retire-old-layout` part is trivially true, because HEAD is that branch. Its other parts (ancestry, exact 17 paths, clean messages, nothing on origin, no scratch worktree) are real checks.

## Task 2: the Mac run

Run by the user on 2026-11-08 (00:19 PST) on the Mac, branch `chore/retire-old-layout` at `c4e9879`, with `./host-test.sh`. The results below come from the user's pasted terminal output; `host-test.log` (repo root) was read afterwards and agrees on every point checked (summary line, versions, the SKIP, the INFO pin line, the ten step lines).

| Item | Result |
|---|---|
| run-all.sh summary line | `Summary: 32 passed, 0 failed, 0 not run` (32 `PASS: H-` lines in the log) |
| `FAIL`, `NOT RUN` or `SETUP` lines | none |
| Host checks that passed | H-00, H-02, H-03, H-12, H-17, H-21, H-25, H-27, H-01, H-04, H-05, H-06, H-13, H-14, H-15, H-18, H-22, H-24, H-26, H-30, H-08, H-16, H-23, H-11, H-09, H-28, H-29, H-31, H-32, H-33, H-20, H-10 |
| H-32 | passed, "with no cc_ container" (the removed coexistence step is not missed) |
| Docker | 28.5.1, build e180ab8; Docker Desktop 4.48.0 (207573); Compose v2.40.0-desktop.1; Mac `/bin/bash` 3.2.57 |
| Linters on the Mac | ShellCheck 0.11.0, hadolint 2.15.1 |
| Exec bits | the exec-bit fix printed nothing; `ls -l` showed `-rwx--x--x` on both scripts, executable, so `sbx-fix-modes` was not needed |

host-test.sh steps (all OK, final line `0 step(s) failed.`):

| Step | Result |
|---|---|
| context | OK |
| sbx self-test in the Mac shell | OK (`All cases pass.`) |
| host checks | OK |
| run folder | OK |
| linter versions | OK |
| pin digests | OK (TEMURIN, UV, SHELLCHECK and HADOLINT pass) |
| guard and self-tests in sbx-hosttest | OK (18 PASS, `All rules hold.`; guard and entrypoint self-tests `All cases pass.`) |
| guard in the Mac shell | OK (18 PASS, `All rules hold.`) |
| build warnings | OK (none) |
| remove test sandbox | OK |

Lines that are not failures, recorded verbatim:

- `SKIP: xattr is installed here, so its absence cannot be tested` (sbx self-test in the Mac shell; the case needs a machine without `xattr`).
- `INFO: UBUNTU_IMAGE pins sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac, the registry now has sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852 (a newer image; bump the pin when convenient)`.

`sbx-list` (the log is `/home/sandbox/workspace/sbx-list-05.log`):

| NAME | STATUS | PATH |
|---|---|---|
| canvas-graph | running, older image | /Users/demian/gsd-workspace/CanvasGraph |
| email-intel | running, older image | /Users/demian/gsd-workspace/EmailIntel |
| get-shit-done-container | running, older image | /Users/demian/gsd-workspace/GetShitDoneContainer |
| radio-practice | running, older image | /Users/demian/gsd-workspace/RadioPractice |
| static-site-generator | running, older image | /Users/demian/gsd-workspace/StaticSiteGenerator |

The four moved sandboxes (email-intel, get-shit-done-container, radio-practice, static-site-generator) are all registered. `canvas-graph` is a fifth, new sandbox that was never on the old layout. "older image" is expected: host-test.sh just rebuilt the image, and `sbx-start NAME` recreates each sandbox on it (this closes its open shells and Claude sessions).

No gap: nothing needs `/gsd-plan-phase 5 --gaps`.

Not run, in either plan: `./host-test.sh --keep` followed by `tests/host/manual/h29-upgrade-resume.sh` (the plan 03 checkpoint the user skipped). The automatic host run covers the same ground (H-05 home not hidden, H-08 history survives recreate, H-24 ccusage, H-25 images match the pins, H-29 upgrade), so it is the proof used for roadmap criterion 5; the manual helper stays an optional extra.

## Task 3: validation map and records

- `05-VALIDATION.md`: all 15 task rows are `green`; 05-03-T2 reads that its migration part passed in plan 03 and its Mac checklist part passed here (05-05-T2). Wave 0 ticked and `wave_0_complete: true`; `nyquist_compliant: true` (every task has an automated command or a human check, never three in a row without one); `status: validated`; sign-off ticked, approval 2026-11-08.
- Why `validated`: the two Mac runs are plan 03's real migration (passed) and this plan's host run (passed). Plan 03 did not run its own host checklist; it deferred it to this plan, and this plan's run covers it.
- `.planning/todos/pending/2026-11-08-refresh-claude-md-for-the-new-layout.md` created.
- `.claude/` is untouched (`git diff --quiet HEAD -- .claude` exits 0).

## Criteria

Proofs: **Linux** = a line of the Gate table above; **Mac 05** = the host run in this plan; **Mac 03** = the real migration recorded in `05-03-SUMMARY.md`; **Plan 04** = `05-04-SUMMARY.md`.

| Item | Proof |
|---|---|
| SC1 a migrated sandbox keeps login, sessions and ccusage | Mac 03: `StaticSiteGenerator` moved, the three checks and git fetch answered yes. Mac 05: all four old sandboxes are registered on the new layout (sbx-list) |
| SC2 old layout gone, README names only things that exist | Linux: old paths absent from `git ls-files`, old-layout scan empty, accuracy check prints nothing (no `cc-upgrade` anywhere). Mac 05: guard has 18 rules and passes without the old layout |
| SC3 README explains the two mounts, the `sbx-*` scripts, the upgrade flow | Linux: accuracy checks over README.md and MIGRATION.md; README and MIGRATION unchanged against origin/main; docs gate in `05-03-SUMMARY.md` |
| SC4 README has a short threat-model section | Linux: README unchanged since the docs PR; threat-model token check (plan 02 Task 3, cited in `05-03-SUMMARY.md`) |
| SC5 the host checklist runs end to end on the Mac | Mac 05: `Summary: 32 passed, 0 failed, 0 not run`, every host-test.sh step OK (H-08 login and history survive, H-25 versions match the pins, H-24 ccusage, H-05 home not hidden) |
| SCR-08 old layout retired, the rest still works | Plan 04 (decision "Retire now", deletion commits); Linux gate (18 guard rules, three self-tests); Mac 05 (32 host checks) |
| DOC-01 README matches the repo | Linux: accuracy checks print nothing, README 399 lines, old-layout scan empty |
| DOC-02 migration documented | Mac 03: the real move with the three checks; Mac 05: four moved sandboxes registered |
| DOC-03 threat model | Linux: as SC4 |
| DOC-04 host checklist | Mac 05: as SC5 (the manual h29 helper was not run, see Task 2) |
| D-01 no migration script, no new shell | Plan 03 recorded one approved deviation (`bin/sbx-fix-modes`); everything else is copy/paste |
| D-02 SANDBOX.md becomes README.md | docs PR, `05-03-SUMMARY.md` branch diff; Linux: README.md unchanged against origin/main |
| D-03 README simple and schematic | Linux: README 399 lines (under the 400 cap); docs gate |
| D-04 recipe in MIGRATION.md | Linux: MIGRATION.md unchanged against origin/main, 195 lines, accuracy check passes |
| D-05 references point at README.md | Linux: old-layout scan empty; no `SANDBOX.md` reference (docs gate) |
| D-06 copy, never move the old folder | Plan 01 dry run (old folder checksums unchanged), cited in `05-03-SUMMARY.md` |
| D-07 variables set once | Plan 01 dry run under `bash -eu`; Mac 03 pasted by the user |
| D-08 what is carried over | Mac 03: login, sessions, ccusage and git credentials carried over |
| D-09 order of commands | Mac 03: one ordering problem found and fixed (name check first) |
| D-10 three checks and the way back | Mac 03: three checks yes; the rollback itself was not exercised |
| D-11 example values from the roadmap | Plan 01 doc checks |
| D-12 Mac tools clone for the dev sandbox | MIGRATION.md section present; used for the four moves (Mac 05 shows all registered) |
| D-13 this sandbox migrated last | Mac 05: `get-shit-done-container` is registered on the new layout and the retirement ran only after it moved |
| D-14 ClaudeCode/ and OpenCode/ deleted entirely | Linux: `git ls-files ClaudeCode OpenCode` empty; Plan 04 |
| D-15 deletion last, only after every sandbox moved, with the old-layout checks | Plan 04: decision "Retire now" after the user confirmed all four moved; the guard rule, host step and helpers removed; Linux: 18 rules, old-layout scan empty; Mac 05: 32 checks, no coexistence step |
| D-16 threat-model section | Linux: as SC4 |
| D-17 host git documented as a rule | docs PR, README unchanged against origin/main; the host-git todo was completed in plan 03 |
| D-18 acceptance by moving the smallest sandbox | Mac 03: `StaticSiteGenerator`, three checks pass |
| D-19 existing checklist covers DOC-04 | Mac 05: `./host-test.sh` ran end to end and passed; no new test was built |

## Follow-ups

- **New todo:** `.planning/todos/pending/2026-11-08-refresh-claude-md-for-the-new-layout.md`; `.claude/CLAUDE.md` still describes the old layout and needs its own `.claude/`-only PR.
- **Bump the `UBUNTU_IMAGE` pin** in `versions.env` when convenient: the registry has a newer image (`sha256:fe815609...`, pinned `sha256:68ee2200...`). Not blocking.
- **Recreate the sandboxes on the new image** when convenient: `sbx-start NAME` for each of the five (canvas-graph, email-intel, get-shit-done-container, radio-practice, static-site-generator). It closes open shells and Claude sessions, so do it between sessions.
- **User memory notes** that name `/home/sandbox/...` paths for steps files and `host-test.log` (mac-test-entry-point, terminal-cannot-copy-paste, and the Mac folder name in them) now live under `/home/sandbox/workspace/`: steps file `/home/sandbox/workspace/mac-steps-05b.txt`, logs `/home/sandbox/workspace/<name>/host-test.log` and `/home/sandbox/workspace/sbx-list-05.log`.
- **`.planning/PROJECT.md`:** the Coexistence constraint is retired at the phase transition.
- **The code PR waits for the user's go** to push `chore/retire-old-layout` (then `gh pr create --base main --head chore/retire-old-layout` with the draft above). Nothing was pushed.
- **Optional:** the manual `./host-test.sh --keep` plus `tests/host/manual/h29-upgrade-resume.sh` run was never done; the plan 03 gaps A3, A4 and A10 are still unrecorded.

## Known Stubs

None.

## Threat Flags

None. No file was added to the repo and nothing was pushed.

## Self-Check: PASSED

- `05-VALIDATION.md` rows, the todo file and this SUMMARY exist and hold what they claim (Task 3 verify command: exit 0).
- `git rev-list --count c4e9879..HEAD` = 0, matching `commits: 0`; `git diff --quiet HEAD -- .claude` exits 0.
- Mac results match `host-test.log` (summary line, versions, SKIP, INFO, ten OK steps).
