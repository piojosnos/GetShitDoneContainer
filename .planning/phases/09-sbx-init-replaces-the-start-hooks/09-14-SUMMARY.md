---
phase: 09-sbx-init-replaces-the-start-hooks
plan: 14
subsystem: init
tags: [sbx-init, signals, process-group, best-practices-clone, host-test, login-shell]

requires:
  - phase: 09-sbx-init-replaces-the-start-hooks
    provides: plans 09-01 to 09-13 (sbx-init, GSD sync step, best-practices links step, wrappers, agents folder, host checks)
provides:
  - an interrupted sbx-init (Ctrl-C, SIGHUP, SIGTERM) kills the GSD installer's process group before the lock is released, removes its log and exits 130
  - a separate FAIL and fix for a best-practices folder that exists but is incomplete, shared by init and the self-check
  - H-27 and H-34 login-shell assertions on the real images, which settle WR-02 by test
affects: [phase-9 PR, phase 10]

status: complete
actuals:
  tokens: 10900
  tasks: 4
  commits: 3
plan_head_before: 75de44b34acf503318bc0738d1510deadf8a12bb
plan_head_after: 8b74b76020a061942798eaf7622e2aa447b440dd

tech-stack:
  added: []
  patterns:
    - "SIGHUP and SIGTERM install signal.default_int_handler so every interruption unwinds as KeyboardInterrupt through the finally blocks"
    - "one shared failed() result (incomplete_clone_result) so init and the self-check print the same text"
    - "stand-in agent behind the wrapper's SBX_AGENT_BIN_DIR knob to test a login shell on the real image offline"

key-files:
  created: []
  modified:
    - base/init/gsd_sync.py
    - base/init/init_runner.py
    - base/init/sbx-init
    - base/init/best_practices_link.py
    - base/selfcheck/bundle_links.py
    - tests/selftest/init/init_helpers.py
    - tests/selftest/init/test_init_gsd_sync.py
    - tests/selftest/init/test_init_launcher.py
    - tests/selftest/init/test_init_best_practices_link.py
    - tests/selftest/selfcheck/test_bundle_links.py
    - tests/host/h27-bundle-clone-and-publish.sh
    - tests/host/h34-selfcheck.sh
    - tests/host-checklist.md
    - tests/README.md
    - README.md

key-decisions:
  - "WR-02 needed no code change: the Mac run proves a login shell inside an sbx-claude or sbx-cursor session finds the agent in /opt/sbx/agents/bin and a plain login shell does not, so the wrappers, Dockerfiles and guard stay as they were"
  - "An existing but incomplete clone folder is a separate FAIL whose fix says pull it or move it aside, never delete, and init touches nothing in the config folder in that case"

patterns-established:
  - "Interruption: _run_installer kills the group on any BaseException, removes the log in a finally, then re-raises; main maps KeyboardInterrupt to exit 130"

requirements-completed: [INIT-02, INIT-04, INIT-05]

coverage:
  - id: D1
    description: "Ctrl-C, a closed terminal or a stop during the GSD sync leaves no installer, no child, no log and no marker, frees the lock, and exits 130 with one line"
    requirement: "INIT-02"
    verification:
      - kind: integration
        ref: "tests/selftest/init/test_init_launcher.py::test_an_interrupted_run_stops_the_installer_and_its_child_drops_the_log_and_frees_the_lock (sigint, sighup, sigterm)"
        status: pass
    human_judgment: false
  - id: D2
    description: "A clone folder that exists but lacks rules/ or skills/ gets its own FAIL and a pull or move-aside fix, identical in init and the self-check; the absent case keeps its text"
    requirement: "INIT-05"
    verification:
      - kind: unit
        ref: "tests/selftest/init/test_init_best_practices_link.py and tests/selftest/selfcheck/test_bundle_links.py (uv run pytest -q, 432 passed)"
        status: pass
    human_judgment: false
  - id: D3
    description: "A login shell started inside an agent session finds the agent in /opt/sbx/agents/bin and a plain login shell does not, on the real images, for Claude and Cursor"
    requirement: "INIT-04"
    verification:
      - kind: manual_procedural
        ref: "host-test.log: PASS H-27 and PASS H-34 with the login-shell phrases; Summary: 17 passed, 0 failed, 0 not run"
        status: pass
    human_judgment: true
    rationale: "Docker does not run in the dev sandbox; the run is a human action on the Mac and the executor read its logs"

duration: not measured (spans the Mac gate)
completed: 2026-11-17
---

# Phase 9 Plan 14: Review warning fixes Summary

**An interrupted sbx-init now kills the GSD installer's process group before the lock is released and exits 130, an incomplete best-practices folder gets its own pull or move-aside fix, and H-27 and H-34 prove on the real images that login shells inside an agent session keep the agents folder.**

## Performance

- **Duration:** not measured; the plan spans a Mac gate that waits on the user
- **Completed:** 2026-11-17
- **Tasks:** 4 (three code tasks and the Mac gate)
- **Files modified:** 15

## Accomplishments

- WR-01: SIGINT, SIGHUP and SIGTERM during the GSD sync kill the installer's group (the installer pid is gone when the launcher exits, its child within 5 s), remove `sbx-init-gsd-*.log`, write no marker and leave the lock free; the launcher prints `sbx-init: interrupted; run sbx-init again` and exits 130.
- WR-03: nothing at the clone path keeps the old `no best-practices clone at PATH` fix; something there that lacks `rules/` (Claude) or `skills/` (Cursor) prints `PATH exists but has no rules/ folder` with a fix to run `git -C PATH pull` then `sbx-init`, or to move it aside and run `sbx-gh-login` and `sbx-bundle-clone`. Init and `bundle_links_result` share `incomplete_clone_result`, so the text is byte for byte equal, and init makes nothing in the config folder.
- WR-02 and UAT test 1: H-27 (Claude) and H-34 (Cursor) start a login shell through the real wrapper with a stand-in agent and assert it finds the agent in `/opt/sbx/agents/bin`, and that a plain `bash -lc` finds nothing. Both passed on the Mac, so no fix was needed.

## Test-first records

- **Task 1 (RED):** the three interruption cases failed before the change; the launcher exited -2, -1 and -15 instead of 130, with the installer still alive and the log left behind. GREEN after the change.
- **Task 2 (RED):** 7 failed and 33 passed in the two clone test files (the incomplete-folder cases printed the no-clone text). GREEN with 40 passing.

## Dev-sandbox gate

| Check | Result |
|---|---|
| `uv run pytest -q` | 432 passed |
| Guard (`bash tests/guard/run-all.sh`) | 20 PASS lines, `All rules hold.` |
| sbx self-test (`bash tests/selftest/sbx/run-all.sh`) | 150 PASS; the same with `SBX_IMAGE_TAG=test SBX_CA_CERT=/nonexistent/ca.pem` |
| ASCII, ID, dash and bundle-name sweeps over added lines | empty |
| Wrappers, Dockerfiles, `tests/guard`, `compose.yml`, `.claude/CLAUDE.md` against b444151 | unchanged; no `base/profile.d` |
| Modes | `base/init/sbx-init` and H-27 stay 100755, H-34 stays 100644 |

## Mac gate (task 4)

Approved by the user ("Done, all looks good"); the executor read the logs itself.

`host-test.log` (branch `feat/sbx-init`, commit 8b74b76):

- `Summary: 17 passed, 0 failed, 0 not run`, ending `0 step(s) failed.`
- `PASS: H-27` includes "a login shell inside an sbx-claude session found claude in /opt/sbx/agents/bin and a plain login shell did not"
- `PASS: H-34` includes "a login shell inside an sbx-cursor session found cursor-agent in /opt/sbx/agents/bin and a plain login shell did not"
- H-34 INFO lines: 4 and 5 init steps, `sbx-selfcheck: 55 checks, 0 failed` and `sbx-selfcheck: 53 checks, 0 failed`
- `All rules hold.` twice (sbx-hosttest and the Mac shell)

`init-gap-gate.log`: the IDs of `sbx-base:local`, `sbx-claude:local` and `sbx-cursor:local` are identical before and after the run.

## Task Commits

1. **Task 1: interrupted sbx-init stops the GSD installer (tracer)** - `68ccaad` (fix)
2. **Task 2: incomplete clone folder gets its own FAIL and fix** - `fc0f69b` (fix)
3. **Task 3: H-27 and H-34 login-shell checks, docs, dev gate** - `8b74b76` (test)
4. **Task 4: Mac gate** - no commit (human verification; logs are outside git)

**Plan metadata:** the docs commit that adds this SUMMARY, STATE.md, ROADMAP.md and REQUIREMENTS.md, followed by one planning-only commit for the review disposition and the UAT note.

## Decisions Made

- WR-02 is fixed by verification, not by code: the review's worry (a login shell resetting PATH) does not occur on the real images.
- The incomplete-clone fix never says delete; it says pull or move aside (threat T-09-40).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. The host-test log and the dev-sandbox gate agreed on every count.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The three review warnings are closed; IN-01 to IN-05 stay open by design.
- The code PR is prepared by hand from the `feat/` branch; push only with the user's go.

## Known Stubs

None.

## Threat Flags

None. The change adds no network endpoint, auth path or file access outside the plan's threat model.

## Self-Check: PASSED

- Commits 68ccaad, fc0f69b and 8b74b76 exist on `feat/sbx-init`.
- `git rev-list --count 75de44b..HEAD` is 3 at SUMMARY time, matching `commits: 3`.
- `host-test.log` and `init-gap-gate.log` read; every acceptance line found.

---
*Phase: 09-sbx-init-replaces-the-start-hooks*
*Completed: 2026-11-17*
