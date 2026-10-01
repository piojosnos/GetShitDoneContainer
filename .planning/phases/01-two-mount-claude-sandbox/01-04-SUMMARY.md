---
phase: 01-two-mount-claude-sandbox
plan: 04
subsystem: testing
tags: [docker, compose, host-verification, checklist, shellcheck, hadolint, bash]

requires:
  - phase: 01-03
    provides: "mount-check entrypoint, hardening, Safety checks doc section, static-check.sh to extend"
provides:
  - "SANDBOX.md: Host verification checklist H-00..H-13 with copy-paste Mac commands and pass conditions, mapped to ROADMAP success criteria 1-5"
  - "SANDBOX.md: Record your results template (per-ID table, docker compose version, Docker Desktop version, H-10 observation)"
  - "SANDBOX.md: Troubleshooting and known limits (stale .claude.json.lock, Console sign-in, cap_drop fallback, File sharing, H-10 env_file follow-up)"
  - "tests/static-check.sh: checklist-completeness checks plus optional shellcheck and hadolint runs (SKIP lines when absent)"
affects: [phase-02, phase-03, phase-05]

plan_head_before: 20dacb0f23f4815b6b0987701c35690209ba5eaf
plan_head_after: a25f7eb1641ca5bb701b7a00f9dfc60aef58d7ef

actuals:
  tokens: 3100
  tasks: 1
  commits: 1

tech-stack:
  added: []
  patterns:
    - "host checklist: one subsection per check ID, commands plus an explicit pass condition"
    - "optional linters run only when on PATH, SKIP line otherwise, never a project dependency"

key-files:
  created: []
  modified:
    - SANDBOX.md
    - tests/static-check.sh

key-decisions:
  - "Task 2 (blocking-human host verification) is DEFERRED by the user to Phase 2, not approved and not run; Phase 1 criteria are verified statically only"
  - "REQUIREMENTS.md left Pending for LAY-01..LAY-04, IMG-02, IMG-05, IMG-06: they are Mac-verifiable and the Mac checks have not been run"
  - "shellcheck found SC2164 on the cd in static-check.sh (from 01-01); fixed with '|| exit 1' so the optional linter run is clean"

# Honest record: static-only. See "Human verification status" below.
requirements-completed: []
requirements-addressed: [LAY-01, LAY-02, LAY-03, LAY-04, IMG-02, IMG-05, IMG-06]
human_verification: deferred   # NOT approved, NOT run. User decision 2026-10-01: skip now, test in Phase 2.

coverage:
  - id: D1
    description: "SANDBOX.md carries the full H-00..H-13 host checklist, coexistence check, results template and troubleshooting, with every ID present"
    requirement: "LAY-04"
    verification:
      - kind: other
        ref: "bash tests/static-check.sh (PASS: docs carry host checks H-00..H-13; docs cover the stale Claude lock; docs state the Console sign-in limit; docs carry the cap_drop fallback; docs record H-10 and the Compose version; docs never remove volumes on down)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Phase 1 success criteria 1-5 hold on the real Mac (arm64 build, non-root, login survives recreate and --no-cache rebuild, history persists, nothing deleted, no volumes, H-10 refusal)"
    verification: []
    human_judgment: true
    rationale: "Docker is not available in the dev sandbox and the human deferred H-00..H-13 to Phase 2. Nothing has been built or run with Docker. These are unverified, not passed."

duration: 2min
completed: 2026-10-01
status: complete
---

# Phase 1 Plan 4: Host verification checklist Summary

**Copy-paste Mac checklist H-00..H-13 (mapped to roadmap success criteria 1-5) with results template and troubleshooting, plus static guards and optional shellcheck/hadolint runs; the Mac run itself is DEFERRED by the user to Phase 2.**

## Human verification status: DEFERRED (not approved)

Task 2 is a `checkpoint:human-verify` with `gate="blocking-human"`. Before dispatch the user answered it in their own words: "I'm going to skip manually testing this, and will test on phase 2."

This is a deferral, not an approval and not a pass. No check was run and no result was invented. Phase 1 success criteria are verified **statically only** (`bash tests/static-check.sh`), which proves the file contents and wiring, not that anything builds or runs under Docker.

| ID | Result |
|---|---|
| H-00 | not run (deferred to Phase 2 by user, 2026-10-01) |
| H-01 | not run (deferred to Phase 2 by user, 2026-10-01) |
| H-02 | not run (deferred to Phase 2 by user, 2026-10-01) |
| H-03 | not run (deferred to Phase 2 by user, 2026-10-01) |
| H-04 | not run (deferred to Phase 2 by user, 2026-10-01) |
| H-05 | not run (deferred to Phase 2 by user, 2026-10-01) |
| H-06 | not run (deferred to Phase 2 by user, 2026-10-01) |
| H-07 | not run (deferred to Phase 2 by user, 2026-10-01) |
| H-08 | not run (deferred to Phase 2 by user, 2026-10-01) |
| H-09 | not run (deferred to Phase 2 by user, 2026-10-01) |
| H-10 | not run (deferred to Phase 2 by user, 2026-10-01) |
| H-11 | not run (deferred to Phase 2 by user, 2026-10-01) |
| H-12 | not run (deferred to Phase 2 by user, 2026-10-01) |
| H-13 | not run (deferred to Phase 2 by user, 2026-10-01) |
| Coexistence (old-layout containers untouched) | not run (deferred to Phase 2 by user, 2026-10-01) |

- `docker compose version` output: not collected.
- Docker Desktop version: not collected.
- H-10 observation: not collected. It is unknown whether the user's Compose honors `create_host_path: false`.

### Open human-verification items carried into Phase 2

1. Run H-00..H-13 and the coexistence check on the Mac from `SANDBOX.md` and record the results table, the `docker compose version` output and the Docker Desktop version. This is also the first `docker build` of `claude/`, which installs the npm package approved in 01-01 Task 1.
2. **H-10 env_file-sentinel follow-up trigger.** If `up` with a nonexistent `SBX_DIR` creates the missing folders, the conditional follow-up is an `env_file` sentinel at the root of `SBX_DIR`. It amends the D-12 layout, so it needs the user's approval first and is then planned with `/gsd-plan-phase 1 --gaps`. Until H-10 runs, which D-10 layer holds (create_host_path, entrypoint mount check, preflight loop) is unknown.
3. **H-12 installed-version-equals-pin check.** The installed Claude Code must print exactly `2.1.285 (Claude Code)` via `docker run --rm --entrypoint claude sbx-claude:local --version`, and a plain `docker run` must be refused with `[sbx] ERROR ... not a bind mount` and rc=1. This closes threat T-01-SC.
4. If any host check fails only because of `cap_drop: [ALL]` (assumption A4), remove `cap_drop` and keep `no-new-privileges`, and report it.
5. Any failing check becomes input for gap closure (`/gsd-plan-phase 1 --gaps`).
6. Flagged edge assumptions A-E1..A-E6 from the plan stay unexercised (host paths with spaces, interleaved history from concurrent shells, system prune, Phase 1 agent-only image content, native arm64 resolution of ubuntu:24.04, VirtioFS ownership).

## Performance

- **Duration:** 2 min
- **Started:** 2026-10-01T18:43:52Z
- **Completed:** 2026-10-01T18:45:30Z
- **Tasks:** 1 executed, 1 deferred by the human (Task 2)
- **Files modified:** 2

## Accomplishments

- `SANDBOX.md` gained "Host verification checklist (H-00..H-13)": a setup block (compose version, both builds, exports, mkdir, preflight loop, `config`, `up -d --wait`) and one subsection per check with Mac commands and an explicit pass condition, including the plan's changes (H-05 `.local` ownership, H-08 leave-shell-open note, H-09 volume and Mounts checks, H-10 missing-folder refusal with cleanup, H-12 pinned version `2.1.285 (Claude Code)`, H-13 `claude update` refusal and `claude doctor`), plus a Coexistence check and the SC1-SC5 mapping.
- `SANDBOX.md` gained "Record your results" (per-ID table, Compose version, Docker Desktop version, H-10 observation) and "Troubleshooting and known limits" (stale `.claude.json.lock` safe to delete when `pgrep -a claude` prints nothing, Console sign-in not persisted, `cap_drop` fallback, Mounts denied, missing variable, lowercase name, session keyed by directory, docker run bypass, H-10 env_file follow-up).
- `tests/static-check.sh` now guards checklist completeness (one FAIL per missing H-ID), the lock, Console and cap_drop notes, and the results section, and runs shellcheck and hadolint when installed (`SKIP:` line otherwise).
- With shellcheck v0.11.0 and hadolint v2.15.1 downloaded to the session scratchpad (outside the repo, not committed), both passed. Without them the script prints `SKIP: shellcheck not installed` and `SKIP: hadolint not installed` and exits 0.

## Task Commits

1. **Task 1: Host verification checklist H-00..H-13, results template, troubleshooting and known limits** - `a25f7eb` (feat)
2. **Task 2: Run H-00..H-13 on the Mac and report results** - no commit. Deferred by the human to Phase 2.

**Plan metadata:** committed separately (docs: complete plan).

## Files Created/Modified

- `SANDBOX.md` - host checklist H-00..H-13, results template, troubleshooting and known limits
- `tests/static-check.sh` - 5 doc-completeness checks, optional linter runs, `cd ... || exit 1` fix

## Decisions Made

- Honored the human's pre-dispatch decision to defer Task 2 rather than returning a checkpoint, and recorded it as deferred, not approved.
- Did not mark LAY-01..LAY-04, IMG-02, IMG-05, IMG-06 complete in REQUIREMENTS.md. They are Mac-verifiable and nothing has run on a Mac. They stay Pending until the deferred checks pass in Phase 2.
- Used `/Users/you/...` placeholders as the plan specifies (RESEARCH used a real username).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] shellcheck SC2164 on `cd` in tests/static-check.sh**
- **Found during:** Task 1 (first run of the new optional shellcheck check)
- **Issue:** `cd "$(dirname "$0")/.."` (from 01-01) had no failure guard, so `shellcheck -S warning` reported a warning and the new check would FAIL wherever shellcheck is installed.
- **Fix:** Appended `|| exit 1`.
- **Files modified:** tests/static-check.sh
- **Verification:** with shellcheck on PATH, `PASS: shellcheck`; `bash tests/static-check.sh` exits 0
- **Committed in:** a25f7eb (Task 1 commit)

### Deferred by human decision (not an executor deviation)

- Task 2 (blocking-human host verification) was not executed. See "Human verification status".

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Trivial and necessary for the optional linter check to pass. No scope creep.

## Issues Encountered

None. Docker is unavailable in the dev sandbox, so nothing in the checklist could be run here.

## Known Stubs

None. The "Record your results" table has intentionally empty cells for the user to fill in on the Mac; that is a template, not a stub.

## Threat Flags

None. No new network, auth, file-access or schema surface was added. T-01-18 is mitigated (static guards keep the docs free of the volumes-removal flag on down and of the hyphenated v1 command; H-10 cleanup removes only the path the user typed). T-01-19 and T-01-SC are only partly mitigated until the host results exist: the template exists but no results are recorded, and the installed-equals-pin check (H-12) has not run.

## User Setup Required

External services require manual configuration before the deferred checks can run: Docker Desktop must share the parent folder of `SBX_DIR` (Settings, Resources, File sharing), and a claude.ai login is needed once inside the sandbox (H-07). See the plan's `user_setup` block.

## Next Phase Readiness

- The checklist and results template are ready for the user to run when convenient (planned: during Phase 2).
- Blocker for calling Phase 1 verified: H-00..H-13 and coexistence are unrun, so arm64 builds, login surviving recreate and rebuild, history persistence, the absence of volumes and the H-10 refusal are all unproven.

---
*Phase: 01-two-mount-claude-sandbox*
*Completed: 2026-10-01*

## Self-Check: PASSED

- `SANDBOX.md` and `tests/static-check.sh` exist and are modified in `a25f7eb`.
- `git log` contains `a25f7eb`.
- `bash tests/static-check.sh` exits 0; all H-00..H-13 present in `SANDBOX.md`.
- `git diff --quiet 934e2c5694dbc1524ae9993f2bf025ffa779358e -- README.md ClaudeCode OpenCode` exits 0.
