---
phase: 10-host-side-to-python
plan: 03
subsystem: infra
tags: [python, uv, launcher, build, sbx-upgrade, sbx-rm, sbx-fix-modes, pytest, versions-env, openssl]

requires:
  - phase: 10-host-side-to-python
    provides: the sbx package core, the Compose layer of sbx/docker.py, the injectable Docker function, the DockerRecorder helper and the two-line uv launcher shape
provides:
  - sbx/build.py, build.sh in Python (read_pins, build_plan, prepare_extra_certs, banner, main) behind a two-line launcher
  - sbx/upgrade.py with an injected build function (default build.main)
  - sbx/rm.py, the only module that deletes a registry entry or removes a container
  - sbx/fix_modes.py with an injected xattr function
  - the unit test that proves every pin ARG of the three Dockerfiles names itself when missing
  - the every-command refusal of SBX_IMAGE_TAG=latest as one parametrized test
  - bin/sbx-lib.sh, tests/unit/lib-expect.sh and every bash group of tests/unit/sbx deleted
affects: [10-04, 10-05, 10-06, 10-07, 10-08, 10-09, 10-10, 10-11]

actuals:
  tokens: 24000
  tasks: 3
  commits: 5
plan_head_before: 25e5655d754e220a692486b1fe6d348fb3ac77a8
plan_head_after: f7ebfbc813930abfdeb74e195c89c494fbcb35d6

tech-stack:
  added: []
  patterns:
    - "versions.env is parsed as NAME=value text; each pin is a bare --build-arg NAME and its value sits in the environment given to Docker"
    - "A command that calls another command takes it as a parameter (upgrade: build_function=build.main), so a test passes a stub"
    - "The terminal check and the answer reader are parameters (rm: is_terminal, read_answer); the xattr command is a parameter (fix_modes: xattr_function)"
    - "Destructive actions live in one module: only rm.py unlinks an entry or runs down, stop and rm of a container"

key-files:
  created:
    - sbx/build.py
    - sbx/upgrade.py
    - sbx/rm.py
    - sbx/fix_modes.py
    - tests/unit/sbx/test_sbx_build.py
    - tests/unit/sbx/test_sbx_upgrade.py
    - tests/unit/sbx/test_sbx_rm.py
    - tests/unit/sbx/test_sbx_fix_modes.py
  modified:
    - build.sh
    - bin/sbx-upgrade
    - bin/sbx-rm
    - bin/sbx-fix-modes
    - versions.env
    - tests/unit/sbx/test_sbx_launchers.py
    - tests/guard/start.sh
    - tests/guard/lib.sh
    - tests/guard/supply-chain.sh
  deleted:
    - bin/sbx-lib.sh
    - tests/unit/lib-expect.sh
    - tests/unit/sbx/image-tag.sh
    - tests/unit/sbx/rm.sh
    - tests/unit/sbx/upgrade.sh
    - tests/unit/sbx/fix-modes.sh
    - tests/unit/sbx/lib.sh
    - tests/unit/sbx/run-all.sh

key-decisions:
  - "build reads versions.env as text only; a value such as $(command) stays text, so the file is data and not code"
  - "Certificate files are written in the order of the blocks in the PEM file (the bash glob sorted them as text, so ten or more certificates came out of order)"
  - "A docker that is not installed reads as exit 127 and the build says so, instead of 'the build of sbx-base:local failed' with no clue"
  - "sbx-rm prints the underlying entry problem before the --unregister hint when an entry is broken, as the bash command did"

patterns-established:
  - "Tag refusal as one parametrized test over every command main, with a snapshot of the whole tmp tree before and after"
  - "Dockerfile guard line proven by reading the Dockerfiles in a unit test instead of grepping from a bash guard"

requirements-completed: []

coverage:
  - id: D1
    description: "build.sh is a two-line launcher into sbx.build: it refuses a tag other than local or test before reading versions.env, refuses a missing and an empty versions.env with the bash text, reads the file as text, and builds the base then one image per agent with BASE_IMAGE of its own tag"
    requirement: HOST-01
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_build.py"
        status: pass
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_launchers.py (build launcher refuses the latest tag from another directory)"
        status: pass
    human_judgment: false
  - id: D2
    description: "With SBX_CA_CERT the PEM file is split into one file per certificate with no key text, refusals keep the bash wording, the context and fingerprints go to the base build only, and the banner is printed before the first build and after the last"
    requirement: HOST-01
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_build.py (certificate cases, real openssl in tmp_path)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every ARG whose name ends in _VERSION or _URL in the three Dockerfiles is followed by a RUN line that stops with 'NAME is not set; build with ./build.sh'"
    requirement: HOST-01
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_build.py (test_guard_line_*)"
        status: pass
    human_judgment: false
  - id: D4
    description: "sbx-upgrade warns a running sandbox before the build, leaves the sandbox as it was with no compose call when the build fails, recreates with up -d --force-recreate --wait, and ends with the marker line, the new-images line and the tool versions line"
    requirement: HOST-01
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_upgrade.py"
        status: pass
    human_judgment: false
  - id: D5
    description: "sbx-rm takes NAME, --unregister and --yes in any order once each, asks about a running sandbox only on a terminal, removes a broken entry by container name only with --unregister, and deletes the entry only after a good down"
    requirement: HOST-01
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_rm.py"
        status: pass
    human_judgment: false
  - id: D6
    description: "sbx-fix-modes sets host modes 644 or 755 from the git index, then the mode part of the override_stat attribute through an injected xattr function, keeps uid and gid, prints the counts line and says when xattr is not installed"
    requirement: HOST-01
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_fix_modes.py (real git repo, real modes)"
        status: pass
    human_judgment: false
  - id: D7
    description: "Each of sbx-add, sbx-list, sbx-start, sbx-stop, sbx-shell, sbx-upgrade, sbx-rm, sbx-fix-modes and build.sh refuses SBX_IMAGE_TAG=latest with exit 1, no Docker call and no file made"
    requirement: HOST-01
    verification:
      - kind: unit
        ref: "tests/unit/sbx/test_sbx_launchers.py (test_every_command_refuses_the_latest_tag_*)"
        status: pass
    human_judgment: false
  - id: D8
    description: "The real build, upgrade, rm and fix-modes under uv on macOS with Docker Desktop, and the real xattr"
    requirement: HOST-01
    verification:
      - kind: manual_procedural
        ref: "host run of the persistence and refusal groups in the later host plans"
        status: not_run
    human_judgment: true
    rationale: "Docker and macOS exist only on the host; this plan was proven in the dev sandbox with the Docker recorder and a stand-in xattr function"

duration: about 15min (commits 01:52 to 01:56 UTC; the start time was not recorded)
completed: 2026-11-20
status: complete
---

# Phase 10 Plan 03: build.sh, sbx-upgrade, sbx-rm and sbx-fix-modes in Python Summary

**Every `bin/sbx-*` command and `build.sh` now run as Python behind two-line uv launchers; versions.env is read as text, sbx-rm is the only file that destroys anything, and `bin/sbx-lib.sh` and the bash unit harness are deleted.**

## Performance

- **Duration:** about 15 min (commits 01:52 to 01:56 UTC)
- **Completed:** 2026-11-20
- **Tasks:** 3 (one tracer, two TDD with a RED and a GREEN commit each)
- **Files changed:** 25 (8 created, 9 modified, 8 deleted)

## Accomplishments

- `sbx/build.py`: `read_pins` (NAME=value text, `$(...)` stays text), `build_plan` (base first, then one image per `KNOWN_AGENT_LIST` entry with `BASE_IMAGE` of its own tag; absolute Dockerfile and context paths), the certificate split with `openssl` in `tempfile.TemporaryDirectory`, the banner, and `main`. Each pin is a bare `--build-arg NAME` and its value is in the environment handed to Docker.
- `sbx/upgrade.py` calls the build in-process through `build_function`; a failed build returns before any compose call. `sbx/rm.py` is the single deleter (`.unlink`, compose `down`, `docker stop`, `docker rm`). `sbx/fix_modes.py` parses one `git ls-files -s -z` run and talks to the attribute only through `xattr_function`.
- The unit test `test_guard_line_*` reads the three Dockerfiles and proves each `_VERSION` and `_URL` ARG is followed by a RUN line naming the missing pin; the same test has a case that shows it sees an unguarded ARG.
- `test_every_command_refuses_the_latest_tag_*` runs the nine command mains with the recorder and snapshots the whole tmp tree before and after.
- Deleted: `bin/sbx-lib.sh`, `tests/unit/lib-expect.sh`, and `image-tag.sh`, `rm.sh`, `upgrade.sh`, `fix-modes.sh`, `lib.sh` and `run-all.sh` under `tests/unit/sbx/` (this also removes the temporary `plant_sandbox` helper that plan 10-02 added). `bin/` holds exactly nine two-line launchers.
- Results: `uv run pytest -q` 864 passed, 1 skipped (the launcher usage case for `build.sh`, which takes any argument); `bash tests/guard/run-all.sh` ends `All rules hold.`.

## Task Commits

1. **Task 1: build.sh end to end in Python and the bare-build unit test (tracer)**: `89c0ef4` (feat). Both automated verifies passed before Task 2 began (28 build tests plus the launcher tests, the bash unit run and the bash guard), so the slice was proven before it was expanded.
2. **Task 2: sbx-upgrade and sbx-rm**: `bd6c077` (test, RED, import error) and `9133069` (feat, GREEN)
3. **Task 3: sbx-fix-modes, library and harness deleted**: `5750dd7` (test, RED, import error) and `f7ebfbc` (feat, GREEN)

**Plan metadata:** the commit holding this file (docs: complete plan)

## Decisions Made

- `build` keeps the bash order: tag, versions.env present, pins present, certificate checks (absolute path, readable file, openssl on the PATH of the passed environment), then the banner and the builds. A refusal in the first three makes no temporary directory.
- The certificate directory goes under `TMPDIR` of the passed environment, so a test can point it at a directory it owns and check it is empty afterwards.
- `sbx-rm` reads an entry that exists but is unusable as broken and one that is missing as not registered, as the bash command did; the entry is read once and the result is passed on.
- `sbx-fix-modes` compares the host mode with `stat.S_IMODE` and not with the first ten characters of `ls`, so a setuid bit is also corrected.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] A docker that is not installed gave no clue**
- **Found during:** Task 1
- **Issue:** `run_docker` reports a missing binary as exit 127 and the build output goes to the terminal, so the user would only read `the build of sbx-base:local failed`.
- **Fix:** exit 127 is named: `cannot run docker; is Docker installed and on the PATH?`. A unit test covers it.
- **Files modified:** `sbx/build.py`, `tests/unit/sbx/test_sbx_build.py`
- **Commit:** `89c0ef4`

### Other deviations

**2. Certificate file order.** Files are named `sbx-extra-ca-N.crt` in the order of the blocks. The bash glob sorted them as text, so `-10` came before `-2`. Fingerprints and banner follow the block order too. No effect below ten certificates.

**3. Unterminated block.** A BEGIN line without an END is written out and then refused by the openssl check as an invalid block. The awk version also kept it; the Python version does not depend on the awk quirk.

**4. Docs that still name the deleted files.** The plan exempts `host-test.sh`, `GLOSSARY.md` and `.claude/CLAUDE.md` from the `sbx-lib.sh` check. `host-test.sh` still sources `bin/sbx-lib.sh` and runs `tests/unit/sbx/run-all.sh`, so it cannot run until plan 10-05 replaces it, as the plan says. `tests/README.md` still describes the bash harness under `tests/unit/sbx/`, and `GLOSSARY.md` and `.claude/CLAUDE.md` still mention the library; I left all three for the documentation plans of the phase (10-09 and 10-10 name `tests/README.md`).

---

**Total deviations:** 4 (1 Rule 2 addition, 3 scope notes)
**Impact on plan:** none on the contract.

## Issues Encountered

None.

## Requirements left Pending, and why

- **HOST-01** stays Pending, as the orchestrator said: `host-test.sh` (and `clean.sh`) are still bash; they are ported in later plans.
- **HOST-02** stays Pending: every command that reads the registry now reads `NAME.json`, but `tests/host/h28-sbx-add-start-stop.sh` and `host-test.sh` still read the older entry format, and the real registry is moved by plan 10-10.
- **HOST-03** stays Pending (unchanged from plan 10-02; left for the phase verification).
- **HOST-04** and **HOST-05** stay Pending: the persistence group is not written, and the bash guard, `tests/host/` and `host-test.sh` still exist.

## User Setup Required

None. The first host run of `./build.sh` through uv (output of the docker builds reaching the terminal, `Ctrl-C` stopping the build) is one more thing the host plans check.

## Known Stubs

None.

## Threat Flags

None. The mitigations hold: versions.env is parsed as text and a `$(touch pwned)` value is tested to stay text (T-10-07); only certificate blocks are written and a key in the input is tested to never reach the build directory (T-10-08); only `sbx/rm.py` contains `.unlink(`, `"down"` or `"rm"` (T-10-09; the guard rule follows in plan 10-04); no package was installed and no pin changed (T-10-SC, `git diff` of versions.env shows comment lines only).

## Next Phase Readiness

- Plan 10-04 can port the bash guard as pytest: `tests/guard/start.sh` now holds only the compose.yml image line for the compose rule, and the globs over `tests/unit/` are gone from `lib.sh` and `supply-chain.sh`.
- `host-test.sh` and `clean.sh` are the last bash commands with logic; `host-test.sh` is broken until plan 10-05 (it names the deleted library and the deleted bash run-all).

## Self-Check: PASSED

- Commits `89c0ef4`, `bd6c077`, `9133069`, `5750dd7`, `f7ebfbc` exist on `feat/host-side-to-python`; `git rev-list --count 25e5655..HEAD` was 5 before this file was committed.
- `sbx/build.py`, `sbx/upgrade.py`, `sbx/rm.py`, `sbx/fix_modes.py` and the four new test files exist; `bin/` lists exactly sbx-add, sbx-fix-modes, sbx-list, sbx-migrate-registry, sbx-rm, sbx-shell, sbx-start, sbx-stop, sbx-upgrade, each two lines, mode 100755 and `#!/bin/sh`; `build.sh` is two lines and 100755.
- `bin/sbx-lib.sh`, `tests/unit/lib-expect.sh` and `tests/unit/sbx/*.sh` are gone; `git grep -l sbx-lib.sh` outside `.planning` names only `.claude/CLAUDE.md`, `GLOSSARY.md` and `host-test.sh`.
- `uv run pytest -q`: 864 passed, 1 skipped; `tests/guard/run-all.sh`: All rules hold.; no non-ASCII byte in `sbx/*.py` or `tests/unit/sbx/*.py`; no `monkeypatch` or `mock.patch` in `tests/unit/sbx`; `grep -lE '"down"|"rm"|\.unlink\(' sbx/*.py` prints only `sbx/rm.py`; no pin line changed in versions.env.

---
*Phase: 10-host-side-to-python*
*Completed: 2026-11-20*
