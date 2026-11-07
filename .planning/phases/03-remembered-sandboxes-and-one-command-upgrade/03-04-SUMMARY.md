---
phase: 03-remembered-sandboxes-and-one-command-upgrade
plan: 04
subsystem: infra
tags: [gate, branch, mac-run, validation]

requires:
  - phase: 03-remembered-sandboxes-and-one-command-upgrade
    provides: bin/sbx-*, the sbx self-test, H-28 to H-30 and the attended helper from plans 01 to 03
provides:
  - the final Linux gate record and the empty planning-ID scan
  - local branch feat/sbx-scripts (9 code commits on origin/main, same code tree as chore/phase-03-run), not pushed
  - the Mac run record (30 of 30 host checks, Mac-shell self-test on bash 3.2, attended helper all PASS)
  - the criteria map (roadmap criteria 1 to 5, SCR-01/02/03/07, D-01 to D-22) and the filled 03-VALIDATION.md
affects: [phase verification, the code PR, a follow-up bump of UBUNTU_IMAGE]

key-files:
  created: []
  modified:
    - .planning/phases/03-remembered-sandboxes-and-one-command-upgrade/03-VALIDATION.md

key-decisions:
  - "The pin digests failure (UBUNTU_IMAGE) is upstream drift, not caused by this phase; versions.env is left alone and the bump goes in a separate small PR"

requirements-completed: [SCR-01, SCR-02, SCR-03, SCR-07]

duration: about 45min of agent time, plus the wait for the Mac run
completed: 2026-11-06
status: complete
actuals:
  tokens: 7500
  tasks: 3
  commits: 0
plan_head_before: 9abf603e91c8a938d9228bbe18b006bcffa8c79c
plan_head_after: 9abf603e91c8a938d9228bbe18b006bcffa8c79c
---

# Phase 3 Plan 04: The Phase Gate Summary

**The final Linux gate passes, `feat/sbx-scripts` holds the nine code commits on a fresh `origin/main`, and the Mac run passes 30 of 30 host checks plus the Mac-shell self-test on `/bin/bash` 3.2.57 and the attended login helper; one unrelated step (`pin digests`, UBUNTU_IMAGE drift) failed and is recorded as an out-of-scope finding.**

## Gate

All commands ran in `/home/sandbox/GetShitDoneContainer` on `chore/phase-03-run` (HEAD `9abf603`), `origin/main` = `b389168` after `git fetch origin`.

| Check | Result |
|---|---|
| `bash -n` on `build.sh clean.sh host-test.sh base/sbx-entrypoint base/sbx-start-lib.sh claude/start.d/* claude/bin/* bin/* tests/*/*.sh tests/*/*/*.sh` | no error |
| Guard without linters | exactly two FAIL lines: `FAIL: shellcheck_passes`, `FAIL: hadolint_passes` |
| Guard with the rehearsal linters (`/tmp/sbx-linters/bin`) | 19 `PASS:` lines, last line `All rules hold.` (last PASS: `PASS: every_dockerfile_arg_is_pinned`) |
| `tests/selftest/guard/run-all.sh` | last line `All cases pass.` (119 PASS lines) |
| `tests/selftest/entrypoint/run-all.sh` | last line `All cases pass.` (60 PASS lines) |
| `tests/selftest/sbx/run-all.sh` | last line `All cases pass.` (60 PASS lines) |
| `git diff --quiet origin/main HEAD -- compose.yml build.sh versions.env .dockerignore` | exit 0 (unchanged) |
| `git diff --quiet origin/main HEAD -- ClaudeCode OpenCode README.md .claude` | exit 0 (untouched) |

`git ls-files -s bin`:

```
100755 bin/sbx-add
100644 bin/sbx-lib.sh
100755 bin/sbx-start
100755 bin/sbx-stop
100755 bin/sbx-upgrade
```

Line counts:

| Group | Lines |
|---|---|
| `bin/*` | 560 (sbx-add 168, sbx-lib.sh 245, sbx-start 34, sbx-stop 33, sbx-upgrade 80) |
| `tests/guard/*.sh` plus `tests/selftest/guard/*.sh` | 935 |
| `tests/selftest/sbx/*.sh` | 530 (add 203, entry 141, lib 110, run-all 16, upgrade 60) |
| `tests/host/lib-sbx.sh` | 81 |
| `tests/host/h28-sbx-add-start-stop.sh` | 199 |
| `tests/host/h29-sbx-upgrade.sh` | 248 |
| `tests/host/h30-version-line.sh` | 82 |
| `tests/host/manual/h29-upgrade-resume.sh` | 149 |

## Planning-ID scan

Regex from the plan, over the 27 files `git diff --name-only --diff-filter=AMR origin/main...HEAD -- . ':(exclude).planning'` lists. One hit:

- `tests/guard/supply-chain.sh:39`: `grep -hE -A1 'curl|wget' ...` matches `A1`. **False positive:** `-A1` is grep's "one line of trailing context" flag, not an identifier.

No other hit. No file was changed by this scan.

## Code commits

Nine commits touch non-`.planning` paths between `origin/main` and HEAD (the five planning commits before them touch only `.planning/`). For each, `git show --name-only` lists no `.planning/` path and its message holds no planning ID and no `Co-Authored-By` or "Generated with" line. No mixed commit.

| Original | On feat/sbx-scripts | Subject |
|---|---|---|
| aa794c3 | b739b1a | feat(bin): register a sandbox once, then start and stop it by name |
| ad2f27a | c06cf94 | test(bin): pin the sbx-* registry and name rules in a docker-free self-test |
| 978416e | cdcbfb6 | test(host): prove sbx-add, sbx-start and sbx-stop on the Mac |
| e2795de | 348b12b | feat(bin): sbx-upgrade rebuilds the images and recreates one sandbox |
| ce283eb | 49f191d | test(guard): the sbx-* scripts never delete data, and sbx-upgrade refuses before the build |
| a05a587 | 090a09e | test(host): prove sbx-upgrade on the Mac, with an attended login check |
| f4a8b6a | 25bec46 | feat(images): print the tool versions in every interactive shell and after sbx-upgrade |
| d6af561 | 080e171 | test(host): prove the tool versions line on the Mac |
| 9abf603 | b9d3085 | docs: the sbx-* scripts replace the paste-by-hand sandbox flow |

## Branch

- `git branch feat/sbx-scripts origin/main` (origin/main `b389168`), temporary worktree `/tmp/sbx-scripts-branch`, nine cherry-picks in order, no conflict. Worktree removed afterwards.
- **Branch tip: `b9d30854a8697e0fa152912bf811d3e2d5af8daa`** (`b9d3085`), 9 commits ahead of origin/main. Re-checked at the start of this continuation: the tip is unchanged, origin/main is still `b389168`, and `git ls-remote --heads origin feat/sbx-scripts` is empty.
- `git diff --quiet HEAD feat/sbx-scripts -- . ':(exclude).planning'` exited 0: same code tree as `chore/phase-03-run`.
- Inside the worktree: rehearsal guard 19 PASS lines and `All rules hold.`; the three self-tests end `All cases pass.`; `bin/` modes as above.
- `git diff --name-only origin/main..feat/sbx-scripts` contains no `.planning/` and no `.claude/` path.
- The upstream that `git branch ... origin/main` set was removed (`git branch --unset-upstream`), so a bare `git push` cannot target origin/main. Nothing was pushed, merged or opened.
- The Mac run used the `chore/phase-03-run` checkout at `9abf603` (the host-test.log context block says `branch chore/phase-03-run, commit 9abf603`), which has the same code tree as `feat/sbx-scripts`.

## Mac run (Task 2)

Source: `/home/sandbox/GetShitDoneContainer/host-test.log` (430 lines, run from `/Users/demian/GetShitDoneContainer/GetShitDoneContainer`) and `/home/sandbox/h29m.log`.

### Versions

| Item | Log line |
|---|---|
| Docker | `Docker version 28.5.1, build e180ab8` |
| Docker Compose | `Docker Compose version v2.40.0-desktop.1` (H-00: `Compose 2.40.0-desktop.1 is v2 or newer`) |
| Docker Desktop | `INFO: Docker: Docker Desktop 4.48.0 (207573)` |
| docker context | `INFO: docker context: desktop-linux, DOCKER_HOST: not set` |
| Mac bash | `/bin/bash is 3.2.57(1)-release` and `INFO: bash 3.2.57(1)-release` |

### host-test.sh steps (the log's own `== Summary` block)

```
OK: context
OK: sbx self-test in the Mac shell
OK: host checks
OK: run folder
OK: linter versions
FAIL: pin digests
OK: guard and self-tests in sbx-hosttest
OK: guard in the Mac shell
OK: build warnings
SKIP: remove test sandbox (--keep: left at /private/var/folders/.../sbx-hosttest-20261106-154222.um8JSM)
1 step(s) failed. Log: /Users/demian/GetShitDoneContainer/GetShitDoneContainer/host-test.log
```

- `run-all.sh` ended `Summary: 30 passed, 0 failed, 0 not run`; the "host checks" step is `OK`, so its exit status was 0.
- The "sbx self-test in the Mac shell" step ran 60 cases under `/bin/bash` 3.2.57 and ended `All cases pass.`
- "guard in sbx-hosttest" and "guard in the Mac shell" (with the real shellcheck 0.11.0 and hadolint 2.15.1) both ended `All rules hold.`; the self-tests inside the sandbox ended `All cases pass.`
- "build warnings": `no InvalidDefaultArgInFrom warning in ...`.
- SKIP of the last step is expected with `--keep`.
- Verbatim FAIL, NOT RUN, SETUP lines: one FAIL (below). No NOT RUN and no SETUP line.

### The H-28, H-29 and H-30 lines

```
INFO: H-28 runs bin/ through PATH with /bin/bash 3.2.57(1)-release; registry /private/var/folders/.../h28-sbxcfg-64764
PASS: H-28 sbx-add registered a folder with a space and refused it twice; sbx-start and sbx-stop worked by name with /bin/bash; the container and the files stayed
INFO: H-29 runs bin/ through PATH with /bin/bash 3.2.57(1)-release; registry /private/var/folders/.../h29-sbxcfg-65041
PASS: H-29 a failed build left the sandbox as it was; sbx-upgrade rebuilt, recreated only sbx-hosttest, kept its files and one bind mount, ended with the versions line, and started a stopped sandbox
PASS: H-30 the line matches versions.env, an interactive shell prints it once, bash -c and bash -lc print nothing
```

### The attended helper (`/home/sandbox/h29m.log`, escape codes stripped)

```
INFO: H-29 runs bin/ through PATH with /bin/bash 3.2.57(1)-release; registry .../h29m-sbxcfg-65973
PASS: H-29 claude auth status shows "loggedIn": true
INFO: running sbx-upgrade hosttest ; logs in .../logs/h29m-upgrade.*
PASS: H-29 sbx-upgrade rebuilt and recreated the helper's sandbox
PASS: H-29 claude auth status still shows "loggedIn": true after sbx-upgrade
PASS: H-29 claude --continue resumed the earlier session after sbx-upgrade
PASS: H-29 the test sandbox runs on the run folder again
```

No FAIL line. The user's note: `claude --continue` resumed the earlier session (answered y).

### Optional real-use step (step 4, try-sbx)

Not run. The user did not report it.

### Cleanup (step 5)

Not run yet when this was recorded. The orchestrator wrote the command to `/home/sandbox/mac-cleanup-03.txt` (stops sbx-hosttest, removes the run folder with the test Claude login). The run folder `.../sbx-hosttest-20261106-154222.um8JSM` holds the helper's real Claude login until the user runs it (T-03-19 stays open until then). The steps file said the cleanup command is printed "near the end of host-test.log"; that was wrong: it is in the log's `Next` block (line 140), before the linter and guard steps.

### Assumptions M1 to M9

| ID | Assumption | Result | Evidence |
|---|---|---|---|
| M1 | `docker compose stop` with no container exits 0 | Confirmed | H-28 PASS; its first check runs `sbx-stop hosttest` before any start and fails on a non-zero exit (`check_stop_before_start`) |
| M2 | bash.bashrc returns early for non-interactive shells and /etc/profile reads it only when PS1 is set | Confirmed | H-30 PASS: "an interactive shell prints it once, bash -c and bash -lc print nothing" |
| M3 | `java -version` prints the Temurin version in quotes on its first line | Confirmed | H-30 PASS: the line matches versions.env, whose jdk field comes from the TEMURIN_IMAGE tag; the image build's shape check also passed (H-22 PASS shows Temurin 21.0.12 at its pin) |
| M4 | `python3 --version` on noble prints `Python 3.12.x` | Confirmed | H-30 PASS: the python field is read with `python3 --version` and the whole line matched |
| M5 | `up -d --force-recreate --wait` recreates the container and returns once it runs | Confirmed | H-29 PASS "rebuilt, recreated only sbx-hosttest"; the check compares the container id before and after; the helper's "rebuilt and recreated" PASS too |
| M6 | a bogus build option makes build.sh fail at once without touching the running container | Confirmed | H-29 PASS "a failed build left the sandbox as it was" (same container id and start time, still running) |
| M7 | `/bin/bash` on the Mac is 3.2 | Confirmed | `/bin/bash is 3.2.57(1)-release`; both H-28 and H-29 INFO lines name it |
| M8 | a folder with a space under the macOS temp folder bind-mounts with Docker Desktop | Confirmed | H-28 PASS "registered a folder with a space"; the folder is `$RUN/<name>-<pid> spaced dir` under `/private/var/folders/...`; its workspace mount source and sentinel file are checked; H-29 reuses it |
| M9 | `-p sbx-hosttest` wins over an exported COMPOSE_PROJECT_NAME | Confirmed | H-28 PASS; `run_sbx` exports `COMPOSE_PROJECT_NAME=sbx-ambient` and the check requires the project label `sbx-hosttest` |

## Out-of-scope finding: pin digests

`== pin digests` failed on one line:

```
FAIL: UBUNTU_IMAGE pins sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac, the registry has sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852
```

TEMURIN_IMAGE, UV_IMAGE, SHELLCHECK_IMAGE and HADOLINT_IMAGE all passed.

- **Assessment:** upstream republished `ubuntu:24.04`, the same drift an earlier commit fixed (0285bdf "chore: bump the Ubuntu base to the current 24.04 digest"). This phase did not touch `versions.env` (Gate: unchanged against origin/main), so it did not cause it. All 30 host checks passed on the images built from the pinned digest, so the failure is a freshness warning about the pin, not a build or behaviour fault.
- **Action in this plan:** none. `versions.env` and all code stay as they are.
- **Follow-up:** bump `UBUNTU_IMAGE` in `versions.env` in a separate small PR (the host-test pin check prints the new digest), then rerun the pin check.

## PR description draft

Title: `feat: remembered sandboxes and a one-command upgrade`

**What changed**

- `bin/` with `sbx-add`, `sbx-start`, `sbx-stop`, `sbx-upgrade` and their shared library `sbx-lib.sh`. Register a sandbox once, then start, stop and upgrade it by name.
- A registry of two-line files in `~/.config/sbx`, outside every sandbox mount. The scripts read each file line by line and never source it.
- The reserved sandbox names now live in one list in `base/sbx-start-lib.sh`; `sbx-add` reads that list.
- A tool versions line written into both images at build time. Interactive shells print it when they open, and `sbx-upgrade` prints it at the end.
- A docker-free self-test (`tests/selftest/sbx/`) that also runs under the Mac's `/bin/bash`.
- Host checks H-28 to H-30 and an attended login helper (`tests/host/manual/h29-upgrade-resume.sh`).
- A guard rule that keeps deletes out of `bin/`.
- `SANDBOX.md` teaches the script flow in place of the paste-by-hand steps.

**What you accept**

- Add the repo's `bin/` to `PATH` once.
- An upgrade recreates a running sandbox after one warning line; open shells and Claude sessions in it close.
- Other sandboxes switch to the new images at their next `sbx-start`.
- `bin/` is as trusted as `build.sh`, also when the repo sits inside a sandbox folder.
- Each upgrade leaves the old images behind for `./clean.sh`.

**How it was verified**

- Linux: `bash -n` on every script, the guard (19 rules) with shellcheck and hadolint, and the entrypoint, guard and sbx self-tests.
- Mac (Docker Desktop 4.48.0, Compose 2.40.0-desktop.1): `./host-test.sh --keep` ended `Summary: 30 passed, 0 failed, 0 not run`; the self-test passed under `/bin/bash` 3.2.57; the guard held in the sandbox and in the Mac shell; the attended helper showed the login and the session surviving `sbx-upgrade`.
- The host-test pin check reports that the `ubuntu:24.04` digest in `versions.env` is out of date upstream. This change does not touch it; a separate PR bumps it.

**Follow-up**

- Bump `UBUNTU_IMAGE` in `versions.env` (separate PR).
- Jump-in, list and remove build on the registry.

## Criteria

The code PR waits for the user's go to push `feat/sbx-scripts`; nothing was pushed, merged or opened.

### Roadmap criteria

| ID | Criterion | Proof |
|---|---|---|
| SC1 | `sbx-add` registers once, agent `claude`, creates `<name>/` and `state/`, no script needs the path again | self-test `sbx-add: the entry is the two lines SBX_DIR and SBX_AGENT=claude`, `sbx-add: the host folder, its project folder and state/ are made`; Mac H-28 (sbx-start, sbx-stop and sbx-upgrade take only the name) |
| SC2 | start and stop by name; stopping deletes nothing | Mac H-28 (container kept, stopped, sentinel file unchanged, second stop ok); guard rule `host_scripts_keep_sandbox_data` and its planted cases |
| SC3 | one command rebuilds both images and recreates the sandbox; login and sessions survive | Mac H-29 and the attended helper (`loggedIn` true before and after, `claude --continue` resumed the session) |
| SC4 | versions printed at the end of a rebuild and when a bash shell opens | Mac H-30 (line matches versions.env; interactive shell prints it once; `bash -c` and `bash -lc` print nothing) and the H-29 last-line check |
| SC5 | runs under stock bash 3.2 and a host path with spaces | step "sbx self-test in the Mac shell" on `/bin/bash is 3.2.57(1)-release` (60 cases); H-28 and H-29 run through PATH with `/bin/bash` on a `spaced dir` path |

### Requirements

| ID | Status | Proof |
|---|---|---|
| SCR-01 | proven | SC1 proofs; self-test group `registry:` and the `sbx-add:` refusal cases (60 cases, also on the Mac shell) |
| SCR-02 | proven | SC2 proofs; self-test `sbx-start:` and `sbx-stop:` refusal cases; H-28 |
| SCR-03 | proven | SC3 proofs; self-test `sbx-upgrade:` refusals before the build; H-29 failed-build case |
| SCR-07 | proven | SC4 proofs; H-30; H-29 versions line |

### Locked decisions D-01 to D-22

| ID | Proof |
|---|---|
| D-01 | self-test `sbx-add: the entry is the two lines SBX_DIR and SBX_AGENT=claude`; H-28 |
| D-02 | self-test `sbx-add: a path that holds the registry folder is refused`, `a path inside the registry folder is refused`, `with SBX_CONFIG_DIR unset the entry goes under HOME/.config/sbx` |
| D-03 | self-test `registry: a value is read as text and never run`, `a value with a semicolon is never run`, `a path with a space reads whole`; the planned mutant that sources the entry fails the suite (plan 01 summary) |
| D-04 | self-test cases for an uppercase, underscore, path, empty, 32-character, line-break and non-ASCII name, `the state name is refused`, `the best-practices name is refused`, `a name already registered is refused and its entry is unchanged`, `a relative path is refused` |
| D-05 | self-test `the host folder, its project folder and state/ are made`, `an existing folder and its files are kept`; H-28 |
| D-06 | self-test `the entry is the two lines SBX_DIR and SBX_AGENT=claude`, `registry: another agent is refused`, `registry: a missing SBX_AGENT is refused` |
| D-07 | `git ls-files -s bin` (four 100755 scripts); self-test usage cases (`no argument prints the usage and exits 2`) for sbx-add, sbx-start, sbx-stop and sbx-upgrade |
| D-08 | H-28 and H-29 run the scripts through PATH (INFO lines `runs bin/ through PATH`); the scripts find compose.yml and build.sh from their own location |
| D-09 | `bin/sbx-lib.sh` (245 lines) is sourced by all four; the `registry:` self-test group drives it through the scripts |
| D-10 | H-28 (`sbx-start` runs the sandbox on the registered folder in project `sbx-hosttest`); self-test `sbx-start: a missing project folder is refused before Docker` |
| D-11 | H-28 (container kept, files unchanged after `sbx-stop`); guard rule `host_scripts_keep_sandbox_data` |
| D-12 | H-29 (rebuilt and recreated only sbx-hosttest; a failed build left the sandbox as it was); self-test `sbx-upgrade: ... is refused before the build` cases |
| D-13 | the warning line is asserted by the plan 02 tracer with a stand-in docker (plan 02 summary); the Mac run proves the recreate (H-29) but does not assert the warning text |
| D-14 | H-29 "recreated only sbx-hosttest" proves other sandboxes are not touched; that another sandbox switches images at its next `sbx-start` is Compose's own behaviour and was not run on the Mac in this phase |
| D-15 | H-30 (the file's line matches versions.env); the image builds' own smoke tests ran in every Mac build |
| D-16 | H-30 (interactive prints once; `bash -c` and `bash -lc` quiet); H-29 "ended with the versions line" |
| D-17 | H-30 compares the whole line to the expected one-line text |
| D-18 | H-29 "started a stopped sandbox" |
| D-19 | H-28 (`sbx-start` returned with the container running and the sentinel readable in it); the polling bound is covered by the plan 01 tracer |
| D-20 | self-test `the state name is refused` and `the best-practices name is refused` read the list `bin/` sources from `base/sbx-start-lib.sh`; the entrypoint self-test suite ends `All cases pass.` |
| D-21 | self-test `the root folder is refused`, `a path that holds the registry folder is refused`, `the folder of another sandbox is refused`, `a path inside another sandbox folder is refused`, `a path that holds another sandbox folder is refused`, `a path that only shares a text prefix is accepted` |
| D-22 | H-30 compares the ` | ` separator and the full Python version; self-test `a relative SBX_CONFIG_DIR is refused`; H-28 and H-29 set `SBX_CONFIG_DIR` under the run folder |

## Deviations from Plan

### Findings (not auto-fixed)

**1. [Out of scope] Pin digest drift for UBUNTU_IMAGE**
- **Found during:** Task 2 (Mac run, step `pin digests`)
- **Issue:** the registry digest of `ubuntu:24.04` differs from the pin in `versions.env` (see "Out-of-scope finding" above)
- **Fix:** none here, by design; follow-up PR to bump `UBUNTU_IMAGE`
- **Files modified:** none
- **Commit:** none

**2. [Plan wording] Cleanup location in the steps file**
- The steps file said the cleanup command is printed "near the end of host-test.log". It is in the `Next` block at line 140. The user had not run the cleanup yet when this was recorded.

**3. [Not run] Optional step 4 (try-sbx real use)**
- Not run; it was optional.

Otherwise the plan ran as written. No code changed in this plan, so there are no plan commits.

## Known Stubs

None.

## Threat Flags

None.

## Notes

- One literal verify clause from plan 03 (the `tests/README.md` row grep without backticks) fails by design; the backticked form passes (see the plan 03 summary).
- Open until the user acts: run `/home/sandbox/mac-cleanup-03.txt` on the Mac; approve and push `feat/sbx-scripts`, then open and merge the code PR.
