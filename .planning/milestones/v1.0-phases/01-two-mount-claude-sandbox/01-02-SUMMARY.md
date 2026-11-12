---
phase: 01-two-mount-claude-sandbox
plan: 02
subsystem: infra
tags: [docker, compose, bash-history, gh, git, bind-mounts, state-layout]

requires:
  - phase: 01-01
    provides: "base/Dockerfile, compose.yml with workspace and state/claude binds, tests/static-check.sh, SANDBOX.md"
provides:
  - "base/Dockerfile: gh 2.102.0 from a checksum-verified release tarball; HISTFILE, PROMPT_COMMAND, GH_CONFIG_DIR, GIT_CONFIG_GLOBAL in image ENV; shell/gh/git mount targets created as sandbox"
  - "compose.yml: five directory binds in total (workspace, state/claude, state/shell, state/gh, state/git), all long syntax with create_host_path false"
  - "SANDBOX.md: mkdir for all four state folders, what-lives-where rows, history, gh token and git identity notes"
  - "tests/static-check.sh: checks for the three new mounts, their ENV, the gh pin and checksum, and exactly five binds"
affects: [01-03, 01-04, phase-03, phase-05]

plan_head_before: e0c99103ffa3b27255d7065342a87a7862a30710
plan_head_after: 59738d1bd503eeb734179b3547cf4652521b4c66

actuals:
  tokens: 2000
  tasks: 2
  commits: 2

tech-stack:
  added: ["gh 2.102.0 (release tarball, sha256sum -c)"]
  patterns:
    - "one image ENV variable per tool, pointing into one extra directory bind under state/"
    - "single-file state is never mounted: git creates its config file inside a mounted directory"

key-files:
  created: []
  modified:
    - base/Dockerfile
    - compose.yml
    - SANDBOX.md
    - tests/static-check.sh

key-decisions:
  - "History is wired by image ENV only (HISTFILE plus PROMPT_COMMAND=history -a), with no edits to bashrc or profile.d, so every docker exec shell gets it and commands reach the Mac on every prompt"
  - "git identity uses a directory mount (state/git) holding a config file git creates itself, not a single-file mount (D-12)"
  - "Kept the 01-01 convention: home subdirectories come from one plain mkdir -p after USER sandbox, extended with the three new targets"

requirements-completed: [LAY-03, LAY-02, IMG-05]

coverage:
  - id: D1
    description: "Bash history written to state/shell/bash_history on every prompt via image ENV, shared across exec shells, with a state/shell directory bind"
    requirement: "LAY-03"
    verification:
      - kind: other
        ref: "bash tests/static-check.sh (shell history bind target; HISTFILE and PROMPT_COMMAND in image ENV; history mount target created as sandbox)"
        status: pass
    human_judgment: true
    rationale: "Static greps prove the wiring text only. That history survives recreate and appears in a second shell needs Docker on the Mac (host check H-08 in plan 01-04)."
  - id: D2
    description: "gh 2.102.0 in the base from a checksum-verified tarball; gh login and git identity persisted through GH_CONFIG_DIR and GIT_CONFIG_GLOBAL with state/gh and state/git directory binds"
    requirement: "IMG-05"
    verification:
      - kind: other
        ref: "bash tests/static-check.sh (gh 2.102.0 pinned and checksum-verified; gh and git config in image ENV; gh and git state bind targets; state mount targets created as sandbox)"
        status: pass
    human_judgment: true
    rationale: "The native arm64 build of the tarball, the checksum succeeding at build time, and login and identity surviving recreate need Docker on the Mac (host checks H-06 and H-09 in plan 01-04)."
  - id: D3
    description: "Exactly five directory bind mounts, nothing over /home/sandbox, every source under SBX_DIR, quick-start creates every bind source"
    requirement: "LAY-02"
    verification:
      - kind: other
        ref: "bash tests/static-check.sh (exactly five bind mounts; every bind mount sets create_host_path false; every mount source is under SBX_DIR; nothing mounted over /home/sandbox; quick-start creates every bind source)"
        status: pass
    human_judgment: false

duration: 2min
completed: 2026-10-01
status: complete
---

# Phase 1 Plan 02: Shell history, gh and git state Summary

**Bash history, gh login and git identity now survive recreate: three image ENV variables point into three extra directory binds under `state/`, with gh 2.102.0 installed in the base from a checksum-verified native tarball.**

## Performance

- **Duration:** about 2 min
- **Started:** 2026-10-01T18:39:14Z
- **Completed:** 2026-10-01T18:40Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- `HISTFILE` and `PROMPT_COMMAND="history -a"` in the base image ENV send every typed command to `$SBX_DIR/state/shell/bash_history` at once, so a shell still open when the container is removed loses nothing and concurrent shells share history (LAY-03).
- gh 2.102.0 is installed from the release tarball for the build architecture, checked with `sha256sum -c` against the release checksums file, extracting only `gh` with `--no-same-owner` (IMG-05, T-01-09).
- `GH_CONFIG_DIR` and `GIT_CONFIG_GLOBAL` point into `state/gh` and `state/git`, so `gh auth login` and `git config --global` persist; the Mac's `~/.gitconfig` is never involved.
- `compose.yml` now has exactly five directory binds, all long syntax, all `create_host_path: false`, all sourced under `${SBX_DIR}`; nothing is mounted over `/home/sandbox` (LAY-02).
- `SANDBOX.md` has the final `mkdir -p "$SBX_DIR"/workspace "$SBX_DIR"/state/{claude,shell,gh,git}` line, what-lives-where rows, and a note that the gh token is plain text in `state/gh/hosts.yml` (T-01-10).
- `tests/static-check.sh` grew from 36 to 45 passing checks.

## Task Commits

1. **Task 1: Bash history survives recreate** - `2db06b9` (feat)
2. **Task 2: gh login and git identity survive recreate (gh 2.102.0)** - `59738d1` (feat)

**Plan metadata:** committed separately as `docs(01-02): complete ...` (SUMMARY, STATE, ROADMAP, REQUIREMENTS)

## Files Created/Modified

- `base/Dockerfile` - `ARG GH_VERSION`, gh tarball block, ENV for history/gh/git, extended mount-target `mkdir -p`
- `compose.yml` - three more directory binds (state/shell, state/gh, state/git)
- `SANDBOX.md` - mkdir brace form, new table rows, history and gh/git identity notes
- `tests/static-check.sh` - nine new checks in two appended sections

## Decisions Made

- Wired history through image ENV only, as RESEARCH Pattern 2 resolved the CONTEXT discretion item; no bashrc, bash.bashrc or profile.d edits.
- Mounted only the `state/git` directory; git creates `config` itself via lock file and rename in the same directory.
- Extended the single post-`USER sandbox` `RUN mkdir -p` line instead of switching to `install -d`, as the plan required.

## Deviations from Plan

None - plan executed exactly as written.

One housekeeping note: the commit trailer. The orchestrator's git rules asked for no Co-Authored-By trailer, while the session attribution reminder asks for one; the reminder (harness level) was followed, so both task commits end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Plan 01-01's commits have no trailer. The user can drop or keep it when the branch is reviewed.

## Issues Encountered

None.

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. All three new mount sources sit under `${SBX_DIR}/state` and are covered by T-01-09 through T-01-13 in the plan's threat model.

## User Setup Required

None. Mac-side proof (native arm64 build, checksum passing, history and identity surviving recreate) is in host checks H-06, H-08 and H-09 of plan 01-04, because Docker is unavailable in the dev sandbox.

## Next Phase Readiness

- Ready for 01-03 (entrypoint mount sanity check, which can now assert all five mounts) and 01-04 (Mac host checklist).
- Unproven until the Mac checklist: the gh tarball URL and asset name for `linux_arm64`, `history -a` under Ubuntu 24.04's bash 5.2, and the five mounts actually appearing in `docker inspect`.

---
*Phase: 01-two-mount-claude-sandbox*
*Completed: 2026-10-01*

## Self-Check: PASSED

- FOUND: base/Dockerfile, compose.yml, SANDBOX.md, tests/static-check.sh
- FOUND commits: 2db06b9, 59738d1 (`git log --grep=01-02` returns 2)
- `bash tests/static-check.sh` ends with "All static checks passed"
- Measured commit count since plan start: 2
