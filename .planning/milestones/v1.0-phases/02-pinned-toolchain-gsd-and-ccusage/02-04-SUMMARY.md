---
phase: 02-pinned-toolchain-gsd-and-ccusage
plan: 04
subsystem: infra
tags: [docker, caches, npm, uv, maven, state-folder, guard, host-check]

requires:
  - phase: 02-pinned-toolchain-gsd-and-ccusage
    provides: base image with Node, uv, JDK and Maven (plan 03)
provides:
  - base/Dockerfile image ENV NPM_CONFIG_CACHE, UV_CACHE_DIR, UV_LINK_MODE=copy and SBX_STATE_DIRS="cache/npm cache/uv m2", and ~/.m2 as a link into state/m2
  - claude/Dockerfile that appends to SBX_STATE_DIRS and builds Claude Code with a throwaway npm cache in /tmp
  - guard rules agent_image_keeps_base_state_folders and npm_builds_keep_their_cache_out_of_the_mount, each with a planted-violation self-test
  - entrypoint self-test case for nested state folders
  - host check H-23 in the restart chain, with self-test group and fake docker support
affects: [02-05, 02-07, 02-09]

actuals:
  tokens: 10300
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Agent images append to SBX_STATE_DIRS (ENV SBX_STATE_DIRS=\"${SBX_STATE_DIRS} name\"), never replace it"
    - "Build-time npm installs set NPM_CONFIG_CACHE=/tmp/npm-cache on the same line, so nothing is baked under the mount point"

key-files:
  created:
    - tests/host/h23-caches-survive-recreate.sh
    - tests/selftest/host/h23-caches-survive-recreate.sh
  modified:
    - base/Dockerfile
    - claude/Dockerfile
    - tests/guard/start.sh
    - tests/guard/isolation.sh
    - tests/selftest/guard/sandbox-rules.sh
    - tests/selftest/entrypoint/start-folders.sh
    - SANDBOX.md
    - tests/selftest/host/support/fake-docker
    - tests/host/run-all.sh
    - tests/selftest/host/run-all.sh
    - tests/host-checklist.md
    - tests/selftest/host/runner-healthy.sh
    - tests/selftest/host/runner-failures.sh

key-decisions:
  - "The base owns the three cache folders because npm, uv and Maven are base toolchains; the entrypoint needed no change, since create_state_dirs already splits SBX_STATE_DIRS on spaces and runs mkdir -p per entry"
  - "~/.m2 is a symlink made as the sandbox user at build time; it dangles in the image until the entrypoint makes state/m2 at start"
  - "compose.yml is unchanged and still has no volume; caches sit in each sandbox's own state/ folder and are never shared"
  - "H-23 names its planted file exactly like its run-unique marker (h23-PID-EPOCH), so one value is both the content and the file name"

patterns-established:
  - "A guard rule that must see a planted violation is proven in a scratch copy of the tree; the scratch copy has no .git, so a rule group is judged by its own PASS or FAIL line, not by the group's exit code, when the group also holds a git-based rule"
  - "A host check helper that compares a tool's stdout (container_stdout) discards stderr, so a tool notice never reaches the compared value"

requirements-completed: []

coverage:
  - id: D1
    description: "The npm, uv and Maven caches point into the sandbox's state/ folder through image ENV and one link, and the entrypoint creates their folders at every start"
    requirement: IMG-07
    verification:
      - kind: other
        ref: "Linux suite plus the acceptance greps on base/Dockerfile and claude/Dockerfile"
        status: pass
      - kind: unit
        ref: "tests/selftest/entrypoint/start-folders.sh: entrypoint: nested state folders from SBX_STATE_DIRS are created"
        status: pass
      - kind: manual_procedural
        ref: "H-23 in bash tests/host/run-all.sh on the Mac (plan 09); Docker is not available in the dev sandbox"
        status: unknown
    human_judgment: false
  - id: D2
    description: "The two traps are held closed by the guard: a Claude image that replaces SBX_STATE_DIRS fails, and an npm install without the throwaway cache fails and is named"
    requirement: IMG-07
    verification:
      - kind: unit
        ref: "tests/selftest/guard/sandbox-rules.sh: state folders (3 cases) and npm cache (3 cases), 6 PASS lines"
        status: pass
    human_judgment: false
  - id: D3
    description: "H-23 proves npm and uv report caches under state/cache, ~/.m2 resolves into state/m2, the entrypoint made the folders, and a file in each cache is on the Mac before and after a down and up; every failure mode is caught"
    requirement: IMG-07
    verification:
      - kind: unit
        ref: "bash tests/selftest/host/h23-caches-survive-recreate.sh (19 PASS lines)"
        status: pass
      - kind: manual_procedural
        ref: "H-23 in bash tests/host/run-all.sh on the Mac (plan 09)"
        status: unknown
    human_judgment: false
  - id: D4
    description: "SANDBOX.md lists the cache folders and states the cost: slower small-file access over the Mac file sharing, several GB per sandbox, and that deleting state/cache or state/m2 is always safe"
    requirement: IMG-07
    verification:
      - kind: other
        ref: "grep acceptance checks on SANDBOX.md and the docs guard"
        status: pass
    human_judgment: true
    rationale: "Whether the wording reads clearly to a non-expert maintainer is a judgment no test asserts"

duration: not recorded
completed: 2026-10-09
status: complete
commits: 2
plan_head_before: a3a76c21e847384aa6a7b400608d3f199647719b
plan_head_after: fe8016bac2d1748b0ace949be5f073af2e555272
---

# Phase 2 Plan 04: Caches in the state folder Summary

**The npm, uv and Maven caches now live in the sandbox's own `state/` folder on the Mac (image ENV plus one `~/.m2` link, folders made by the entrypoint at start), so a recreate or rebuild keeps them; two guard rules close the SBX_STATE_DIRS-replace and baked-npm-cache traps, and host check H-23 proves survival across a down and up.**

## Performance

- **Duration:** not recorded
- **Completed:** 2026-10-09
- **Tasks:** 2 (1 tracer, 1 TDD auto)
- **Files modified:** 15 (2 created, 13 modified)

## Accomplishments

- `base/Dockerfile`: the per-shell ENV block gains `NPM_CONFIG_CACHE`, `UV_CACHE_DIR`, `UV_LINK_MODE=copy` and `SBX_STATE_DIRS="cache/npm cache/uv m2"`, each with a bullet; the home folders RUN (as sandbox) also makes the link `/home/sandbox/.m2` to `/home/sandbox/workspace/state/m2`.
- `claude/Dockerfile`: `SBX_STATE_DIRS="${SBX_STATE_DIRS} claude"` keeps the base list; the Claude Code RUN runs `NPM_CONFIG_CACHE=/tmp/npm-cache npm install -g ...` and removes `/tmp/npm-cache` instead of `/root/.npm`.
- `tests/guard/start.sh`: `agent_image_keeps_base_state_folders` (the base assignment must hold `cache/npm`, `cache/uv` and `m2`; every assignment in the Claude image must contain `${SBX_STATE_DIRS}`).
- `tests/guard/isolation.sh`: `npm_builds_keep_their_cache_out_of_the_mount` (every `npm install` line in a Dockerfile must set `NPM_CONFIG_CACHE=/tmp/npm-cache`; offending lines are printed).
- `tests/selftest/guard/sandbox-rules.sh`: `case_state_and_cache_rules` (clean copy passes; replaced SBX_STATE_DIRS fails and is named; planted `npm install` fails and its line is named).
- `tests/selftest/entrypoint/start-folders.sh`: the real entrypoint copy with `SBX_STATE_DIRS="cache/npm cache/uv m2 claude"` makes `cache/npm`, `cache/uv`, `m2`, `claude`, `shell`, `gh` and `git`.
- `SANDBOX.md`: three rows in "What lives where", the state/ row in the first table, and three bullets (survive recreate and rebuild; slower and several GB; `state/cache` and `state/m2` always safe to delete).
- H-23 (`tests/host/h23-caches-survive-recreate.sh`) with local helper `container_stdout`, in the restart chain right after H-16; fake docker support (`FAKE_NO_CACHE_DIRS`, `FAKE_NPM_CACHE`, `FAKE_M2_LINK`, `FAKE_CACHE_NOT_SHARED`, `FAKE_DOWN_LOSES_CACHES`); checklist title H-00..H-23, new row, chain `H-08, H-16, H-23, H-11, H-09, H-20, H-10`; runner counts 23 PASS lines healthy, 22 passed in the failure summaries.

## TDD record (Task 2)

- **Red** (self-test group, the `run-all.sh` entries, checklist row and runner counts written first; no check script and no fake answers): `bash tests/selftest/host/h23-caches-survive-recreate.sh` exited 1 with 17 `FAIL:` lines and 2 `PASS:` lines (the two vacuous ones: "the sandbox is up at the end" and "a cache lost on recreate was still there before it").
- **Green** (check and fake docker support added): the same command exits 0 with 19 `PASS: H-23:` lines and no `FAIL:`.

## Task Commits

1. **Task 1 (tracer): npm, uv and Maven caches live in the state folder** `4d1e2eb` (feat)
2. **Task 2: H-23 checks the caches survive a recreate** `fe8016b` (test)

The tracer feedback gate ran in interactive end-of-phase mode with an automated-only verify: the full Linux suite was re-run on the committed tracer state (it had passed just before the commit) and held before Task 2 started.

## Verification

Full Linux suite (bash -n over all scripts, guard, guard self-test, entrypoint self-test, host self-test, bundle self-test) passes after each task, exit 0, "All rules hold." and "All cases pass." Task 2's own verify (the H-23 group, `runner-healthy`, `runner-failures`, `guard/host-tests.sh`, `guard/docs.sh`, `guard/suites.sh`) prints no `FAIL:`. All acceptance greps of both tasks gave the expected counts, including: `grep -c 'npm install' claude/Dockerfile` and `grep -c '/tmp/npm-cache npm install' claude/Dockerfile` both print 1; the chain line in `run-all.sh` and the checklist sentence print 1; `healthy run has 23 PASS lines` prints 1.

## Not verified here (Docker is not available in the dev sandbox)

Nothing in either Dockerfile was built. Mac assumptions for plan 09's run:

- `ln -s` to the not-yet-existing `state/m2` succeeds at build time (a dangling link is legal) and `~/.m2` resolves once the entrypoint has made the folder.
- npm reads `NPM_CONFIG_CACHE` from the environment and `npm config get cache` prints it; `uv cache dir` prints `UV_CACHE_DIR`.
- A `docker exec` shell receives image ENV, so `$NPM_CONFIG_CACHE`, `$UV_CACHE_DIR` and `$HOME` are set in the H-23 plant script.
- The Dockerfile `ENV SBX_STATE_DIRS="${SBX_STATE_DIRS} claude"` expands the base image's value (ENV expansion uses the parent's environment), giving `cache/npm cache/uv m2 claude`.
- The Claude Code `npm install -g` with `NPM_CONFIG_CACHE=/tmp/npm-cache` as an env prefix on the same command still honours `--allow-scripts`.

## Deviations from Plan

### Orchestrator-directed changes

**1. [Branching] Work stayed on `chore/planning-phase-02-plan`; no `feat/phase-02-pinned-toolchain` branch**
- The dispatch said to stay on the current branch and skip the branch-name and origin/main ancestry checks. The two code commits touch no file under `.planning/`; this SUMMARY, STATE.md and ROADMAP.md go into a separate planning-only commit (the plan said to leave the SUMMARY uncommitted; the dispatch said to commit it).

### Plan wording adjusted

**2. [Rule 1 - Bug] Clean-copy isolation case judged by its rule line, not the group exit code**
- **Found during:** Task 1, first run of `case_state_and_cache_rules`.
- **Issue:** The plan asks for `GUARD_RC 0` from `isolation.sh` on a clean scratch copy. The scratch copy has no `.git`, so the group's git-based rule `old_layout_untouched` fails there, and the exit code can never be 0.
- **Fix:** The clean-copy case checks that the output holds `PASS: npm_builds_keep_their_cache_out_of_the_mount`. `start.sh` is still judged by exit code 0. The case comment says why.
- **Files modified:** `tests/selftest/guard/sandbox-rules.sh`
- **Commit:** `4d1e2eb`

**3. [Interpretation] Planted file name**
- The plan says the marker is `h23-$$-$(date +%s)` and the file is named `h23-MARKER`. Read literally that gives `h23-h23-PID-EPOCH`. The file is named exactly like the marker (`h23-PID-EPOCH`) and holds it; the self-test finds the files by the glob `h23-*`. The failure messages read `state/NAME/h23-PID-EPOCH is missing on the Mac WHEN`.

**Total deviations:** 1 auto-fixed (1 test-expectation bug), 1 interpretation, 1 orchestrator-directed. **Impact:** none on behavior or coverage.

## Issues Encountered

None.

## Known Stubs

None.

## Threat Flags

None beyond the plan's threat model. T-02-13 (no volume, per-sandbox state/ folder; `exactly_one_mount_and_not_over_home` still passes), T-02-14 (throwaway build cache plus the new `npm_builds_keep_their_cache_out_of_the_mount` rule; H-25 is a later plan), T-02-15 (the Claude image appends; `agent_image_keeps_base_state_folders`; H-23 checks the folders after a start) are implemented. T-02-16 is accepted as planned. No package-manager installs were run and no new package was added.

## Requirements

`IMG-07` is declared by this plan and by plan 09, which has no SUMMARY yet, so it is not marked complete here.

## Next Phase Readiness

- Plans 05 and 07 add Claude-image installs; any `npm install` there must carry `NPM_CONFIG_CACHE=/tmp/npm-cache` on the same line, and any new `ENV SBX_STATE_DIRS` must start from `${SBX_STATE_DIRS}`, or the guard stops them.
- Plan 09 runs `./build.sh` and `bash tests/host/run-all.sh` on the Mac; H-23 and the Mac assumptions above are the things to read first.

## Self-Check: PASSED

- FOUND: tests/host/h23-caches-survive-recreate.sh, tests/selftest/host/h23-caches-survive-recreate.sh, base/Dockerfile, claude/Dockerfile
- FOUND commits: 4d1e2eb, fe8016b (`git rev-list --count a3a76c2..HEAD` = 2 before this SUMMARY)

---
*Phase: 02-pinned-toolchain-gsd-and-ccusage*
*Completed: 2026-10-09*
