---
phase: 04-jump-in-and-sandbox-housekeeping
verified: 2026-11-07T23:59:00Z
status: human_needed
score: 12/13 must-haves verified
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
covered_digest: "v2:sha256:b3f26d2167746b1bbc41d019b2c086ef1b5b4fe88d8b84c0f91ce077b97fc66b"
behavior_unverified: 1
overrides_applied: 0
behavior_unverified_items:
  - truth: "Interrupted between the down and the delete, or run twice at once, sbx-rm never touches the folder and never deletes the entry before a successful down; a rerun finishes the job, and a parallel delete that loses the race reports 'could not delete' (plan 03, verification: backstop)"
    test: "Run sbx-rm NAME --unregister twice at once against one registered sandbox, and separately make the registry folder read-only before the delete step"
    expected: "The folder is never touched; the entry is deleted only after a good down; the loser of the race (or the read-only case) exits 1 with 'could not delete ... the container is gone' and no 'deleted the registry entry' line; a rerun finishes the job"
    why_human: "The order guarantee (entry deleted only after a good down) is pinned by the self-test case 'a failed down exits 1 and keeps the entry'. The race and the failed-delete branch (bin/sbx-rm lines 68 to 71) have no test at all (review finding IN-04), and the plan tags this truth as a backstop, so presence plus wiring is not evidence. It needs a held-out test or an observed run."
human_verification:
  - test: "Backstop truth for sbx-rm: parallel run and failed entry delete (see behavior_unverified_items)"
    expected: "Folder untouched, entry kept until a good down, failed delete reports 'could not delete' and exits 1"
    why_human: "No test exercises the race or the failed-delete branch"
  - test: "Judgment-tier prohibition SCR-04: no host command starts Claude"
    expected: "No bin/ script launches claude; Claude starts only with sbx-claude inside the shell. Non-authoritative verdict from this verifier: holds (grep of bin/ finds only a comment and the image name). Human review recommended."
    why_human: "unverified-prohibition: judgment tier, an LLM-judge verdict is never authoritative"
  - test: "Judgment-tier prohibition SCR-06 (plan 05): nothing pushed, merged or opened for the code PR"
    expected: "feat/sbx-shell-list-rm is local only. Non-authoritative verdict: holds (no remote branch of that name is listed by git branch -a, upstream unset per the SUMMARY). Human review recommended."
    why_human: "unverified-prohibition: judgment tier; the remote state can only be confirmed on GitHub"
  - test: "Decide whether the open code-review warnings WR-01 to WR-05 block the code PR"
    expected: "A disposition (fixed, skipped or deferred) for each; none is a data-loss defect, but WR-04 (running sandbox removed after one warning line) bears directly on the goal wording 'without risking code, login, or history'"
    why_human: "Product judgment on a locked decision (D-09) that the review challenges"
---

# Phase 4: Jump-In and Sandbox Housekeeping Verification Report

**Phase Goal:** The user gets into any registered sandbox with one command, and can see and clean up their sandboxes without risking code, login, or history.
**Verified:** 2026-11-07
**Status:** human_needed
**Re-verification:** No, initial verification

## Goal Achievement

The goal is achieved on every observable criterion. Code exists, is substantive, is wired, and is proven by docker-free self-tests re-run in this verification plus a real-Docker Mac run (33 host checks, attended helper). One truth tagged `backstop` in plan 03 (the concurrency edge of `sbx-rm`) has no test behind it, so the status is `human_needed` and not `passed`. There is no BLOCKER.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC1: on a stopped sandbox the jump-in command starts it and opens bash in `/home/sandbox/workspace/<name>`; on a running one it only opens the shell | VERIFIED | `bin/sbx-shell` lines 26 to 36: `check_name`, `read_registry_entry`, `if ! sandbox_is_running; then bring_up_sandbox`, then `exec docker exec -it -w "/home/sandbox/workspace/$1" "sbx-$1" bash`. Self-test (re-run, 154 PASS, 0 FAIL): "a sandbox with no container is started, then the shell opens", "a stopped sandbox is started, then the shell opens", "a running sandbox gets the shell only", "the shell opens in the project folder". Mac: H-31 PASS in `host-test.log` (running sandbox not recreated, stopped one started again); helper line "the shell opened in the project folder" |
| 2 | SC2: `sbx-claude` in that shell starts Claude already logged in; no separate host command launches Claude | VERIFIED | `claude/bin/sbx-claude` exists; grep of `bin/` finds no launch of claude (one comment in `sbx-shell`, image name only elsewhere). Mac helper `/home/sandbox/h31m.log`: all five H-31 lines PASS, including `claude auth status shows "loggedIn": true` and "sbx-claude in a new sbx-shell shell started Claude already logged in" after a stop and a new `sbx-shell` |
| 3 | SC3: `sbx-list` shows all registered sandboxes with host path and running or stopped status, matching `docker ps -a` | VERIFIED | `bin/sbx-list`: one `docker ps -a --filter label=sbx.name --format '{{.Names}} {{.State}}'`, `status_word` maps running to running and everything else to stopped, `no container` when absent; `compose.yml` line 29 sets the `sbx.name` label and line 14 the container name `sbx-${SBX_NAME}`. Self-test group `sbx-list table` all PASS. Mac: "H-32 sbx-list showed no container, running and stopped as docker ps -a did, with the folder that has a space" |
| 4 | SC4: `sbx-rm` removes the container, optionally the registration; `<name>/` and `state/` are untouched; re-registering the same path brings back login and history | VERIFIED | `bin/sbx-rm`: `run_compose "$1" down` with no option, `rm -- "$entryFile"` only after the down, no read or write under `entryDir`. Self-tests: "compose down runs once ... with no option", "the files in the sandbox folder are unchanged", "--unregister deletes the entry after the down", "a failed down exits 1 and keeps the entry". Mac: "H-33 ... sbx-add of the same folder brought back state/claude and the history"; real-use pass `sbx-rm try-sbx --unregister` |
| 5 | `sbx-shell` refuses before any compose call or shell: wrong argument count (exit 2), bad or path name, unregistered name, missing `NAME/` or `state/`, missing image; failed `up` or a container that stops during start opens no shell; shell exit status is the script's exit status (the `exec`) | VERIFIED | Self-test groups `sbx-shell refusals`, `checks before compose`, `exit status and failed starts` all PASS (re-run). `open_shell` uses `exec` |
| 6 | Start steps are shared once: `bring_up_sandbox` and `runs_older_image` live in `bin/sbx-lib.sh`; `sbx-start` calls `bring_up_sandbox` and ends with `sbx-start: open a shell with: sbx-shell NAME`; a running sandbox on an older image is entered by `sbx-shell` unchanged and silently | VERIFIED | `bin/sbx-lib.sh` lines 270 to 288 (function bodies read); `bin/sbx-start` is 24 lines and calls `bring_up_sandbox "$1"`. Self-test "sbx-start: the closing hint names sbx-shell", "a running sandbox on an older image is entered as it is", "an older image prints no message". Mac H-28 and H-29 pass with the shared library |
| 7 | `sbx-list` contract: no argument; failed `docker ps` exits 1 and prints no table; broken entries are rows; empty registry message; exact-name match only (adjacency); byte-order rows; older-image mark and note; labelled containers with no entry listed, old `cc_` never | VERIFIED | Self-test groups `usage`, `docker failure`, `empty registry`, `broken entries`, `adjacent names`, `order`, `older image marker` all PASS (re-run). Header in `SANDBOX.md` line 208 equals `printf '%-31s %-20s %s'` output (checked byte for byte). Mac H-32: unregistered test container listed by label, no `cc_` container |
| 8 | `sbx-rm` contract: one plain `compose down` scoped to `sbx-NAME`; running sandbox warned then removed; `--unregister` before or after the name; usage exit 2; refusals before docker; second run exits 0; second `--unregister` refused; missing folder or image does not block | VERIFIED | Self-test groups `usage`, `refusals`, `running sandbox`, `stopped sandbox and no container`, `unregister`, `failed down`, `missing folder and image` all PASS (re-run). Mac H-33 PASS (volumes, images and other sandboxes kept; ran again with no container and with the folder moved) |
| 9 | `sbx-rm` backstop: interrupted or parallel runs never touch the folder and never delete the entry before a good down; a parallel delete losing the race reports 'could not delete' | PRESENT_BEHAVIOR_UNVERIFIED (insufficient_spec) | The sequential ordering is proven (see 8). The race and the failed-delete branch (`bin/sbx-rm` lines 68 to 71) are exercised by no self-test or host check (`grep -n 'could not delete\|race\|parallel'` over `tests/selftest/sbx/rm.sh` and `tests/host/h33-sbx-rm.sh` finds nothing); review finding IN-04 says the same. Plan tagged it `verification: backstop`, so it abstains pending a held-out test or an observed run. Human item below |
| 10 | Guard rule `host_scripts_keep_sandbox_data` is narrowed (broad for every `bin/` file but `sbx-rm`; narrow for `sbx-rm` with exactly one allowed `rm` line; a missing `bin/sbx-rm` fails) and the guard is still 19 rules | VERIFIED | `tests/guard/isolation.sh` lines 40 to 63 read. Guard re-run with rehearsal linters: 19 PASS lines, ends `All rules hold.`. Guard self-test ends `All cases pass.` with planted cases for a volume take-down, an image removal, a second operand, a delete of another path and a missing `sbx-rm` |
| 11 | `SANDBOX.md` teaches the three commands (Scripts table, Start, enter, stop, List sandboxes, Remove a sandbox, raw commands, troubleshooting, helper named); test docs name H-31 to H-33 and the seventh helper; `README.md`, `ClaudeCode/`, `OpenCode/` unchanged | VERIFIED | Section headings found at `SANDBOX.md` lines 48, 128, 201, 229, 406; line 171: "There is no command that starts Claude from the Mac"; `git diff origin/main feat/sbx-shell-list-rm` over `README.md ClaudeCode OpenCode compose.yml build.sh versions.env .dockerignore base claude .claude` is empty |
| 12 | Final gate and PR branch: all Linux suites green, `bin/sbx-shell`, `sbx-list`, `sbx-rm` are 100755, branch `feat/sbx-shell-list-rm` holds only code commits with the same code tree and no planning ID or attribution | VERIFIED | Entrypoint, guard and sbx self-tests each end `All cases pass.` (re-run here). `git ls-files -s bin` shows 100755 for all seven scripts and 100644 for `sbx-lib.sh`. `git diff HEAD feat/sbx-shell-list-rm -- . ':!.planning'` is empty; `git diff --name-only origin/main feat/sbx-shell-list-rm` lists 0 `.planning` paths; 11 commits (`main..feat/sbx-shell-list-rm`), commit bodies have no planning ID or attribution; planning-ID regex over the added lines prints nothing |
| 13 | Mac gate: `./host-test.sh --keep` ends `Summary: 33 passed, 0 failed, 0 not run` and every step OK; attended helper passes | VERIFIED (human-verified evidence) | `host-test.log` line 256 and the first run log both read `Summary: 33 passed, 0 failed, 0 not run`; steps `context`, `sbx self-test in the Mac shell`, `host checks`, `run folder`, `linter versions`, `pin digests`, `guard and self-tests in sbx-hosttest`, `guard in the Mac shell`, `build warnings` are OK. Both runs were made on commit `375f23b`, whose non-`.planning` tree equals HEAD and the PR branch (empty diff, checked). `h31m.log`: 5 of 5 PASS |

**Score:** 12/13 truths verified (1 present and wired, behavior unverified)

### Deferred Items

None. Later phases (5 and 7) do not claim any of the open points.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `bin/sbx-shell` | jump-in | VERIFIED | 36 lines, 100755, contains the required `exec docker exec -it -w ...` line, wired to the library |
| `bin/sbx-lib.sh` | `bring_up_sandbox`, `runs_older_image` shared | VERIFIED | functions present and called by `sbx-start`, `sbx-shell`, `sbx-list` |
| `bin/sbx-start` | start through `bring_up_sandbox`, hint line | VERIFIED | 24 lines |
| `bin/sbx-list` | list with status | VERIFIED | 175 lines, 100755 |
| `bin/sbx-rm` | removal | VERIFIED | 90 lines, 100755, exactly one `rm` line |
| `tests/guard/isolation.sh` | narrowed data rule | VERIFIED | |
| `tests/selftest/sbx/{shell,list,rm}.sh`, `lib.sh` | docker-free cases | VERIFIED | 154 PASS, 0 FAIL |
| `tests/host/h31-sbx-shell.sh`, `h32-sbx-list.sh`, `h33-sbx-rm.sh`, `manual/h31-jump-in.sh` | host checks and helper | VERIFIED | ran on the Mac, all PASS |
| `SANDBOX.md`, `tests/README.md`, `tests/host-checklist.md` | docs | VERIFIED | |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `bin/sbx-shell` | `bin/sbx-lib.sh` | `if ! sandbox_is_running "$1"; then bring_up_sandbox "$1"` | WIRED | lines 32 to 34 |
| `bin/sbx-start` | `bin/sbx-lib.sh` | `bring_up_sandbox "$1"` | WIRED | |
| `bring_up_sandbox` | `compose.yml` | `run_compose ... up -d --wait`, then `wait_until_ready` | WIRED | |
| `bin/sbx-list` | library and `compose.yml` | `runs_older_image`, `label=sbx.name` | WIRED | label set at `compose.yml` line 29 |
| `bin/sbx-rm` | library | `run_compose "$1" down` | WIRED | |
| `tests/guard/isolation.sh` | `bin/sbx-rm` | narrow check, one allowed line | WIRED | |
| `tests/host/run-all.sh` | h31, h32, h33 | chain list | WIRED | 33 checks ran on the Mac |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `bin/sbx-list` | `containerStateText` | `docker ps -a --filter label=sbx.name` | Yes (Mac H-32 compared rows to `docker ps -a`) | FLOWING |
| `bin/sbx-list` | `entryDir`, `entryPath` | registry files via `read_registry_entry` | Yes | FLOWING |
| `bin/sbx-rm` | `entryFile`, `entryDir` | registry entry | Yes | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| sbx self-test | `bash tests/selftest/sbx/run-all.sh` | 154 PASS, 0 FAIL, `All cases pass.` | PASS |
| guard self-test | `bash tests/selftest/guard/run-all.sh` | `All cases pass.` | PASS |
| entrypoint self-test | `bash tests/selftest/entrypoint/run-all.sh` | `All cases pass.` | PASS |
| guard with linters | `PATH="${TMPDIR:-/tmp}/sbx-linters/bin:$PATH" bash tests/guard/run-all.sh` | 19 PASS, `All rules hold.` | PASS |
| Real Docker | Mac `./host-test.sh --keep` (human-verified log) | 33 passed, 0 failed, 0 not run | PASS |

### Probe Execution

SKIPPED: the plans declare no `probe-*.sh` scripts; the equivalent runnable checks are the suites above.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|--------------|-------------|--------|----------|
| SCR-04 | 04-01, 04-04, 04-05 | One command jumps into a sandbox: starts it if needed, opens a shell; Claude from that shell with `sbx-claude` | SATISFIED | Truths 1, 2, 5, 6; H-31 and helper |
| SCR-05 | 04-02, 04-04, 04-05 | List all registered sandboxes with host path and running status | SATISFIED | Truths 3, 7; H-32 |
| SCR-06 | 04-03, 04-04, 04-05 | Remove a sandbox's container (and optionally its registration) without touching workspace or state | SATISFIED for the sequential path (truths 4, 8, 10); the concurrency edge is truth 9, awaiting human decision | H-33 |

All three IDs in the plan frontmatter appear in `REQUIREMENTS.md` (lines 64 to 66, mapped to Phase 4 at lines 154 to 156, marked Complete). `grep "Phase 4"` finds no other requirement, so there are no orphaned IDs.

### Prohibitions

| Prohibition | Tier | Verdict |
|-------------|------|---------|
| SCR-04: never recreate, restart or stop a running sandbox on entry | test | Enforced: self-test "a running sandbox gets the shell only", "an older image is entered as it is" |
| SCR-04: never open a shell in a container other than `sbx-NAME` of a registered, rule-passing name | test | Enforced: refusal cases (unregistered, path, uppercase) |
| SCR-04: no host command starts Claude | judgment | Non-authoritative verdict: holds. unverified-prohibition, human review recommended |
| SCR-04: self-test never reaches the Mac's Docker; H-31 never touches real `~/.config/sbx` | test | Enforced: "no case reached the refusing docker" in each group; host checks use a per-check registry under the run folder (INFO lines in `host-test.log`) |
| SCR-05: never show stopped or no container when Docker could not be asked | test | Enforced: "a failed docker ps exits 1 and prints no table" |
| SCR-05: only reads | test | Enforced: "the registry is unchanged", no compose, exec or rm in `sbx-list` (guard) |
| SCR-05: never list or act on `cc_` containers | test | Enforced by the label filter; H-32 asserts no `cc_` line |
| SCR-06: nothing under `SBX_DIR` read, written or deleted | test | Enforced: "the files in the sandbox folder are unchanged", H-33 |
| SCR-06: no volumes or images removed, no other project taken down | test | Enforced: no-option `down` case, guard planted cases, H-33 |
| SCR-06: entry deleted only after a good down, nothing else deleted | test | Enforced: "a failed down exits 1 and keeps the entry", one-line `rm` guard. Race edge: see truth 9 |
| SCR-06: other `bin/` scripts never delete or take down | test | Enforced: broad guard rule, planted case "the word rm in sbx-list" |
| SCR-06 (plan 04): README and old layout unchanged; no volume or image removal documented | test | Enforced: empty diff; `old_layout_untouched` PASS |
| SCR-06 (plan 05): never push, merge or open the PR | judgment | Non-authoritative verdict: holds (branch absent from remotes). unverified-prohibition, human review recommended |
| SCR-04 (plan 05): no `.planning` file on the code branch, no planning ID or attribution | test | Enforced: 0 `.planning` paths, regex scan empty, commit bodies clean |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (phase files) | | TBD, FIXME, XXX, TODO, HACK | None found | grep over `bin/`, the new host checks and the new self-test files is empty |
| (added lines) | | em or en dash, ASCII `--` as punctuation | None found | all `--` hits are literal code such as `rm --` and `grep -qxF --` |

Open code-review findings (04-REVIEW.md, 0 critical, 5 warning, 5 info, all dispositions `open`). None makes a must-have false; each is recorded here as a WARNING for the user to triage.

| Finding | Severity here | Note |
|---------|---------------|------|
| WR-01 H-31 greps for `TTY` only | WARNING | Test brittleness: a Docker that says `stdin is not a terminal` would give a false FAIL and turn H-32, H-33, H-20, H-10 into NOT RUN. Passes today on Docker 28.5.1 |
| WR-02 `sbx-rm` refuses entries `sbx-list` calls broken | WARNING | Edge outside the four success criteria (relative `SBX_DIR`, non-claude agent). The cleanup command fails on the cases that most need cleanup; the user falls back to a hand `rm` |
| WR-03 missing-image message when Docker is not running | WARNING | Misleading advice on the most likely daily failure; goal still met |
| WR-04 `sbx-rm` removes a running sandbox after one warning, default 10 s stop timeout | WARNING | Locked decision D-09. Disk contents are not lost by `down`, but an in-flight write under `state/` or the project folder at the SIGKILL could be cut. Bears on the goal wording; user decision |
| WR-05 H-33 snapshots can pass vacuously on a Docker error | WARNING | Weakens the "volumes and other sandboxes untouched" claim in H-33, though the self-test and the guard also cover it |
| IN-01 to IN-05 | INFO | Guard holes, label versus name lookup, H-33 folder move without trap, untested failed-delete branch (the cause of truth 9), warning on stdout |

### Human Verification Required

#### 1. sbx-rm concurrency and failed-delete edge (truth 9)

**Test:** Against a scratch registry, run `sbx-rm NAME --unregister` twice at once; separately make `~/.config/sbx/sandboxes` read-only and run it once.
**Expected:** The sandbox folder is never touched; the entry goes only after a good down; the losing or read-only run exits 1 with "could not delete ... the container is gone" and prints no "deleted the registry entry" line; a rerun finishes the job.
**Why human:** No test exercises these branches. Cheapest closure: add the read-only case suggested in IN-04 to `tests/selftest/sbx/rm.sh` (skipped as root), which turns the truth into VERIFIED without a human run.

#### 2. Judgment-tier prohibitions (SCR-04 no host Claude launcher; SCR-06 no push or merge)

**Test:** Skim `bin/` for any launcher of Claude; confirm on GitHub that `feat/sbx-shell-list-rm` is not pushed.
**Expected:** Neither exists.
**Why human:** Judgment tier. This report's verdicts (both hold) are non-authoritative and flagged `unverified-prohibition`.

#### 3. Triage of the five open review warnings

**Test:** Decide for WR-01 to WR-05 whether to fix before the code PR, skip, or defer.
**Expected:** A recorded disposition in `04-REVIEW-DISPOSITION.md`. In particular, decide whether D-09 (no prompt for a running sandbox) still stands given WR-04.
**Why human:** Product judgment, not verifiable from code.

### Gaps Summary

No gaps. All four roadmap success criteria, all three requirement IDs and the plan-level truths are met in code and, for Docker behavior, by the user's Mac run (33 passed, 0 failed, 0 not run, plus the attended helper with all five lines PASS). The Linux suites were re-run here and pass (154 sbx cases, guard and entrypoint self-tests, 19 guard rules). The status is `human_needed` solely because of one backstop-tagged truth with no test (the `sbx-rm` concurrency edge), the two flagged judgment-tier prohibitions, and the open review warnings that need a disposition.

---

_Verified: 2026-11-07_
_Verifier: Claude (gsd-verifier)_
