---
phase: 10-host-side-to-python
plan: 04
subsystem: testing
tags: [python, pytest, guard, supply-chain, isolation, launchers, shellcheck, hadolint]

requires:
  - phase: 10-host-side-to-python
    provides: the sbx package, the two-line uv launcher shape and the Python host modules the guard now scans
provides:
  - tests/guard/guard_helpers.py (REPO_DIR, the file lists, nowhere_matches, run_linter)
  - 20 pytest twins of the bash guard rules, over the old files and the new Python code
  - the launcher rule (two lines, an existing module with main, git mode 100755)
  - the linter fallback that runs shellcheck and hadolint from sbx-base:test through docker run
affects: [10-05, 10-09, 10-10, 10-11]

actuals:
  tokens: 21000
  tasks: 3
  commits: 5
plan_head_before: 5490a24d543fe80e76f7932906eeece2bb1f5088
plan_head_after: 8c144e0ae49da05ef748ec80ae4762ceaacedcda

tech-stack:
  added: []
  patterns:
    - "File lists are pathlib globs evaluated when a rule runs; a file a later plan deletes drops out by itself, and an empty list fails the rule as no file to scan"
    - "The linter fallback is a docker run of the test base image with the repo mounted read-only; no stand-in script is written"
    - "tests/guard is in none of its own scan lists, because the rule files name the strings they forbid"

key-files:
  created:
    - tests/guard/guard_helpers.py
    - tests/guard/test_guard_linters.py
    - tests/guard/test_guard_isolation.py
    - tests/guard/test_guard_start.py
    - tests/guard/test_guard_supply_chain.py
    - tests/guard/test_guard_launchers.py
  modified:
    - pyproject.toml
  deleted:
    - tests/guard/lib.sh
    - tests/guard/run-all.sh
    - tests/guard/linters.sh
    - tests/guard/isolation.sh
    - tests/guard/start.sh
    - tests/guard/supply-chain.sh

key-decisions:
  - "The Python delete pattern of the keep-data rule also matches single-quoted Docker verbs, so a verb quoted either way is caught"
  - "test_python_list carries __test__ = False so pytest does not collect the helper when a rule file imports it"
  - "The keep-data rule scans only the launchers in bin/ for the bash word list, because build.sh and the still-bash clean.sh are not host commands that must stay free of deletion words"

patterns-established:
  - "A guard rule is one test function named after the old bash rule, with a banner whose why lines carry the old rule comment"
  - "A planted probe (a forbidden string in a new sbx module, a bad launcher in bin/) proves a rule fires; the probe is removed before the commit"

requirements-completed: []

coverage:
  - id: D1
    description: "The guard is pytest: one test per bash rule, named test_<rule name>, in tests/guard/test_guard_*.py, in testpaths, and 21 pass with the new launcher rule"
    requirement: HOST-05
    verification:
      - kind: unit
        ref: "uv run pytest tests/guard -q (21 passed)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The file lists include sbx/*.py and the Python tests outside tests/guard; a rmtree and a get-shit-done-cc string planted in a new sbx module failed the keep-data and the compromised-package rules"
    requirement: HOST-05
    verification:
      - kind: unit
        ref: "planted sbx/zz_guard_probe.py, then pytest tests/guard -k 'keep_sandbox_data or compromised' (2 failed); probe removed"
        status: pass
    human_judgment: false
  - id: D3
    description: "shellcheck and hadolint run natively when installed, else from sbx-base:test through docker run with the repo mounted read-only; with neither, the rule fails and names ./host-test.sh; nothing is written to disk"
    requirement: HOST-05
    verification:
      - kind: unit
        ref: "native path: test_shellcheck_passes and test_hadolint_passes pass; no-tool path: run_linter with a PATH lacking both tools returned status 1 and the ./host-test.sh message"
        status: pass
      - kind: manual_procedural
        ref: "docker run of sbx-base:test on the macOS host (docker is not installed in the dev sandbox)"
        status: not_run
    human_judgment: true
    rationale: "The docker run branch needs Docker and the test image, which exist only on the host"
  - id: D4
    description: "Every launcher (each bin/ file, and build.sh, clean.sh, host-test.sh when they start with #!/bin/sh) has exactly two lines, the pinned exec uv run line with /.. exactly in bin/, an existing sbx module that defines main, and git mode 100755"
    requirement: HOST-01
    verification:
      - kind: unit
        ref: "tests/guard/test_guard_launchers.py; a planted bin/ file with a different second line and one naming a missing module both failed it"
        status: pass
    human_judgment: false
  - id: D5
    description: "tests/guard holds only Python files; the six bash guard files are deleted"
    requirement: HOST-05
    verification:
      - kind: unit
        ref: "ls tests/guard; uv run pytest -q (885 passed, 1 skipped)"
        status: pass
    human_judgment: false

duration: about 10min (commits 01:59 to 02:01 UTC; the start time was not recorded)
completed: 2026-11-20
status: complete
---

# Phase 10 Plan 04: The guard as pytest Summary

**The 20 bash guard rules now run as pytest over the old files and the new Python code, a 21st rule pins the shape, module and git mode of every launcher, and the bash guard is deleted.**

## Performance

- **Duration:** about 10 min (commits 01:59 to 02:01 UTC)
- **Completed:** 2026-11-20
- **Tasks:** 3 (one tracer, two auto)
- **Files changed:** 14 (6 created, 1 modified, 6 deleted, plus this summary and the state files)

## Accomplishments

- `tests/guard/guard_helpers.py`: `REPO_DIR`, the file lists (`dockerfile_list`, `compose_file`, `launcher_list`, `image_script_list`, `shell_file_list`, `host_python_list`, `test_python_list`, `sandbox_file_list`), `nowhere_matches` (hits as `path:line: text`, an empty list raises "no file to scan", an unreadable file is a hit) and `run_linter`.
- `run_linter` uses the tool on the PATH, else `docker run --rm -v REPO:REPO:ro -w REPO --entrypoint TOOL sbx-base:test`, else returns 1 with `... ./host-test.sh builds it`. Nothing is written.
- Rules ported with their regexes (POSIX classes turned into `\s` and `\S`): 2 linters, 5 isolation, 3 start, 10 supply chain. The keep-data rule now reads `sbx/*.py` except `rm.py` and `clean.py` for deletion calls and the Docker verbs rm, rmi, down, prune and kill and `--volumes`. The compromised-package rule lists `sbx/*.py` through `sandbox_file_list` and every Python test outside `tests/guard`, `tests/integration/support` and `tests/host/support`.
- `test_every_launcher_is_two_lines_into_an_existing_module` reads the git index for the mode, so a script that lost its exec bit on a sandbox edit is caught on the host.
- Results: `uv run pytest tests/guard -q` 21 passed; `uv run pytest -q` 885 passed, 1 skipped.

## Task Commits

1. **Task 1: helpers and the two linter rules (tracer)**: `a5a50bb` (test) and `c311f1b` (chore, testpaths). Both automated verifies passed (2 passed, the bash guard still ended `All rules hold.`) before Task 2 began, so the slice was proven before it was expanded.
2. **Task 2: isolation, start and supply-chain rules**: `483e638` (test, 18 rules)
3. **Task 3: the launcher rule; the bash guard goes**: `e3b6718` (test) and `8c144e0` (chore, six files deleted)

**Plan metadata:** the commit holding this file (docs: complete plan)

## Decisions Made

- The Python delete pattern also matches a Docker verb in single quotes, which the plan's pattern (double quotes only) would have missed.
- `test_python_list` is marked `__test__ = False`, pytest's own opt-out, because its name starts with `test_` and a rule file imports it.
- The bash-word half of the keep-data rule scans `bin/` launchers only (not `build.sh` or `clean.sh`), as the bash rule scanned `bin/*` only; `clean.sh` is still bash with real `rm` calls until it is ported.
- `shell_file_list` globs `tests/**/*.sh`, one level deeper than the old `tests/*/*.sh`; today the two lists name the same files.

## Deviations from Plan

None in behavior. Two small additions to the helper module: `line_list` and `relative_name` and `relative_name_list`, used by the rule files so each one stays free of path and line plumbing.

## Issues Encountered

None.

## Requirements left Pending, and why

- **HOST-01** stays Pending: `host-test.sh` and `clean.sh` are still bash. This plan finished the launcher rule that will cover them once they are two-line launchers.
- **HOST-05** stays Pending: the bash guard is gone, but `host-test.sh`, `clean.sh`, `tests/host/` and the last of the fake docker still exist.
- **HOST-02, HOST-03, HOST-04** stay Pending (unchanged from plan 10-03).

## User Setup Required

None. On the host the guard runs after the integration tests in the same pytest session (plan 10-05 orders the paths), so `sbx-base:test` exists when the linter rules need it.

## Known Stubs

None.

## Threat Flags

None. T-10-10 holds: the compromised-package and pipe-to-shell rules scan the new Python code and tests, and a planted probe in `sbx/` failed the keep-data and package rules. T-10-11 holds: the launcher rule pins the exact exec line and the module. T-10-SC: no package installed and no pin changed.

## Next Phase Readiness

- `host-test.sh` still runs `bash tests/guard/run-all.sh` in two steps (`sandbox_suites` and `host_guard`); those steps are dead and the file still sources the deleted bash library, so it cannot run until plan 10-05 replaces it. `tests/README.md` and `GLOSSARY.md` still name `tests/guard/run-all.sh` and `tests/guard/start.sh`; the documentation plans of the phase (10-09 and 10-10 name `tests/README.md`) should update them.
- The no-local-tag rule already names `sbx/host_test.py`, `sbx/hosttest_names.py` and `tests/integration/**/*.py`, so it starts covering them as soon as they exist.

## Self-Check: PASSED

- Commits `a5a50bb`, `c311f1b`, `483e638`, `e3b6718`, `8c144e0` exist on `feat/host-side-to-python`; `git rev-list --count 5490a24..HEAD` was 5 before this file was committed.
- `tests/guard` lists only `guard_helpers.py` and the five `test_guard_*.py` files (plus `__pycache__`); no `.sh` file remains there.
- `grep -nE 'open\([^)]*"w"|write_text|chmod' tests/guard/*.py`, the `:local` grep on `guard_helpers.py`, the non-ASCII grep, and the planning-ID grep over `tests/guard` all print nothing; the probe `sbx/zz_guard_probe.py` does not exist.
- `uv run pytest tests/guard -q`: 21 passed; `uv run pytest -q`: 885 passed, 1 skipped.
