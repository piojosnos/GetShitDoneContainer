---
phase: 10-host-side-to-python
plan: 08
subsystem: testing
tags: [python, pytest, integration, docker, best-practices-clone, sbx-init, owner-fix, pins]

requires:
  - phase: 10-host-side-to-python
    provides: the integration harness (AgentSpec rows, step, run_timeout, docker_exec, sandbox and best_practices_origin fixtures), the throwaway-sandbox helpers of plan 07
provides:
  - test_first_run_refuses_then_inits_from_the_clone and test_relink_after_a_pull (both agents)
  - test_init_gives_root_owned_state_back (both agents)
  - test_image_versions_match_the_repo (both agents)
  - test_every_pinned_digest_resolves (once, not per agent)
  - 13 unit cases for the pure helpers of these scenarios
affects: [10-09, 10-10, 10-11]

actuals:
  tokens: 9400
  tasks: 2
  commits: 3
plan_head_before: 17570e3798545a5d7f2aebba771263050815fa77
plan_head_after: 6c7785650f6ad607af6a21543de467639a688cbe

tech-stack:
  added: []
  patterns:
    - "Agent differences in a scenario come from AgentSpec: wrapper, binary, version pin, links step, init step count, rules link; the live-link target (rules directory for Claude, a skill directory for Cursor) is one small function"
    - "The origin of a throwaway sandbox is a bare copy of the run's origin inside the sandbox directory, so the container reaches it under the workspace path and a push never changes the run's origin"
    - "A root container that plants state is named, offline, and removed in a finally block"

key-files:
  created:
    - tests/integration/test_first_run_and_relink.py
    - tests/integration/test_owner_fix.py
    - tests/integration/test_images_match_versions.py
    - tests/integration/test_pin_digests.py
    - tests/unit/sbx/test_sbx_integration_text_helpers.py
  modified: []

key-decisions:
  - "The text and pin parsers of the new scenarios stay private in their scenario files and are covered by one new unit test file that imports them, instead of moving single-use helpers into scenario_helpers.py"
  - "The pin digest check was ported from the old host-test.sh (the function was deleted in an earlier plan; read from git history) and reads versions.env through sbx.build.read_pins"

patterns-established:
  - "A scenario that needs a git identity on the host passes GIT_CONFIG_GLOBAL=/dev/null and the test identity in the environment; the host user's own git configuration is never read"

requirements-completed: []

coverage:
  - id: D1
    description: "First run on a fresh throwaway sandbox: the agent wrapper refuses before sbx-init with empty stdout; the agent binary is on no plain or login PATH; sbx-init without a clone stops at the agent's links step with a fix line naming sbx-best-practices-clone; the clone runs sbx-init to the agent's step count; links match the agent (Claude: rules and skills, Cursor: skills only) and read through to the fixture; a second clone changes nothing and names sbx-init; the remote is the given URL; a pushed branch reaches the origin copy and main does not move; the wrapper then prints the version pin; a login shell inside an agent session finds the agents directory and a plain login shell does not; GSD synced at GSD_CORE_VERSION with no npx or @latest in the output"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "uv run pytest --collect-only: [claude] and [cursor] collected; 12 step blocks; the stand-in session script parses with bash -n and was run once by hand against the real wrapper scripts; uv run pytest -q 960 passed, 1 skipped"
        status: pass
      - kind: manual_procedural
        ref: "the real run needs Docker: ./host-test.sh on the Mac at the phase's final check"
        status: not_run
    human_judgment: true
    rationale: "Needs real Docker and the built test images"
  - id: D2
    description: "Relink: an edit of the clone on the host and a pull inside the sandbox are live through the links; a skill dropped from the clone loses its link after sbx-init and the kept skill keeps its link; the uncommitted edit, the pulled file and every planted user file survive"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "collected for claude and cursor; 6 step blocks; read against base/init/best_practices_linker.py"
        status: pass
      - kind: manual_procedural
        ref: "real run on the host at the phase's final check"
        status: not_run
    human_judgment: true
    rationale: "Needs real Docker"
  - id: D3
    description: "Owner fix: a named throwaway root container (offline, removed in a finally block) plants a root-owned file in the agent state directory, sbx-init gives it back to uid 1000, and no path under state/ outside the skipped caches is owned by root"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "collected for claude and cursor; the find command and its skip list checked by a unit case"
        status: pass
      - kind: manual_procedural
        ref: "real run on the host at the phase's final check"
        status: not_run
    human_judgment: true
    rationale: "Needs real Docker and a root container on the bind mount"
  - id: D4
    description: "Images: /etc/sbx/versions.env in sbx-AGENT:test equals the repo's versions.env, with a diff of at most 20 lines and the ./host-test.sh rebuild named in the failure"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "collected for claude and cursor; the diff helper checked by a unit case"
        status: pass
      - kind: manual_procedural
        ref: "real run on the host at the phase's final check"
        status: not_run
    human_judgment: true
    rationale: "Needs the built test images"
  - id: D5
    description: "Pin digests: every NAME=image@sha256 pin of versions.env is resolved with docker buildx imagetools inspect; an empty answer fails, an equal digest prints PASS, a moved tag prints an INFO line with both digests and passes; collected once, not per agent"
    requirement: HOST-04
    verification:
      - kind: unit
        ref: "collected once; four unit cases on the pin parser, the Digest line reader and the three result lines, one of them against the real versions.env"
        status: pass
      - kind: manual_procedural
        ref: "the registry lookups need Docker with buildx and network access: ./host-test.sh on the Mac"
        status: not_run
    human_judgment: true
    rationale: "Needs registry access"

duration: about 35min
completed: 2026-11-20
status: complete
---

# Phase 10 Plan 08: First run, relink, owner fix, image versions and pin digests Summary

**The last scenario set of the phase: a fresh-sandbox first run and a relink after a pull (both agents, links and agent differences read from AgentSpec), `sbx-init` giving a root-owned file back, the agent image's `versions.env` equal to the repo's, and the pin digest check kept as one plain integration test.**

These scenarios need Docker, which the dev sandbox lacks. Here they are proven by collection (`[claude]` and `[cursor]` for the four per-agent functions, and `test_every_pinned_digest_resolves` once: 9 items), by the full suite (`uv run pytest -q`: 960 passed, 1 skipped, which includes 13 new unit cases), and by reading each scenario against `sbx-best-practices-clone`, `sbx-run-agent`, `init_runner.py`, `best_practices_linker.py`, the old host checks and the agent rows. **The real run happens on the host at the phase's final check (`./host-test.sh`); nothing here has run against Docker yet.**

## Accomplishments

- `test_first_run_and_relink.py`, first run: twelve steps (setup and eleven checks). The wrapper refuses with `run sbx-init first` and empty stdout; the agent is on neither a plain nor a login PATH; `sbx-init` without a clone exits 1 at the agent's links step with a `fix:` line naming `sbx-best-practices-clone` and a last line `sbx-init: stopped at <links_step>`; the clone, given the origin copy's URL, ends in `<n> steps passed`; the rules link (Claude only) and each fixture skill link have the expected relative targets and a file read through the link equals the fixture; a second clone exits 1 saying nothing changed and naming `sbx-init`; the remote is the given URL; a branch committed and pushed in the container is in `origin.git` and its main equals the run's origin main; the wrapper prints the pin; a stand-in agent binary proves the login shell inside a wrapper session finds `/opt/sbx/agents/bin/<binary>` while a plain login shell finds none; `state/<config>/gsd-core/VERSION` equals `GSD_CORE_VERSION` and neither `sbx-init` run printed `npx` or `@latest`.
- `test_first_run_and_relink.py`, relink: six steps. A host edit and a pull inside the sandbox (a commit pushed from a second host clone to the origin copy) show through the link at once; user files are planted; a skill is dropped from the clone through a commit made in the container, `sbx-init` exits 0, the dropped link is gone and the kept skill (and the rules link for Claude) still point into the clone; the uncommitted edit, the pulled file and every planted file are unchanged.
- `test_owner_fix.py`: three steps on the shared sandbox. A root container named `sbx-hosttest-ownerfix-<agent>` (`--network none`, `-u root`, `--volumes-from`, removed in a `finally` block) touches a file in `state/<config>/`; its owner reads 0 in the sandbox; `sbx-init` exits 0 with the right closing line and the owner reads 1000; `find ... -user 0` outside `cache/npm`, `cache/uv` and `m2` prints nothing. A finalizer removes the planted file from inside the sandbox.
- `test_images_match_versions.py`: one step per agent comparing `/etc/sbx/versions.env` in `sbx-<agent>:test` with the repo file; a difference prints a unified diff (20 lines at most) and names `./host-test.sh` as the rebuild.
- `test_pin_digests.py`: one test, no fixtures. Each digest pin is looked up with `docker buildx imagetools inspect`; the lines are `PASS`, `INFO` (moved tag, with both digests, passes) or `FAIL` (unresolvable, fails); an empty pin list fails too, so the test cannot pass by finding nothing.
- `test_sbx_integration_text_helpers.py`: 13 unit cases for the pure helpers (last line, line prefix, fix line, the live-link target for each agent against the fixture files, the stand-in script under `bash -n`, the root-owned search and its skip list, the diff text, the pin parser including against the real `versions.env`, the `Digest:` reader, the three result lines).

## Task Commits

1. **Task 1: first run and relink (tracer)**: `794d74c`
2. **Task 2: owner fix, image versions and pin digests**: `d0767a0`
3. **Unit cases for the new helpers**: `6c77856`

**Plan metadata:** the commit holding this file (docs: complete plan)

The tracer gate (auto mode off, `human_verify_mode` end-of-phase, automated-only verify) was the collection re-run, which passed; the real run of the first-run scenario is part of the phase's final check.

## Decisions Made

- The pure parsers stay private in the scenario file that uses them (`_last_line`, `_pinned_image_map` and the rest), and one new unit file imports them. Moving single-use helpers into `scenario_helpers.py` would break the rule plan 07 set (a helper only one scenario uses stays in that file) and would still leave them untested without this file.
- The pin check reads `versions.env` through `sbx.build.read_pins`, the same reader `build.sh` uses, and then applies the old pattern (name `[A-Z_]+`, value `image@sha256:<64 hex>`), so a pin in a form the build accepts is read the same way here.
- The expected closing lines and link targets are written out in the scenarios, not imported from `base/init`, so a change in the product text shows as a failing scenario.

## Deviations from Plan

**1. [Scope] A unit test file was added**
- The plan's `files_modified` lists the four scenario files. The objective for this run asks for unit tests of any new helpers, so `tests/unit/sbx/test_sbx_integration_text_helpers.py` was added (Decisions Made). `uv run pytest -q` went from 947 to 960 passed.

**2. [Interpretation] The pin digest function was ported from git history**
- The plan points at `host-test.sh pin_digests`, but that function was removed when `host-test.sh` became a thin launcher. It was read from `9b1fde6^:host-test.sh` and ported line for line (regex, `Digest:` read, the three result lines).

**3. [Interpretation] Planted user files differ from the old check for Cursor**
- The old check planted a skill, memory, session, `CLAUDE.md` and a `settings.json` key, all Claude files. Here every agent gets a user skill directory and a note file in its config directory, and an agent with a `session_dir` (Claude) also gets a session file and a memory file. The settings key and `CLAUDE.md` are not planted: they are Claude-only and a plain note file proves the same promise (init leaves unknown files alone).

**4. [Interpretation] The pulled file goes where the agent's link reaches**
- Claude links the whole `rules/` directory, so a new rule file shows through it; Cursor links each skill directory, so the pulled file is added inside `skills/sbx-fixture-one/`. `_live_target` gives that directory and an existing file in it for both the edit and the pull.

**5. [Interpretation] The owner-fix plant is `touch` only**
- The old check ran `touch` and then `chown 0:0`; a file made by `touch` in a root container is already owned by root, and the scenario reads the owner back as 0 before `sbx-init`, so the chown adds nothing.

**6. [Interpretation] A second private `_git_environ`**
- The first-run file needs the same host git environment as `conftest.py` (`GIT_CONFIG_GLOBAL=/dev/null`, a test identity). That is two copies of an eight-line dict; the plan's three-copy threshold is not reached, so it was not moved into `scenario_helpers.py`.

**7. [Scope] Not ported, as the plan says**
- The clash part of the old relink check (a real skill directory in the way) is covered by `tests/unit/init`; the lock part of the old owner check is covered there with a real second process; the bare-build part of the old image check is a unit test already. The old first-run check's last step (a clone of a missing origin names `sbx-gh-login` and leaves no directory) is not among the plan's eleven steps and was left out.

## Issues Encountered

None.

## Requirements left Pending, and why

- **HOST-04** stays Pending: none of the integration scenarios has run on a real host yet (this plan completes the scenario set, but its real run is the host check at the end of the phase).
- **HOST-01, HOST-02, HOST-03, HOST-05** stay Pending (unchanged).

## User Setup Required

None. The host run at the phase's final check is `./host-test.sh` on the Mac; read `host-test.log` afterwards.

## Known Stubs

None.

## Threat Flags

None. T-10-19: the first-run scenario asserts the synced `VERSION` equals the pin and that no `npx` or `@latest` appears in either `sbx-init` output. The root container of the owner-fix scenario is named, offline and removed in a `finally` block; the throwaway sandboxes are `hosttest-first-<agent>` and `hosttest-relink-<agent>` in the run directory's test registry. T-10-SC: no package installed.

## Next Phase Readiness

- Likely first findings of the real run: assumption A3 (`cursor-agent --version` prints the pin) and A4 (the Cursor GSD sync writes `state/cursor/gsd-core/VERSION`); both are backed by selfcheck checks that pass on the host, and if either fails the fix is decided with the user. Also the git "dubious ownership" behavior of host git reading `origin.git` after the container pushed to it (the old check did the same on the Mac and passed).
- Four more throwaway containers (two per agent) stay up until the run's cleanup.

## Self-Check: PASSED

- Commits `794d74c`, `d0767a0`, `6c77856` exist on `feat/host-side-to-python`; `git rev-list --count 17570e3..HEAD` was 3 before this file was committed.
- The four scenario files and the unit file exist; `ls tests/integration/test_*.py | wc -l` prints 14.
- `uv run pytest -q`: 960 passed, 1 skipped; the non-ASCII scan and the planning-ID scan of `tests/integration` and the new unit file print nothing.
