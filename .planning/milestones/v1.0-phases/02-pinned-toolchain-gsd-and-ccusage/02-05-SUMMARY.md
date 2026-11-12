---
phase: 02-pinned-toolchain-gsd-and-ccusage
plan: 05
subsystem: infra
tags: [docker, gsd, start-hook, offline, guard, host-check, fake-docker]

requires:
  - phase: 02-pinned-toolchain-gsd-and-ccusage
    provides: approved pin table (plan 02), Claude image caches and the SBX_STATE_DIRS and npm cache guard rules (plan 04)
provides:
  - versions.env GSD_CORE_VERSION=1.15.0 and the pinned GSD install in claude/Dockerfile with a build-time identity check
  - claude/start.d/05-gsd, the start hook that runs the baked gsd-core installer at every start, offline and fail closed
  - tests/selftest/host/support/fake-gsd (fake gsd-core and gsd-tools) and the entrypoint self-test group gsd-hook.sh
  - guard rule gsd_sync_runs_before_the_bundle with a planted-violation self-test
  - fake docker that runs every real start hook in name order (run_image_hooks), with FAKE_START_SAYS and FAKE_BROKEN_RC
  - H-17 extended (offline GSD sync, no npx or @latest, prompt stop) and H-14 extended (05-gsd owner and mode)
affects: [02-06, 02-07, 02-08, 02-09]

actuals:
  tokens: 11500
  tasks: 2
  commits: 2

tech-stack:
  added: ["@opengsd/gsd-core 1.15.0 (image only, installed with npm at build time)"]
  patterns:
    - "A start hook runs only what the image holds; its tool output goes to a temp file and is shown only on failure"
    - "A folder the installer cannot create is made first by the hook, so an uncreatable path fails at once instead of hanging"
    - "The fake docker runs every claude/start.d hook in name order with fakes on PATH, so a hook ordering claim is testable on Linux"

key-files:
  created:
    - claude/start.d/05-gsd
    - tests/selftest/host/support/fake-gsd
    - tests/selftest/entrypoint/gsd-hook.sh
  modified:
    - versions.env
    - claude/Dockerfile
    - tests/guard/start.sh
    - tests/selftest/entrypoint/run-all.sh
    - tests/selftest/host/support/fake-docker
    - tests/selftest/host/lib.sh
    - tests/host/h17-start-offline-and-failing-hook.sh
    - tests/selftest/host/h17-start-offline-and-failing-hook.sh
    - tests/host/h14-bundle-in-image.sh
    - tests/selftest/guard/sandbox-rules.sh

key-decisions:
  - "The GSD hook is named 05-gsd so it sorts before 10-best-practices; a bundle skill therefore wins a name clash, and a guard rule keeps it that way"
  - "The hook compares the synced gsd-core/VERSION with gsd-tools runtime-identity --raw, so a silently stale GSD cannot pass a start"
  - "The hook makes the config folder itself before the installer, because the installer waits forever on a folder it cannot create; timeout 300 around the installer is the second guard"
  - "fake_start_sync discards hook stdout so the success line does not clutter the host self-test output; errors still reach stderr"

patterns-established:
  - "Host self-tests that need an extra fake binary copy it into WORK/bin in prepare_fake_docker, never link it"

requirements-completed: []

coverage:
  - id: D1
    description: "The Claude image installs @opengsd/gsd-core at GSD_CORE_VERSION with npm, as root into /usr/local, and the build fails unless gsd-tools runtime-identity --raw reports that package and version as the sandbox user"
    requirement: TOOL-02
    verification:
      - kind: other
        ref: "acceptance greps on claude/Dockerfile and versions.env (npm install line, GSD_CORE_VERSION is not set message, runtime-identity --raw, COPY versions.env still last)"
        status: pass
      - kind: manual_procedural
        ref: "docker build in plan 09 on the Mac; Docker is not available in the dev sandbox"
        status: unknown
    human_judgment: false
  - id: D2
    description: "05-gsd runs the baked installer with stdin closed at every start, prints one line [sbx] GSD <version> synced, hides the installer output, and stops the start on an empty variable, an uncreatable folder (before the installer), a failing installer, a stuck installer or a version that differs from the image"
    requirement: TOOL-02
    verification:
      - kind: unit
        ref: "bash tests/selftest/entrypoint/gsd-hook.sh (18 PASS lines, 9 named cases)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The GSD hook sorts before 10-best-practices, so the bundle copy of a clashing skill is what remains"
    requirement: TOOL-02
    verification:
      - kind: unit
        ref: "gsd-hook.sh case 'the bundle hook runs after it, so a bundle skill wins a name clash' runs both real hooks through run_start_hooks"
        status: pass
      - kind: unit
        ref: "tests/guard/start.sh gsd_sync_runs_before_the_bundle, and sandbox-rules.sh 'start hooks: a GSD hook that sorts after the bundle hook fails'"
        status: pass
    human_judgment: false
  - id: D4
    description: "H-17 requires the offline start to sync GSD at the pinned version and print its line, its output to name no npx and no @latest, and every failing-hook container to stop within 60 s; H-14 requires 05-gsd to be root:root mode 755"
    requirement: TOOL-03
    verification:
      - kind: unit
        ref: "bash tests/selftest/host/h17-start-offline-and-failing-hook.sh (4 new cases pass, all earlier cases still pass); bash tests/selftest/host/h14-bundle-in-image.sh"
        status: pass
      - kind: manual_procedural
        ref: "H-17 and H-14 in bash tests/host/run-all.sh on the Mac (plan 09)"
        status: unknown
    human_judgment: false
  - id: D5
    description: "A start interrupted during the GSD sync is repaired by the next start, because every start runs the full idempotent installer"
    requirement: TOOL-03
    verification:
      - kind: other
        ref: "backstop: no automated case interrupts the installer; the idempotence rests on the research finding for gsd-core 1.15.0"
        status: unknown
    human_judgment: false

duration: not recorded
completed: 2026-10-09
status: complete
commits: 2
plan_head_before: 39c1103b7d44102c6d6a8b73fa2f43c1ffe266c9
plan_head_after: 73856b2facde254c647280e92542147e7659b71c
---

# Phase 2 Plan 05: Pinned GSD baked and synced at every start Summary

**The Claude image installs `@opengsd/gsd-core` 1.15.0 from npm and checks its identity at build time, and a new start hook `05-gsd` runs the baked installer into `state/claude` at every start (offline, output hidden, fail closed, before the bundle hook); H-17 and H-14 now prove it on the Mac, and the fake docker runs every real hook on Linux.**

## Performance

- **Duration:** not recorded
- **Completed:** 2026-10-09
- **Tasks:** 2 (1 tracer, 1 TDD auto)
- **Files modified:** 13 (3 created, 10 modified)

## Accomplishments

- `versions.env`: `GSD_CORE_VERSION=1.15.0` under `# sbx-claude`, the approved value from the pin table.
- `claude/Dockerfile`: a `# --- GSD ---` block (`ARG GSD_CORE_VERSION`, a RUN that stops without the pin, `NPM_CONFIG_CACHE=/tmp/npm-cache npm install -g "@opengsd/gsd-core@${GSD_CORE_VERSION}"`, cache removed); the best-practices bullet now names the hook order; the smoke test also requires `gsd-tools runtime-identity --raw` to equal `{"packageName":"@opengsd/gsd-core","version":"<pin>"}`. `COPY versions.env` is still the last instruction.
- `claude/start.d/05-gsd` (mode 755): functions `check_inputs`, `make_config_folder`, `image_gsd_version`, `run_installer`, `check_synced_version`; installer under `timeout 300` with stdin from /dev/null and output in a temp file shown only on failure; success prints `[sbx] GSD 1.15.0 synced`.
- `tests/selftest/host/support/fake-gsd`: one script installed as `gsd-core` and `gsd-tools`, with knobs FAKE_GSD_LOG, FAKE_GSD_VERSION, FAKE_GSD_IDENTITY, FAKE_GSD_FAIL, FAKE_GSD_DROPS_SETTINGS, FAKE_GSD_CLASH.
- `tests/selftest/entrypoint/gsd-hook.sh` (new group, added to `run-all.sh`): 9 named cases, 18 PASS lines.
- `tests/guard/start.sh`: `gsd_sync_runs_before_the_bundle` (fails with `no start hook runs the GSD installer`, or `HOOK sorts after 10-best-practices`).
- Fake docker: `run_image_hooks CONFIG_DIR`; compose up and `--network none` runs execute every hook of `claude/start.d` in name order; `run_network_none` remembers `-e CLAUDE_CONFIG_DIR=`; knobs FAKE_START_SAYS and FAKE_BROKEN_RC; the H-14 probe also reports `05-gsd`.
- `tests/selftest/host/lib.sh`: `prepare_fake_docker` installs the fake GSD; `fake_start_sync` runs every hook in name order.
- H-17: `check_offline_gsd` (VERSION equals the pin, the GSD line printed, no `npx` or `@latest`), and `check_bad_hook_stop` reports a stop by the time limit (exit 143 or 137). H-14: `05-gsd` expected root:root 755.

## TDD record

**Task 1 (tracer), group first:**
- **Red, run 1** (group written, no fake, no hook): `bash tests/selftest/entrypoint/gsd-hook.sh` stopped at once with `cp: cannot stat '.../tests/selftest/host/support/fake-gsd'` and ran no case.
- **Red, run 2** (fake GSD and the `GSD_CORE_VERSION` pin added, no hook): 14 `FAIL:` lines (sync line, stderr empty, installer arguments, folder made, failing installer x3, uncreatable folder x2, empty variable x2, version mismatch x2, GSD skill stays); 4 vacuous PASS lines (hidden output x2, installer never ran, the clash diff).
- **Green** (hook, Dockerfile, guard rule added): the group exits 0 with 18 `PASS: gsd hook:` lines and no `FAIL:`.

**Task 2, H-17 cases first:**
- **Red** (4 new cases written, fake and check unchanged): `bash tests/selftest/host/h17-start-offline-and-failing-hook.sh` printed 7 `FAIL:` lines (`the offline start synced GSD at the pinned version`, `an offline start whose GSD sync fails fails the check` and its text, `a start that names npx fails the check` and its text, `a failing hook that does not stop in time fails the check` and its text).
- **Green** (fake docker, self-test library and checks changed): the same group exits 0; the four new case names print 4 PASS lines, and every earlier H-17 case still passes with the real hooks running.

## Task Commits

1. **Task 1 (tracer): bake the pinned GSD and sync it at every start** `e15af98` (feat)
2. **Task 2: H-17 needs an offline GSD sync and a prompt stop; the fake runs every start hook** `73856b2` (test)

The tracer feedback gate ran in interactive end-of-phase mode with an automated-only verify: the full Linux suite had passed on the tracer state just before its commit and held before Task 2 started.

## Verification

Full Linux suite (bash -n over all scripts, guard, guard self-test, entrypoint self-test, host self-test, bundle self-test) passes after each task: "All rules hold." and "All cases pass." from every suite. Task 2's own verify (H-17, H-14, H-16 groups and `sandbox-rules.sh`) prints no `FAIL:`. Acceptance checks: `gsd-hook.sh` prints 18 `PASS: gsd hook:` lines (needed 9); `start.sh` prints the `gsd_sync_runs_before_the_bundle` PASS line; the H-17 group prints 4 of the 4 new case lines; the guard self-test prints `PASS: start hooks: a GSD hook that sorts after the bundle hook fails`.

## Not verified here (Docker is not available in the dev sandbox)

Nothing was built and the real `gsd-core` was never run in this plan. Mac assumptions for plan 09's run:

- `npm install -g @opengsd/gsd-core@1.15.0` succeeds with `NPM_CONFIG_CACHE=/tmp/npm-cache`, puts `gsd-core` and `gsd-tools` on PATH, and `gsd-tools runtime-identity --raw` prints exactly `{"packageName":"@opengsd/gsd-core","version":"1.15.0"}` (the research measured this on arm64 Node 24; the Dockerfile smoke test now asserts it).
- The real installer called as `gsd-core --claude --global --config-dir DIR` with stdin closed finishes offline, writes `DIR/gsd-core/VERSION` equal to the package version, and stays within 300 s.
- `sed -n 's/.*"version" *: *"\([^"]*\)".*/\1/p'` extracts the version from the real identity line (the fake prints the same shape).
- The real installer behaves like the fake on the points the checks read: hidden output on success and no `npx` or `@latest` in what the container prints.
- H-17 and H-14 pass in `bash tests/host/run-all.sh`.

## Deviations from Plan

### Orchestrator-directed changes

**1. [Branching] Work stayed on `chore/planning-phase-02-plan`; no `feat/phase-02-pinned-toolchain` branch**
- The dispatch said to stay on the current branch and skip the branch-name and origin/main ancestry checks. The two code commits touch no file under `.planning/`; this SUMMARY, STATE.md and ROADMAP.md go into a separate planning-only commit (the plan said to leave the SUMMARY uncommitted; the dispatch said to commit it).

### Auto-fixed Issues

**2. [Rule 3 - Blocking noise] Hook stdout hidden in `fake_start_sync`**
- **Found during:** Task 2, first run of the H-16 and H-14 groups.
- **Issue:** `fake_start_sync` now runs the GSD hook, whose success line `[sbx] GSD 1.15.0 synced` printed into the self-test output of three groups.
- **Fix:** `fake_start_sync` sends hook stdout to /dev/null; errors still go to stderr and a failing hook returns 1.
- **Files modified:** `tests/selftest/host/lib.sh`
- **Commit:** `73856b2`

**Total deviations:** 1 auto-fixed (test output noise), 1 orchestrator-directed. **Impact:** none on behavior or coverage.

## Issues Encountered

None.

## Known Stubs

None.

## Threat Flags

None beyond the plan's threat model. T-02-17 (only the baked gsd-core runs; `no_installs_at_container_start` passes over the new hook; H-17 checks the offline output), T-02-18 (installer at every start, version compared with the image identity), T-02-19 (folder made first, `timeout 300`, H-17 fails a late stop), T-02-21 (only `@opengsd/gsd-core`, identity asserted at build time) are implemented. T-02-20 and T-02-SC are accepted or covered as planned. No package-manager install was run in the dev sandbox; the Dockerfile line installs the package the approved pin table names.

## Reversibility

The tracer is rated costly: every sandbox's persisted `state/claude` gets GSD's files and a `settings.json` merge at each start; undoing it needs GSD's own uninstall in each sandbox. This was decided by the user and is flagged, not gated.

## Requirements

`TOOL-02` and `TOOL-03` are declared by this plan and also by plans 06, 08 and 09 (and 02), which have no SUMMARY yet, so neither is marked complete here.

## Next Phase Readiness

- Plan 06 must change H-16 and the docs: the planning check found that the real installer removes a `skills/gsd-*` folder GSD does not ship, so H-16's planted `gsd-h16-sample` would vanish. It also owns the "image wins and spares the user's files" proof and the attended bump to `GSD_BUMP_TARGET` 1.16.0.
- Any later `npm install` in a Dockerfile still needs `NPM_CONFIG_CACHE=/tmp/npm-cache` on the same line; any new `ENV SBX_STATE_DIRS` must start from `${SBX_STATE_DIRS}`.
- Plan 09 runs `./build.sh` and `bash tests/host/run-all.sh` on the Mac; the assumptions list above is what to read first.

## Self-Check: PASSED

- FOUND: claude/start.d/05-gsd (mode 755), tests/selftest/host/support/fake-gsd, tests/selftest/entrypoint/gsd-hook.sh
- FOUND commits: e15af98, 73856b2
