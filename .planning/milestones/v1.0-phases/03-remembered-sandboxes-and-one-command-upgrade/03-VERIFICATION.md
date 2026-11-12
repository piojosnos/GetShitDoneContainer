---
phase: 03-remembered-sandboxes-and-one-command-upgrade
verified: 2026-11-07T01:30:00Z
status: passed
score: 5/5 must-haves verified
covered_files:
  - ".planning/phases/03-remembered-sandboxes-and-one-command-upgrade/03-01-PLAN.md"
  - ".planning/phases/03-remembered-sandboxes-and-one-command-upgrade/03-01-SUMMARY.md"
  - ".planning/phases/03-remembered-sandboxes-and-one-command-upgrade/03-02-PLAN.md"
  - ".planning/phases/03-remembered-sandboxes-and-one-command-upgrade/03-02-SUMMARY.md"
  - ".planning/phases/03-remembered-sandboxes-and-one-command-upgrade/03-03-PLAN.md"
  - ".planning/phases/03-remembered-sandboxes-and-one-command-upgrade/03-03-SUMMARY.md"
  - ".planning/phases/03-remembered-sandboxes-and-one-command-upgrade/03-04-PLAN.md"
  - ".planning/phases/03-remembered-sandboxes-and-one-command-upgrade/03-04-SUMMARY.md"
  - "SANDBOX.md"
  - "base/Dockerfile"
  - "base/sbx-start-lib.sh"
  - "bin/sbx-add"
  - "bin/sbx-lib.sh"
  - "bin/sbx-start"
  - "bin/sbx-stop"
  - "bin/sbx-upgrade"
  - "claude/Dockerfile"
  - "host-test.sh"
  - "tests/README.md"
  - "tests/guard/isolation.sh"
  - "tests/guard/lib.sh"
  - "tests/guard/supply-chain.sh"
  - "tests/host-checklist.md"
  - "tests/host/h28-sbx-add-start-stop.sh"
  - "tests/host/h29-sbx-upgrade.sh"
  - "tests/host/h30-version-line.sh"
  - "tests/host/lib-sbx.sh"
  - "tests/host/manual/h29-upgrade-resume.sh"
  - "tests/host/run-all.sh"
  - "tests/selftest/guard/sandbox-rules.sh"
  - "tests/selftest/sbx/add.sh"
  - "tests/selftest/sbx/entry.sh"
  - "tests/selftest/sbx/lib.sh"
  - "tests/selftest/sbx/run-all.sh"
  - "tests/selftest/sbx/start.sh"
  - "tests/selftest/sbx/upgrade.sh"
covered_digest: "v2:sha256:dc28ff7e30f1013ef9d30affa95fde4e6a0c75a02aae164f0baed8def052aa1d"
behavior_unverified: 0
overrides_applied: 0
coincidental_reliance_items:
  - truth: "SC3: login and past sessions survive sbx-upgrade (attended helper)"
    reason: fixture-only
    harden: "The attended helper ran at 9abf603, before the review fixes. It still holds because the fixes changed only the warning wording (self-test pinned) and a '|| running=\"\"' guard on the poll. Re-run tests/host/manual/h29-upgrade-resume.sh once on the PR tip if you want the evidence on the exact commit."
human_verification:
  - test: "Confirm nothing was pushed, merged or opened as a PR for feat/sbx-scripts or chore/phase-03-run"
    expected: "No remote branch and no PR for either branch yet (the plan's judgment-tier prohibition: 'MUST NOT push, merge or open the code PR; the user approves each push')"
    why_human: "Judgment-tier prohibition, so the verdict is non-authoritative. Evidence seen: no origin/feat/sbx-scripts or origin/chore/phase-03-run remote-tracking ref, and `git ls-remote --heads origin` for both names printed nothing. Network reachability of that call was not proven, so only the user can vouch for it."
---

# Phase 3: Remembered Sandboxes and One-Command Upgrade Verification Report

**Phase Goal:** The user registers each sandbox once, then starts, stops, and upgrades it by name alone. One command rebuilds the images and recreates the sandbox, and login and history survive.
**Verified:** 2026-11-07
**Status:** human_needed (one flagged judgment-tier prohibition; every roadmap truth is VERIFIED)
**Re-verification:** No, initial verification
**Verified commit:** `eb04e2c` on `chore/phase-03-run` (the final code commit). `feat/sbx-scripts` (tip `eb1f042`) carries the same 14 code commits on `origin/main` `b389168`.

## Goal Achievement

The summaries predate the review fixes (SUMMARY 04 describes 9 commits at `9abf603`). I verified against the final tree, not the summaries.

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `sbx-add <name> <host_path>` registers once, agent `claude` by default, creates `<name>/` and `state/`; afterwards no script needs the host path | VERIFIED | Ran it myself (scratch `SBX_CONFIG_DIR`, host path with spaces): exit 0, entry is exactly `SBX_DIR=<path>` then `SBX_AGENT=claude`, folders `demo` and `state` created. `sbx-start`, `sbx-stop`, `sbx-upgrade` take only NAME and read `entryDir` from the registry (`bin/sbx-lib.sh` `read_registry_entry`, line-by-line, never sourced). Refusals checked live: duplicate name, `State`, reserved `state`, `$HOME`-holding-repo, a folder inside the repo, the registry folder; each exit 1. H-28 on the Mac PASS. |
| 2 | Start and stop with only the name; stopping never deletes anything in `<name>/` or `state/` | VERIFIED | `bin/sbx-stop` runs only `docker compose ... stop` via `run_compose`. `bin/sbx-start` runs `up -d --wait` then a readiness poll. Guard rule `host_scripts_keep_sandbox_data` PASS (no rm, rmdir, prune, kill, down, `--volumes` in `bin/*`; my grep of `bin/` also finds none). Mac H-28 PASS: "the container and the files stayed". |
| 3 | One command rebuilds base, then Claude image, then recreates; Claude still logged in, past sessions still there | VERIFIED | `bin/sbx-upgrade`: validate name, entry and folders, `warn_if_running`, `bash build.sh "$@"` as its own process (a failure returns before any compose call), `up -d --force-recreate --wait`, `wait_until_ready`, then the versions line. Mac H-29 at `eb04e2c`: failed build left the sandbox as it was; recreated only `sbx-hosttest`; files, volume list and the single bind mount unchanged. Attended helper `/home/sandbox/h29m.log`: `loggedIn: true` before and after `sbx-upgrade`, `claude --continue` resumed. See "Evidence timing" below. |
| 4 | Claude Code, GSD, ccusage, Node, JDK, Maven, Python versions printed at the end of a rebuild and whenever a bash shell opens | VERIFIED | `base/Dockerfile` writes `/etc/sbx/tool-versions` at build time (build fails on a malformed line) and appends `cat /etc/sbx/tool-versions` to `/etc/bash.bashrc`; `claude/Dockerfile` prepends the three Claude fields from the pins the smoke test checks (`claude --version`, `gsd-tools runtime-identity`, `ccusage --version`). `sbx-upgrade` ends with `docker exec ... cat /etc/sbx/tool-versions`. Mac H-30 PASS at `eb04e2c`: line equals `versions.env`, an interactive shell prints it once, `bash -c` and `bash -lc` print nothing. H-29 checks `sbx-upgrade`'s last line equals it. |
| 5 | All `sbx-*` scripts run under macOS stock bash 3.2 and work with a host path containing spaces | VERIFIED | `host-test.log` (run at `eb04e2c`): "sbx self-test in the Mac shell" under `/bin/bash` 3.2.57 ended `All cases pass.`, including the letter-case case as PASS rather than INFO; H-28 and H-29 ran `bin/` through PATH with `/bin/bash` 3.2.57 first, H-28 on a folder with a space. I also ran `sbx-add` with a space path here (bash 5). |

**Score:** 5/5 truths verified, 0 present-but-behavior-unverified.

### Evidence timing (the question you asked about the attended helper)

The attended login and resume helper ran at `9abf603`. Between `9abf603` and `eb04e2c` the files that the upgrade path executes changed only like this (`git diff 9abf603..eb04e2c -- bin/sbx-upgrade bin/sbx-lib.sh compose.yml build.sh base claude tests/host/manual`):

- `bin/sbx-upgrade`: one line; the inline warning echo became `warn_sessions_close "$1" "is running; after the build, recreating it"`. The self-test "the warning keeps its wording" pins the output byte for byte.
- `bin/sbx-lib.sh`: the new `warn_sessions_close`, and `|| running=""` on the readiness poll's `docker container inspect` (only changes the path where the container vanished).
- `compose.yml`, `build.sh`, `versions.env`, `base/`, `claude/`, the helper itself: no change.

The login and resume property rests on the unchanged mount and recreate (`state/claude` bind mount, `--force-recreate`), not on anything the fixes touched. Judgment: the helper evidence still holds. The full automated H-29 also passed at `eb04e2c`, so the recreate path is proven on the final commit; only the interactive login part is one commit behind. Optional: re-run `tests/host/manual/h29-upgrade-resume.sh` on the PR tip.

### Plan-level truths and prohibitions (beyond the roadmap)

| Item | Status | Evidence |
|------|--------|----------|
| Registry entries are read, never sourced; name rule written once in `base/sbx-start-lib.sh` | VERIFIED | `read_registry_entry` uses `while IFS= read -r`; `load_name_rule` reads `sandboxNamePattern` and `sandboxReservedNameList` from the start library. Self-test cases pass. |
| Compose isolation from the caller's environment (D-10) | VERIFIED | `run_compose` uses `--env-file /dev/null -p sbx-NAME -f $repoDir/compose.yml`, sets `SBX_NAME` and `SBX_DIR` on that command, `sbx_init` unsets the `COMPOSE_*` variables. H-28 exports bogus values and passes. |
| `bin/sbx-add|start|stop|upgrade` are mode 100755; `compose.yml`, `build.sh`, `versions.env` unchanged vs `origin/main`; no `.planning/` path in the code diff | VERIFIED | `git ls-files -s bin`; `git diff --name-only origin/main feat/sbx-scripts` shows 0 `.planning` paths; the three files are absent from the diff stat. |
| SCR-03 prohibition: no recreate or change when the build failed (test) | VERIFIED | `run_build` returns 1 before `recreate_sandbox` under `set -eu`; H-29 failed-build case PASS on the Mac. |
| SCR-03 prohibition: no removal of volume, container, image or file (test) | VERIFIED, with a reading note | Guard rule plus two planted failures in `tests/selftest/guard/sandbox-rules.sh` (pass); H-29 shows files and volume list unchanged. Read literally, "container" conflicts with `--force-recreate`, which replaces the one named container by design (the roadmap requires the recreate). The plan's own rationale ("Stop is compose stop and upgrade is up --force-recreate") shows the intent is no data or other-object deletion. |
| SCR-03 prohibition: no closing of sessions without a printed warning (test) | VERIFIED | `warn_if_running` precedes `run_build`; `sbx-start` now warns via `warn_if_older_image` before the recreate; self-test cases cover warned, not warned, and ordering. |
| SCR-03 prohibition: only the named sandbox is recreated (test) | VERIFIED | `-p sbx-NAME`; H-29 "recreated only sbx-hosttest" PASS on the Mac. |
| SCR-07 prohibitions: version never differs from the image; silent in non-interactive shells; no tool queried at shell open (test) | VERIFIED | Line is a file written at build time from the pins; H-30 PASS. |
| SCR-01 prohibition: no `.planning/` files or planning IDs on the code branch (test) | VERIFIED | 0 `.planning` paths in `origin/main..feat/sbx-scripts`; 0 commit messages with `Co-Authored-By` or "generated with"; my grep of `bin base claude tests host-test.sh SANDBOX.md` for D-nn, "Phase N", PLAN.md, 03-0 finds nothing; no non-ASCII bytes in the changed scripts or `SANDBOX.md`. |
| SCR-03 prohibition: no push, merge or code PR without the user (judgment) | UNCERTAIN, non-authoritative: flagged | See `human_verification`. No remote ref found for either branch. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `bin/sbx-lib.sh` (257 lines) | registry, name rule, compose, readiness | VERIFIED | Substantive, sourced by all four scripts, `bash -n` clean |
| `bin/sbx-add` (283) | registration and overlap refusals | VERIFIED | Includes `refuse_registry_overlap`, `refuse_repo_overlap`, `refuse_sandbox_overlap`; folder-identity comparison (`-ef`, `cd -P`) |
| `bin/sbx-start` (62), `bin/sbx-stop` (33), `bin/sbx-upgrade` (80) | start, stop, upgrade by name | VERIFIED | Wired to the library; real Compose calls, no stubs |
| `base/sbx-start-lib.sh` | `sandboxReservedNameList` | VERIFIED | One list, read by container and host |
| `base/Dockerfile`, `claude/Dockerfile` | tool-versions file and bashrc line | VERIFIED | Format checked by `grep -Eq` at build time |
| `tests/selftest/sbx/*` | docker-free self-test | VERIFIED | Ran here: `All cases pass.` |
| `tests/guard/isolation.sh` | `host_scripts_keep_sandbox_data` | VERIFIED | PASS; planted-failure cases pass |
| `tests/host/h28`, `h29`, `h30`, `lib-sbx.sh`, `manual/h29-upgrade-resume.sh` | Mac checks | VERIFIED | All three PASS in `host-test.log`; helper log all PASS |
| `SANDBOX.md` | script flow | VERIFIED | Documents PATH line, each script, refusals, the warn-on-older-image behavior |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `bin/sbx-lib.sh` | `base/sbx-start-lib.sh` | `read_start_variable` sources in a subshell | WIRED |
| `bin/sbx-lib.sh` | `compose.yml` | `run_compose` with `--env-file /dev/null -p sbx-NAME -f` | WIRED |
| `bin/sbx-lib.sh` | registry file | `read_registry_entry` line-by-line | WIRED |
| `bin/sbx-upgrade` | `build.sh` | `bash "$repoDir/build.sh" "$@"` as its own step | WIRED |
| `bin/sbx-upgrade` | `/etc/sbx/tool-versions` | `docker exec ... cat` as the last output | WIRED |
| `/etc/bash.bashrc` | `/etc/sbx/tool-versions` | appended `cat` line after the PS1 guard | WIRED (H-30) |
| `claude/Dockerfile` | `base/Dockerfile` | prepends its fields to the base file | WIRED (H-30 compares all seven fields) |

### Data-Flow Trace (Level 4)

| Artifact | Data | Source | Real data | Status |
|----------|------|--------|-----------|--------|
| `sbx-upgrade` last line | tool versions | file written at build from pins and one `java -version` / `python3 --version` query | Yes | FLOWING |
| `sbx-start`/`stop`/`upgrade` | `entryDir` | registry file written by `sbx-add` | Yes | FLOWING |

### Behavioral Spot-Checks (run by me, no Docker)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| sbx self-test | `bash tests/selftest/sbx/run-all.sh` | `All cases pass.` | PASS |
| entrypoint self-test | `bash tests/selftest/entrypoint/run-all.sh` | `All cases pass.` | PASS |
| guard self-test | `bash tests/selftest/guard/run-all.sh` | `All cases pass.` | PASS |
| guard | `bash tests/guard/run-all.sh` | 17 PASS; only `shellcheck_passes` and `hadolint_passes` FAIL (linters not installed here; both pass on the Mac per `host-test.log`) | PASS (expected) |
| `bash -n` on `bin/*` | each file | no error | PASS |
| sbx-add with a space path, duplicates, bad names, repo and registry overlap, usage, missing folder | run live in a scratch dir | exit codes 0, 1, 2 as specified | PASS |

### Probe Execution

SKIPPED: the phase declares no `probe-*.sh` scripts.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SCR-01 | 03-01, 03-03, 03-04 | Register once with `sbx-add`; other scripts take only `<name>`; agent defaults to `claude` | SATISFIED | Truth 1 |
| SCR-02 | 03-01, 03-03, 03-04 | Start and stop by name | SATISFIED | Truth 2 |
| SCR-03 | 03-02, 03-03, 03-04 | One command rebuilds both images and recreates, keeping login and history | SATISFIED | Truth 3 |
| SCR-07 | 03-03, 03-04 | Tool versions printed after a rebuild and on shell entry | SATISFIED | Truth 4 |

All four IDs appear in plan frontmatter and in `REQUIREMENTS.md` (checked, traceability row "Phase 3 / Complete"). No orphans: SCR-04 to SCR-06 map to Phase 4 and SCR-08 to Phase 5.

### Anti-Patterns Found

None. `TBD/FIXME/XXX/TODO/HACK` search of the changed code files hit only the `mktemp ...XXXXXX` templates in `host-test.sh` (false positive). No stubs, no hardcoded empties flowing to output.

### Review Findings Status

| Finding | Status |
|---------|--------|
| CR-01 repo overlap | Fixed in `ae1763f`; confirmed live (`/home/sandbox` and a path inside the repo are refused) |
| WR-01 silent `set -e` exit | Fixed in `2bb1261`; guard in `wait_until_ready` present; scripted-docker self-test passes |
| WR-02 destructive `sbx-start` | Fixed (warn) in `addc6cd`; H-28 shows no false warning on the Mac |
| WR-03 text-only overlap | Fixed in `841ba8c`; Mac self-test shows the letter-case check as PASS under APFS |
| IN-01 to IN-05 | Open by design (out of scope). IN-02 (`sbx-stop` says "is stopped" for a never-created sandbox) and IN-03 (a stray file in the registry blocks every `sbx-add`) are usability warts, not goal failures. |

### Not Counted as Gaps

- `pin digests` failed in `host-test.log` (UBUNTU_IMAGE digest moved upstream). Not caused by this phase, `versions.env` is unchanged, and `fix/pin-digest-notice` handles it. Treated as out of scope as instructed.
- True-positive path of the WR-02 warning (a running sandbox on a really replaced image) has only the stand-in self-test, not a Mac run. It is a review-fix extra, not a roadmap truth. A manual check is listed in `03-REVIEW-FIX.md`.
- `/tmp` against `/private/tmp` in `sbx-add` is not exercised by any automated check (the same-folder letter-case case is).
- `build.sh` run directly does not print the versions line; `sbx-upgrade`, the rebuild command, does. This matches the locked design (the roadmap's "end of a rebuild" is read as the upgrade command).
- Housekeeping: `ROADMAP.md` still shows the Phase 3 checkbox unticked in the phase list (line 24) although the plans list is ticked; REQUIREMENTS already shows the four IDs complete. Orchestrator bookkeeping, not a code gap.

### Human Verification Required

#### 1. No push, merge or PR happened for the code branch

**Test:** Confirm you have not pushed `feat/sbx-scripts` or `chore/phase-03-run`, and no PR exists.
**Expected:** Neither branch exists on `origin`; no PR.
**Why human:** Judgment-tier prohibition, so non-authoritative. I saw no remote-tracking ref and an empty `git ls-remote --heads` result, but could not prove the remote was reachable. Flag: `unverified-prohibition - human review recommended`. Accepting this item makes the phase complete with 1 flagged prohibition.

**Resolved (orchestrator, 2026-11-07):** `git ls-remote --heads origin` reached the remote (24 branch heads listed) and none is `feat/sbx-scripts`, `chore/phase-03-run`, `fix/pin-digest-notice` or `chore/planning-phase-03-context`. Nothing was pushed, merged or opened. The prohibition holds, so the status is passed.

### Gaps Summary

No gaps. All five roadmap criteria and SCR-01, SCR-02, SCR-03, SCR-07 are met on the final commit `eb04e2c`, with Docker-free checks re-run here and Mac evidence taken from `host-test.log` (30 of 30, bash 3.2 self-test, guard with real linters). The status is `human_needed` only because the flagged judgment-tier push prohibition is a mandatory human-review item. The only older-than-final evidence is the attended login helper (`9abf603`), which I judge still valid.

---

_Verified: 2026-11-07_
_Verifier: Claude (gsd-verifier)_
