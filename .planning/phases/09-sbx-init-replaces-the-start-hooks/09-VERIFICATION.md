---
phase: 09-sbx-init-replaces-the-start-hooks
verified: 2026-11-17T06:00:00Z
status: passed
score: 5/5 must-haves verified
covered_files:
  - base/Dockerfile
  - base/init/best_practices_link.py
  - base/init/gsd_sync.py
  - base/init/init_runner.py
  - base/init/steps/800_state_owner.py
  - base/selfcheck/bundle_links.py
  - claude/Dockerfile
  - claude/bin/sbx-claude
  - compose.yml
  - cursor/Dockerfile
  - cursor/bin/sbx-cursor
  - tests/guard/start.sh
  - tests/host/h27-bundle-clone-and-publish.sh
  - tests/host/h34-selfcheck.sh
covered_digest: "v2:sha256:b608dacfa123e1c046c05f49815b4581fe74e258acb0698eae6b411e4f68d788"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 5/5
  gaps_closed:
    - "WR-02: agent PATH inside a login shell started by an agent session (now automated by H-27 and H-34, passed on the Mac)"
    - "WR-01: interrupted sbx-init leaves the GSD installer running after the lock is released"
    - "WR-03: dead-end fix when the clone folder exists but is incomplete"
  gaps_remaining: []
  regressions: []
gaps: []
---

# Phase 9: sbx-init replaces the start hooks Verification Report

**Phase Goal:** A container start only keeps the container alive. The user runs `sbx-init` to sync GSD and link the bundle and sees each step's result, so no entrypoint, hook, poll or wait sits between `up` and a usable shell.
**Verified:** 2026-11-17
**Status:** passed
**Re-verification:** Yes, after gap closure plan 09-14 (HEAD ecaf70d; no code changed since 8b74b76, only `.planning/` files)

## Goal Achievement

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `sbx-init` syncs GSD, links the bundle, prints OK or FAIL per step; a rerun gives the same result; a run while another holds the lock stops without touching anything | VERIFIED (regression check) | Runner, lock and steps unchanged from the earlier full verification. 09-14 additionally hardened the interruption path: `base/init/gsd_sync.py` `_run_installer` wraps the wait in `except BaseException`, kills the installer's process group (`os.killpg`, installer runs `start_new_session=True`) and removes its log in a `finally` before re-raising; `base/init/init_runner.py` `main` installs `signal.default_int_handler` for SIGHUP and SIGTERM, catches `KeyboardInterrupt` after `run_init`'s lock `finally` has run, prints `sbx-init: interrupted; run sbx-init again` and returns 130. Test run here: `test_an_interrupted_run_stops_the_installer_and_its_child_drops_the_log_and_frees_the_lock` for SIGINT, SIGHUP and SIGTERM goes through the real launcher, step and a sleeping installer with a child; asserts exit 130, last stderr line, installer and grandchild gone, no marker, lock free. Mac: H-34 "Claude 4 steps passed, Cursor 5 steps passed", H-35 lock refusal, H-27 GSD synced at the pinned version. |
| 2 | A container start runs no hooks and no entrypoint; the container only sleeps; entrypoint, hook runner, `start.d/`, readiness poll, guard rules and entrypoint self-test are gone | VERIFIED (regression check) | `compose.yml` unchanged since the earlier verification (`init: true`, `command: ["sleep","infinity"]`, no `entrypoint:`); `git diff b444151..HEAD` over Dockerfiles, compose, guard, wrappers is empty. Guard rule `container_runs_no_entrypoint` still passes (guard: "All rules hold."). Mac H-28 asserts a null `Config.Entrypoint`. |
| 3 | `sbx-claude` and `sbx-cursor` fail at once when init has not run; `claude` and `cursor-agent` are not on a plain PATH | VERIFIED | Wrappers and Dockerfiles unchanged. Mac H-27: "sbx-claude refused before sbx-init and claude is off the plain PATH ... Claude started after init". New in 09-14, also on the real images: H-27 runs a stand-in agent through the real wrapper (`SBX_AGENT_BIN_DIR`) that rebuilds the wrapper's PATH and starts `bash -lc 'command -v claude'`, and requires exactly `/opt/sbx/agents/bin/claude`; then a plain `bash -lc` must find nothing. H-34 does the same for `cursor-agent` through `sbx-cursor`, with exit-code and empty-output assertions on the plain shell. The Mac log shows both passed. |
| 4 | A user skill with the same name as a bundle skill survives `sbx-init`, which reports the clash as a FAIL; init removes only its own links | VERIFIED | `_place_link` logic unchanged. 09-14 added `incomplete_clone_result` in `base/selfcheck/bundle_links.py`, called from both `base/init/best_practices_link.py` and `bundle_links_result`, so init and the self-check print one text; the incomplete-clone FAIL fix says `git -C PATH pull` then `sbx-init`, or move aside then `sbx-gh-login` and `sbx-bundle-clone`, never delete. A path with nothing at it keeps the "no best-practices clone" fix. Init touches nothing in the config folder in that case. pytest in `tests/selftest/init/test_init_best_practices_link.py` and `tests/selftest/selfcheck/test_bundle_links.py` pass. Mac H-16 passed. |
| 5 | After `sbx-init` on the Mac every file in `state/claude` is owned by `sandbox`; `./host-test.sh` passes | VERIFIED | `800_state_owner.py` unchanged. `host-test.log` (branch `feat/sbx-init`, commit 8b74b76, code identical to HEAD): "Summary: 17 passed, 0 failed, 0 not run", "0 step(s) failed", "All rules hold." twice; H-35 state-owner and lock lines present. `init-gap-gate.log`: sbx-base, sbx-claude and sbx-cursor `:local` image IDs identical before and after. |

**Score:** 5/5 truths verified (0 present, behavior-unverified).

### Plan 09-14 must-haves

| Must-have | Status | Evidence |
|-----------|--------|----------|
| Interruption kills the installer group before the lock releases, log removed, no marker, exit 130 with one stderr line | VERIFIED | Code above plus the three-signal pytest case, which passes (9 interruption and incomplete-clone cases passed in a targeted run; full suite 432 passed) |
| Absent versus incomplete clone path give two FAILs and two fixes, same text in init and self-check | VERIFIED | `incomplete_clone_result` shared by both callers |
| WR-02 tested, not fixed: wrappers, Dockerfiles, guard, login files unchanged | VERIFIED | `git diff b444151..HEAD` over `claude/bin cursor/bin *Dockerfile tests/guard compose.yml .claude base/profile.d` is empty |
| Counts unchanged (55 and 53 self-checks, 4 and 5 steps, 20 guard rules, 17 host checks) | VERIFIED | Mac log INFO lines and "17 passed"; guard passes |
| Mac: H-27 and H-34 login-shell PASS lines; `Summary: 17 passed` and `0 step(s) failed`; image IDs unchanged | VERIFIED | `host-test.log` lines 212, 220, 239, 330; `init-gap-gate.log`. This is automated Mac evidence, not a pending human item |
| Prohibitions (no edit to wrappers, Dockerfiles, guard, CLAUDE.md; IN-01..IN-05 untouched; no logs or `.planning/` mixed into code commits) | VERIFIED | Diff above is empty for those paths; the log files are untracked in git status |

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `base/init/gsd_sync.py` (`except BaseException`, `_kill_group`, log `unlink`) | VERIFIED | Substantive and wired through the GSD step |
| `base/init/init_runner.py` (`default_int_handler`, 130) | VERIFIED | Wired in `main`, launcher `base/init/sbx-init` documents exit 130 |
| `base/selfcheck/bundle_links.py` `incomplete_clone_result` | VERIFIED | Two callers |
| `tests/selftest/init/test_init_launcher.py` interruption test | VERIFIED | Real subprocess, three signals, passes |
| `tests/host/h27-bundle-clone-and-publish.sh` (`sessionlogin`, plain login check), `tests/host/h34-selfcheck.sh` (`check_cursor_login_shells`) | VERIFIED | Substantive assertions; passed on the Mac |
| All earlier phase artifacts (init runner, steps, wrappers, deletions, selfchecks, H-35) | VERIFIED | Unchanged since the earlier full verification; suites and Mac run green |

### Key Link Verification

| From | To | Status |
|------|----|--------|
| `init_runner.main` signal handlers | `_run_installer` BaseException branch, then `run_init` lock `finally` | WIRED |
| `best_practices_link.py` and `bundle_links_result` | `incomplete_clone_result` | WIRED |
| H-27 / H-34 | real `sbx-claude` / `sbx-cursor` wrappers via `SBX_AGENT_BIN_DIR` | WIRED |
| All earlier links (runner to marker to wrappers, `sbx-bundle-clone` to `sbx-init`, compose to sleep) | | WIRED (unchanged) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Python suites | `uv run pytest -q` | 432 passed | PASS |
| Interruption and incomplete-clone cases | `uv run pytest -q tests/selftest/init -k "interrupted or incomplete or exists_but"` | 9 passed | PASS |
| Guard | `bash tests/guard/run-all.sh` | "All rules hold." | PASS |
| sbx self-test | `bash tests/selftest/sbx/run-all.sh` | "All cases pass." | PASS |
| Docker-only behavior | Mac `./host-test.sh` at 8b74b76 | 17 passed, 0 failed, 0 not run | PASS |

### Probe Execution

No phase-declared probe scripts. Skipped.

### Requirements Coverage

| Requirement | Source Plans | Status | Evidence |
|-------------|--------------|--------|----------|
| INIT-01 | 09-01, 09-02, 09-07, 09-11, 09-12, 09-13 | SATISFIED | Truth 1 |
| INIT-02 | 09-01, 09-10, 09-11, 09-13, 09-14 | SATISFIED | Truth 1; interruption edge case now closed |
| INIT-03 | 09-07, 09-08, 09-09, 09-10, 09-12, 09-13 | SATISFIED | Truth 2 |
| INIT-04 | 09-05, 09-06, 09-07, 09-11, 09-12, 09-13, 09-14 | SATISFIED | Truth 3, including login shells inside agent sessions |
| INIT-05 | 09-04, 09-11, 09-13, 09-14 | SATISFIED | Truth 4 |
| INIT-06 | 09-03, 09-11, 09-13 | SATISFIED | Truth 5 |

All six IDs are in REQUIREMENTS.md (checked, mapped to Phase 9) and claimed by plans; none is orphaned.

### Anti-Patterns Found

No `TBD`, `FIXME` or `XXX` markers in files this phase touched (the only grep hit is the `XXXXXX` mktemp template in `tests/host/lib.sh`, not a marker). No stub patterns in the 09-14 code. `.claude/CLAUDE.md` is intentionally stale (separate PR), not counted.

### Code Review Findings

WR-01, WR-02 and WR-03 are fixed (WR-02 by test, no code change needed). IN-01 to IN-05 remain open info items (hidden clash on I/O problem, `flock` handle leak on a non-EWOULDBLOCK error, hard-coded `/home/sandbox` in hints, test-only env overrides in the wrappers, unused `_place_link` return); none threatens a success criterion or requirement, and the plan prohibits changing them.

### Human Verification Required

None. The earlier WR-02 item is settled by the passed Mac run of H-27 and H-34 (automated evidence). UAT test 1, skipped by the user, is covered by those checks.

### Gaps Summary

No gaps. All five roadmap success criteria and all six requirements hold in the code on `feat/sbx-init`; the project suites pass here (432 pytest, guard, sbx self-test) and the Mac gate passed at the same code state.

---

_Verified: 2026-11-17T06:00:00Z_
_Verifier: Claude (gsd-verifier)_
