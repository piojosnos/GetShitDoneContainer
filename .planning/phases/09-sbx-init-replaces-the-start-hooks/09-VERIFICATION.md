---
phase: 09-sbx-init-replaces-the-start-hooks
verified: 2026-11-16T21:00:00Z
status: human_needed
score: 5/5 must-haves verified
covered_files:
  - base/Dockerfile
  - base/init/best_practices_link.py
  - base/init/gsd_sync.py
  - base/init/init_runner.py
  - base/init/steps/800_state_owner.py
  - claude/Dockerfile
  - claude/bin/sbx-claude
  - compose.yml
  - cursor/Dockerfile
  - cursor/bin/sbx-cursor
  - tests/guard/start.sh
covered_digest: "v2:sha256:09fa073d85775bee2d0fb23bcfe580a0403858283aa310a17d7ec02fb0546aba"
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "On the Mac, run sbx-init, then sbx-claude, and ask Claude to run `command -v claude` and `bash -lc 'command -v claude'` through its Bash tool (or run `bash -lc 'command -v claude'` in a shell whose PATH was prefixed with /opt/sbx/agents/bin by the wrapper). Repeat for Cursor with cursor-agent."
    expected: "Both print /opt/sbx/agents/bin/claude (or cursor-agent). A tool Claude starts, such as /gsd-review, finds the CLI."
    why_human: "Review finding WR-02. Ubuntu's /etc/profile resets PATH for a non-root login shell (base/Dockerfile:97 already records that a login shell may reset PATH), and Claude Code runs its Bash tool through a login shell. No test or host check runs a login shell after the wrapper sets PATH; H-27 only checks `command -v claude` in a plain shell. Needs a real Claude session on the Mac. If PATH is reset, README.md:193 is wrong and /gsd-review loses claude; the review's fix (a marker variable plus a /etc/profile.d re-add) applies."
gaps: []
---

# Phase 9: sbx-init replaces the start hooks Verification Report

**Phase Goal:** A container start only keeps the container alive. The user runs `sbx-init` to sync GSD and link the bundle and sees each step's result, so no entrypoint, hook, poll or wait sits between `up` and a usable shell.
**Verified:** 2026-11-16
**Status:** human_needed (all five success criteria hold in code and in the Mac gate; one review finding about the agent PATH inside Claude's own shell needs a Mac check)
**Re-verification:** No, initial verification

## Goal Achievement

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | In a fresh sandbox `sbx-init` syncs GSD, links the bundle, prints each step OK or FAIL; a rerun gives the same result; a run while another holds the lock stops without touching anything | VERIFIED | `base/init/init_runner.py`: `_run_steps` prints `OK:` or `FAIL:` plus a `fix:` line per step and stops at the first FAIL; `_take_lock` takes a non-blocking `flock`, a held lock prints `FAIL: lock: another sbx-init is running` and returns before the marker is touched. Steps: shared `010_state_folders`, `800_state_owner`; agent `050_gsd_sync`, `900_best_practices_links` (Cursor adds `060_self_update_off`). pytest: `test_two_runs_in_a_row_print_the_same_lines_and_both_exit_zero`, `test_a_rerun_runs_every_step_again`, `test_a_run_started_while_another_process_holds_the_lock_changes_nothing`, `test_the_lock_is_free_again_after_a_run_in_the_same_process` (422 passed here). Mac: H-34 "Claude 4 steps passed, Cursor 5 steps passed"; H-35 "a second sbx-init was refused while one held the lock and changed nothing"; H-27 GSD synced offline at the pinned version. |
| 2 | A container start runs no hooks and no entrypoint; the container only sleeps; entrypoint, start-hook runner, `start.d/`, readiness poll, their guard rules and the entrypoint self-test are gone | VERIFIED | `compose.yml`: `init: true`, `command: ["sleep", "infinity"]`, no `entrypoint:`. `grep -rn ENTRYPOINT base claude cursor compose.yml` finds none in a Dockerfile or compose. `git diff main...HEAD` shows `base/sbx-entrypoint`, `base/sbx-start-lib.sh`, `base/bin/sbx-link-bundle`, `claude/start.d/*`, `cursor/start.d/*`, `tests/selftest/entrypoint/*`, H-12, H-17, H-20 deleted; `find` shows no `start.d`, `sbx-entrypoint` or `sbx-start-lib*` in the tree; only `tests/selftest/init/test_init_inventory.py` names them, in `not in` assertions. `bin/sbx-lib.sh` `bring_up_sandbox` runs `up -d --wait` (Compose's own running-state wait, no project poll); the poll was removed in 0f71504. New guard rule `container_runs_no_entrypoint` in `tests/guard/start.sh` asserts the three properties; old hook guard rules are gone from the file. Mac: H-28 asserts `Config.Entrypoint` null; guard passes in sandbox and Mac shell. |
| 3 | `sbx-claude` and `sbx-cursor` fail at once when init has not run, neither waiting nor running init; `claude` and `cursor-agent` are not on a plain PATH | VERIFIED | `claude/bin/sbx-claude` (and the symmetric `cursor/bin/sbx-cursor`): `[ ! -f "$initMarker" ]` -> stderr "run sbx-init first", `exit 1`, before any PATH change or `exec`. Marker `/home/sandbox/.sbx-init-done` is in the container's own home layer, so a recreate drops it; the runner removes it before running steps and writes it only after every step passed. `claude/Dockerfile` links the CLI into `/opt/sbx/agents/bin`, `rm /usr/local/bin/claude`, and the build smoke test asserts `! command -v claude`; cursor mirrors it; guard rule `agents_stay_off_the_path` asserts both and forbids a `/usr/local/bin` link. pytest: `test_without_the_marker_the_wrapper_refuses_at_once_and_never_starts_the_agent`, `test_a_marker_that_is_a_folder_counts_as_missing`, `test_the_wrapper_holds_no_sleep_warning_or_clone_test`. Mac: H-27 "sbx-claude refused before sbx-init and claude is off the plain PATH ... Claude started after init". |
| 4 | A user skill with the same name as a bundle skill survives `sbx-init`, which reports the clash as a FAIL; init removes only its own links into the bundle | VERIFIED | `base/init/best_practices_link.py`: `_place_link` creates or replaces only when the entry is absent or `is_best_practices_link(entry, own_root)`; otherwise it appends to `clash_list` and leaves it. The only deletion calls are `Path.unlink` on an own link (`_place_link`, `_remove_stale_links`). No `rmtree`, no list file. pytest: `test_a_user_folder_with_a_clone_skill_name_is_left_named_and_the_rest_is_linked`, `test_a_real_rules_folder_is_left_named...`, `test_a_copy_of_a_clone_skill_is_left_and_named`, `test_a_link_outside_the_clone_is_left_and_named`, `test_a_user_skill_the_clone_does_not_have_is_untouched`, `test_a_dangling_own_link_for_a_dropped_skill_is_removed`. Mac: H-16 "a skill folder and a rules folder of your own were kept and reported, and sbx-init relinked once they were moved aside; kept your skills, memories, sessions, settings". |
| 5 | After `sbx-init` on the Mac every file in `state/claude` is owned by `sandbox`; `./host-test.sh` passes | VERIFIED | `base/init/steps/800_state_owner.py` scans with the shared `root_owned_scan` (lstat, skips only `cache/npm`, `cache/uv`, `m2`, so `state/claude` is covered), `os.lchown` back to the sandbox uid/gid, repeats up to 3 rounds, fails if anything stays root-owned. pytest: `test_the_owner_change_is_made_on_every_path_and_each_one_is_counted`, `test_a_link_to_a_folder_outside_the_tree_is_changed_as_a_link...`, `test_a_path_still_owned_after_three_rounds_fails_naming_it`. Mac `host-test.log`: "H-35 OK: state-owner: 314 paths given back to sandbox ... left no root-owned state outside the caches"; "Summary: 17 passed, 0 failed, 0 not run"; "0 step(s) failed". |

**Score:** 5/5 truths verified (0 present, behavior-unverified). The two behavior-dependent truths (lock, ownership give-back) have both a pytest case and a Mac host check that exercise the behavior.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `base/init/sbx-init`, `init_runner.py` | launcher and runner | VERIFIED | Substantive (marker, lock, step loading, fail-closed on no agent steps); installed and linked in `base/Dockerfile:246-258`; `sbx-init` on `/usr/local/bin` |
| `base/init/steps/010_state_folders.py`, `800_state_owner.py` | shared steps | VERIFIED | `STEP_LIST` present, covered by init and selfcheck tests |
| `claude/init/050_gsd_sync.py`, `900_best_practices_links.py`; `cursor/init/050_gsd_sync.py`, `060_self_update_off.py`, `900_best_practices_links.py` | agent steps | VERIFIED | Each defines `STEP_LIST`; Mac init ran 4 (Claude) and 5 (Cursor) steps |
| `claude/bin/sbx-claude`, `cursor/bin/sbx-cursor` | marker-gated wrappers | VERIFIED | Wired to `/opt/sbx/agents/bin` and the marker path equal to `paths.INIT_MARKER_FILE` (pytest `test_the_default_marker_and_agents_folder_equal_the_python_paths`) |
| `base/selfcheck/checks/035_init_marker.py`, `claude-off-path`, `cursor-off-path` | self-check of the new state | VERIFIED | Mac: 55 and 53 self-checks, 0 failed |
| `tests/host/h35-init-owner-and-lock.sh`, rewritten H-16, H-27, H-34 | Docker-only behavior | VERIFIED | PASS in `host-test.log` |
| Deleted start path (entrypoint, start lib, `start.d`, bash linker, entrypoint self-test) | gone | VERIFIED | Absent from the tree |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `bin/sbx-start` / `bring_up_sandbox` | user | prints "run sbx-init there before the agent"; no init run, no poll | WIRED |
| `sbx-bundle-clone` | `sbx-init` | ends in `sbx-init` (09-06; H-27 "its sbx-init passed with 4 steps") | WIRED |
| Runner | agent steps | `/etc/sbx/init.d/<agent>/*.py`; missing folder is one FAIL (`test_a_missing_agent_folder_prints_only_the_agent_steps_failure`) | WIRED |
| Runner marker | wrappers | `/home/sandbox/.sbx-init-done` written last, removed first | WIRED |
| `compose_up` / H-34 | `sbx-init` before self-check | 09-10 | WIRED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| init, selfcheck and wrapper suites | `uv run pytest -q` | 422 passed | PASS |
| Guard rules (no entrypoint, agents off PATH, pins, lint) | `bash tests/guard/run-all.sh` | "All rules hold." | PASS |
| sbx self-test | `bash tests/selftest/sbx/run-all.sh` | "All cases pass." | PASS |
| Docker-only behavior | Mac `./host-test.sh` (host-test.log) | 17 passed, 0 failed; H-16, H-27, H-34, H-35 PASS; images unchanged per init-gate.log | PASS (accepted as human verification per the task) |

### Probe Execution

No phase-declared probe scripts. Step skipped.

### Requirements Coverage

All six IDs appear in PLAN frontmatter and in REQUIREMENTS.md; none is orphaned.

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| INIT-01 | 09-01, 09-02, 09-07, 09-11, 09-12, 09-13 | `sbx-init` creates state folders, syncs GSD, links bundle, prints OK/FAIL per step | SATISFIED | Truth 1; runner and steps; H-34 |
| INIT-02 | 09-01, 09-10, 09-11, 09-13 | Rerun redoes every step, same result; lock stops overlap | SATISFIED | Truth 1; pytest rerun and lock tests; H-35. See WR-01 for an interruption edge case |
| INIT-03 | 09-07, 09-08, 09-09, 09-10, 09-12, 09-13 | No hooks, no entrypoint; container only sleeps; poll, guards, self-test gone | SATISFIED | Truth 2 |
| INIT-04 | 09-05, 09-06, 09-07, 09-11, 09-12, 09-13 | Agents off PATH; wrappers fail at once without init | SATISFIED | Truth 3 |
| INIT-05 | 09-04, 09-11, 09-13 | Init never deletes a same-named user skill; touches only own links | SATISFIED | Truth 4 |
| INIT-06 | 09-03, 09-11, 09-13 | Files in `state/claude` owned by `sandbox` after init | SATISFIED | Truth 5 |

### Anti-Patterns Found

None blocking. No `TBD`, `FIXME` or `XXX` in `base/init`, `base/bin`, `bin`, `claude/bin`, `cursor/bin`, `claude/init`, `cursor/init`. `.claude/CLAUDE.md` still describes the entrypoint; intentionally stale (separate PR), not counted.

### Code Review Findings (09-REVIEW.md, 0 critical, 3 warning, 5 info, all `open`)

| ID | Threatens the goal or a requirement? | Assessment |
|----|--------------------------------------|------------|
| WR-02 | Not a stated requirement, but it threatens a documented promise (README.md:193) | Listed under human_verification above. Wrapper PATH prefix may not survive Claude's login shell. INIT-04 itself (off the plain PATH, refuse before init) is met and proven on the Mac. |
| WR-01 | No requirement fails; edge case of INIT-02 | Confirmed in code: `_wait_or_stop` (`base/init/gsd_sync.py`) catches only `TimeoutExpired`. The installer runs in its own session (`start_new_session=True`), so after Ctrl-C or a closed terminal the lock is released but the installer keeps running, and a rerun can overlap it. The normal paths (overlapping second run, timeout) hold. Recommend a follow-up fix (kill the group on `BaseException`) and a test; not a phase blocker. |
| WR-03 | No | Dead-end fix hint when the clone folder exists but lacks `rules/` or `skills/`; the step still fails closed (no marker), so INIT-04 is not weakened. Follow-up. |
| IN-01 to IN-05 | No | Polish: hidden clash when an I/O problem is also reported, handle leak on a non-EWOULDBLOCK `flock` error, hard-coded `/home/sandbox` in hints, test-only env overrides in shipped wrappers, unused `_place_link` return. |

### Human Verification Required

#### 1. Agent PATH inside the agent's own Bash tool (WR-02)

**Test:** On the Mac, after `sbx-init`, start `sbx-claude`; in Claude run `command -v claude` and `bash -lc 'command -v claude'` (then the Cursor equivalents with `sbx-cursor`).
**Expected:** The agents folder is on PATH for the agent's child shells, so `/gsd-review` finds `claude` and `cursor-agent`.
**Why human:** Needs a live agent session; no automated test runs a login shell after the wrapper sets PATH. If it fails, the phase goal (a usable setup with agents only through wrappers) still holds for the user's own shell, but README.md:193 and `/gsd-review` need the review's fix.

### Gaps Summary

No gaps. Every success criterion and all six requirements are met by code in the repo, the project suites run here (422 pytest, guard, sbx self-test) and the Mac gate. The status is `human_needed` only because the unverified WR-02 PATH question needs one Mac check. WR-01 and WR-03 are recommended follow-ups, not blockers.

---

_Verified: 2026-11-16T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
