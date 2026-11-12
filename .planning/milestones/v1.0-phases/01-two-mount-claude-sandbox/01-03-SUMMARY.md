---
phase: 01-two-mount-claude-sandbox
plan: 03
subsystem: infra
tags: [docker, compose, entrypoint, bind-mounts, hardening, bash]

requires:
  - phase: 01-02
    provides: "five directory binds in compose.yml, mount targets created in base/Dockerfile, static-check.sh and SANDBOX.md to extend"
provides:
  - "base/sbx-entrypoint: checks workspace, shell, gh, git and SBX_MOUNTS targets against /proc/self/mountinfo and for writability, then exec"
  - "base/Dockerfile: COPY and chmod 755 of the entrypoint, ENTRYPOINT set, CMD bash kept"
  - "claude/Dockerfile: SBX_MOUNTS=/home/sandbox/.claude in ENV"
  - "compose.yml: security_opt no-new-privileges:true and cap_drop ALL on the sandbox service"
  - "SANDBOX.md: Safety checks section with image-only smoke tests, the MISSING: preflight loop, up --wait plus compose logs"
  - "tests/static-check.sh: 12 more checks (entrypoint, ENTRYPOINT wiring, SBX_MOUNTS, hardening, docs)"
affects: [01-04, phase-03, phase-05]

plan_head_before: 56b03c822e4bd2f78ffcda5be98e1b6332824d51
plan_head_after: 0cb93bb53d2f6b1ae16e28dbd41b2ffca2910b3a

actuals:
  tokens: 2200
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "entrypoint is only a check plus exec; all environment stays in image ENV so docker exec shells never depend on it"
    - "SBX_MOUNTS: an agent image lists its extra mount targets in ENV and the base entrypoint checks them"
    - "layered D-10 defense: create_host_path false, entrypoint mount check, documented preflight loop"

key-files:
  created:
    - base/sbx-entrypoint
  modified:
    - base/Dockerfile
    - claude/Dockerfile
    - compose.yml
    - SANDBOX.md
    - tests/static-check.sh

key-decisions:
  - "Entrypoint detects missing mounts with awk over /proc/self/mountinfo field 5, not util-linux mountpoint, so it has no extra dependency"
  - "SBX_MOUNTS is expanded unquoted on purpose so an agent image can list several paths without the base knowing about any agent"
  - "no-new-privileges and cap_drop ALL are both set; if a host check fails only because of cap_drop, drop cap_drop and keep no-new-privileges"
  - "The env_file sentinel fallback for a Compose that ignores create_host_path is NOT implemented here; it stays a conditional follow-up that needs user approval (01-04, H-10)"

requirements-completed: [LAY-04, IMG-06]

coverage:
  - id: D1
    description: "Both images refuse to start without their bind mounts: the entrypoint exits 1 with an [sbx] ERROR line naming the path that is not a mount, and also stops on a mount that is not writable"
    requirement: "LAY-04"
    verification:
      - kind: other
        ref: "out=$(bash base/sbx-entrypoint true 2>&1); exit status 1 and output contains '[sbx] ERROR: /home/sandbox/workspace is not a bind mount' (run in the dev sandbox, where nothing is mounted)"
        status: pass
      - kind: other
        ref: "bash tests/static-check.sh (entrypoint is executable; entrypoint parses; entrypoint checks mounts then execs; entrypoint checks every base mount target; base image installs and uses the entrypoint; claude image adds its state mount to SBX_MOUNTS)"
        status: pass
    human_judgment: true
    rationale: "The failing path is proven here, but a real docker run without mounts, the passing path on real bind mounts and the writability check as the sandbox user in a container need Docker on the Mac (host check H-12 in plan 01-04)."
  - id: D2
    description: "A mistyped SBX_DIR is caught before start: create_host_path false on all five binds, plus a documented one-line preflight that prints MISSING: for each absent folder, plus up --wait with compose logs"
    requirement: "IMG-06"
    verification:
      - kind: other
        ref: "bash tests/static-check.sh (every bind mount sets create_host_path false; docs carry the missing-folder preflight; docs tell the user to read compose logs)"
        status: pass
    human_judgment: true
    rationale: "Whether the user's Compose version honors create_host_path false is unknowable without running it on the Mac (host check H-10 in plan 01-04 records which layer holds)."
  - id: D3
    description: "The sandbox container runs with no-new-privileges and with all Linux capabilities dropped"
    requirement: "IMG-06"
    verification:
      - kind: other
        ref: "bash tests/static-check.sh (no-new-privileges set; all capabilities dropped)"
        status: pass
    human_judgment: true
    rationale: "Static greps prove the keys are present. That the container still works with every capability dropped needs Docker on the Mac (host checks H-12 and the cap_drop fallback in plan 01-04)."

duration: 1min
completed: 2026-10-01
status: complete
---

# Phase 1 Plan 03: Mount-check entrypoint and hardening Summary

**The sandbox now fails loudly instead of losing data: a 27-line bash entrypoint refuses to start either image unless every state and workspace path is a real, writable bind mount, and compose drops all capabilities with no-new-privileges.**

## Performance

- **Duration:** about 1 min of wall clock (first commit to SUMMARY)
- **Started:** 2026-10-01T18:41:21Z
- **Completed:** 2026-10-01T18:42:05Z (SUMMARY written)
- **Tasks:** 2
- **Files modified:** 6 (1 created, 5 modified)

## Accomplishments

- `base/sbx-entrypoint` checks `/home/sandbox/workspace`, `.local/state/sbx/{shell,gh,git}` and every path in `SBX_MOUNTS` with an awk match on field 5 of `/proc/self/mountinfo`. A missing mount prints `[sbx] ERROR: PATH is not a bind mount; its data would be lost on recreate.` plus a pointer to `docker compose up` and SANDBOX.md, then exits 1. A non-writable mount prints `[sbx] ERROR: PATH is not writable by USER.` and exits 1. The last line is `exec "$@"`, so compose's `sleep infinity` runs unchanged (LAY-04).
- It installs nothing, changes no ownership and sets no environment, so `docker exec` shells never depend on it. The mode is 100755 in git.
- `base/Dockerfile` copies it to `/usr/local/bin/sbx-entrypoint` (root-owned, 755) before `USER sandbox` and sets `ENTRYPOINT` after `WORKDIR`; `CMD ["bash"]` is kept. `claude/Dockerfile` adds `SBX_MOUNTS=/home/sandbox/.claude`, so the base never needs to know about Claude (IMG-02).
- `compose.yml` gets `security_opt: [no-new-privileges:true]` and `cap_drop: [ALL]` with a why-comment and the fallback instruction (IMG-06).
- `SANDBOX.md` has a Safety checks section: image-only smoke tests with `--entrypoint claude`, the `MISSING:` preflight loop to paste before `up`, and `docker compose up -d --wait` plus `docker compose logs`.
- `tests/static-check.sh` now reports 62 passing checks (12 added by this plan), with the entrypoint included in the no-package-runner, no-compromised-GSD-name and no-old-`cc_` scans.

## Task Commits

1. **Task 1: The container refuses to run without its bind mounts** - `b3ee990` (feat)
2. **Task 2: A mistyped SBX_DIR is caught before start, and no extra privileges** - `0cb93bb` (feat)

**Plan metadata:** committed separately as `docs(01-03): complete ...` (SUMMARY, STATE, ROADMAP, REQUIREMENTS)

## Files Created/Modified

- `base/sbx-entrypoint` - mount sanity check, then `exec "$@"` (new, mode 755)
- `base/Dockerfile` - COPY and chmod of the entrypoint, ENTRYPOINT instruction
- `claude/Dockerfile` - `SBX_MOUNTS` in ENV
- `compose.yml` - `security_opt` and `cap_drop` on the sandbox service
- `SANDBOX.md` - Safety checks, image-only smoke tests, missing-folder preflight
- `tests/static-check.sh` - entrypoint, wiring, hardening and docs checks

## Decisions Made

- Used `/proc/self/mountinfo` instead of `mountpoint` so the entrypoint has no dependency beyond awk (RESEARCH Pattern 3).
- Left `${SBX_MOUNTS:-}` unquoted deliberately; the script comment says why.
- Did not implement the `env_file` sentinel fallback: it amends D-12 and depends on H-10, so it needs user approval (01-04).

## Deviations from Plan

None - plan executed exactly as written.

Verification beyond the plan, done in the dev sandbox with a copy of the entrypoint whose paths and mountinfo were redirected to a scratch directory: the passing path runs the command (`exec-ok`, exit 0), an `SBX_MOUNTS` target that is a mount but not writable stops with the `not writable by sandbox` error, and the unmodified script exits 1 with the workspace error. The scratch copy was not committed.

## Issues Encountered

None.

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. The new surface is the entrypoint (T-01-14, T-01-17) and the compose hardening (T-01-16), all in the plan's threat model.

## Next Phase Readiness

- Ready for 01-04: host checklist can now include H-10 (bogus `SBX_DIR`), H-12 (plain `docker run` refused, `up --wait` reporting the failure, `docker compose logs` showing the `[sbx] ERROR` line) and the `cap_drop` fallback note for SANDBOX.md troubleshooting.
- Open for the Mac: whether the user's Compose honors `create_host_path: false` (D-10) and whether the container runs with all capabilities dropped. Neither can be tested without Docker.

---
*Phase: 01-two-mount-claude-sandbox*
*Completed: 2026-10-01*

## Self-Check: PASSED

- FOUND: base/sbx-entrypoint, 01-03-SUMMARY.md
- FOUND commits: b3ee990, 0cb93bb
- `bash tests/static-check.sh` exits 0 (62 checks), entrypoint failing-path test passes, mode 100755
