# Phase 6: Test diet (research)

**Researched:** 2026-11-13
**Domain:** deleting and trimming this repo's own bash test suites (guard, self-tests, host checks); no external libraries
**Confidence:** HIGH (every inventory item below was read in the repo this session; the few judgment calls are listed under Open Questions)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Carried forward (v2 decisions doc, not re-asked)
- **D-01:** Deletions only, no rewrite. Phases 8 to 10 rebuild what is left.
- **D-02:** No test drives Claude (no `claude -p`). Proxies only: a file, link, owner or env var is in place.
- **D-03:** Host check IDs keep their gaps; nothing is renumbered (Phase 8 names checks by ID).

### Persistence proxies (DIET-03)
- **D-04:** The fake credentials file and the fake session file are planted in H-09 (rebuild and recreate) and in H-29 (`sbx-upgrade`), next to the sentinels those checks already plant. Both use one small shared plant and check helper, so the two checks stay alike. No new host check.
- **D-05:** `DISABLE_UPDATES`, the managed settings and the bundle links are proved by the parts of H-13, H-14 and H-15 that stay (see D-06); no extra check for them.

### What stays in the trimmed checks (DIET-02)
- **D-06:**
  - H-13 keeps the five env vars (including `DISABLE_UPDATES`) and the two "no local claude" path tests; the `claude update` reply goes.
  - H-15 keeps "the container reads the clone's rule through `~/.claude/rules`"; the `claude -p /context` listing goes.
  - H-16 keeps the live clone, the relink on restart and the user files surviving it; the "GSD aged and resynced to the pin" part and its GSD skill edit go.
  - H-23 keeps the cache folders under `state/`, the tools finding them and a marker surviving a recreate; the Maven download from Maven Central goes.

### No stand-in docker at all (DIET-05, changes roadmap criterion 1)
- **D-07:** Both stand-ins go: the scripted fake docker and the 7-line fence in `tests/selftest/sbx/lib.sh` (`start_group`, `make_scripted_docker`, `set_standin_*`, `reset_standin_calls`, `run_sbx_scripted`, `no_docker_call`). The user wants no mock of Docker in the tests.
- **D-08:** The sbx self-test keeps the cases where a script must refuse before Docker (bad name, wrong usage, unregistered name, refusal before compose). They run with `DOCKER_HOST=unix:///nonexistent` set by the group setup, so the real `docker` cannot reach any daemon. A case that calls Docker too early fails on its exit code and error text. Every case that needs Docker to answer (container running, stopped, older image, `ps` rows, down failing) is deleted; H-28 to H-33 cover those paths with real Docker.
- **D-09:** Roadmap criterion 1 and DIET-05 say "only the 7-line fence stays". Update both to "no stand-in `docker` is left" in the same planning change.

### host-test.sh (DIET-01)
- **D-10:** `--keep` stays, reworded as "leave the test sandbox up to look around after a failure". The `tests/host/manual/` hint and the "holds a Claude login if a helper logged in" text in the cleanup output go (`host-test.sh` header and `tests/host/run-all.sh` `print_next_block`).
- **D-11:** H-00 becomes one preflight line in `host-test.sh` (Compose v2 present); `h00-compose-v2.sh` and its fatal slot in `tests/host/run-all.sh` go.

### Claude's Discretion
- Which self-test cases count as "refuses before Docker" when sorting `start.sh`, `shell.sh`, `list.sh` and `rm.sh`; a group left with no case is deleted with its `run-all.sh` entry.
- The exact guard rule shape for the managed deny entries and the one-FROM rule (DIET-04), and which three `tests/guard/start.sh` rules H-20 covers.
- How H-11 folds into H-28 (stop is quick and keeps the files).
- Doc updates that follow the deletions: `tests/README.md`, `tests/host-checklist.md`, the README and `MIGRATION.md` mentions of the manual helpers.

### Deferred Ideas (OUT OF SCOPE)
- A `docker` wrapper script or a dry-run flag in the `sbx-*` commands, so the refusal tests can prove that no Docker call was made. Revisit in Phase 10 (host side to Python), where the pytest refusal group lands.

Reviewed todos (not folded): the bundle hook todos (atomic links, keeping user skills), the `sbx-claude` wait and the GSD root-owned files: Phase 9 (`sbx-init`). `sbx-bundle-clone` error hint, `sbx-gh-login` skip, the leaked-token limit: Future Requirements. MIGRATION.md follow-ups, the CLAUDE.md refresh and the phase 5 review nits: docs work, not a test diet.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DIET-01 | No test needs a person at the keyboard: `tests/host/manual/` and every interactive helper are gone | Deletion inventory (section 1), reference sweep (section 2), run-all and host-test edits (sections 4 and 5); no interactive call remains outside `manual/` (grep in Validation) |
| DIET-02 | No test drives Claude or checks Claude, GSD, Docker or Maven Central behaviour: H-18, `fake-claude-api.js`, H-21, H-24, H-02 and those parts of H-13, H-15, H-16 and H-23 are gone; H-00 becomes one preflight line; H-11 merges into H-28 | Per-check edit lists (section 4), H-00 preflight (4.2), H-11 fold (4.3) |
| DIET-03 | Proxies replace the manual helpers: planted fake credentials and session files survive recreate and `sbx-upgrade`; `DISABLE_UPDATES` set; managed settings present; bundle links resolve | Shared plant helper (section 6); D-05 maps the other three proxies to H-13, H-14, H-15 which stay |
| DIET-04 | Guard rules assert the managed deny entries and the one-FROM rule; the guard self-test, the `sbx-rm` source-line rule and the three start rules H-20 covers are gone | Guard section 8 with tested rule code; Open Questions 1 and 2 pin the two judgment calls |
| DIET-05 | No stand-in `docker` is left; refusal cases run with `DOCKER_HOST` pointing nowhere; `start-library.sh` and the name-rule cases of the entrypoint self-test are gone | sbx self-test classification (section 7), entrypoint self-test (section 9) |
</phase_requirements>

## Summary

This is a deletion phase in our own bash tree, so the work is an exact inventory, not library research. Whole files to delete: 7 manual helpers plus `lib-manual.sh` (8 files, 950 lines), `fake-claude-api.js`, the 5 guard self-test files, `start-library.sh`, and six host checks (`h00`, `h02`, `h11`, `h18`, `h21`, `h24`). Four host checks (H-13, H-15, H-16, H-23) are trimmed, two (H-09, H-29) gain one shared plant helper, and H-28 absorbs the stop-timing half of H-11. In the sbx self-test, `lib.sh` loses the fence and the scripted fake (about 190 of 299 lines), `start.sh`, `shell.sh`, `list.sh` and `rm.sh` shrink to their refusal cases (about 230 passing cases drop to about 120), and the other five groups lose only their `no_docker_call` line.

Three findings change how the plan must be written. First, the Docker CLI documents that `DOCKER_CONTEXT` overrides `DOCKER_HOST`, so `start_group` must `unset DOCKER_CONTEXT` as well as export `DOCKER_HOST`, or a Mac shell with a context set still reaches the real daemon. Second, deleting `tests/host/manual/` breaks exactly one guard rule (`no_compromised_gsd_package`, whose glob names `tests/host/manual/*.sh`); I reproduced this in a scratch copy, so the guard edit must land with the directory deletion. Third, D-09 is already applied: ROADMAP criterion 1 and DIET-05 already read "no stand-in `docker` is left", so no planning doc edit is needed for it.

Two roadmap phrases need a user confirmation before the plan locks, because the code does not decide them: which three start rules H-20 "covers", and how much of the `sbx-rm` guard rule is the "source-line rule". Both have a recommended answer below (Open Questions 1 and 2).

**Primary recommendation:** Split into three plans by verification surface: (A) guard, entrypoint and sbx self-tests plus the `selftest/guard` deletion, all provable in the dev sandbox; (B) host checks, `run-all.sh`, `host-test.sh`, the new helper and `host-test.sh` preflight, provable only by `bash -n`, the guard and the Mac run; (C) docs sweep last. Land the manual-directory deletion and the `supply-chain.sh` glob fix in the same commit.

## Project Constraints (from CLAUDE.md and global rules)

- GSD comes only from `@opengsd/gsd-core`; the guard rule `no_compromised_gsd_package` enforces it and must keep scanning the remaining test files. [VERIFIED: .claude/CLAUDE.md Constraints]
- Docker is not available in the dev sandbox, so plans must include host-side manual verification steps: the Mac gate is `./host-test.sh`, then read `host-test.log`. [VERIFIED: .claude/CLAUDE.md Constraints, memory mac-test-entry-point]
- Host shell code is stock bash 3.2 with BSD tools (no associative arrays, no `mapfile`, no `${var,,}`; `date +%s`, `sed`, `stat` portable forms only). [VERIFIED: tests/host/lib.sh header]
- Never extend a stand-in docker; use a host check instead. [VERIFIED: memory fake-docker-quasi-deprecated]
- Coding rules apply to every edited and new shell file: braces on every `if`/`for`/`while`, a blank line before and after control flow, full variable names, collection suffixes (`xList`), ASCII only in source, no dash punctuation in comments or docs, no planning IDs (D-xx, DIET-xx, phase numbers) in committed source or docs. The H-nn check IDs are the repo's own test names and stay.
- Docs: match the neighbouring voice, schematic tables, docs follow code.
- Write automated tests for new behavior (memory). The guard self-test is being deleted by DIET-04, so the two new guard rules get no committed self-test; prove them once with a scratch-copy negative control in the plan's verify step (command in Validation Architecture).
- Git: new branch from updated `main`, no AI attribution in commit messages, explicit staging, push only on the user's go, planning and code in separate PRs. After sandbox edits run `git diff --summary` and restore any lost exec bit (memory sandbox-edits-drop-exec-bit-on-mac).

## Architectural Responsibility Map

| Capability | Primary tier | Secondary tier | Rationale |
|------------|-------------|----------------|-----------|
| Refusal cases of `bin/sbx-*` | sbx self-test (dev sandbox and Mac shell, no daemon) | none | `DOCKER_HOST` nowhere makes any early Docker call fail on exit code and text |
| Everything that needs Docker to answer (running, stopped, older image, ps rows, down) | Host checks H-28 to H-33 on the Mac | none | D-08: real Docker only; no mock |
| Persistence proxies (fake credentials and session survive) | Host checks H-09 and H-29 | none | The bind mount is the thing under test, so it needs real Docker |
| Env, managed settings, bundle links | Host checks H-13, H-14, H-15 | guard (deny entries in source) | Runtime proof stays on the Mac; the guard asserts the source files |
| One-FROM rule, deny entries, supply chain | Guard (reads files only) | host H-14 reads the deny entries in the image | Cheap, runs in the dev sandbox and in CI later |
| Compose v2 preflight | `host-test.sh` | none | One line before any step; D-11 |

## Standard Stack

No packages are installed or added. The tools already in the repo are the stack: bash (5.2.21 here, 3.2 on the Mac), `shellcheck` and `hadolint` through the guard, plain `expect`/`PASS`/`FAIL` helpers in `tests/selftest/lib-expect.sh`, and the host helpers in `tests/host/lib*.sh`. [VERIFIED: tool probes this session, see Environment Availability]

Package Legitimacy Audit: not applicable, no external package is recommended.

## Architecture Patterns

### Test surface after the phase

```
dev sandbox (no Docker)                           Mac (Docker Desktop)
-----------------------                           --------------------
tests/guard/run-all.sh   (17 rules)               ./host-test.sh
tests/selftest/sbx/      DOCKER_HOST nowhere        context, sbx selftest under /bin/bash 3.2,
tests/selftest/entrypoint/                          tests/host/run-all.sh (26 checks, chained),
                                                    run folder, linters, pin digests,
                                                    guard + entrypoint selftest in sbx-hosttest,
                                                    guard in Mac shell, build warnings, cleanup
     preflight line: Compose v2 present, else stop before any step
```

### Recommended edit order inside the repo

1. `tests/guard/supply-chain.sh` glob fix, then delete `tests/host/manual/` (same commit).
2. Delete `tests/selftest/guard/` together with its entry in `host-test.sh` `sandbox_suites`.
3. sbx self-test (`lib.sh` first, then each group), entrypoint self-test.
4. Guard rule changes (add two, delete three, trim one).
5. Host checks, `run-all.sh`, `host-test.sh`, new `lib-login.sh`.
6. Docs sweep last, so it describes the final tree.

### Anti-patterns to avoid

- **Renumbering host checks.** IDs keep gaps (D-03). The checklist header becomes "H-01 to H-33 with gaps", not a new range.
- **Re-creating a docker double "just for the refusal cases".** Deferred to Phase 10; the replacement is the environment, not a script.
- **Rewriting a kept case.** The only edits to kept cases are the ones forced by removed helpers (see 7.3).

## 1. Deletion inventory

| Path | Lines | Referenced by (all must be edited in the same plan) |
|------|-------|-----------------------------------------------------|
| `tests/host/manual/h07-login.sh` | 85 | `tests/host-checklist.md`, `README.md` |
| `tests/host/manual/h09-rebuild-resume.sh` | 96 | same |
| `tests/host/manual/h13-doctor.sh` | 29 | same, plus H-13 header |
| `tests/host/manual/h16-gsd-bump.sh` | 153 | same |
| `tests/host/manual/h19-bundle-behaviour.sh` | 229 | same, plus H-15 reading-a-failure bullet |
| `tests/host/manual/h29-upgrade-resume.sh` | 149 | same, plus `README.md:338` |
| `tests/host/manual/h31-jump-in.sh` | 111 | same, plus `host-checklist.md:110` |
| `tests/host/manual/lib-manual.sh` | 98 | only the helpers |
| `tests/host/support/fake-claude-api.js` | 132 | H-18 only, `host-checklist.md:121` |
| `tests/selftest/guard/helpers.sh`, `lib.sh`, `linters.sh`, `run-all.sh`, `sandbox-rules.sh` | 386 | `host-test.sh:120`, `tests/README.md` |
| `tests/selftest/entrypoint/start-library.sh` | 51 | runner picks groups by glob; `tests/README.md` row only |
| `tests/host/h00-compose-v2.sh` | 53 | `run-all.sh` (`fatalCheck`, `run_compose_check`, `remainingList`), checklist |
| `tests/host/h02-claude-on-base.sh` | 81 | `run-all.sh` noSandbox list, checklist |
| `tests/host/h11-stop-is-quick-and-safe.sh` | 85 | `run-all.sh` chain list, checklist (two places) |
| `tests/host/h18-scope-and-deny.sh` | 216 | `run-all.sh` sandbox list, checklist (table row and a reading-a-failure bullet) |
| `tests/host/h21-bad-name-refused.sh` | 100 | `run-all.sh` noSandbox list, checklist (row and bullet), `tests/README.md:36` |
| `tests/host/h24-ccusage-reports-usage.sh` | 89 | `run-all.sh` sandbox list, checklist, `README.md:340` |
| Both stand-in `docker` scripts | n/a | They are generated text inside `tests/selftest/sbx/lib.sh` (`start_group` writes the fence, `make_scripted_docker` writes the scripted fake); there is no separate file to delete |

There is no `tests/selftest/guard` reference in `tests/guard/*` or `tests/selftest/sbx/*`; the only code reference is `host-test.sh:120`. [VERIFIED: grep this session]

Files that stay but become unused (not in the delete list, so leave them and say so in the summary): `tests/host/support/bundle/rules/sbx-fixture-shell.md` (only H-15's deleted listing and H-18 used its scoped-rule meaning; it is still diffed by `check_bundle_links` and cloned by the fixture origin, so deleting it is optional and outside DIET-02).

Counts: host checks 32 files now, 26 after (`h00 h02 h11 h18 h21 h24` gone). Guard rules 18 now, 17 after (see section 8).

## 2. Reference sweep (every live mention outside `.planning/`)

Found with `grep -rIn 'manual\|fake-claude-api\|H-00\|H-02\|H-11\|H-18\|H-21\|H-24\|selftest/guard\|start-library'` over the repo, excluding `.planning` and `.gsd`.

| File:line | Text to change |
|-----------|----------------|
| `host-test.sh:6` | `# --keep leaves the test sandbox up for the helpers in tests/host/manual/.` becomes a line saying `--keep` leaves the test sandbox up to look around after a failure (D-10) |
| `host-test.sh:52` | `# host_checks: H-00 to H-33; builds both images first` becomes `H-01 to H-33` |
| `host-test.sh:107` | comment "the guard and both self-tests inside sbx-hosttest" becomes "the guard and the entrypoint self-test" |
| `host-test.sh:120` | drop `tests/selftest/guard/run-all.sh` from the `for suite in` list |
| `tests/host/run-all.sh:21-26` | `fatalCheck`, the three lists and `remainingList` (see 4.1) |
| `tests/host/run-all.sh:143-156` | `print_next_block`: header comment "and where the helpers are"; line 149 "The run folder holds a Claude login if a helper logged in:"; line 155 "If something looks wrong, see tests/host/manual/" |
| `tests/host/run-all.sh:239-248` | `run_compose_check` function and its call in Main |
| `tests/host/h09-rebuild-keeps-files-no-volumes.sh:6` | "The login and claude --continue part is manual/h09-rebuild-resume.sh." |
| `tests/host/h13-env-and-no-self-update.sh:6` | "The claude doctor part needs a terminal: manual/h13-doctor.sh." |
| `tests/guard/supply-chain.sh:14` | glob `tests/host/manual/*.sh` in `no_compromised_gsd_package` (this one breaks the guard when the folder is gone) |
| `README.md:338` | Verify table row "Login survives a rebuild" |
| `README.md:340` | Verify table row "ccusage works / H-24" |
| `README.md:344` | bullet "The other helpers in `tests/host/manual/` ..." |
| `README.md:356` | "each may hold a test Claude login" (now only a fake login; delete the clause) |
| `clean.sh:76` | comment "Each run folder may hold a test Claude login." (delete the line) |
| `tests/README.md:13,16,36,38-45,51,56-63` | suite table, `--keep` sentence, "Host checks H-12, H-16, H-17, H-20 and H-21", the whole `tests/selftest/guard/` section, the sbx section, the host section |
| `tests/host-checklist.md` | see 10 |
| `MIGRATION.md`, `ZSCALER.md` | **no mention** of the helpers, H-checks or host-test (grep returned nothing); nothing to edit despite the CONTEXT note |

## 3. Runtime State Inventory

This is a deletion phase, not a rename, but the five categories were answered for completeness.

| Category | Items found | Action required |
|----------|-------------|------------------|
| Stored data | Old Mac run folders `$TMPDIR/sbx-hosttest-*` may hold a real Claude login left by the removed helpers | None in code; `./clean.sh --yes` already removes them. Keep that advice in README |
| Live service config | None; no external service names a deleted file | None |
| OS-registered state | None; no launchd, cron or hook runs a deleted script | None |
| Secrets and env vars | None read by deleted code except `ANTHROPIC_API_KEY=sk-ant-dummy` and `ANTHROPIC_BASE_URL`, set inline in H-15 and H-18 and removed with them | None |
| Build artifacts | `host-test.log` (gitignored) is regenerated every run | None |

## 4. Host checks

### 4.1 `tests/host/run-all.sh` after the phase

Current lines 21 to 24, quoted verbatim [VERIFIED: tests/host/run-all.sh:21-24]:

```
fatalCheck="h00-compose-v2.sh"
noSandboxCheckList="h02-claude-on-base.sh h03-variable-interpolation.sh h12-plain-run-refused-pin-installed.sh h17-start-offline-and-failing-hook.sh h21-bad-name-refused.sh h25-images-match-versions.sh h27-bundle-clone-and-publish.sh"
sandboxCheckList="h01-native-arch.sh h04-nonroot-user.sh h05-workspace-and-home.sh h06-git-and-identity.sh h13-env-and-no-self-update.sh h14-wrappers-and-settings-in-image.sh h15-bundle-linked-and-visible.sh h18-scope-and-deny.sh h22-toolchain-in-base.sh h24-ccusage-reports-usage.sh h26-isolation-by-inspect.sh h30-version-line.sh"
chainCheckList="h08-history-survives-recreate.sh h16-live-clone-and-restart.sh h23-caches-survive-recreate.sh h11-stop-is-quick-and-safe.sh h09-rebuild-keeps-files-no-volumes.sh h28-sbx-add-start-stop.sh h29-sbx-upgrade.sh h31-sbx-shell.sh h32-sbx-list.sh h33-sbx-rm.sh h20-mistyped-name-refused.sh h10-missing-folder-refused.sh"
```

After the phase (remove `fatalCheck` and its use in `remainingList`; the chain order is otherwise unchanged):

```
noSandboxCheckList="h03-variable-interpolation.sh h12-plain-run-refused-pin-installed.sh h17-start-offline-and-failing-hook.sh h25-images-match-versions.sh h27-bundle-clone-and-publish.sh"
sandboxCheckList="h01-native-arch.sh h04-nonroot-user.sh h05-workspace-and-home.sh h06-git-and-identity.sh h13-env-and-no-self-update.sh h14-wrappers-and-settings-in-image.sh h15-bundle-linked-and-visible.sh h22-toolchain-in-base.sh h26-isolation-by-inspect.sh h30-version-line.sh"
chainCheckList="h08-history-survives-recreate.sh h16-live-clone-and-restart.sh h23-caches-survive-recreate.sh h09-rebuild-keeps-files-no-volumes.sh h28-sbx-add-start-stop.sh h29-sbx-upgrade.sh h31-sbx-shell.sh h32-sbx-list.sh h33-sbx-rm.sh h20-mistyped-name-refused.sh h10-missing-folder-refused.sh"
remainingList="$noSandboxCheckList $sandboxCheckList $chainCheckList"
```

5 + 10 + 11 = 26 checks. Also delete `run_compose_check` (lines 239 to 248 region) and its Main call, and update the header comment above the lists if it mentions the fatal slot. `finish` and `fatal` stay (still used by `check_docker_reachable` and the setup steps).

### 4.2 H-00 as one preflight line (D-11)

Today H-00 is fatal: a failed Compose check ends the run via `finish`. `host-test.sh` only records FAIL and continues, so the preflight must exit early, not be a `run_step`. Put it at the top of `main` in `host-test.sh`, before the first `run_step`. Pattern, bash 3.2 safe (`docker compose version --short` prints `v2.x.y` or `2.x.y`; H-00 strips the `v` the same way):

```bash
docker compose version --short </dev/null 2>&1 | grep -Eq '^v?([2-9]|[1-9][0-9])\.' || { echo "Docker Compose v2 or newer is required; install Docker Desktop"; exit 1; }
```

`exit` inside `main` ends the left side of the `main 2>&1 | tee` pipe; the script then exits with `PIPESTATUS[0]` which is 1. The message still reaches `host-test.log` through `tee`. Direct runs of `bash tests/host/run-all.sh` lose the Compose check; a Compose v1 machine would then fail later at `compose_up`. Accept this (D-11 puts the line in `host-test.sh` only) and say so in the checklist.

### 4.3 H-11 into H-28 (D-06 discretion)

H-11 proves three things: (1) `compose down` took under 10 s, (2) the container is gone after down, (3) project and state sentinels are intact, then it restarts. H-28 already runs `sbx-stop` and, in `check_stop`, asserts the container is stopped but kept and that both sentinel files (`$sbxDir/hosttest/h28-sentinel.txt`, `$sbxDir/state/h28-sentinel.txt`) are unchanged [VERIFIED: tests/host/h28-sbx-add-start-stop.sh `check_stop`]. So (2) and (3) are already covered on the stronger real path (`sbx-stop` is `compose stop`, which keeps the container). Only the timing is new. Fold it as about six lines in `check_stop`:

```bash
  stopStart=$(date +%s)
  run_sbx h28-stop sbx-stop hosttest
  stopSeconds=$(( $(date +%s) - stopStart ))
  ...
  if [ "$stopSeconds" -ge 10 ]; then
    add_problem "sbx-stop took $stopSeconds s; 10 s or more means the stop fell through to a kill"
  fi
```

(`stopStart` and `stopSeconds` as `local`.) Compose waits 10 s before it kills, which is why 10 is the threshold in H-11's own comment. Update H-28's report text with "sbx-stop returned in under 10 s". Remove `h11-stop-is-quick-and-safe.sh` from the chain list. `compose_down` in H-11 is a different command from `sbx-stop`; the fold intentionally times the user-facing one. [ASSUMED: A5, that dropping the `compose down` timing loses nothing the user cares about]

### 4.4 H-13 (env and no self-update): D-06

Keep: `read_environment` env capture, the two `test ! -e` path probes, `check_variables_set` (CLAUDE_CONFIG_DIR, DISABLE_UPDATES, HISTFILE, GH_CONFIG_DIR, GIT_CONFIG_GLOBAL), `check_no_share_folder`, `check_no_local_bin_copy`.
Delete: line 6 (`The claude doctor part ...`), the `updateOutput=$(run_timeout 60 in_container claude update)` line, the function `check_updates_disabled` and its Main call, and "claude update is disabled" in the `report_check` pass text. Reword the header comment of `read_environment` ("the claude update reply" goes). `DISABLE_UPDATES=1` is set at `claude/Dockerfile:62` [VERIFIED: claude/Dockerfile:62], so the env-var proof stays meaningful.

### 4.5 H-15 (bundle linked): D-06

Keep: `. lib-bundle.sh`, `check_bundle_links "$configDir" "$cloneDir"`, `check_container_view`, `cloneDir` and `configDir` variables.
Delete: the whole `check_claude_view` function (it runs `claude -p /context` with a dummy key) and its Main call. Rewrite the title line ("and Claude lists it" goes), the "Needs" comment and the `report_check` pass text to say what remains: `state/claude` links into the clone and the container reads the clone through `~/.claude/rules`. `clone_skill_names` is still used by `check_bundle_links` in `lib-bundle.sh`.

### 4.6 H-16 (live clone): D-06

Keep: `check_edit_is_live`, `check_pull_is_live`, `plant_files` (minus the GSD lines), `restart_test_sandbox`, `check_bundle_links`, `check_stale_files_gone`, `check_clone_kept`, `check_user_files_spared` (with its own `sessionFile`, `h16-session.jsonl`).
Delete:
- In `pick_samples`: the `gsdSkillPath=$(find ... -name 'gsd-*' ...)` lookup, the `fail H-16 "state/claude has no skills/gsd-* folder; GSD never synced"` branch and `firstGsdSkill=...`. Keep the clone-exists check.
- In `plant_files`: `"$syncedDir/gsd-core"` in the `mkdir -p` list, `printf '0.0.0' >"$syncedDir/gsd-core/VERSION"` and `printf 'h16 hand edit\n' >>"$syncedDir/skills/$firstGsdSkill/SKILL.md"`. The header comment says "ages GSD": remove that.
- The whole `check_gsd_refreshed` function (it is the only user of `pin_of GSD_CORE_VERSION` here) and its Main call.
- "refreshed GSD" in the `report_check` pass text and in the file header.
The restart still runs the GSD hook; H-16 just no longer asserts on it.

### 4.7 H-23 (caches): D-06

Keep: `container_stdout`, `check_state_folders`, `check_cache_locations`, `plant_cache_files`, `restart_test_sandbox`, the marker check after the recreate.
Delete: the variables `mavenPlugin`, `mavenRepoName`, `mavenJar`; the whole `download_maven_artifact` function and its call; the `mavenJar` existence block in `check_files_on_host`; "Maven Central reachable" in the header "Needs" line; the Maven download clause in the `report_check` text. `plant_cache_files` already writes a marker into `$HOME/.m2` (the link to `state/m2`), so the m2 persistence proof stays. `in_project` is still used by H-05, H-06 and H-22, so the library function stays.

### 4.8 H-09 and H-29 header text

H-09 line 6 goes (manual helper). H-29 has no helper reference in code; only the checklist row mentions "the login and session survive in the helper".

## 5. `host-test.sh` edits (DIET-01, D-10, D-11)

| Location | Change |
|----------|--------|
| header line 6 | reword `--keep`: leaves the test sandbox up to look around after a failure |
| `show_context` or top of `main` | the preflight line from 4.2 (top of `main`, before `run_step "context"`) |
| `host_checks` comment | `H-01 to H-33` |
| `sandbox_suites` | loop over `tests/guard/run-all.sh tests/selftest/entrypoint/run-all.sh`; update the comment that says "both self-tests" |
| `print_next_block` in `run-all.sh` | drop the "holds a Claude login if a helper logged in" clause and the "see tests/host/manual/" line; the cleanup command line stays |

`--keep` parsing and the `record "remove test sandbox (--keep: left at $RUN)" SKIP` line stay. Nothing in `host-test.sh` is interactive today; the only prompts in the tree were in `manual/` and in the sbx-rm terminal cases that section 7 deletes. [VERIFIED: grep for `read `, `ask_`, `/dev/tty`, `[y/N]` over tests and host-test.sh]

## 6. Persistence proxies (DIET-03, D-04)

### Where Claude keeps the files under the sandbox state layout

The container sets `CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude` [VERIFIED: claude/Dockerfile:58]; on the host that is `$RUN/state/claude` (H-09) or `$sbxDir/state/claude` (H-29). The removed login helper asserted these two items there [VERIFIED: tests/host/manual/h07-login.sh:37-45]: `for stateFile in .claude.json .credentials.json` and the folder `projects/`. Sessions are JSONL files under `projects/-home-sandbox-workspace-hosttest/` (the folder name H-16 and H-24 already use). So:

| Fake | Host path | Pattern it parallels |
|------|-----------|----------------------|
| credentials | `<state dir>/claude/.credentials.json` | H-29 `state/claude/h29-sentinel.txt` |
| session | `<state dir>/claude/projects/-home-sandbox-workspace-hosttest/<check>-session.jsonl` | H-16 `h16-session.jsonl`, H-09 memory sentinel in the same folder |

### Existing plant patterns to extend

- H-09 `plant_sentinels` writes four files from `sentinelText="h09-$$-$(date +%s)"` and `check_sentinels_survived` loops over four paths comparing `cat` to the text. Add the two fakes to both.
- H-29 `plant_and_snapshot` writes three sentinels under `$sbxDir` and `check_upgrade` loops over three paths after `sbx-upgrade`. Add the two fakes to both. H-29 runs on its own folder (`$RUN/h29-$$ spaced dir`), so the helper must take the state dir as an argument.

### Shared helper (new file `tests/host/lib-login.sh`)

Recommend a new small library next to `lib-sbx.sh` and `lib-bundle.sh` (sourced after `host_init`, functions only). `lib.sh` stays untouched, which keeps the helper out of checks that do not need it.

```bash
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Fake Claude login files for the host tests: plant them, check them after a
# recreate
# ------------------------------------------------------------------------------
# Sourced after lib.sh by the checks that prove persistence; functions only.
# The files hold a run-unique text; no real credential is ever written.
# ------------------------------------------------------------------------------

loginProjectName=-home-sandbox-workspace-hosttest

# ------------------------------------------------------------------------------
# plant_login_files STATE_DIR TEXT PREFIX: writes the fake credentials file and
# the fake session file PREFIX-session.jsonl under STATE_DIR/claude
# ------------------------------------------------------------------------------
plant_login_files() {
  local claudeDir=$1/claude
  local projectDir=$claudeDir/projects/$loginProjectName

  mkdir -p "$projectDir"
  printf '{"fake":"%s"}\n' "$2" >"$claudeDir/.credentials.json"
  printf '{"fake":"%s"}\n' "$2" >"$projectDir/$3-session.jsonl"
}

# ------------------------------------------------------------------------------
# check_login_files STATE_DIR TEXT PREFIX WHEN: both files still hold TEXT
# ------------------------------------------------------------------------------
check_login_files() {
  local claudeDir=$1/claude
  local loginFile

  for loginFile in "$claudeDir/.credentials.json" "$claudeDir/projects/$loginProjectName/$3-session.jsonl"; do
    if ! grep -Fq "$2" "$loginFile" 2>/dev/null; then
      add_problem "${loginFile#"$1"/} is missing or changed $4"
    fi
  done
}
```

Use: H-09 calls `plant_login_files "$RUN/state" "$sentinelText" h09` in `plant_sentinels` and `check_login_files "$RUN/state" "$sentinelText" h09 "after the rebuild"` in `check_sentinels_survived`. H-29 calls `plant_login_files "$sbxDir/state" "$sentinelText" h29` in `plant_and_snapshot` and `check_login_files "$sbxDir/state" "$sentinelText" h29 "after sbx-upgrade"` in `check_upgrade`. Update both `report_check` pass texts ("a fake login and session file survived"). H-16's own session file stays as it is. Keep the host-side comparison only (D-02: a file is in place); no mode or owner assertion, because `stat` flags differ between GNU and BSD.

Criterion 3 says "the same run shows DISABLE_UPDATES set, the managed settings present and the bundle links resolving". That is satisfied by H-13, H-14 and H-15 in the same `./host-test.sh` run (D-05); no code change beyond the trims. H-14 already asserts the two managed deny entries inside the image [VERIFIED: tests/host/h14-wrappers-and-settings-in-image.sh `check_managed_settings`].

## 7. `tests/selftest/sbx`: classification

### 7.1 What the fence and the scripted fake are

[VERIFIED: tests/selftest/sbx/lib.sh:14-39 and 58-104]
- Fence: written by `start_group` as `$WORK/fence/docker` (`echo "docker $*" >>docker-calls; exit 99`) and put first on `PATH`. `no_docker_call` asserts its log file never appeared.
- Scripted fake: `make_scripted_docker` writes `$WORK/scripted/docker`, a `case` script fed by files in `$WORK/standin-state`; `set_standin_state`, `set_standin_knob`, `set_standin_ps`, `reset_standin_calls` drive it, `run_sbx_scripted` and `run_sbx_in_terminal` put it first on `PATH`.

### 7.2 What replaces them

In `start_group`, delete the fence block and the `PATH=` lines, and set the environment instead. Bash 3.2 safe:

```bash
  SBX_CONFIG_DIR=$WORK/cfg
  export SBX_CONFIG_DIR
  unset SBX_DIR SBX_NAME DOCKER_CONTEXT
  DOCKER_HOST=unix:///nonexistent
  export DOCKER_HOST
```

**`unset DOCKER_CONTEXT` is required.** The Docker CLI reference documents `DOCKER_CONTEXT` as "Name of the `docker context` to use (overrides `DOCKER_HOST` env var and default context set with `docker context use`)" [CITED: docs.docker.com/reference/cli/docker/]. The context page says the same of `DOCKER_HOST` vs the default context [CITED: docs.docker.com/engine/manage-resources/contexts/]. A Mac shell that exports `DOCKER_CONTEXT` would otherwise reach the real daemon, and the old `sbx-rm` cases (`docker rm sbx-broken`) would then act on real containers. In the dev sandbox there is no `docker` binary at all [VERIFIED: `command -v docker` returned 1], so a missing command and an unreachable daemon both make `docker info` exit non-zero, which is the same branch of `require_docker` and `read_container_states`. A unix socket path that does not exist fails at once (no timeout). [ASSUMED: A4, the fast failure on the Mac; I cannot run Docker or macOS here]

Edit the header comment of `lib.sh` (lines 3 and 11 to 13 mention the stand-in) and the five group header comments (`start.sh:3,7`, `shell.sh:7`, `list.sh:7`, `rm.sh:7`).

Delete from `lib.sh`: `make_scripted_docker`, `set_standin_state`, `set_standin_knob`, `set_standin_ps`, `reset_standin_calls`, `run_sbx_scripted`, `run_sbx_in_terminal` (only the deleted rm cases used it; it also removes the `script(1)` portability trap), `no_docker_call`, and `appears_before` (after the trim nothing calls it; confirm with grep). Keep: `run_sbx`, `refused_cleanly`, `usage_printed`, `plant_entry`, `lib_eval`, `start_group`.

### 7.3 Every group and case

A "refuses before Docker" case runs with no daemon and passes by exit code and error text. "Docker not answering" cases also stay: with the daemon unreachable they exercise the real failure instead of a scripted one (Open Question 3).

Groups that keep every case: `add.sh` (49 cases, none touch Docker), `entry.sh` (20), `fix-modes.sh` (18; its "stand-in xattr" is a fake `xattr`, not a docker mock, and stays), `upgrade.sh` (6). In each, delete only the final line `expect "...: no case reached docker" no_docker_call` (`add.sh:295`, `entry.sh:140`, `fix-modes.sh:173`, `upgrade.sh:59`).

| Group | Case function | Verdict | Why / edit |
|-------|---------------|---------|------------|
| `start.sh` | `case_container_gone` | delete | needs scripted compose success |
| | `case_older_image` | delete | needs running containers and image ids |
| | `case_docker_down_or_image_missing`, Docker-down half | keep | natural with no daemon; message `cannot reach Docker; is Docker running?` (verified by running `sbx-start` here) |
| | same, image-missing half | delete | needs `docker info` to succeed and `image inspect` to fail |
| | `refused_before_up` helper | change to `refused_cleanly "$1" "$2" "" ""` | its `standin-calls` check is gone |
| | `case_shared_wording` | keep | sources the lib, no Docker |
| `shell.sh` | `case_shell_refusals` (5) | keep | usage, unregistered, path, uppercase |
| | `case_shell_checks_before_compose`: missing project folder, missing state folder | keep | refused by `check_sandbox_folders` (the earlier `sandbox_is_running` inspect fails harmlessly) |
| | same: missing image | delete | needs the daemon to answer |
| | same: Docker not answering (2 expects) | keep | verified: `sbx-shell: cannot reach Docker; is Docker running?`, and the text has no `sbx-upgrade` |
| | `refused_before_shell` | reduce to `refused_cleanly` | drops `called_compose` and `opened_no_shell` |
| | `case_shell_start_paths`, `case_shell_status_and_failures` | delete | scripted compose and exec |
| | helpers `opened_shell`, `opened_no_shell`, `called_compose`, `started_then_shell`, `entered_as_it_is`, `quiet_run`, `failed_without_shell` | delete | only the deleted cases used them |
| `list.sh` | `case_list_usage` | keep | usage before Docker |
| | `case_list_docker_failure` | keep, run with `run_sbx` | a failed `docker ps` exits 1 with `cannot read the containers from Docker`; no daemon is that failure |
| | `case_list_empty`, `case_list_table`, `case_list_order`, `case_list_marker`, `case_list_broken`, `case_list_adjacency` | delete | each needs `docker ps` to answer (an unreachable daemon makes `sbx-list` exit 1 before any row prints) |
| | helpers `has_line`, `has_row`, `has_leftover`, `row_start`, `line_starts_with`, `row_ends_with`, `unmarked_row`, `rows_in_name_order`, `leftover_after_table`, `broken_row_beside_good`, `adjacent_is_not_entry`, `one_ps_call_only`, `registry_snapshot` | delete | unused after the trim; keep `usage_is_exact`, `failed_without_table` |
| `rm.sh` | `case_rm_usage` (9), `case_rm_refusals` (4) | keep | |
| | `case_rm_broken_entry`: "without `--unregister` is refused with the hint" and "the refusal says what is wrong" | keep | `remove_broken_sandbox` returns before any Docker call |
| | same: "broken entry with Docker not answering is kept" | keep | `sbx-rm broken --unregister --yes` prints `cannot reach Docker; is Docker running?` (verified) |
| | same: bad name `Bad_Name` refused and kept | keep, drop the `standin-calls` expect | assert `1:kept` as now; optionally add `has_text` for `breaks the sandbox name rule` |
| | same: running without terminal, failed removal by name, `n`, `y`, stopped, no container | delete | need a running or stopped container |
| | `case_rm_running`, `case_rm_stopped_and_gone`, `case_rm_unregister`, `case_rm_confirm`, `case_rm_down_fails`, `case_rm_delete_fails`, `case_rm_no_folder_or_image` | delete | each needs Docker to answer; `case_rm_delete_fails` calls a stopped scripted down |
| | helpers `folder_listing`, `plant_sandbox_files`, `closing_line`, `down_call_is_exact`, `no_compose_call`, `warned_before_down`, `removed_quietly`, `unregistered_after_down`, `others_and_folder_kept`, `unregister_refused_again`, `failed_down_kept_entry`, `kept_after_refusal`, `asked_then_removed`, `removed_unasked`, `by_name_calls`, `broken_cleared`, `ran_compose_down` | delete | |
| | `broken_kept` | keep, drop its `no_compose_call` and `by_name_calls` lines | the remaining test is exit 1, the text, and the entry unchanged (`cmp`) |

Two other points the planner should know. First, because `sbx-shell` and `sbx-upgrade` call Docker (a failing, harmless call) before some folder checks, a kept refusal case passes whether or not an early call happens; D-08 accepts this ("fails on its exit code and error text"), and the deferred wrapper idea in Phase 10 is the real fix. Second, name-rule coverage does not drop when the entrypoint name cases go (section 9): `sbx-add`'s `case_bad_names` exercises the same rule, which `bin/sbx-lib.sh` reads from `base/sbx-start-lib.sh` (uppercase, underscore, path, empty, 32 characters, line break, non-ASCII, `state`, `best-practices`). [VERIFIED: tests/selftest/sbx/add.sh:96-129, bin/sbx-lib.sh `load_name_rule`]

Resulting size: about 120 passing cases in the sbx self-test (from 230): add 48, entry 19, fix-modes 17, upgrade 5, start 3, shell 9, list 2, rm 17.

## 8. Guard

### 8.1 Current rules (18) [VERIFIED: ran `bash tests/guard/run-all.sh`, all PASS]

| File | Rules |
|------|-------|
| `isolation.sh` | `no_docker_socket_or_privileges`, `host_scripts_keep_sandbox_data` |
| `linters.sh` | `shellcheck_passes`, `hadolint_passes` |
| `start.sh` | `no_installs_at_container_start`, `start_hooks_have_two_digit_names`, `gsd_sync_runs_before_the_bundle`, `compose_starts_in_the_workspace`, `agent_image_keeps_base_state_folders` |
| `supply-chain.sh` | `no_compromised_gsd_package`, `gsd_installs_only_the_official_package`, `no_pipe_to_shell_installers`, `installs_use_pins`, `no_floating_latest_versions`, `versions_file_has_one_pin_per_line`, `pins_are_exact`, `dockerfile_args_have_no_defaults`, `every_dockerfile_arg_is_pinned` |

The runner `tests/guard/run-all.sh` runs every `*.sh` in its folder except `lib.sh` and `run-all.sh`, so a new group file needs no registration. `SHELL_FILES` in `lib.sh` uses globs (`tests/*/*.sh tests/*/*/*.sh`), so a new file is shellchecked automatically and the globs still match after the deletions.

### 8.2 The three start rules (recommendation: Open Question 1)

H-20 proves that a start on a folder with no project folder is refused and nothing is created, which is the behaviour `compose_starts_in_the_workspace` protects. The other candidates split as follows: the two hook rules (`start_hooks_have_two_digit_names`, `gsd_sync_runs_before_the_bundle`) are named in the milestone decisions as deleted with the hook guard rules in the `sbx-init` phase, so they are not Phase 6's. That leaves exactly three: `no_installs_at_container_start`, `compose_starts_in_the_workspace`, `agent_image_keeps_base_state_folders`. [ASSUMED: A1, because only the middle one is literally H-20 behaviour; the count matches "three" and the hook rules have a later owner.]

`agent_image_keeps_base_state_folders` is backed at runtime by H-23's `check_state_folders` (`cache/npm`, `cache/uv`, `m2`) and H-16 (`state/claude`). `no_installs_at_container_start` has no host check; dropping it leaves the supply-chain rule `no_pipe_to_shell_installers` (which scans `$ENTRY claude/start.d/*`) as the only start-script supply guard. If the user prefers to keep it, `start.sh` keeps one rule and Phase 9 deletes the file.

### 8.3 The `sbx-rm` source-line rule (Open Question 2)

`host_scripts_keep_sandbox_data` (isolation.sh:31) has two halves: (a) no other `bin/*` script contains `rm|rmdir|prune|kill|down|--volumes`; (b) a block that greps `bin/sbx-rm` for forbidden words and for any `rm` line that is not one of two exact lines (`  if ! rm -- "$entryFile"; then` and `  if ! docker rm "sbx-$1" >/dev/null </dev/null; then`). Half (b) is the "pins that one delete to an exact line" rule [VERIFIED: .planning/MILESTONES.md:84 and PROJECT.md:120]. H-33 proves the real behaviour of `sbx-rm` (folders, volumes, images, other containers kept) with real Docker. Recommend deleting half (b) only: the `{ grep ...; grep ... } | report_lines 'bin/sbx-rm:'` block, keeping (a) and the `bin/sbx-rm is missing` guard (it builds `otherFileList`). Update the rule comment and the `tests/README.md` guard rows accordingly. [ASSUMED: A2]

### 8.4 Two new rules, in the existing style

`claude/managed-settings.json` lines 7 and 8 hold the two deny entries, quoted verbatim [VERIFIED: claude/managed-settings.json:6-9]:

```
    "deny": [
      "Edit(//home/sandbox/workspace/state/claude/.best-practices-skills)",
      "Edit(//home/sandbox/workspace/state/claude/skills/**)"
    ]
```

`claude/Dockerfile` has `ARG BASE_IMAGE=sbx-base:local` at line 7 and `FROM ${BASE_IMAGE}` at line 8 [VERIFIED: claude/Dockerfile:7-8]. Both rules below were run here against the real tree (PASS) and against a scratch copy with one deny line deleted and a second `FROM` appended (both FAIL, with the named message); shellcheck at `-S warning` is clean.

Add to `tests/guard/isolation.sh` (the file's subject is "no socket, no privileges, data kept"; the deny list is the edit protection on synced files) and add to the `run_rules` list:

```bash
# ------------------------------------------------------------------------------
# managed_settings_deny_skill_edits: the managed settings deny Edit on the synced skills
# ------------------------------------------------------------------------------
# Host check H-14 reads the same two entries in the image.
# ------------------------------------------------------------------------------
managed_settings_deny_skill_edits() {
  local ok=0
  local denyEntry

  for denyEntry in 'Edit(//home/sandbox/workspace/state/claude/.best-practices-skills)' 'Edit(//home/sandbox/workspace/state/claude/skills/**)'; do
    if ! grep -Fq "\"$denyEntry\"" claude/managed-settings.json; then
      echo "    claude/managed-settings.json has no deny entry $denyEntry"
      ok=1
    fi
  done

  return "$ok"
}
```

Add to `tests/guard/supply-chain.sh` beside `dockerfile_args_have_no_defaults` (it already reads the Dockerfile `FROM` lines of the base image) and to its `run_rules` list:

```bash
# ------------------------------------------------------------------------------
# claude_image_has_one_from_line: the Claude image is one stage on the base image
# ------------------------------------------------------------------------------
claude_image_has_one_from_line() {
  local fromCount

  fromCount=$(grep -c '^FROM' $CLAUDE)

  if [ "$fromCount" -ne 1 ] || ! grep -Fxq 'FROM ${BASE_IMAGE}' $CLAUDE; then
    echo "    $CLAUDE must have exactly one FROM line, FROM \${BASE_IMAGE} (found $fromCount FROM lines)"
    return 1
  fi
}
```

The grep is a presence test, so a deny entry moved into another key would still pass; H-14 reads the parsed `permissions.deny` list in the image, which is why the guard rule stays plain grep. Result: 18 rules, minus 3 start rules, plus 2 new rules, is 17.

### 8.5 Forced guard edit when `manual/` is deleted

`supply-chain.sh:14`, `no_compromised_gsd_package`, passes the glob `tests/host/manual/*.sh`. With the folder gone bash passes the literal pattern, `grep` exits 2, and the rule fails with "grep could not read every file it was given". I reproduced this in a scratch copy: it is the only rule that fails. Remove `tests/host/manual/*.sh` from that line. `tests/host/support/*.*` still matches `toolchain-probe.sh` and `fake-claude-api.js` is not needed in the list.

## 9. Entrypoint self-test

- Delete `tests/selftest/entrypoint/start-library.sh` (5 cases). Nothing else references it; `run-all.sh` picks groups by glob.
- In `start-folders.sh` delete `case_name_rule` (12 expects, lines 129 to 166), its Main call, and the two helpers only it uses, `start_with_name` and `refused_by_name_rule`. `make_entry_copy` and `started_in` stay (used by the other three cases). Retitle the file header "Self-test of the start folders and the sandbox name rule" to the start folders only. DIET-05 names "the name-rule cases of the entrypoint self-test"; CONTEXT does not list them, REQUIREMENTS does, so include them. Remaining: bundle-hook 18, gsd-hook 14, start-folders 3, start-hooks 8 (43 cases from 60).
- `tests/README.md` entrypoint row: drop "the sandbox name rule" from Catches and "H-21" from the Does-not-catch sentence.

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| Making the real `docker` unreachable in a test | a new fence or fake `docker` script | `export DOCKER_HOST=unix:///nonexistent` plus `unset DOCKER_CONTEXT` in `start_group` | D-07 forbids any stand-in; the CLI honours these variables |
| A new check for DISABLE_UPDATES, deny entries and links | a fourth host check | the parts of H-13, H-14, H-15 that stay (D-05) | the proof already exists on real Docker |
| Two near-identical plant blocks in H-09 and H-29 | copy-pasted `printf` lines | `lib-login.sh` (`plant_login_files`, `check_login_files`) | D-04; the checks must stay alike |
| A timing harness for stop | a new `time` wrapper | `date +%s` before and after in `check_stop` | same technique H-11 used; BSD safe |
| JSON parsing in the guard | `jq` or Python in a guard rule | `grep -F` on the quoted entry | the guard is bash 3.2 and runs on the Mac without `jq`; H-14 parses the real JSON |

**Key insight:** every replacement is a smaller version of something that already exists in the tree; nothing new needs a design.

## Common Pitfalls

### Pitfall 1: The guard goes red the moment the manual folder is deleted
**What goes wrong:** `no_compromised_gsd_package` fails with "grep could not read every file".
**Why:** its file list contains the glob `tests/host/manual/*.sh`.
**How to avoid:** edit `supply-chain.sh:14` in the same commit as the deletion.
**Warning signs:** `bash tests/guard/run-all.sh` shows `1 rule(s) broken`.

### Pitfall 2: `DOCKER_CONTEXT` defeats `DOCKER_HOST`
**What goes wrong:** with a context exported in the Mac shell, the "nowhere" daemon is ignored and kept cases reach real Docker.
**How to avoid:** `unset DOCKER_CONTEXT` next to the `DOCKER_HOST` export (section 7.2).
**Warning signs:** a self-test case on the Mac prints a different error than the dev sandbox does.

### Pitfall 3: A deleted check left in one of three lists
**What goes wrong:** `run-all.sh` runs `bash "$HOST_DIR/$script"` on a missing file, a FAIL on the Mac only.
**How to avoid:** the list-consistency one-liner in Validation (checks every listed name exists and every `h*.sh` is listed); `bash -n` on each edited file.

### Pitfall 4: Stale header and report text after a trim
**What goes wrong:** H-13, H-15, H-16, H-23 and H-28 print pass messages that still promise "claude update is disabled", "Claude lists", "refreshed GSD", "a Maven download", so the log lies.
**How to avoid:** change each `report_check` text and each file header in the same edit as the code (sections 4.4 to 4.7).

### Pitfall 5: Dead helpers and lost exec bits
**What goes wrong:** after the trim, `lib.sh` and group files keep unused helpers (`appears_before`, `run_sbx_in_terminal`, the shell and list predicates); sandbox edits also drop the exec bit on Mac-run scripts.
**How to avoid:** grep each helper name before deleting it, and after the last edit run `git diff --summary` and restore `100755` where it was.

### Pitfall 6: The preflight as a `run_step`
**What goes wrong:** H-00 was fatal; a recorded FAIL lets every later step run and flood the log.
**How to avoid:** `exit 1` from the top of `main` (section 4.2).

### Pitfall 7: Docs say the helpers still exist
**What goes wrong:** `tests/README.md` and the checklist describe `manual/`, `--keep` for helpers, the guard self-test and a stand-in docker.
**How to avoid:** section 10 lists each place; the verify greps in Validation return nothing when done.

## Code Examples

The persistence helper (section 6), the two guard rules (8.4), the `start_group` environment (7.2), the H-11 timing fold (4.3) and the preflight line (4.2) are given where they apply. One more, the list-consistency check, was run here and printed nothing against the current tree (after the edits it prints nothing only if lists and files agree):

```bash
for s in $(sed -n 's/^[a-zA-Z]*CheckList="\(.*\)"$/\1/p' tests/host/run-all.sh); do test -f "tests/host/$s" || echo "missing $s"; done
for f in tests/host/h*.sh; do grep -q "${f##*/}" tests/host/run-all.sh || echo "unlisted ${f##*/}"; done
```

## 10. Docs to update (all deletions or one-line rewrites)

**`tests/README.md`** (72 lines): suite table row 13 `tests/host/` and `tests/host/manual/` becomes `tests/host/`; delete row 11 (`tests/selftest/guard/`); the sbx row says "no Docker" and describes a refusing stand-in, rewrite to "refusal cases only, with `DOCKER_HOST` pointing nowhere"; paragraph at line 16: remove "guard and" before "entrypoint and guard self-tests", drop "Pass `--keep` ... for `tests/host/manual/`" for "Pass `--keep` to leave the test sandbox up after a failure"; guard section: "18 rules" becomes 17, drop the clauses about the `sbx-rm` delete pinning, add the deny entries and one-FROM; delete the whole `## tests/selftest/guard/` section; entrypoint section Catches and Does-not-catch (section 9); sbx section (Runs, Catches, Does not catch); host section title and rows: "H-00 to H-33" becomes "H-01 to H-33", "Where" drops "the helpers in `manual/` need a real terminal", "Does not catch" drops "only the helpers in `manual/` cover them" (Claude's login and behaviour are now simply not tested).

**`tests/host-checklist.md`** (144 lines):
- Title and bullet 5: "H-00..H-33" and "H-00 to H-33" become "H-01 to H-33 (the IDs keep their gaps)". Intro paragraph: delete "Seven short helpers in `tests/host/manual/` ..." sentence.
- "How to run it": drop "2. Clean up" only if the section is reworded; "Leaves the test sandbox running, so a helper can use it" and "where the helpers are" go.
- Table: delete rows H-00, H-02, H-07, H-11, H-18, H-19, H-21, H-24. Edit H-09 (script and Run columns: drop `manual/h09-rebuild-resume.sh`, add "a fake credentials file and a fake session file survive"), H-13 (drop "`claude doctor` agrees" and the helper), H-15 (drop "Claude lists the always-on rules ..."), H-16 (drop "refreshes GSD ... and the helper bumps the GSD pin"), H-23 (drop the real Maven download clause), H-28 (add "sbx-stop returns in under 10 s"), H-29 (drop "the login and session survive in the helper", add the fake files), H-31 (drop the helper clause at the end).
- Delete the section `## Manual helpers (when something looks wrong)` entirely.
- "Reading a failure": delete the H-31 `script` bullet's helper pointer (keep the `script` explanation, point to the FAIL line), the H-21 bullet, the H-15 `/context` and "H-15 and a login" bullets, the H-18 bullet (and its sub-bullets), the "After the managed settings landed" bullet; in the NOT RUN bullet remove `H-11` from the chain list. Keep the H-03 and H-20 bullets.
- "Clean up": drop the sentence about helper runs and real Claude logins. "Record your results": drop "and the lines of any helper you ran".

**`README.md`**: row 338 becomes "Login files survive a rebuild | H-09 and H-29 (a planted fake credentials file and session file) | `./host-test.sh`"; delete row 340 (ccusage) and bullet 344; at line 356 delete "; each may hold a test Claude login". **`clean.sh:76`**: delete the comment line. **`MIGRATION.md`, `ZSCALER.md`**: nothing.

D-09 planning edits: **already done** (`REQUIREMENTS.md` DIET-05 and `ROADMAP.md` Phase 6 criterion 1 both already say no stand-in `docker` is left). [VERIFIED: grep of .planning/REQUIREMENTS.md:16 and ROADMAP.md:52]

## State of the Art

| Old approach | Current approach | When changed | Impact |
|--------------|------------------|--------------|--------|
| A scripted fake `docker` answering from files | The real `docker` with `DOCKER_HOST` pointing at a missing socket | this phase | Only refusal cases remain in the self-test; everything that needs an answer is a Mac host check |
| Manual helpers prove login and resume | Planted fake files prove the mount keeps them | this phase | No Claude login, no tokens, no terminal |
| Compose v2 as a chained fatal check | One preflight line before any step | this phase | Same outcome, 53 lines fewer |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | "The three start rules H-20 covers" means `no_installs_at_container_start`, `compose_starts_in_the_workspace`, `agent_image_keeps_base_state_folders` (the two hook rules belong to the `sbx-init` phase) | 8.2 | If the user meant another set, one rule is lost or kept wrongly; `no_installs_at_container_start` has no host check behind it |
| A2 | "The `sbx-rm` source-line rule" is only the second half of `host_scripts_keep_sandbox_data` (the exact-line `rm` pin plus the sbx-rm forbidden-word greps) | 8.3 | If the whole rule was meant, the other-scripts-never-delete half is lost |
| A3 | "Docker not answering" cases (start, shell, list, rm broken) count as refusals and stay | 7.3 | If the user wants only pre-Docker refusals, drop 4 cases (about 5 expects) |
| A4 | A unix socket path that does not exist makes `docker info` fail at once on the Mac | 7.2 | A hang would show as a slow Mac self-test; not testable in the dev sandbox |
| A5 | Timing `sbx-stop` in H-28 is an acceptable stand-in for H-11's `compose down` timing | 4.3 | A slow `compose down` would go unnoticed; every other check still calls `compose_down` |
| A6 | `exit 1` at the top of `host-test.sh` `main` is the right shape for the preflight | 4.2 | A reviewer may prefer a recorded FAIL; trivial to change |

## Open Questions

1. **Which three `tests/guard/start.sh` rules does H-20 cover?**
   - Known: only `compose_starts_in_the_workspace` maps literally to H-20 (mistyped name refused, nothing created). The two hook rules have a later owner. `agent_image_keeps_base_state_folders` maps to H-23.
   - Unclear: whether `no_installs_at_container_start` was meant (it has no host check).
   - Recommendation: delete the three non-hook rules and say plainly that `no_installs_at_container_start` loses its only direct check; the plan gets a `checkpoint:decision` for the user. Default if no answer: follow the recommendation.

2. **How much of the `sbx-rm` guard rule goes?**
   - Known: the rule has an "other scripts never delete" half and an "`sbx-rm` exact lines" half.
   - Recommendation: delete only the `sbx-rm` half (section 8.3). Same checkpoint.

3. **Keep the four "Docker not answering" refusal cases?** Recommendation: keep; they are the real-failure version of what the scripted fake used to fake, with zero mock.

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | all suites | yes | 5.2.21 (dev sandbox); 3.2 on the Mac | none needed |
| shellcheck | guard `shellcheck_passes` | yes | `/usr/local/bin/shellcheck` | none needed |
| hadolint | guard `hadolint_passes` | yes | `/usr/local/bin/hadolint` | none needed |
| python3, jq | not required by this phase | yes | `/usr/bin/python3`, `/usr/bin/jq` | n/a |
| docker | host checks, `host-test.sh` | **no** in the dev sandbox | none | Mac only: `./host-test.sh` then read `host-test.log` |
| macOS bash 3.2, BSD tools | portability of edited host code | no in the dev sandbox | none | The Mac run is the portability gate; keep to documented bash 3.2 constructs |

**Missing with no fallback:** none blocks authoring. Host-check changes (4.x, 6) are provable only by `bash -n`, the guard and a Mac run; plans must carry a Mac verification step.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | plain bash: guard rules (`PASS:`/`FAIL:` lines via `run_rules`), self-tests (`expect`), host checks (`report_check`) |
| Config file | `.shellcheckrc`, `.hadolint.yaml`; no test runner config |
| Quick run command | `bash tests/selftest/sbx/run-all.sh` (about 4 s) and `bash tests/selftest/entrypoint/run-all.sh` (under 1 s) |
| Full suite command (dev sandbox) | `bash tests/guard/run-all.sh` (about 12 s) plus the two above |
| Full suite command (Mac) | `./host-test.sh`, then read `host-test.log`; expect 26 host checks, 0 failed, 0 not run |

Baseline before the phase [VERIFIED: ran this session]: guard "All rules hold." (18 rules), sbx self-test "All cases pass.", entrypoint "All cases pass.", guard self-test "All cases pass." (the last is deleted by the phase).

### Phase Requirements to Test Map

| Req | Behavior | Type | Automated command (dev sandbox) | Exists |
|-----|----------|------|---------------------------------|--------|
| DIET-01 | manual helpers and every interactive line gone | static | `test ! -e tests/host/manual && ! grep -rIn 'tests/host/manual\|manual/h' --exclude-dir=.git --exclude-dir=.planning --exclude-dir=.gsd .` | new, one-line |
| DIET-01 | host-test.sh asks nothing | static | `! grep -nE 'read -p\|ask_\|/dev/tty\|\[y/N\]' host-test.sh tests/host/*.sh` | new |
| DIET-02 | the six checks and `fake-claude-api.js` gone, lists consistent | static | the list-consistency loop (Code Examples) plus `test ! -e tests/host/h00-compose-v2.sh ...` for each | new |
| DIET-02 | nothing drives or checks Claude or Maven Central | static | `! grep -rnE 'claude (-p\|update\|doctor)\|ANTHROPIC_(API_KEY\|BASE_URL)\|maven-dependency-plugin\|fake-claude' tests host-test.sh README.md` | new |
| DIET-02 | no syntax slip in edited host files | static | `for f in tests/host/*.sh host-test.sh; do bash -n "$f" \|\| echo "syntax $f"; done` | new |
| DIET-03 | helper used by both H-09 and H-29 | static | `grep -c 'plant_login_files' tests/host/h09-*.sh tests/host/h29-*.sh` (each 1 or more), same for `check_login_files` | new |
| DIET-03 | files survive recreate and `sbx-upgrade`; env, settings, links | host (Mac) | `./host-test.sh` H-09, H-29, H-13, H-14, H-15 lines PASS | Mac only |
| DIET-04 | two new rules pass, three start rules and the sbx-rm half gone | guard | `bash tests/guard/run-all.sh` ends "All rules hold."; output has `PASS: managed_settings_deny_skill_edits` and `PASS: claude_image_has_one_from_line`, none of `compose_starts_in_the_workspace`, `agent_image_keeps_base_state_folders`, `no_installs_at_container_start` | new rules |
| DIET-04 | the new rules can fail (no self-test left) | one-time negative control | in a scratch copy: delete the `skills/**` line from `claude/managed-settings.json` and append `FROM debian` to `claude/Dockerfile`, run `bash tests/guard/isolation.sh` and `bash tests/guard/supply-chain.sh`, expect both named FAIL lines | manual, record in the summary |
| DIET-04 | selftest guard deleted | static | `test ! -e tests/selftest/guard` and `! grep -n 'selftest/guard' host-test.sh tests/README.md` | new |
| DIET-05 | no stand-in `docker` left | static | `! grep -rnE 'make_scripted_docker\|set_standin\|run_sbx_scripted\|run_sbx_in_terminal\|no_docker_call\|standin-calls\|/fence' tests/selftest` | new |
| DIET-05 | refusal cases pass with no daemon | self-test | `bash tests/selftest/sbx/run-all.sh` (about 120 cases, "All cases pass.") | existing, trimmed |
| DIET-05 | environment, not a script, blocks Docker | static | `grep -n 'DOCKER_HOST=unix:///nonexistent\|unset .*DOCKER_CONTEXT' tests/selftest/sbx/lib.sh` | new |
| DIET-05 | start-library and name-rule cases gone | self-test | `test ! -e tests/selftest/entrypoint/start-library.sh` and `bash tests/selftest/entrypoint/run-all.sh` (43 cases) | existing, trimmed |
| Success criterion 5 | Mac run unattended and green | host (Mac) | `./host-test.sh` exits 0; the steps `sbx self-test in the Mac shell`, `host checks`, `guard and self-tests in sbx-hosttest`, `guard in the Mac shell` are OK | Mac only |

### Sampling Rate

- **Per task commit:** the suite the task touched (a single group such as `bash tests/selftest/sbx/rm.sh`, or `bash tests/guard/isolation.sh`) plus `bash -n` on edited host files.
- **Per wave merge:** `bash tests/guard/run-all.sh`, `bash tests/selftest/sbx/run-all.sh`, `bash tests/selftest/entrypoint/run-all.sh`, the list-consistency loop and the reference-sweep greps.
- **Phase gate:** all of the above green, then the user runs `./host-test.sh` on the Mac and reads `host-test.log` (a `checkpoint:human-verify` task; Docker is not in the dev sandbox).

### Wave 0 Gaps

None. No framework, fixture or config is missing; `tests/host/lib-login.sh` is new code delivered by the plan itself, not test infrastructure that must exist first.

## Security Domain

`security_enforcement` is enabled in `.planning/config.json` (ASVS level 1). This phase edits test code only; no runtime auth, session or crypto code changes.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | the planted credentials file is fake and holds only a run-unique text |
| V3 Session Management | no | same |
| V4 Access Control | indirect | the guard keeps asserting the managed deny entries (source) and H-14 reads them in the image |
| V5 Input Validation | no new input | the name rule is unchanged and stays covered by `sbx-add` cases |
| V6 Cryptography | no | none |
| V14 Configuration | yes | the supply-chain guard rules stay and keep scanning every remaining test file |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| A self-test case acting on the user's real containers once the fence is gone | Tampering | `DOCKER_HOST` at a missing socket and `unset DOCKER_CONTEXT` in `start_group` (the context variable would otherwise win) |
| A fake credentials file mistaken for or colliding with a real login | Information disclosure | the file lives only in a throwaway run folder under `$TMPDIR/sbx-hosttest-*`, holds no token, and `clean.sh` removes run folders |
| Weakening the supply-chain guard by shrinking its file list | Tampering | remove only the missing `manual/` glob; `no_compromised_gsd_package` still covers `tests/host/*.sh`, `tests/selftest/*/*.sh` and the support folders |
| Dropping `no_installs_at_container_start` loses a start-script supply guard | Tampering | Open Question 1; `no_pipe_to_shell_installers` still scans `$ENTRY` and the hooks |

## Sources

### Primary (HIGH confidence)
- This repo, read and run this session: `host-test.sh`, `tests/host/run-all.sh`, `tests/host/lib*.sh`, `h00`, `h02`, `h09`, `h11`, `h13` to `h16`, `h18`, `h20`, `h21`, `h23`, `h24`, `h28`, `h29`, `tests/host/manual/*` (greps), `tests/selftest/sbx/*`, `tests/selftest/entrypoint/*`, `tests/selftest/guard/*`, `tests/guard/*`, `bin/sbx-lib.sh`, `bin/sbx-shell`, `bin/sbx-list`, `bin/sbx-rm`, `bin/sbx-start`, `bin/sbx-stop`, `bin/sbx-upgrade`, `claude/Dockerfile`, `claude/managed-settings.json`, `base/sbx-start-lib.sh`, `README.md`, `tests/README.md`, `tests/host-checklist.md`, `clean.sh`, `.planning/{ROADMAP,REQUIREMENTS,STATE,PROJECT,MILESTONES}.md`, `.planning/research/v2-simple-tooling-decisions.md`.
- Runs: guard (all 18 PASS), sbx, entrypoint and guard self-tests (all pass), scratch-copy deletion of the four targets (only `no_compromised_gsd_package` failed), direct runs of `sbx-shell`, `sbx-list`, `sbx-start`, `sbx-rm` with no docker and `DOCKER_HOST=unix:///nonexistent`, and both new guard rules against the real tree and a mutated copy.

### Secondary (MEDIUM confidence)
- Docker CLI reference, environment variables: https://docs.docker.com/reference/cli/docker/ (DOCKER_CONTEXT overrides DOCKER_HOST) [CITED]
- Docker contexts: https://docs.docker.com/engine/manage-resources/contexts/ (DOCKER_HOST overrides the default context) [CITED]

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Deletion and reference inventory: HIGH, produced by grep and read in full.
- Per-check edit lists: HIGH, derived from the current source of each check.
- sbx classification: HIGH for the delete/keep split (each kept case was run without Docker); MEDIUM for A3.
- Guard rule shapes: HIGH (run); the three-rule and sbx-rm scope calls: MEDIUM (A1, A2).
- Mac behaviour (bash 3.2, socket failure speed): not observable here, covered by the Mac gate.

**Research date:** 2026-11-13
**Valid until:** until the next commit touches `tests/`, `host-test.sh` or `bin/` (the inventory is line-anchored)
