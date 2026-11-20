---
phase: 10-host-side-to-python
plan: 11
subsystem: testing
tags: [phase-gate, host-test, uv, pytest, pr-branches, docker-desktop]

requires:
  - phase: 10-host-side-to-python
    provides: the Python host commands, the JSON registry, the integration scenarios, clean.sh in Python, the docs (plans 10-01 to 10-10)
provides:
  - the dev-sandbox phase gate record (suites, counts, layout, modes, sweeps)
  - three local PR branches, one kind of change each, nothing pushed
  - the host proof: ./host-test.sh passes on macOS with every scenario for Claude and Cursor
affects: [10.1, 10.1.1, 10.2]

actuals:
  tokens: 3600
  tasks: 3
  commits: 0
plan_head_before: cff842e51ce02589d7890230f5c016ede70e4250
plan_head_after: cff842e51ce02589d7890230f5c016ede70e4250

tech-stack:
  added: []
  patterns:
    - "A phase closes with a dev-sandbox gate, local one-kind PR branches, then one host run"

key-files:
  created: []
  modified: []

key-decisions:
  - "The PR branches are built by cherry-pick from origin/main in temporary worktrees; the upstreams of the two new branches are unset so a bare push cannot target main"
  - "HOST-01 to HOST-04 are marked complete on the strength of the host run plus the dev-sandbox unit suites (reasons below)"

patterns-established:
  - "The host gate reads host-test.log and python-host-gate.log, and ends on the last line 'host-test.sh: every test passed'"

requirements-completed: [HOST-01, HOST-02, HOST-03, HOST-04, HOST-05]

coverage:
  - id: D1
    description: "uv run pytest passes in the dev sandbox for every suite"
    requirement: HOST-05
    verification:
      - kind: unit
        ref: "uv run pytest -q: 982 passed, 1 skipped"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every host command, build.sh, clean.sh and host-test.sh is a two-line launcher into Python run through uv"
    requirement: HOST-01
    verification:
      - kind: integration
        ref: "host-test.log: 550 passed, 1 skipped; launcher tests in tests/unit/sbx/test_sbx_launchers.py"
        status: pass
    human_judgment: false
  - id: D3
    description: "The registry is one NAME.json per sandbox with path and agent, and the overlap check resolves both paths"
    requirement: HOST-02
    verification:
      - kind: unit
        ref: "tests/unit/sbx (495 passed in the dev sandbox; the same suite passed on the host)"
        status: pass
      - kind: integration
        ref: "host-test.log: sandboxes made with the real sbx-add for both agents"
        status: pass
    human_judgment: false
  - id: D4
    description: "Every scenario passes for Claude and for Cursor on real Docker Desktop, plus the pin digest test"
    requirement: HOST-04
    verification:
      - kind: integration
        ref: "host-test.log: 16 scenarios PASSED for [claude], 16 for [cursor], test_every_pinned_digest_resolves PASSED"
        status: pass
    human_judgment: false
  - id: D5
    description: "sbx-shell hands its exit status and Ctrl-C to the shell through the uv parent"
    verification:
      - kind: manual_procedural
        ref: "python-host-gate.log: shell exit 4 after Ctrl-C stopped only sleep 30"
        status: pass
    human_judgment: true
    rationale: "Ctrl-C handling needs a person at a real terminal; the scenario only covers the exit status"

duration: 95min
completed: 2026-11-20
status: complete
---

# Phase 10 Plan 11: The phase gate and the host run Summary

**The Python host side passes on a real macOS host with only uv added: 550 tests passed in 134 s, all 16 scenarios for both Claude and Cursor, the `:local` images untouched, and three local PR branches ready for the user's push go.**

## Performance

- **Duration:** about 95 min, mostly the host run and the manual checks
- **Tasks:** 3 of 3 (Task 3 was the blocking host gate; the user answered "approved")
- **Files modified:** none on the working branch; this SUMMARY and the planning records are the only changes

## Task 1: dev-sandbox gate (no commit, read-only)

| Check | Result |
|---|---|
| `uv run pytest -q` | 982 passed, 1 skipped |
| tests/unit/selfcheck | 323 passed |
| tests/unit/init | 142 passed |
| tests/unit/sbx | 495 passed, 1 skipped |
| tests/guard | 22 passed |
| tests/integration collected | 33 tests (16 scenarios for each agent plus the pin digest test) |
| bin/ | 9 launchers |
| launchers | all 12 launchers, plus build.sh, clean.sh and host-test.sh, are two lines, `#!/bin/sh`, mode 100755 in git |
| removed | bin/sbx-lib.sh, tests/host, tests/unit/lib-expect.sh and every tracked `tests/**/*.sh` are gone |
| commits 8b5c955..HEAD | 65, none mixes kinds; no test module basename repeats |
| sweeps | non-ASCII, planning IDs, dash punctuation, H-nn IDs, monkeypatch and mock.patch, the compromised package names, agent literals in scenario files: all empty |

The one skip is `tests/unit/sbx/test_sbx_launchers.py:97` ("build.sh takes any argument"). It is by design: build.sh passes its arguments through, so the wrong-argument-count test does not apply to it. It is not a defect and not recorded in the broken-windows ledger.

## Task 2: local PR branches (nothing pushed)

| Branch | Tip | Content |
|---|---|---|
| `feat/host-side-to-python-code` | 86ab0b6 | 44 code commits on origin/main (8b5c955); its code tree equals the working branch |
| `chore/claude-md-host-python` | 00f44c3 | 1 commit, `.claude/CLAUDE.md` only |
| `chore/planning-phase-10-context` | f968482 | 20 commits ahead of origin/main (the 8 original plus 12 `.planning/` only commits) |

The upstreams of the two new branches are unset so a bare `git push` cannot target main. `git ls-remote` shows none of them on the remote.

Waiting for the user's explicit go, per branch (PR text carries no AI attribution):

1. `git push -u origin feat/host-side-to-python-code`, then `gh pr create --base main --head feat/host-side-to-python-code`
2. `git push -u origin chore/claude-md-host-python`, then `gh pr create --base main --head chore/claude-md-host-python` (merge it after the code PR, because it describes the new layout)
3. `git push -u origin chore/planning-phase-10-context`, then `gh pr create --base main --head chore/planning-phase-10-context` (after the phase-completion commits are added the same way; the orchestrator does that after verification)

## Task 3: the host gate (user ran it on macOS at cff842e)

Evidence: `/home/sandbox/workspace/get-shit-done-container/host-test.log` and `/home/sandbox/workspace/python-host-gate.log`.

- `./host-test.sh --keep`: 550 passed, 1 skipped in 134.25 s; last line `host-test.sh: every test passed; log: ...host-test.log`. No FAILED or `STEP FAILED:` line.
- Integration: 16 distinct scenarios PASSED for `[claude]` and 16 for `[cursor]`; `test_every_pinned_digest_resolves` PASSED. Its INFO line says the UBUNTU_IMAGE pin differs from the registry's newer image; that is expected and means "bump the pin when convenient".
- Image ids: `sbx-base:local` aa738f6795d2, `sbx-claude:local` 5cc1c6aca6f3, `sbx-cursor:local` c6eb0aba9919, identical before and after the run. The run built and kept only `:test` images.
- Manual shell check: the first attempt logged `shell exit 130`. The user typed plain `exit` after Ctrl-C, and bash returns the interrupted `sleep`'s 130, so this was the check being done wrong, not a defect. The rerun on `hosttest-claude`: Ctrl-C stopped only `sleep 30`, the prompt came back, `exit 4` gave `shell exit 4`.
- A `bash: history: .../state/shell/bash_history: cannot create` warning appeared in that shell because the throwaway sandbox never ran `sbx-init` (which makes `state/shell`). Expected, not a defect.
- `./clean.sh` dry run: marks only this run's 12 `sbx-hosttest-*` containers, lists the run directory and the two root certificate directories, keeps every user sandbox, and ends `Dry run: nothing removed.`
- `git status --short` on the host: no `.venv` line (D-03 holds).
- Step 6: `sbx-rm` of `hosttest-claude` and `hosttest-cursor` ran; both are absent from the kept `cfg` listing.

Flagged assumptions confirmed by the passing run: A2 (`pty` drives `docker exec -it` through the launcher), A3 (`cursor-agent --version` prints the pin; the versions scenario passed), A4 (Cursor GSD sync writes its VERSION; the Cursor scenarios passed), A5 (Docker Desktop shares `$TMPDIR`; every sandbox lived there), A6 (`sbx-shell` works under uv: `shell exit 4` and Ctrl-C). None was refuted.

## Requirements

| ID | Marked | Why |
|---|---|---|
| HOST-01 | complete | every `bin/sbx-*`, `build.sh`, `clean.sh` and `host-test.sh` is a two-line `#!/bin/sh` launcher into Python run through uv (Task 1 layout check); the host ran them all with only uv added |
| HOST-02 | complete | the registry is one `NAME.json` with `path` and `agent` (unit suite, and the scenarios made their sandboxes with the real `sbx-add` and read them back with every other command) |
| HOST-03 | complete | the overlap check resolves both paths before comparing; the plan-02 unit tests cover same, inside, holds, symlink, `..`, text-prefix sibling and unresolvable, and the suite passed on the host |
| HOST-04 | complete | the wording matches what ran: the listed scenarios for each agent, each stops at its first failed step and names it; all PASSED on real Docker |
| HOST-05 | already complete | unchanged |

HOST-01 to HOST-03 rest on unit tests plus the host run rather than a dedicated host scenario each; the verifier can still re-check them.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Stale plan count] Integration collects 33 tests, not 31**
- **Found during:** Task 1
- **Issue:** the plan's count check expected 31 tests (15 scenarios for each agent plus the pin digest test). Plan 10-09 added `tests/integration/test_upgrade_running_sandbox.py` at the user's request, so each agent runs 16 scenarios and the suite collects 33.
- **Fix:** none needed in code; the count in the plan was stale. The host run matches the new count (16 distinct scenarios for each agent).
- **Files modified:** none
- **Commit:** none

### Other notes

- The first manual shell check logged `shell exit 130`; see Task 3. It was the user's exit method, and the rerun passed. No code change.

## Auth gates

None.

## Known Stubs

None.

## Threat Flags

None. No file changed in this plan.

## Open items for the user

- Per-branch push go for the three branches above.
- The user moves their real registry with `sbx-migrate-registry` from the tools clone after the code PR is merged and pulled there (MIGRATION.md). It was not part of this gate.
- Bump the UBUNTU_IMAGE pin when convenient (the pin digest test reports a newer image).

## Self-Check: PASSED

- 10-11-PLAN.md, host-test.log and python-host-gate.log read and cited.
- Branch tips 86ab0b6, 00f44c3 and f968482 exist locally.
