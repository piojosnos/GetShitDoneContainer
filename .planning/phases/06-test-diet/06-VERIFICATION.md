---
phase: 06-test-diet
verified: 2026-11-13T19:00:00Z
status: passed
score: 5/5 must-haves verified
covered_files:
  - .planning/phases/06-test-diet/06-01-PLAN.md
  - .planning/phases/06-test-diet/06-01-SUMMARY.md
  - .planning/phases/06-test-diet/06-02-PLAN.md
  - .planning/phases/06-test-diet/06-02-SUMMARY.md
  - .planning/phases/06-test-diet/06-03-PLAN.md
  - .planning/phases/06-test-diet/06-03-SUMMARY.md
  - .planning/phases/06-test-diet/06-04-PLAN.md
  - .planning/phases/06-test-diet/06-04-SUMMARY.md
  - .planning/phases/06-test-diet/06-05-PLAN.md
  - .planning/phases/06-test-diet/06-05-SUMMARY.md
  - .planning/phases/06-test-diet/06-06-PLAN.md
  - .planning/phases/06-test-diet/06-06-SUMMARY.md
  - host-test.sh
  - tests/guard/isolation.sh
  - tests/guard/start.sh
  - tests/guard/supply-chain.sh
  - tests/host/h09-rebuild-keeps-files-no-volumes.sh
  - tests/host/h13-env-and-no-self-update.sh
  - tests/host/h28-sbx-add-start-stop.sh
  - tests/host/h29-sbx-upgrade.sh
  - tests/host/lib-login.sh
  - tests/host/run-all.sh
  - tests/selftest/sbx/lib.sh
covered_digest: "v2:sha256:b139e5c42dbd1790c23a9db63ca8f12fb0912d3cd9b0a5604a980de9553a25e5"
behavior_unverified: 0
overrides_applied: 0
---

# Phase 6: Test diet Verification Report

**Phase Goal:** The test suite checks only our own setup and runs with nobody at the keyboard; manual helpers, checks of Claude/GSD/Docker/Maven Central behaviour, the guard self-test and every stand-in docker are deleted, with simple proxies in their place. Deletions only.
**Verified:** 2026-11-13
**Status:** passed
**Re-verification:** No, initial verification

## Observable Truths

| # | Truth (ROADMAP success criterion) | Status | Evidence |
|---|-----------------------------------|--------|----------|
| 1 | `tests/host/manual/`, `fake-claude-api.js`, `tests/selftest/guard/`, `start-library.sh` and both stand-in dockers are gone; sbx refusal cases run with `DOCKER_HOST` pointing nowhere | VERIFIED | All four paths absent (`ls` errors). `find` for files named `docker`, `fake-*` finds only `tests/selftest/entrypoint/support/fake-gsd` (a GSD stand-in, not docker). `tests/selftest/sbx/lib.sh:29` sets `DOCKER_HOST=unix:///nonexistent` and unsets `DOCKER_CONTEXT`; no `fence` or scripted-docker code remains. Main had `make_scripted_docker` and the `fence/docker` writer in the same file; both are gone. |
| 2 | No host check drives Claude or checks Claude/GSD/Docker/Maven behaviour; H-02, H-18, H-21, H-24 gone; H-00 one preflight line; H-11 in H-28; H-13/15/16/23 trimmed | VERIFIED | `h00`, `h02`, `h11`, `h18`, `h21`, `h24` scripts are deleted vs main. Preflight is `check_docker_reachable` in `tests/host/run-all.sh:179` (one `docker info` test). H-28 holds the start-hook wait (`pgrep -x sleep`, the old H-11 proof). H-13 keeps only env vars and "no self-installed Claude"; H-23 has no Maven/download code; H-15 and H-16 read only our links and files. |
| 3 | A host check plants a fake credentials file and a fake session file; both survive recreate and `sbx-upgrade`; same run shows `DISABLE_UPDATES`, managed settings, bundle links | VERIFIED | `tests/host/lib-login.sh` plants `.credentials.json` and a session jsonl, and `check_login_files` fails on missing, empty or changed content. Called in H-09 (plant at line 41, check at 82) and H-29 (107, 185). H-13 asserts `DISABLE_UPDATES=1` (line 34); H-14 reads the managed settings; H-15 checks bundle links. The Mac log at commit 2f05426 shows PASS for H-09 ("fake credentials file and session file survived the rebuild"), H-29 ("kept ... the fake credentials and session files"), H-13, H-14 and H-15. |
| 4 | Guard asserts managed deny entries and the one-FROM rule; no `sbx-rm` source-line rule and no three start rules | VERIFIED | `managed_settings_deny_skill_edits` in `tests/guard/isolation.sh` and `claude_image_has_one_from_line` in `tests/guard/supply-chain.sh` exist and pass. The `sbx-rm` source-line block is gone from `host_scripts_keep_sandbox_data`. `tests/guard/start.sh` retains only `start_hooks_have_two_digit_names` and `gsd_sync_runs_before_the_bundle`; `no_installs_at_container_start`, `compose_starts_in_the_workspace` and `agent_image_keeps_base_state_folders` are gone. |
| 5 | On the Mac `./host-test.sh` runs unattended and passes; in the dev sandbox the guard and remaining self-tests pass | VERIFIED | `host-test.log` (branch chore/phase-06-test-diet, commit 2f05426): "Summary: 26 passed, 0 failed, 0 not run", "0 step(s) failed", all ten summary steps OK. No interactive prompt (`read` from tty) in `host-test.sh` or `tests/`. I ran `bash tests/guard/run-all.sh`, `tests/selftest/sbx/run-all.sh` and `tests/selftest/entrypoint/run-all.sh` in the dev sandbox: all exit 0. |

**Score:** 5/5 truths verified

## Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|-------------|-------------|--------|----------|
| DIET-01 | 06-05, 06-06 | SATISFIED | `tests/host/manual/` deleted; no pointers to it remain outside `.planning/` |
| DIET-02 | 06-04, 06-06 | SATISFIED | H-18, `fake-claude-api.js`, H-21, H-24, H-02 gone; H-00 preflight; H-11 in H-28; H-13/15/16/23 trimmed |
| DIET-03 | 06-03, 06-06 | SATISFIED | `lib-login.sh` with H-09 and H-29; `DISABLE_UPDATES=1` in H-13 |
| DIET-04 | 06-02, 06-06 | SATISFIED | Deny-entry and one-FROM rules added; self-test dir, `sbx-rm` rule and three start rules removed |
| DIET-05 | 06-01, 06-02, 06-06 | SATISFIED | No stand-in docker; `DOCKER_HOST` unreachable; `start-library.sh` gone; entrypoint name cases gone (by locked decision) |

No orphaned requirements: REQUIREMENTS.md maps DIET-01 to DIET-05 to Phase 6 and every ID appears in a plan's `requirements`.

## Anti-Patterns

No TBD/FIXME/XXX markers introduced in the touched files that matter to the goal. Remaining "stand-in" wording in `tests/README.md:24` and `host-test.sh:134,144` refers to the Mac linter wrappers and the `xattr` stand-in in `fix-modes.sh`, neither of which is a docker stand-in (out of scope per the phase).

## Review Disposition

WR-01, WR-05, IN-02, IN-04 fixed (commits 14b3c7b, 62e535e, 8d1e021); the rest are deliberate won't-fix items consistent with the locked decisions in 06-CONTEXT.md. None is reported as a gap.

## Human Verification Required

None. The Mac-only criteria are proven by `host-test.log` at HEAD 2f05426.

## Gaps Summary

None. Phase goal achieved.

---

_Verified: 2026-11-13_
_Verifier: Claude (gsd-verifier)_
