---
phase: 04-jump-in-and-sandbox-housekeeping
plan: 05
subsystem: infra
tags: [gate, branch, mac-run, validation]
status: complete

requires:
  - phase: 04-jump-in-and-sandbox-housekeeping
    provides: bin/sbx-shell, bin/sbx-list, bin/sbx-rm, the sbx self-test groups, H-31 to H-33, the attended helper and SANDBOX.md from plans 01 to 04
provides:
  - the final Linux gate record and the empty planning-ID scan
  - local branch feat/sbx-shell-list-rm (11 code commits on origin/main, same code tree as chore/planning-phase-04-context), not pushed
  - the Mac gate record: 33 host checks, the Mac-shell self-test on bash 3.2, the attended jump-in helper, the real-use pass
  - the criteria map and the PR description draft
affects: [phase verification, the code PR]

key-decisions:
  - "The phase gate passed on the Mac as written; no gap-closure plan is needed"

requirements-completed: [SCR-04, SCR-05, SCR-06]

duration: "Task 1 plus the continuation, spanning the user's Mac run"
completed: 2026-11-07

actuals:
  tokens: 7700
  tasks: 3
  commits: 0

plan_head_before: 375f23bf0ad823ccafaa169c32cff97edc904dfe
plan_head_after: 375f23bf0ad823ccafaa169c32cff97edc904dfe
---

# Phase 4 Plan 05: The Phase Gate Summary

**The phase gate passed: every Linux check is green, the planning-ID scan is empty, `feat/sbx-shell-list-rm` holds the 11 code commits on a fresh `origin/main`, and on the Mac `./host-test.sh --keep` ended with 33 passed, 0 failed, 0 not run, the sbx self-test passed on `/bin/bash` 3.2.57, and the attended jump-in helper passed every line.**

`commits: 0` is measured from `plan_head_before` to `plan_head_after`: this plan changes no code. The 11 code commits on the branch belong to plans 01 to 04; this plan's own commits are the planning-only records written after this file.

## Gate

All commands ran in `/home/sandbox/GetShitDoneContainer` on `chore/planning-phase-04-context` (HEAD `375f23b`), `origin/main` = `c4b4e18` after `git fetch origin`.

| Check | Result |
|---|---|
| `bash -n` on `build.sh clean.sh host-test.sh base/sbx-entrypoint base/sbx-start-lib.sh claude/start.d/* claude/bin/* bin/* tests/*/*.sh tests/*/*/*.sh` | no error |
| Guard without linters | exactly two FAIL lines: `FAIL: shellcheck_passes`, `FAIL: hadolint_passes` (last line `2 rule(s) broken.`) |
| Guard with the rehearsal linters (`${TMPDIR:-/tmp}/sbx-linters/bin`) | 19 `PASS:` lines, last line `All rules hold.` |
| `tests/selftest/guard/run-all.sh` | last line `All cases pass.` (146 PASS lines) |
| `tests/selftest/entrypoint/run-all.sh` | last line `All cases pass.` (60 PASS lines) |
| `tests/selftest/sbx/run-all.sh` | last line `All cases pass.` (154 PASS lines) |
| `git diff --quiet origin/main HEAD -- compose.yml build.sh versions.env .dockerignore base claude` | exit 0 (unchanged) |
| `git diff --quiet origin/main HEAD -- ClaudeCode OpenCode README.md .claude` | exit 0 (untouched) |

`git ls-files -s bin`:

```
100755 bin/sbx-add
100644 bin/sbx-lib.sh
100755 bin/sbx-list
100755 bin/sbx-rm
100755 bin/sbx-shell
100755 bin/sbx-start
100755 bin/sbx-stop
100755 bin/sbx-upgrade
```

Line counts:

| Group | Lines |
|---|---|
| `bin/*` | 1022 (sbx-add 283, sbx-lib.sh 301, sbx-list 175, sbx-rm 90, sbx-shell 36, sbx-start 24, sbx-stop 33, sbx-upgrade 80) |
| `tests/guard/*.sh` plus `tests/selftest/guard/*.sh` | 964 |
| `tests/selftest/sbx/*.sh` | 1710 (add 296, entry 141, lib 235, list 341, rm 318, run-all 16, shell 219, start 84, upgrade 60) |
| `tests/host/h31-sbx-shell.sh` | 194 |
| `tests/host/h32-sbx-list.sh` | 180 |
| `tests/host/h33-sbx-rm.sh` | 319 |
| `tests/host/manual/h31-jump-in.sh` | 111 |

## Planning-ID scan

Regex from the plan, over the 21 files `git diff --name-only --diff-filter=AMR origin/main...HEAD -- . ':(exclude).planning'` lists (`SANDBOX.md`, `bin/sbx-lib.sh`, `bin/sbx-list`, `bin/sbx-rm`, `bin/sbx-shell`, `bin/sbx-start`, `host-test.sh`, `tests/README.md`, `tests/guard/isolation.sh`, `tests/host-checklist.md`, `tests/host/h31-sbx-shell.sh`, `h32-sbx-list.sh`, `h33-sbx-rm.sh`, `tests/host/manual/h31-jump-in.sh`, `tests/host/run-all.sh`, `tests/selftest/guard/sandbox-rules.sh`, `tests/selftest/sbx/lib.sh`, `list.sh`, `rm.sh`, `shell.sh`, `start.sh`).

The scan printed nothing (grep exit 1). No false positive to record, and no file was changed by the scan.

## Code commits

Eleven commits touch non-`.planning` paths between `origin/main` and HEAD; the other eleven commits on the branch touch only `.planning/` (the plan summaries and the state updates of plans 01 to 04, plus the phase context, research and plans). For each code commit, `git show --name-only --format=` lists no `.planning/` path (count 0 for all eleven), and its message holds no planning ID and no `Co-Authored-By` or "Generated with" line. No mixed commit.

| Original | On feat/sbx-shell-list-rm | Subject |
|---|---|---|
| 7ed9ead | 19dca84 | feat(bin): sbx-shell starts a sandbox when needed and opens a shell in it |
| 844315e | 1f0018c | test(bin): pin the paths of sbx-shell in the docker-free self-test |
| 2ce13b4 | 3a4cc71 | test(host): prove sbx-shell on the Mac, with an attended login check |
| 2502e79 | 4d8acbd | feat(bin): sbx-list shows each registered sandbox with its folder and status |
| 112bfed | 1b96a99 | test(bin): pin the statuses, marker and leftovers of sbx-list in the self-test |
| 6b6249b | 51dfe49 | test(host): prove sbx-list against docker ps on the Mac |
| d2489df | ebd4fc1 | feat(bin): sbx-rm removes a sandbox's container and, when asked, its registry entry |
| f8200e1 | e39dd22 | test(bin): pin the forms, refusals and order of sbx-rm in the self-test |
| a807994 | 6b3eb88 | test(host): prove sbx-rm and re-registering on the Mac |
| da0ecb4 | a0a7a16 | docs: SANDBOX.md teaches sbx-shell, sbx-list and sbx-rm |
| 7696937 | 91872e6 | docs(tests): name the jump-in, list and remove checks |

## Branch

- `git branch feat/sbx-shell-list-rm origin/main` (origin/main `c4b4e18`), temporary worktree `${TMPDIR:-/tmp}/sbx-shell-list-rm-branch`, eleven cherry-picks in order, no conflict. Worktree removed afterwards (`git worktree list` no longer shows it).
- **Branch tip: `91872e6`**, 11 commits ahead of origin/main.
- `git diff --quiet HEAD feat/sbx-shell-list-rm -- . ':(exclude).planning'` exited 0: same code tree as `chore/planning-phase-04-context`.
- Inside the worktree: rehearsal guard `All rules hold.`; the guard, entrypoint and sbx self-tests each end `All cases pass.`; `bin/` modes as above; `git diff --name-only origin/main HEAD` lists only `bin/`, `tests/`, `SANDBOX.md` and `host-test.sh` paths (0 others); 0 commit-message lines with an attribution or a planning ID.
- The upstream that `git branch ... origin/main` set was removed (`git branch --unset-upstream`; `git config --get branch.feat/sbx-shell-list-rm.merge` prints nothing), so a bare `git push` cannot target origin/main. `git ls-remote --heads origin feat/sbx-shell-list-rm` is empty. Nothing was pushed, merged or opened.
- The Mac folder is the same working tree as this sandbox's repo, on `chore/planning-phase-04-context` (tip `375f23b`), whose code tree equals the branch above. So the Mac run proved the code the PR will carry.

## Mac run (Task 2)

Two kept runs happened. The first (10:30 PST) was a full run. The user cleaned it up before running the attended helper, so a second kept run (15:23 PST) was made to host the helper. Both ended identically; `host-test.log` in the repo folder is the second, and its sandbox was cleaned up after the helper.

Environment (both runs): Docker version 28.5.1 (build e180ab8), Docker Compose version v2.40.0-desktop.1, Docker Desktop 4.48.0 (207573), docker context `desktop-linux`, `/bin/bash` 3.2.57(1)-release.

### run-all.sh and host-test.sh

- run-all.sh summary line, both runs: `Summary: 33 passed, 0 failed, 0 not run`; host-test.sh ended `0 step(s) failed.`
- No FAIL, NOT RUN or SETUP line appears in either log.

| Step | Result |
|---|---|
| context | OK |
| sbx self-test in the Mac shell | OK: `/bin/bash is 3.2.57(1)-release`, `INFO: bash 3.2.57(1)-release`, last line `All cases pass.`, 155 PASS lines |
| host checks | OK: 33 passed |
| run folder | OK |
| linter versions | OK (ShellCheck 0.11.0, Haskell Dockerfile Linter 2.15.1) |
| pin digests | OK; TEMURIN, UV, SHELLCHECK and HADOLINT images PASS; the UBUNTU_IMAGE line is an INFO notice (below) |
| guard and self-tests in sbx-hosttest | OK: 19 PASS lines, `All rules hold.`, two `All cases pass.` |
| guard in the Mac shell | OK: 19 PASS lines, `All rules hold.` |
| build warnings | OK: no InvalidDefaultArgInFrom warning |
| remove test sandbox | SKIP (`--keep`, as expected) |

The Mac-shell self-test has 155 PASS lines against 154 on Linux. The one extra is `PASS: sbx-add: the same folder in another letter case is refused`, a case that runs only on the Mac's case-insensitive file system. Everything else matches line for line.

INFO line, not a failure: `UBUNTU_IMAGE pins sha256:68ee2200...33ac, the registry now has sha256:fe815609...f852 (a newer image; bump the pin when convenient)`.

### Host checks H-31 to H-33

```
PASS: H-31 sbx-shell started a sandbox with no container and waited for its hooks; without a terminal Docker refused the shell; through a terminal bash opened in /home/sandbox/workspace/hosttest on the running sandbox (not recreated) and on a stopped one (started again)
PASS: H-32 sbx-list showed no container, running and stopped as docker ps -a did, with the folder that has a space; it marked no sandbox on the current image and listed the unregistered test container by its label, with no cc_ container
PASS: H-33 sbx-rm took the container and its network and kept the folder, the entry, the volumes, the images and the other sandboxes; it ran again with no container and with the folder moved; --unregister deleted only the entry; sbx-add of the same folder brought back state/claude and the history
```

INFO lines: `H-28`, `H-29`, `H-31`, `H-32` and `H-33` each print `runs bin/ through PATH with /bin/bash 3.2.57(1)-release` and name their own registry under the run folder. H-28 also passed: `sbx-start of a running sandbox on the current image printed no warning`. H-29 passed with the sbx-shell-era `sbx-start`.

### Attended helper (`tests/host/manual/h31-jump-in.sh`, log `/home/sandbox/h31m.log`)

All five lines PASS, no FAIL:

```
PASS: H-31 sbx-shell started the helper's sandbox
PASS: H-31 claude auth status shows "loggedIn": true after the login in the sbx-shell shell
PASS: H-31 the shell opened in the project folder
PASS: H-31 sbx-claude in a new sbx-shell shell started Claude already logged in
PASS: H-31 the test sandbox runs on the run folder again
```

User note: `sbx-claude` showed the expected "no best-practices clone is linked" warning (the helper's own sandbox folder has no clone), then started Claude after its 5 s wait. This is the designed behaviour, not a failure.

### Cleanup (T-04-24)

The user cleaned the first run up before the helper ran, so that run never held a login. The second run's sandbox, which holds the helper's Claude login, was cleaned up afterwards with the printed cleanup command, per the user's report.

### Optional real-use pass on the user's own registry

| Step | Showed |
|---|---|
| `sbx-list` (empty registry) | `sbx-list: no sandboxes registered; register one with: sbx-add NAME HOST_PATH`, then the leftover section listing `sbx-hosttest running` (the kept test container has no entry in the user's registry: correct) |
| `sbx-add try-sbx "$HOME/sbx-try"` | registered |
| `sbx-shell try-sbx` | compose created the network and container (Healthy 0.7s), the versions line `claude 2.1.285 \| gsd 1.15.0 \| ccusage 20.0.26 \| node 24.21.0 \| jdk 21.0.12 \| mvn 3.9.11 \| python 3.12.3`, prompt in `~/workspace/try-sbx`; `exit` returned |
| `sbx-list` | `try-sbx running /Users/demian/sbx-try` plus the `sbx-hosttest` leftover row |
| `sbx-rm try-sbx --unregister` | `sbx-rm: sbx-try-sbx is running; removing it will close its open shells and Claude sessions`; container and network removed; `sbx-rm: deleted the registry entry /Users/demian/.config/sbx/sandboxes/try-sbx; sbx-add try-sbx "/Users/demian/sbx-try" registers the folder again`; `sbx-rm: the container sbx-try-sbx is gone; nothing in /Users/demian/sbx-try was changed` |
| `sbx-list` | no sandboxes registered, plus the `sbx-hosttest` leftover row |

### Exec-bit step

After the chmod loop, `git status` showed no mode change; `ls -l bin` showed the seven scripts executable and `sbx-lib.sh` not executable, as in git.

### Assumptions M1 to M8

| ID | Result | Line that shows it |
|---|---|---|
| M1 | Confirmed | `PASS: H-31 ... through a terminal bash opened in /home/sandbox/workspace/hosttest on the running sandbox (not recreated) and on a stopped one (started again)` |
| M2 | Confirmed | `PASS: H-31 ... without a terminal Docker refused the shell` |
| M3 | Confirmed | `PASS: H-33 ... it ran again with no container` |
| M4 | Confirmed | `PASS: H-33 ... it ran again ... with the folder moved` |
| M5 | Confirmed | `PASS: H-32 sbx-list showed no container, running and stopped as docker ps -a did ... listed the unregistered test container by its label`; the real-use `sbx-list` printed the same leftover row |
| M6 | Confirmed | `PASS: H-33 sbx-rm took the container and its network`; the helper log shows the network `sbx-hosttest_default` created and the real-use pass removed the network of `sbx-try-sbx` |
| M7 | Confirmed | `PASS: sbx-list: rows are in byte order of the name` and every shell, list and rm group PASS in the Mac-shell self-test on `/bin/bash is 3.2.57(1)-release` |
| M8 | Confirmed | `PASS: H-32 ... it marked no sandbox on the current image` and `PASS: H-28 ... sbx-start of a running sandbox on the current image printed no warning` |

No fallback was needed for any assumption.

## Criteria

SC1 to SC4 are the four roadmap success criteria of this phase.

| Item | What it requires | Proved by |
|---|---|---|
| SC1 | `sbx-shell` starts a stopped sandbox and opens bash in the project folder; a running one just gets the shell | self-test `sbx-shell: a sandbox with no container is started, then the shell opens`, `... a stopped sandbox is started, then the shell opens`, `... a running sandbox gets the shell only`, `... the shell opens in the project folder`; host check H-31; the helper line `H-31 the shell opened in the project folder` |
| SC2 | `sbx-claude` in that shell starts Claude already logged in; no host command launches Claude | the helper lines `H-31 claude auth status shows "loggedIn": true ...` and `H-31 sbx-claude in a new sbx-shell shell started Claude already logged in`; no bin script launches Claude (`bin/` listing in the Gate) |
| SC3 | `sbx-list` shows host path and running or stopped, matching `docker ps -a` | self-test group `sbx-list table`; host check H-32; real-use `sbx-list` rows |
| SC4 | `sbx-rm` removes the container, optionally the registration, leaves `<name>/` and `state/`, and re-registering brings back login and history | self-test groups `sbx-rm running sandbox`, `sbx-rm unregister`, `sbx-rm failed down`; host check H-33 (round trip); real-use `sbx-rm try-sbx --unregister` |
| SCR-04 | one command jumps into a sandbox; Claude from that shell | SC1 and SC2 proofs; `sbx-start: the closing hint names sbx-shell` |
| SCR-05 | list all registered sandboxes with host path and running status | SC3 proofs; `sbx-list: a container whose name only starts like an entry is not that entry`; `sbx-list: a failed docker ps exits 1 and prints no table` |
| SCR-06 | remove a sandbox's container and optionally its registration without touching workspace or state | SC4 proofs; `sbx-rm: the files in the sandbox folder are unchanged`; the data guard rule `host_scripts_keep_sandbox_data` with its planted cases in `tests/selftest/guard` (`All cases pass.`) |
| D-01 | `sbx-shell NAME` opens a shell; a stopped or missing container goes through the `sbx-start` steps; a running one gets the exec only | self-test groups `sbx-shell start paths` and `sbx-shell checks before compose`; H-31 |
| D-02 | no host command launches Claude | helper lines for `sbx-claude` inside the shell; `bin/` holds no such script |
| D-03 | a running sandbox on an older image is entered as it is, with no message | self-test `sbx-shell: a running sandbox on an older image is entered as it is`, `sbx-shell: an older image prints no message`; H-31 (running sandbox not recreated) |
| D-04 | start steps shared with `sbx-start`; its hint names `sbx-shell` | self-test `sbx-start: the closing hint names sbx-shell` and the unchanged `sbx-start` cases; H-28 and H-29 pass with the shared library |
| D-05 | `sbx-list` takes no arguments; one row per entry; status running, stopped or no container, as `docker ps -a` | self-test groups `sbx-list usage` and `sbx-list table`; H-32 |
| D-06 | a running sandbox on an older image is marked; one shared comparison | self-test group `sbx-list older image marker`; H-32 and H-28 (no mark or warning on the current image); M8 |
| D-07 | labelled containers with no entry listed after the table; old `cc_` containers never | self-test `sbx-list: a labelled container with no entry is listed after the table`; H-32 (`no cc_ container`); real-use leftover row |
| D-08 | `sbx-rm` runs a plain `docker compose down`; never `-v` or `--rmi` | self-test `sbx-rm: compose down runs once, for the sandbox's own project, with no option`; guard rule `host_scripts_keep_sandbox_data`; H-33 (volumes and images kept) |
| D-09 | a running sandbox is removed without a prompt, after one warning line | self-test `sbx-rm: a running sandbox is warned before the down`; real-use `sbx-rm try-sbx --unregister` warning line |
| D-10 | `--unregister` deletes the entry only after a good down | self-test groups `sbx-rm unregister` and `sbx-rm failed down`; H-33 |
| D-11 | `sbx-rm` never touches `SBX_DIR` and ends with a line saying so | self-test `sbx-rm: the last line says nothing in the folder was changed`, `sbx-rm: the files in the sandbox folder are unchanged`; H-33; real-use final line |
| D-12 | re-registering the same path after `--unregister` brings back login and history | H-33 (`sbx-add of the same folder brought back state/claude and the history`) |

The code PR waits for the user's go to push feat/sbx-shell-list-rm.

## PR description draft

Title: `feat: jump into, list and remove sandboxes by name`

### What changed

- `sbx-shell NAME` starts the sandbox when needed and opens bash in its project folder. A running sandbox is entered as it is.
- `sbx-list` shows each registered sandbox with its folder and a status from one `docker ps` call, marks a sandbox on an older image, flags broken entries, and lists labelled containers that have no registry entry.
- `sbx-rm NAME [--unregister]` runs a plain `docker compose down`; the registry entry is deleted only after a good down.
- The start steps and the image comparison are shared in `bin/sbx-lib.sh`; `sbx-start` ends with the `sbx-shell` hint.
- The data guard rule is narrowed: only `sbx-rm` may take a sandbox down and delete its entry.
- Tests: docker-free self-test groups for the three scripts, host checks H-31 to H-33, and an attended jump-in helper.
- `SANDBOX.md` teaches the three commands.

### What you accept

- Entering a running sandbox does not wait for its start hooks.
- `sbx-shell` needs a terminal.
- `sbx-rm` removes a running sandbox after one warning line.
- An unregistered leftover container is handled with plain `docker`.

### How it was verified

- Linux gate: `bash -n` on every script, the guard with the linters (All rules hold., 19 rules), and the guard, entrypoint and sbx self-tests (All cases pass.).
- Mac run: `./host-test.sh --keep` on Docker Desktop 4.48.0 with Compose v2.40.0 ended with `Summary: 33 passed, 0 failed, 0 not run`, and the sbx self-test passed in the Mac's `/bin/bash` 3.2.57.
- Attended jump-in helper on the Mac: `sbx-shell` opened a shell in the project folder, `sbx-claude` logged in there, and after a stop a new `sbx-shell` shell started Claude already logged in.
- Real use on a personal registry: `sbx-add`, `sbx-shell`, `sbx-list` and `sbx-rm --unregister` on a throwaway sandbox, with its folder left untouched.

### Follow-up

- Migration and the README come in the next phase.
- The Ubuntu base image pin has a newer digest in the registry; bump it when convenient.

## Deviations from Plan

None. The plan ran as written. Notes that are not deviations:

- Two kept runs happened instead of one, because the user cleaned the first up before the helper (see "Mac run").
- The Mac checkout was on `chore/planning-phase-04-context`, not on `feat/sbx-shell-list-rm`; the code trees are equal (Branch section), so the run proves the PR's code.
- The Mac self-test counts one more case than Linux (a case-insensitive file system case).

## Auth Gates

None.

## Known Stubs

None. No placeholder, empty-data or TODO pattern in the files this plan touched (it changes only planning records).

## Threat Flags

None. No new network endpoint, auth path, file access pattern or schema at a trust boundary. Threat register: T-04-22 held (nothing pushed, merged or opened; upstream unset), T-04-23 held (the scan is empty), T-04-24 held (cleanup ran), T-04-25 held (only `try-sbx` was removed, and no file in its folder changed), T-04-SC held (no package added; the pin digests step passed).

## Self-Check: PASSED

- The branch `feat/sbx-shell-list-rm` exists locally at `91872e6`, no upstream, not on origin.
- `/home/sandbox/GetShitDoneContainer/host-test.log` and `/home/sandbox/h31m.log` were read; every quoted line comes from them.
- No file outside `.planning/` was changed by this plan.
