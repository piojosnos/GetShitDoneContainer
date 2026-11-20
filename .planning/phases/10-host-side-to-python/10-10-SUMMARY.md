---
phase: 10-host-side-to-python
plan: 10
subsystem: docs
tags: [docs, glossary, uv, json-registry, scenarios, claude-notes]

requires:
  - phase: 10-host-side-to-python
    provides: the Python host modules in sbx/, the JSON registry, sbx-migrate-registry, the integration scenarios, clean.sh in Python, tests/host removed
provides:
  - README, MIGRATION and ZSCALER describing uv, the two-line launchers, the NAME.json registry, the registry move and the first uv run behind a proxy
  - tests/README.md with the suites, the host run and the scenario rule
  - tests/host-checklist.md shrunk to the manual Cursor login check and how to read host-test.log
  - GLOSSARY.md with host launcher and image launcher, integration tests, scenario and step
  - .claude/CLAUDE.md stack notes for the Python host side
  - ROADMAP.md criteria 1, 4 and 5 and REQUIREMENTS.md HOST-04 with the scenario list
affects: [10-11]

actuals:
  tokens: 15200
  tasks: 3
  commits: 4
plan_head_before: 6ccda988a4b54ad527749629f21b44f0f5edbc2c
plan_head_after: 56f6b1b8007a60610bc9ed8ace1b24133f4ddfd3

tech-stack:
  added: []
  patterns:
    - "Docs name the scenario (the test function or file), never an ID"
    - "Three kinds of commit stay apart: docs and code, .claude/CLAUDE.md alone, .planning/ alone"

key-files:
  created: []
  modified:
    - README.md
    - MIGRATION.md
    - ZSCALER.md
    - tests/README.md
    - tests/host-checklist.md
    - GLOSSARY.md
    - .shellcheckrc
    - .claude/CLAUDE.md
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
    - compose.yml
    - sbx/hosttest_names.py
    - tests/guard/test_guard_isolation.py
    - tests/integration/support/best-practices/rules/sbx-fixture-always.md
    - tests/integration/support/best-practices/skills/sbx-fixture-one/SKILL.md
    - tests/integration/support/best-practices/skills/sbx-fixture-two/SKILL.md

key-decisions:
  - "MIGRATION.md keeps its one 'Move the registry to JSON' section; the real-move steps went in a new 'Move it' subsection ahead of the existing 'Try it on a copy first' subsection, which is unchanged"
  - "README quick start got a first row for uv (brew install uv), so its steps now run 1 to 10"
  - "tests/README.md says the host never runs a bare uv run, because the repo .venv belongs to the dev sandbox"
  - "GLOSSARY keeps the retired names (host check, tests/host/ file names, the numbered IDs) in the Retired column, so the old names stay searchable"

patterns-established:
  - "A test sandbox is named hosttest-AGENT; its container is sbx-hosttest-AGENT; docs name both once and then use the container name"

requirements-completed: []

coverage:
  - id: D1
    description: "README.md says the host needs Docker Desktop and uv (brew install uv) and nothing else, that every bin/ command, build.sh, clean.sh and host-test.sh is a two-line launcher into a module of sbx/ run through uv, that the registry is ~/.config/sbx/sandboxes/NAME.json with path and agent (shown as a JSON block), and that a bare uv run on the host is never used; the test sandboxes, the scenario names and the sbx-test-root-ca directory replace the numbered check IDs"
    requirement: HOST-01
    verification:
      - kind: unit
        ref: "plan Task 1 verify run by hand: every required fact present (brew install uv, NAME.json, sbx-migrate-registry, sbx-hosttest-claude, sbx-test-root-ca); no numbered check ID or bash 3.2 claim left; uv run pytest tests/guard passes (the GSD package rule still scans README.md and MIGRATION.md)"
        status: pass
  - id: D2
    description: "MIGRATION.md moves a host to the JSON registry in five numbered steps (install uv, pull the tools clone, sbx-migrate-registry, sbx-list, start each sandbox then delete its old file), says sbx-migrate-registry is one-off, and keeps the try-it-on-a-copy subsection; ZSCALER.md says the first uv run behind the proxy needs UV_SYSTEM_CERTS=true"
    requirement: HOST-02
    verification:
      - kind: unit
        ref: "read against sbx/migrate_registry.py (messages, exit status, old files left in place) and sbx/registry.py (entry keys); the plan's grep checks"
        status: pass
  - id: D3
    description: "tests/README.md lists every suite with its command and place (unit/sbx and guard in the dev sandbox and in ./host-test.sh; unit/init and unit/selfcheck in the dev sandbox only; integration through ./host-test.sh on the host only) and states the scenario rule once; tests/host-checklist.md holds only the Cursor login check and how to read host-test.log"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "read against sbx/host_test.py (suite order, flags, last line), tests/integration/conftest.py and scenario_helpers.py (sandbox fixture, step, --keep); host-checklist.md has 30 lines"
        status: pass
  - id: D4
    description: "GLOSSARY.md widens launcher to host and image launchers, keeps the agent wrapper separate, and replaces host check and the numbered IDs with integration tests, scenario and step; registry entry reads NAME.json; the retired host file names and host-test.sh step names are marked retired"
    requirement: HOST-05
    verification:
      - kind: unit
        ref: "every table row still has four columns (awk pipe count); git grep for a numbered check ID outside .planning/ and .claude/ is empty"
        status: pass
  - id: D5
    description: ".claude/CLAUDE.md describes the Python host side (sbx/, two-line uv launchers, the NAME.json registry, SbxError and run_command, pytest suites, scenario_helpers.py, agent_specs.py, sbx_helpers.py and step()); ROADMAP.md Phase 10 criteria 1, 4 and 5 and REQUIREMENTS.md HOST-04 carry the amended wording; each in its own commit"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "plan Task 3 verify: the .claude commit holds only .claude/CLAUDE.md, the planning commit only .planning/ files"
        status: pass
      - kind: manual_procedural
        ref: "real run: ./host-test.sh on the host at the phase's final check; the amended HOST-04 wording is checked by that run"
        status: not_run
    human_judgment: true
    rationale: "The scenarios in the amended wording have not run on a real host; the dev sandbox has no Docker"

duration: about 45min
completed: 2026-11-20
status: complete
---

# Phase 10 Plan 10: Docs, glossary, Claude notes and the amended roadmap Summary

**README, MIGRATION, ZSCALER, the test docs and the glossary now describe the Python host side (uv, two-line launchers, `NAME.json` registry, scenarios); `.claude/CLAUDE.md` and the planning record follow, each in a commit of its own kind.**

## Accomplishments

- **Task 1 (tracer): the user's path.** README: uv is the one new host prerequisite, each `bin/` command and the three root scripts is a two-line launcher into `sbx/`, the registry block is JSON with `path` and `agent`, `sbx-migrate-registry` is in the commands table, and "Verify a new build" lists scenarios instead of numbered checks. MIGRATION: a "Move it" subsection with five numbered steps ahead of the existing "Try it on a copy first". ZSCALER: install uv, then `UV_SYSTEM_CERTS=true sbx-list` for the first run, and a troubleshooting row.
- **Task 2: test docs, glossary, linter header.** `tests/README.md` (suites table, host run, the scenario rule, one table per suite), `tests/host-checklist.md` (30 lines), `GLOSSARY.md` (launcher widened, integration tests, scenario, step, registry entry `NAME.json`, retired names), `.shellcheckrc` header.
- **Task 3: the project notes and the planning record.** `.claude/CLAUDE.md` in one commit; ROADMAP criteria 1, 4 and 5 and REQUIREMENTS HOST-04 in another.

## Task Commits

1. **Task 1 (tracer): README, MIGRATION, ZSCALER**: `c23fa0b`
2. **Task 2: tests/README, host-checklist, GLOSSARY, .shellcheckrc and the stale comments**: `374bbbc`
3. **Task 3a: `.claude/CLAUDE.md` alone**: `65e118b`
4. **Task 3b: ROADMAP.md and REQUIREMENTS.md alone**: `56f6b1b`

**Plan metadata:** the commit holding this file (docs: complete plan)

## Decisions Made

- One section in MIGRATION.md, not two: the "Move it" steps sit in the existing "Move the registry to JSON" section and its try-on-a-copy subsection is untouched (its facts did not change).
- The quick start table got a uv row first, so the later steps renumber (1 to 10); nothing else in the docs refers to those numbers.
- `./host-test.sh` is described as a launcher that uses an isolated uv environment for pytest (its launcher line is `uv run --isolated --frozen`, unlike the `--no-project` of the others); the docs only say "uv makes its own environment, so the repo `.venv` is never touched", which holds for both.
- The glossary keeps the retired names in its Retired column (including the old `tests/host/` file names and the "H-nn" label), so a reader who meets an old name finds its replacement.

## Deviations from Plan

**1. [Rule 3 - Blocking] The Task 1 verify pattern `SBX_DIR=/Users` matches the raw Compose commands**
- **Found during:** Task 1 verify
- **Issue:** README's "Raw Docker commands" block runs `SBX_NAME=demo SBX_DIR=/Users/you/sbx-demo docker compose ...`, which is correct: raw Compose reads `SBX_DIR` from the environment. The pattern was meant to catch the old two-line registry block.
- **Fix:** the intent was checked with `grep -nE '^SBX_DIR=' README.md`, which prints nothing; the Compose lines stay.
- **Files modified:** none

**2. [Rule 2 - Missing] Stale "host check" wording in five files the plan did not list**
- **Found during:** Task 2 (the glossary retires "host check")
- **Issue:** comments in `compose.yml`, `tests/guard/test_guard_isolation.py`, `sbx/hosttest_names.py` and three fixture files under `tests/integration/support/best-practices/` still said "host check" or "host test run".
- **Fix:** reworded to "integration scenario" and "host run", comments and fixture prose only. `uv run pytest` still passes (982 passed, 1 skipped).
- **Files modified:** the six files above
- **Commit:** `374bbbc`

**3. [Scope] README says more about uv than the plan asked**
- The proxy section of the README has one bullet on `UV_SYSTEM_CERTS=true`; the quick start and the requirements name uv. ZSCALER's troubleshooting table has a uv row. The plan asked for the ZSCALER step only.

**4. [Process] The first Task 1 commit carried a Co-Authored-By line**
- Added by habit from the harness attribution note, against the user's rule of no attribution lines. The commit was amended at once, before any other commit and with nothing pushed; the final `c23fa0b` has none.

**Tracer gate:** after Task 1 the verify was re-run end to end (with the corrected pattern from deviation 1) and passed before Task 2 began. Mode was interactive with `end-of-phase` verification and an automated verify, so no checkpoint was needed.

## Issues Encountered

None.

## Requirements

- No requirement is newly marked complete. **HOST-05** was marked in an earlier plan. **HOST-04** stays **Pending**: its scenarios have not run on a real host. **HOST-01** and **HOST-02** also stay as earlier plans left them; the final plan's host run is where they are seen on a real host.

## User Setup Required

None. The docs now say what a host needs: Docker Desktop and `brew install uv`; behind a proxy, `UV_SYSTEM_CERTS=true` on the first run (ZSCALER.md).

## Known Stubs

None.

## Threat Flags

None. T-10-22: the only new prerequisite shown is uv from Homebrew; no curl-to-shell install appears; the guard's GSD package rule still passes over README.md and MIGRATION.md (`uv run pytest tests/guard`: 22 passed). T-10-SC: no package was installed.

## Next Phase Readiness

- Plan 11 runs the dev-sandbox gate and the host run of `./host-test.sh`. Things to read in `host-test.log`: the steps in the docs (the Cursor login check in `tests/host-checklist.md`) and whether the test sandbox names in README ("Verify a new build", "Free disk space") match what `docker ps -a` shows on the host.
- Known leftovers outside this plan: none; the only remaining mentions of `tests/host/` and the numbered check IDs outside `.planning/` are the Retired cells of `GLOSSARY.md`.

## Self-Check: PASSED

- Commits `c23fa0b`, `374bbbc`, `65e118b`, `56f6b1b` exist on `feat/host-side-to-python`; `git rev-list --count 6ccda98..HEAD` was 4 before this file was committed.
- `tests/README.md`, `tests/host-checklist.md`, `GLOSSARY.md`, `MIGRATION.md`, `ZSCALER.md` and `README.md` exist with the required facts; `git grep` for a numbered check ID outside `.planning/` and `.claude/` prints nothing; `uv run pytest -q`: 982 passed, 1 skipped.
