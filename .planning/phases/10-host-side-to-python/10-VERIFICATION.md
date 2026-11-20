---
phase: 10-host-side-to-python
verified: 2026-11-20T12:00:00Z
status: passed
score: 6/6 must-haves verified
covered_files:
  - .planning/phases/10-host-side-to-python/10-01-PLAN.md
  - .planning/phases/10-host-side-to-python/10-01-SUMMARY.md
  - .planning/phases/10-host-side-to-python/10-02-PLAN.md
  - .planning/phases/10-host-side-to-python/10-02-SUMMARY.md
  - .planning/phases/10-host-side-to-python/10-03-PLAN.md
  - .planning/phases/10-host-side-to-python/10-03-SUMMARY.md
  - .planning/phases/10-host-side-to-python/10-04-PLAN.md
  - .planning/phases/10-host-side-to-python/10-04-SUMMARY.md
  - .planning/phases/10-host-side-to-python/10-05-PLAN.md
  - .planning/phases/10-host-side-to-python/10-05-SUMMARY.md
  - .planning/phases/10-host-side-to-python/10-06-PLAN.md
  - .planning/phases/10-host-side-to-python/10-06-SUMMARY.md
  - .planning/phases/10-host-side-to-python/10-07-PLAN.md
  - .planning/phases/10-host-side-to-python/10-07-SUMMARY.md
  - .planning/phases/10-host-side-to-python/10-08-PLAN.md
  - .planning/phases/10-host-side-to-python/10-08-SUMMARY.md
  - .planning/phases/10-host-side-to-python/10-09-PLAN.md
  - .planning/phases/10-host-side-to-python/10-09-SUMMARY.md
  - .planning/phases/10-host-side-to-python/10-10-PLAN.md
  - .planning/phases/10-host-side-to-python/10-10-SUMMARY.md
  - .planning/phases/10-host-side-to-python/10-11-PLAN.md
  - .planning/phases/10-host-side-to-python/10-11-SUMMARY.md
  - bin/sbx-add
  - host-test.sh
  - sbx/add.py
  - sbx/cli.py
  - sbx/fix_modes.py
  - sbx/overlap.py
  - sbx/registry.py
  - sbx/rm.py
covered_digest: "v2:sha256:1dfe2ddb3aa8ffe5952aeedf6a4413ef4fd5ca279fc646b29254b9a398d4062a"
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "On the Mac, from the branch tip (52a3289), run ./host-test.sh and read host-test.log to its last line"
    expected: "Ends on 'host-test.sh: every test passed' with the same 16 scenarios per agent (claude, cursor) plus the pin digest test; the :local image ids are unchanged"
    why_human: "The only host run was at cff842e. Commits b930dfb..e9b233c changed sbx/cli.py (run_command, used by every command), sbx/rm.py, sbx/fix_modes.py and four test files after it. They are unit tested (991 passed here) but Docker is not available in the dev sandbox, so the final code has not run against real Docker. Success criterion 5 reads './host-test.sh passes on the host'."
---

# Phase 10: Host side to Python Verification Report

**Phase Goal:** Every host command and its tests are short Python run through `uv`, with one JSON registry file per sandbox. The command names stay, and the bash host scripts, the bash host tests and the last of the fake docker are gone.
**Verified:** 2026-11-20
**Status:** human_needed
**Re-verification:** No, initial verification

## Goal Achievement

All six roadmap success criteria hold in the code. The one open item is a confirmation run, not a gap: the host run predates the review fixes.

### Observable Truths

| # | Truth (roadmap success criterion) | Status | Evidence |
|---|-----------------------------------|--------|----------|
| 1 | Every `bin/sbx-*` command, `build.sh` and `./host-test.sh` keep their names and are two-line launchers into Python run through `uv` | VERIFIED | Read all 12 files (9 in `bin/`, `build.sh`, `clean.sh`, `host-test.sh`): each is `#!/bin/sh` plus one `exec uv run --directory ... python -m sbx.<module> "$@"` line. The guard rule `test_every_launcher_is_two_lines_into_an_existing_module` enforces two lines, an existing module with a `main`, and git mode 100755. Names match the v1 set. Host run at cff842e passed using them. |
| 2 | `sbx-add` writes `NAME.json` with `path` and `agent`; every other command reads the sandbox from that file | VERIFIED | Ran `bin/sbx-add one <dir>` with a scratch `SBX_CONFIG_DIR`: wrote `sandboxes/one.json` holding exactly `path` and `agent` (`claude`); `six` with `cursor` wrote agent `cursor`. `sbx/registry.py` is the only reader (`read_entry`, `list_entry_names`, JSON parse, never executed). `add`, `rm`, `fix_modes`, `list_sandboxes`, `start`, `stop`, `shell`, `upgrade` import it. |
| 3 | `sbx-add` refuses a directory that is, holds or sits inside another sandbox's directory, also through a symlink or `..`, because both paths are resolved before comparing | VERIFIED | `sbx/overlap.py` resolves both with `os.path.realpath` and compares with `samefile`; unresolvable counts as overlap. Live run against registered sandbox `a`: a path through a symlink to its parent (`link/inner`), a symlink straight to a subdirectory (`linkinner`), a child (`a/zz`) and the parent of the registry were all refused with exit 1; a `..` part is refused by `check_host_path`. A disjoint path registered. Unit tests in `tests/unit/sbx/test_sbx_overlap.py` and `test_sbx_add.py` cover the same cases. |
| 4 | On the host the pytest suite runs the scenarios for Claude and for Cursor; a scenario stops at its first failed step and names it | VERIFIED | `tests/integration/` has the files for persistence, failed upgrade, refusal (two), lifecycle, list, rm, shell, git on a host repo, isolation, first run and relink (two), init and selfcheck, owner fix, images match versions, plus the running-sandbox upgrade. host-test.log at cff842e lists 16 tests per agent, all PASSED, plus `test_pin_digests`. Failure naming: `scenario_helpers.step()` adds a `STEP FAILED: name` note to the exception that ends the test. |
| 5 | No host logic is in bash; no bash host script, bash host test or fake docker is left; `./host-test.sh` passes on the host | VERIFIED for the content; host pass is at cff842e (see Human Verification) | `git ls-files` shows no shell file outside the launchers (plus image-side files that are out of scope); `tests/host/` and `tests/selftest/` are gone; `bin/sbx-lib.sh` is gone; grep for `fake-docker`, `FakeDocker` and `stand-in docker` in code and live docs finds only planning history. Guard rule `test_no_host_logic_in_shell` enforces it (passes). host-test.log ends `550 passed, 1 skipped` and `host-test.sh: every test passed`. |
| 6 | The host tests are one shared harness run per agent: common checks written once, few small checks differ | VERIFIED | `tests/integration/agent_specs.py` holds one `AgentSpec` row per agent (login file, session dir, settings file, wrapper, version pin, counts); the session fixture in `conftest.py` is parametrized over `AGENT_SPEC_LIST`. The only agent-specific branches in the scenarios are six `if agent.<field> is not None` or `links_rules` guards in two test files. |

**Score:** 6/6 truths verified (0 behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `bin/sbx-*` (9), `build.sh`, `clean.sh`, `host-test.sh` | Two-line launchers | VERIFIED | Read in full; guard passes |
| `sbx/*.py` (add, build, clean, cli, docker, fix_modes, host_test, hosttest_names, list_sandboxes, migrate_registry, names, overlap, registry, rm, shell, start, stop, upgrade) | One module per command, `main` defined | VERIFIED | Substantive and wired; Docker is injected as a parameter |
| `tests/integration/*` and `tests/guard/*`, `tests/unit/*` | Pytest scenarios, guard, unit tests | VERIFIED | `uv run pytest -q` run here: 991 passed, 1 skipped |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `bin/sbx-add` | `sbx.add` | `uv run ... python -m sbx.add` | WIRED | Run live |
| `sbx.add` | `sbx.overlap`, `sbx.registry` | import, called before `write_entry` | WIRED | Registry, repo and sandbox overlap checks run before the directories are made |
| `sbx.rm`, `sbx.fix_modes` | `sbx.registry.read_entry` | import | WIRED | Both read `entry.path` |
| `tests/integration/conftest.py` | `agent_specs.AGENT_SPEC_LIST` | parametrized session fixture | WIRED | Two agents, one harness |
| `host-test.sh` | `sbx.host_test` | `uv run --isolated --frozen` | WIRED | Produced host-test.log |

### Data-Flow Trace (Level 4)

Not applicable beyond the registry: the entry file content flows from `sbx-add` argument to JSON on disk to the reading commands, shown by the live run above.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full pytest suite | `uv run pytest -q` | 991 passed, 1 skipped in 10.4 s | PASS |
| `sbx-add` writes JSON with `path`, `agent` | `bin/sbx-add one DIR` then `cat one.json` | `{path, agent}` | PASS |
| Overlap via symlink, symlinked subdir, child, parent | `bin/sbx-add` with each | exit 1, overlap message each | PASS |
| `..` path | `bin/sbx-add four DIR/a/inner/../x` | exit 1, "empty, . or .. part" | PASS |
| Cursor agent argument | `bin/sbx-add six DIR cursor` | registered, agent cursor | PASS |
| Usage error | `bin/sbx-shell` | `Usage: sbx-shell NAME`, exit 2 | PASS |

### Probe Execution

SKIPPED: the phase declares no `probe-*.sh`; its probe is `./host-test.sh`, which needs Docker (see Human Verification).

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|--------------|-------------|--------|----------|
| HOST-01 | 10-01, 02, 03, 04, 05, 07, 10, 11 | `bin/sbx-*`, `build.sh`, `host-test.sh` are Python through `uv` | SATISFIED | Truth 1 |
| HOST-02 | 10-01, 02, 10, 11 | One `NAME.json` per sandbox with `path` and `agent` | SATISFIED | Truth 2 |
| HOST-03 | 10-02, 11 | Overlap check resolves both paths | SATISFIED | Truth 3 |
| HOST-04 | 10-05, 06, 07, 08, 09, 10, 11 | Pytest scenarios per agent | SATISFIED | Truths 4 and 6; the scenario list was amended by the user (33 tests including a running-sandbox upgrade scenario) |
| HOST-05 | 10-03, 04, 09, 10, 11 | Bash host scripts, tests and fake docker gone | SATISFIED | Truth 5 |

All five IDs appear in plan frontmatter and in REQUIREMENTS.md (marked complete, traceability rows point to Phase 10). No orphaned requirement: REQUIREMENTS.md maps no other ID to Phase 10.

### Anti-Patterns Found

No `TBD`, `FIXME` or `XXX` marker in `sbx/`, `tests/`, `bin/` or the root scripts. No stub behavior found in the modules read.

Review follow-up (10-REVIEW.md, status resolved): the critical finding CR-01 (sbx-fix-modes followed symlinks out of the mount) is fixed in `sbx/fix_modes.py` by `_is_inside` plus two unit tests (symlinked directory, relative symlink to a parent). WR-04 and WR-05 are fixed (`run_command` handles Ctrl-C and `OSError`; `sbx-rm --unregister` requires the `sbx.name` label via `_require_sandbox_label`), each with a test. WR-01 and WR-02 are accepted by the user. WR-03, IN-01 (unused `docker` parameter), IN-02 and IN-04 were not fixed and not in the approved subset; none blocks a roadmap criterion.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `sbx/clean.py` | 62-72 | `clean.sh` removes `sbx-hosttest-*` directories by name prefix (WR-02, accepted) | Warning | Possible data loss for a user sandbox named under that prefix; user accepted |
| `sbx/registry.py` | 107-118 | Non-atomic entry write (WR-01, accepted) | Warning | A crash mid-write leaves a broken entry; `sbx-rm NAME --unregister` clears it |
| `sbx/clean.py`, `sbx/hosttest_names.py` | 100-110, 57-64 | Substring match of the run-directory marker (WR-03, open) | Warning | Narrow mis-classification of a mount under a path containing `/tmp/sbx-hosttest-`; deferred, not blocking |

### Deliberate Deviations (accepted, not gaps)

- 33 integration tests instead of the planned 31: an added running-sandbox upgrade scenario, approved by the user.
- `sbx-stop` checks only the name and the entry, not the directory.
- WR-01 and WR-02 accepted by the user.
- ROADMAP.md still shows the top-level Phase 10 line as `[ ]` (line 43) while the plan list is all checked and requirements are complete; the orchestrator closes it when the phase is marked done.

### Human Verification Required

#### 1. Re-run the host suite on the final branch tip

**Test:** On the Mac, check out `feat/host-side-to-python` at 52a3289 and run `./host-test.sh`; read `host-test.log` to its last line.
**Expected:** `host-test.sh: every test passed`, 16 scenarios per agent plus the pin digest test, `:local` image ids unchanged.
**Why human:** Docker is not available in the dev sandbox, and the one host run (550 passed, 1 skipped, at cff842e) is older than the review fixes. `sbx/cli.py`'s `run_command` wraps every command, so its new `except OSError` and `except KeyboardInterrupt` branches sit on every integration path; `sbx-rm` is exercised by `test_sandbox_rm` (the healthy path; the broken-entry label check is unit tested only); `sbx-fix-modes` is touched by `test_sandbox_lifecycle`. The fixes are small and unit tested, so a failure is unlikely, but criterion 5 says the host run passes, and that was last observed on different code. About three minutes of the user's time. If it passes, the phase is `passed`.

The earlier manual `sbx-shell` check (`shell exit 4`) was valid; the `130` was plain `exit` typed after Ctrl-C and was rerun correctly.

### Gaps Summary

No gaps. All six success criteria and all five requirement IDs are met in the code, and the pytest suite passes here (991 passed, 1 skipped). The phase is held at `human_needed` only because the Docker-backed integration suite has not been run on the code as it stands after the review fixes.

---

_Verified: 2026-11-20_
_Verifier: Claude (gsd-verifier)_

## Human verification result

Host re-run of `./host-test.sh` at 48dafc1 (2026-11-20): 559 passed, 1 skipped; 16 scenarios PASSED for each of claude and cursor; last line `host-test.sh: every test passed`. Status set to passed.
