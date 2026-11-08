---
phase: 04-jump-in-and-sandbox-housekeeping
verified: 2026-11-08T01:00:00Z
status: human_needed
score: 13/13 must-haves verified
covered_files:
  - .planning/phases/04-jump-in-and-sandbox-housekeeping/04-01-PLAN.md
  - .planning/phases/04-jump-in-and-sandbox-housekeeping/04-01-SUMMARY.md
  - .planning/phases/04-jump-in-and-sandbox-housekeeping/04-02-PLAN.md
  - .planning/phases/04-jump-in-and-sandbox-housekeeping/04-02-SUMMARY.md
  - .planning/phases/04-jump-in-and-sandbox-housekeeping/04-03-PLAN.md
  - .planning/phases/04-jump-in-and-sandbox-housekeeping/04-03-SUMMARY.md
  - .planning/phases/04-jump-in-and-sandbox-housekeeping/04-04-PLAN.md
  - .planning/phases/04-jump-in-and-sandbox-housekeeping/04-04-SUMMARY.md
  - .planning/phases/04-jump-in-and-sandbox-housekeeping/04-05-PLAN.md
  - .planning/phases/04-jump-in-and-sandbox-housekeeping/04-05-SUMMARY.md
  - SANDBOX.md
  - bin/sbx-lib.sh
  - bin/sbx-list
  - bin/sbx-rm
  - bin/sbx-shell
  - bin/sbx-start
  - tests/guard/isolation.sh
  - tests/host/h33-sbx-rm.sh
  - tests/selftest/sbx/rm.sh
covered_digest: "v2:sha256:1582363f445d0f01dc0848d45124f42e8ae91b558529130bf06a890aa93b7ee1"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 12/13
  gaps_closed:
    - "Truth 9 (sbx-rm backstop: failed entry delete and parallel loser) is now exercised by case_rm_delete_fails, run on Linux and on the Mac under bash 3.2"
    - "Review warnings WR-01 to WR-05 and finding IN-04 are fixed (73474f5, 2e0e14c, 63de7d2, 2ee102f, 41437c8, bd38b74), including WR-04 which bore on 'without risking code, login, or history'"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Judgment-tier prohibition SCR-04: no host command starts Claude"
    expected: "No bin/ script launches claude; Claude starts only with sbx-claude inside the sbx-shell shell. Non-authoritative verdict from this verifier: holds (grep of bin/ for claude finds only the agent name in sbx-lib.sh and sbx-add, and the image name; no launch). Human review recommended."
    why_human: "unverified-prohibition: judgment tier, an LLM-judge verdict is never authoritative"
  - test: "Judgment-tier prohibition SCR-06 (plan 05): nothing pushed, merged or opened for the code PR"
    expected: "feat/sbx-shell-list-rm is local only. Non-authoritative verdict: holds (git ls-remote --heads origin lists no branch of that name, the branch has no upstream configured, git branch -a shows no remote ref for it). Whether a PR exists can only be confirmed on GitHub. Human review recommended."
    why_human: "unverified-prohibition: judgment tier; the PR state can only be confirmed on GitHub"
---

# Phase 4: Jump-In and Sandbox Housekeeping Verification Report

**Phase Goal:** The user gets into any registered sandbox with one command, and can see and clean up their sandboxes without risking code, login, or history.
**Verified:** 2026-11-08
**Status:** human_needed
**Re-verification:** Yes, after the code review fix round (previous result: human_needed, 12/13)

## Goal Achievement

The goal is achieved on every observable criterion and every plan-level truth. Nothing automated remains open: the one truth that was present but behavior-unverified in the first verification (the `sbx-rm` failed-delete and race edge) now has a passing test that exercises the branch, and the review warnings that bore on the goal wording (WR-04 above all) are fixed in code, docs, self-tests and the Mac host check. The status stays `human_needed` only because two judgment-tier prohibitions are non-authoritative by rule and need a human look. There is no BLOCKER and no gap.

What changed since the first verification, checked against the code and not against the fix report:

- `bin/sbx-rm` (read in full, 191 lines): a running sandbox asks `Remove the running sbx-NAME? [y/N]` when stdin is a terminal; only `y` or `Y` proceeds; `--yes` skips; no terminal and no `--yes` exits 1 and changes nothing; `read_entry` marks an unusable entry as broken; a broken entry without `--unregister` is refused with a hint; with `--unregister` it runs `require_docker`, then `docker stop` and `docker rm` by the exact name (no `-v`, no `-f`), then the one `rm -- "$entryFile"`.
- `bin/sbx-lib.sh`: `require_docker` asks `docker info` and prints `cannot reach Docker; is Docker running?`; `require_images` calls it first, so a stopped Docker no longer reads as a missing image.
- `tests/guard/isolation.sh`: the narrow `sbx-rm` rule allows exactly two lines, the entry `rm --` and the `docker rm "sbx-$1"` line; planted cases for `docker rm -v`, `docker rm -f`, another container and `docker volume rm` fail the rule.
- Code tree: `git diff HEAD feat/sbx-shell-list-rm -- . ':!.planning'` is empty, so the branch holds the same code as HEAD (17 commits over `main`, 0 `.planning` paths).

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC1: on a stopped sandbox the jump-in command starts it and opens bash in `/home/sandbox/workspace/<name>`; on a running one it only opens the shell | VERIFIED | `bin/sbx-shell`: `check_name`, `read_registry_entry`, `if ! sandbox_is_running; then bring_up_sandbox`, then `exec docker exec -it -w "/home/sandbox/workspace/$1" "sbx-$1" bash`. sbx self-test re-run here (212 PASS, 0 FAIL, `All cases pass.`) includes the started, stopped, running and project-folder cases. Mac H-31 PASS in the third host run (`host-test.log`, commit e09213c: 33 passed, 0 failed, 0 not run) and in the attended helper |
| 2 | SC2: `sbx-claude` in that shell starts Claude already logged in; no separate host command launches Claude | VERIFIED | `claude/bin/sbx-claude` exists. Grep of `bin/` for `claude` finds the agent name (`sbx-lib.sh` lines 155 and 156, `sbx-add`) and no launch. Mac helper `/home/sandbox/h31m.log`: 5 of 5 PASS, including `claude auth status` showing logged in after a stop and a new `sbx-shell` (earlier evidence, still valid: the fix round did not touch `sbx-shell` entry logic or the image) |
| 3 | SC3: `sbx-list` shows all registered sandboxes with host path and running or stopped status, matching `docker ps -a` | VERIFIED | `bin/sbx-list` unchanged in the fix round; one `docker ps -a --filter label=sbx.name`; self-test groups for the table, broken entries, adjacent names and order PASS (re-run); Mac H-32 PASS in the third run |
| 4 | SC4: `sbx-rm` removes the container, optionally the registration; `<name>/` and `state/` are untouched; re-registering the same path brings back login and history | VERIFIED | `bin/sbx-rm`: Compose path is `run_compose "$1" down` with no option; the only `rm` outside the broken path is `rm -- "$entryFile"` after the down; nothing reads or writes under `entryDir`. Self-test "the files in the sandbox folder are unchanged", "--unregister deletes the entry after the down", "a failed down exits 1 and keeps the entry" PASS (re-run). Mac H-33 PASS in the third run: refused without terminal or `--yes`, then removed with `--yes`, folder, entry, volumes, images and other sandboxes kept, `sbx-add` of the same folder brought back `state/claude` and the history. Manual Mac check `manual-04c.txt`: prompt then removal, `sbx-list` showed `no container`, `--unregister` removed only the entry |
| 5 | `sbx-shell` refuses before any compose call or shell: wrong argument count (exit 2), bad or path name, unregistered name, missing `NAME/` or `state/`, missing image; failed `up` or a container that stops during start opens no shell; shell exit status is the script's (the `exec`) | VERIFIED | Self-test groups `sbx-shell refusals`, `checks before compose`, `exit status and failed starts` PASS (re-run). New cases: Docker not answering is refused before compose and the shell, with no `sbx-upgrade` advice. Manual Mac check with `DOCKER_HOST` pointing at a dead socket printed `sbx-shell: cannot reach Docker; is Docker running?` |
| 6 | Start steps are shared once: `bring_up_sandbox` and `runs_older_image` live in `bin/sbx-lib.sh`; `sbx-start` calls `bring_up_sandbox` and ends with the `sbx-shell NAME` hint; a running sandbox on an older image is entered unchanged and silently | VERIFIED | Unchanged since the first verification except `require_images`, which now calls `require_docker` first (diff read). Self-test cases for the hint, the older image and the Docker-down `sbx-start` refusal PASS (re-run). Mac H-28 and H-29 pass in the third run |
| 7 | `sbx-list` contract (no argument; failed `docker ps` exits 1 with no table; broken entries are rows; empty registry message; exact-name match; byte order; older-image mark; labelled containers with no entry listed, old `cc_` never) | VERIFIED | `bin/sbx-list` untouched in the fix round; its self-test groups PASS (re-run); Mac H-32 PASS. Broken entry row text `broken entry` is the one `sbx-rm` now clears (manual Mac check step 5) |
| 8 | `sbx-rm` contract: one plain `compose down` scoped to `sbx-NAME`; a running sandbox warned, asked, then removed; `--unregister` and `--yes` before or after the name; usage exit 2; refusals before docker; second run exits 0; second `--unregister` refused; missing folder or image does not block | VERIFIED | Self-test groups (re-run, all PASS): usage, refusals, running sandbox, the terminal question (answers `n`, `N`, empty, `yes`, `no` keep everything; `y` and `Y` remove; `--yes` asks nothing; stopped and no-container asks nothing), no terminal refusal, broken entry (refused without `--unregister`; with Docker not answering kept; running broken container asks; cleared), stopped sandbox and no container, unregister, failed down, missing folder and image. Mac sbx self-test under `/bin/bash` 3.2.57 with BSD `script`: 213 PASS, 0 FAIL, `All cases pass.` (the terminal question cases ran there). Mac H-33 PASS |
| 9 | `sbx-rm` backstop: interrupted or parallel runs never touch the folder and never delete the entry before a good down; a delete that loses the race reports 'could not delete' | VERIFIED | Previously PRESENT_BEHAVIOR_UNVERIFIED. `case_rm_delete_fails` in `tests/selftest/sbx/rm.sh` (lines 516 to 548) makes the registry folder read-only, runs `sbx-rm locked --unregister` on a stopped sandbox and asserts: exit 1; stderr has `could not delete ...; the container is gone and nothing in DIR was changed`; no `deleted the registry entry` line; no `is gone` closing line; the entry is kept; the folder listing is unchanged. The case is wired into the main list (line 587) and skips only when run as root (this run was uid 1001, so it ran: `PASS: sbx-rm: a failed entry delete says the entry could not go and the container did`). It also passed on the Mac under bash 3.2 (`host-test.log` lines 205 to 211). The ordering half (entry deleted only after a good down) is pinned by "a failed down exits 1 and keeps the entry". A losing parallel run reaches exactly this `rm` failure branch, so the held-out case covers the loser's observable behavior. Residual: no test launches two real `sbx-rm` processes at once; the failed delete is simulated with a read-only folder |
| 10 | Guard rule `host_scripts_keep_sandbox_data` is narrowed (broad for every `bin/` file but `sbx-rm`; narrow for `sbx-rm` with exactly the allowed lines; a missing `bin/sbx-rm` fails) and the guard is still 19 rules | VERIFIED | `tests/guard/isolation.sh` diff read (allows the `rm -- "$entryFile"` line and the `docker rm "sbx-$1"` line only). Guard re-run with rehearsal linters on PATH: 19 PASS, `All rules hold.`. Guard self-test: 158 PASS, 0 FAIL. `grep` for `rm` in `bin/sbx-rm` finds exactly the two allowed lines (168 and 180) |
| 11 | `SANDBOX.md` teaches the three commands including the new question, `--yes`, the broken-entry path and the Docker message; test docs name H-31 to H-33; `README.md`, `ClaudeCode/`, `OpenCode/` unchanged | VERIFIED | `SANDBOX.md` line 66 (`sbx-rm NAME [--unregister] [--yes]`), lines 237 to 251 (question, `--yes`, no terminal, broken entry, network left behind), lines 452 to 455 (troubleshooting rows). Docs and `bin/sbx-rm` usage text agree. `git diff origin/main HEAD` over the old layout and `README.md` is empty (checked in the first verification; the fix round touched none of them: the changed files are `SANDBOX.md`, `bin/`, `tests/` only) |
| 12 | Final gate and PR branch: all Linux suites green, `bin/sbx-shell`, `sbx-list`, `sbx-rm` are 100755, branch `feat/sbx-shell-list-rm` holds only code commits with the same code tree and no planning ID or attribution | VERIFIED | Entrypoint 60 PASS, guard self-test 158 PASS, sbx 212 PASS, guard 19 PASS, all with 0 FAIL (re-run here). `git ls-files -s bin` and `git ls-tree feat/sbx-shell-list-rm bin/` both show 100755 for the seven scripts and 100644 for `sbx-lib.sh`. `git diff HEAD feat/sbx-shell-list-rm -- . ':!.planning'` is empty; 17 commits over `main`; 0 `.planning` paths; a scan of the added lines for planning and finding IDs (`D-NN`, `WR-`, `IN-`, `SCR-`, `Phase N`, `04-0N`) prints nothing; commit bodies carry no attribution line or planning ID |
| 13 | Mac gate: `./host-test.sh --keep` ends `Summary: 33 passed, 0 failed, 0 not run` and every step OK; attended helper passes | VERIFIED (human-verified evidence) | Third host run on commit e09213c (code tree equal to HEAD; `host-test.log` is byte-identical to `host-test-run3.log`, checked with `diff`): `Summary: 33 passed, 0 failed, 0 not run`; steps `context`, `sbx self-test in the Mac shell`, `host checks`, `run folder`, `linter versions`, `pin digests`, `guard and self-tests in sbx-hosttest`, `guard in the Mac shell`, `build warnings`, `remove test sandbox` all OK; Docker 28.5.1, Compose v2.40.0-desktop.1 recorded. The H-33 line names the no-terminal refusal and the `--yes` removal. Attended helper `h31m.log`: 5 of 5 PASS (earlier run, still valid) |

**Score:** 13/13 truths verified (0 present, behavior unverified)

### Deferred Items

None. Later phases (5 and 7) do not claim any open point. Review findings IN-01, IN-02, IN-03 and IN-05 are recorded as `deferred` in `04-REVIEW-DISPOSITION.md` with a stated reason; they are hardening and wording follow-ups, not must-have failures, and no later roadmap phase is named for them, so they are carried here as informational only.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `bin/sbx-shell` | jump-in | VERIFIED | 100755, `exec docker exec -it -w ...`, wired to the library |
| `bin/sbx-lib.sh` | `bring_up_sandbox`, `runs_older_image`, `require_docker` shared | VERIFIED | functions present; `require_docker` called by `require_images` and `sbx-rm` |
| `bin/sbx-start` | start through `bring_up_sandbox`, hint line | VERIFIED | |
| `bin/sbx-list` | list with status | VERIFIED | 100755 |
| `bin/sbx-rm` | removal with question, `--yes`, broken-entry path | VERIFIED | 100755, 191 lines, two allowed `rm` lines, no `down` option |
| `tests/guard/isolation.sh` | narrowed data rule | VERIFIED | 19 rules hold |
| `tests/selftest/sbx/{shell,list,rm,start}.sh`, `lib.sh` | docker-free cases | VERIFIED | 212 PASS on Linux, 213 PASS on the Mac, 0 FAIL |
| `tests/host/h31-sbx-shell.sh`, `h32-sbx-list.sh`, `h33-sbx-rm.sh`, `manual/h31-jump-in.sh` | host checks and helper | VERIFIED | ran on the Mac, all PASS |
| `SANDBOX.md`, `tests/README.md`, `tests/host-checklist.md` | docs | VERIFIED | match the code |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `bin/sbx-shell` | `bin/sbx-lib.sh` | `if ! sandbox_is_running "$1"; then bring_up_sandbox "$1"` | WIRED | |
| `bin/sbx-start` | `bin/sbx-lib.sh` | `bring_up_sandbox "$1"` | WIRED | |
| `bring_up_sandbox` | `require_images` then `require_docker` | `docker info` before the image check | WIRED | self-test: Docker down gives the Docker message and no `sbx-upgrade` advice |
| `bin/sbx-list` | library and `compose.yml` | `runs_older_image`, `label=sbx.name` | WIRED | |
| `bin/sbx-rm` | library | `run_compose "$1" down`, `require_docker`, `sandbox_is_running`, `warn_sessions_close` | WIRED | |
| `bin/sbx-rm` main | `confirm_if_running` then `remove_container` / `remove_broken_sandbox` then `unregister_sandbox` | sequential calls under `set -eu` | WIRED | a refused question exits 1 before any `down` (self-test "keeps the sandbox, its entry and its folder") |
| `tests/guard/isolation.sh` | `bin/sbx-rm` | narrow check, two allowed lines | WIRED | planted cases fail on `-v`, `-f`, other container, `volume rm` |
| `tests/host/run-all.sh` | h31, h32, h33 | chain list | WIRED | 33 checks ran on the Mac |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `bin/sbx-list` | `containerStateText` | `docker ps -a --filter label=sbx.name` | Yes (Mac H-32 compared rows to `docker ps -a`) | FLOWING |
| `bin/sbx-rm` | `entryFile`, `entryDir`, `entryBroken`, `folderText` | registry entry via `read_registry_entry` | Yes (manual Mac check printed the real entry path and folder) | FLOWING |
| `bin/sbx-rm` | `answer` | `read -r -p` on the terminal | Yes (Mac manual step 4 answered `y`; self-test through pty answered `n`, `N`, empty, `yes`, `no`, `y`, `Y`) | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| sbx self-test | `bash tests/selftest/sbx/run-all.sh` | 212 PASS, 0 FAIL, `All cases pass.` | PASS |
| guard self-test | `bash tests/selftest/guard/run-all.sh` | 158 PASS, 0 FAIL, `All cases pass.` | PASS |
| entrypoint self-test | `bash tests/selftest/entrypoint/run-all.sh` | 60 PASS, 0 FAIL, `All cases pass.` | PASS |
| guard with linters | `PATH="${TMPDIR:-/tmp}/sbx-linters/bin:$PATH" bash tests/guard/run-all.sh` | 19 PASS, `All rules hold.` (linters found in `/tmp/sbx-linters/bin`) | PASS |
| Failed entry delete branch | case `sbx-rm: a failed entry delete ...` inside the sbx self-test | 6 expectations PASS (uid 1001, not skipped) | PASS |
| Real Docker | Mac `./host-test.sh --keep` (human-verified log, commit e09213c) | 33 passed, 0 failed, 0 not run | PASS |
| Real Docker, manual | `manual-04c.txt` (prompt then removal; broken entry refused then cleared; Docker unreachable message) | outputs as expected | PASS (human-verified) |

### Probe Execution

SKIPPED: the plans declare no `probe-*.sh` scripts; the equivalent runnable checks are the suites above.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|--------------|-------------|--------|----------|
| SCR-04 | 04-01, 04-04, 04-05 | One command jumps into a sandbox: starts it if needed, opens a shell; Claude from that shell with `sbx-claude` | SATISFIED | Truths 1, 2, 5, 6; H-31 and helper |
| SCR-05 | 04-02, 04-04, 04-05 | List all registered sandboxes with host path and running status | SATISFIED | Truths 3, 7; H-32 |
| SCR-06 | 04-03, 04-04, 04-05 | Remove a sandbox's container (and optionally its registration) without touching workspace or state | SATISFIED | Truths 4, 8, 9, 10; H-33; manual Mac check |

All three IDs appear in `REQUIREMENTS.md` (lines 64 to 66, mapped to Phase 4 at lines 154 to 156, marked Complete). No other requirement is mapped to Phase 4, so there are no orphaned IDs.

### Prohibitions

| Prohibition | Tier | Verdict |
|-------------|------|---------|
| SCR-04: never recreate, restart or stop a running sandbox on entry | test | Enforced: "a running sandbox gets the shell only", "an older image is entered as it is" |
| SCR-04: never open a shell in a container other than `sbx-NAME` of a registered, rule-passing name | test | Enforced: refusal cases |
| SCR-04: no host command starts Claude | judgment | Non-authoritative verdict: holds. unverified-prohibition, human review recommended |
| SCR-04: self-test never reaches the Mac's Docker; H-31 never touches real `~/.config/sbx` | test | Enforced: "no case reached the refusing docker" in each group; per-check registry under the run folder |
| SCR-05: never show stopped or no container when Docker could not be asked | test | Enforced: "a failed docker ps exits 1 and prints no table" |
| SCR-05: only reads | test | Enforced: "the registry is unchanged"; broad guard rule |
| SCR-05: never list or act on `cc_` containers | test | Enforced by the label filter; H-32 asserts no `cc_` line |
| SCR-06: nothing under `SBX_DIR` read, written or deleted | test | Enforced: "the files in the sandbox folder are unchanged", the failed-delete case, the question cases, H-33 |
| SCR-06: no volumes or images removed, no other project taken down | test | Enforced: no-option `down` case, guard planted cases (including `docker rm -v`, `-f`, other container, `volume rm`), H-33 now fails loudly if Docker listings error |
| SCR-06: entry deleted only after a good down, nothing else deleted | test | Enforced: "a failed down exits 1 and keeps the entry", "a refused question keeps the entry", the failed-delete case, the two-line `rm` guard |
| SCR-06: a running sandbox is not removed without the user's say | test | Enforced (new): terminal question, `--yes`, no-terminal refusal; Mac H-33 asserts the refusal and the sandbox still running |
| SCR-06: other `bin/` scripts never delete or take down | test | Enforced: broad guard rule, planted case "the word rm in sbx-list" |
| SCR-06 (plan 04): README and old layout unchanged; no volume or image removal documented | test | Enforced: empty diff; `old_layout_untouched` PASS |
| SCR-06 (plan 05): never push, merge or open the PR | judgment | Non-authoritative verdict: holds (no remote branch, no upstream). unverified-prohibition, human review recommended |
| SCR-04 (plan 05): no `.planning` file on the code branch, no planning ID or attribution | test | Enforced: 0 `.planning` paths, ID scan empty, commit bodies clean |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (phase files) | | TBD, FIXME, XXX, TODO, HACK | None found | grep over `bin/sbx-*`, `tests/host/h3*.sh` and `tests/selftest/sbx/*.sh` is empty |
| (added lines vs origin/main) | | em or en dash, ASCII `--` as punctuation | None found | every `--` hit is literal code (`rm --`, `grep -qxF --`, `grep -qF --`) |
| (added lines) | | planning or finding IDs in committed source | None found | regex scan over the code diff prints nothing |

Review findings (04-REVIEW.md, 0 critical, 5 warning, 5 info) now stand as follows, per `04-REVIEW-DISPOSITION.md`, cross-checked against the code:

| Finding | Disposition | Check |
|---------|-------------|-------|
| WR-01 H-31 greps `TTY` only | fixed (73474f5) | Mac H-31 PASS on Docker 28.5.1 with the widened pattern |
| WR-02 `sbx-rm` refused entries `sbx-list` calls broken | fixed (41437c8) | `read_entry`, `remove_broken_sandbox` read; self-test cases and the Mac manual step 5 |
| WR-03 missing-image message when Docker is down | fixed (2e0e14c) | `require_docker`; self-test cases; Mac manual step 6 |
| WR-04 running sandbox removed after one warning | fixed (2ee102f) | `confirm_if_running` read; self-test through a pty on Linux and on the Mac; Mac H-33 and manual step 4 |
| WR-05 H-33 snapshots could pass vacuously | fixed (63de7d2) | stderr no longer merged, failed listings are their own problem; the Mac run passed with real listings |
| IN-04 failed-delete branch untested | fixed (bd38b74) | closes truth 9 |
| IN-01 guard is a pattern list with holes | deferred | INFO. The new `docker rm` allow-line is exact and has planted cases, but the pattern-list design is unchanged |
| IN-02 label lookup in `sbx-list` versus name lookup elsewhere | deferred | INFO |
| IN-03 H-33 folder move has no cleanup trap | deferred | INFO (test hygiene only) |
| IN-05 `warn_sessions_close` warns on stdout | deferred | INFO |

Notes that are not defects: the broken-entry path against real Docker was proven by a manual Mac run (`manual-04c.txt`) and not by a host check, as the fix report itself says; the Docker-unreachable message was exercised on the Mac by pointing `DOCKER_HOST` at a dead socket, not by stopping Docker Desktop; the `n` answer ran on the Mac only through the self-test (the user answered `y` in the manual run). All three are covered by the self-test cases that ran under bash 3.2 with BSD `script`.

### Human Verification Required

#### 1. Judgment-tier prohibition: no host command starts Claude (SCR-04)

**Test:** Skim `bin/` for any launcher of Claude.
**Expected:** None exists; Claude starts only with `sbx-claude` inside the `sbx-shell` shell.
**Why human:** Judgment tier. This report's verdict (holds) is non-authoritative and flagged `unverified-prohibition`.

#### 2. Judgment-tier prohibition: nothing pushed, merged or opened for the code PR (SCR-06, plan 05)

**Test:** Confirm on GitHub that `feat/sbx-shell-list-rm` is not pushed and no PR is open for it.
**Expected:** No remote branch and no PR. Local evidence: `git ls-remote --heads origin` lists no such branch, the branch has no upstream, tip is 27c6517 with 17 commits over `main`.
**Why human:** Judgment tier. The verdict (holds) is non-authoritative and flagged `unverified-prohibition`; the PR state can only be confirmed on GitHub.

### Gaps Summary

No gaps. Everything other than the two judgment-tier prohibitions now passes: all four roadmap success criteria, all three requirement IDs, all 13 truths (the former backstop truth is closed by a wired, passing test), the five fixed review warnings, and the 19 guard rules. The Linux suites were re-run here (sbx 212, guard self-test 158, entrypoint 60, guard 19, all 0 FAIL). The Mac evidence from the user (third host run on e09213c with 33 passed, 0 failed, 0 not run; sbx self-test 213 PASS under bash 3.2; manual checks for the prompt, the broken entry and the Docker-unreachable message) matches the code read here. The status is `human_needed` solely because of the two flagged judgment-tier prohibitions. `04-UAT.md` still lists the earlier four items as pending; its tests 1 and 4 are now resolved by this round and should be refreshed by the orchestrator.

---

_Verified: 2026-11-08_
_Verifier: Claude (gsd-verifier)_
