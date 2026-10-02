---
phase: 01-two-mount-claude-sandbox
verified: 2026-10-01T19:10:00Z
status: human_needed
score: 5/10 must-haves verified
covered_files:
  - .planning/phases/01-two-mount-claude-sandbox/01-01-PLAN.md
  - .planning/phases/01-two-mount-claude-sandbox/01-01-SUMMARY.md
  - .planning/phases/01-two-mount-claude-sandbox/01-02-PLAN.md
  - .planning/phases/01-two-mount-claude-sandbox/01-02-SUMMARY.md
  - .planning/phases/01-two-mount-claude-sandbox/01-03-PLAN.md
  - .planning/phases/01-two-mount-claude-sandbox/01-03-SUMMARY.md
  - .planning/phases/01-two-mount-claude-sandbox/01-04-PLAN.md
  - .planning/phases/01-two-mount-claude-sandbox/01-04-SUMMARY.md
  - SANDBOX.md
  - base/Dockerfile
  - base/sbx-entrypoint
  - claude/Dockerfile
  - compose.yml
  - tests/static-check.sh
covered_digest: "v2:sha256:42ba75b0332978b5fa1932fcfde896fa2d6f96ab89729da6ec45faa6849e84f1"
behavior_unverified: 5
overrides_applied: 0
behavior_unverified_items:
  - truth: "SC1: the base and Claude images build natively on Apple Silicon and `docker compose up` starts the sandbox (uname -m = aarch64, no platform warning)"
    test: "Run host checks H-00..H-03 from SANDBOX.md on the Mac"
    expected: "Both `docker build` commands succeed (including the build-time `claude --version` assertion), `docker image inspect` shows arm64 twice, `docker exec sbx-demo uname -m` prints aarch64, no platform warning"
    why_human: "Docker is not available in the dev sandbox. Static greps prove the Dockerfile text has no platform override, not that the build succeeds or resolves natively."
  - truth: "SC2: shell runs as non-root sandbox, workspace appears at /home/sandbox/workspace, `ls -a /home/sandbox` shows .bashrc and .local, git status has no dubious-ownership error"
    test: "Run H-04, H-05, H-06"
    expected: "uid=1000(sandbox); x.txt created in the container shows up in $SBX_DIR/workspace; .bashrc and .local listed; .local and .local/state owned by sandbox; git status clean of dubious-ownership errors"
    why_human: "Needs a running container and Docker Desktop VirtioFS ownership behavior (assumption A-E6 in the plans, unexercised)."
  - truth: "SC3: Claude login and sessions survive container recreate and a --no-cache rebuild; .claude.json, settings and sessions are visible in state/claude as a directory mount"
    test: "Run H-07, then H-09"
    expected: "`.claude.json`, `.credentials.json`, `projects/` in $SBX_DIR/state/claude; `claude auth status` loggedIn true after `down`, `--no-cache` rebuilds and `up`; `claude --continue` resumes the earlier session; Mounts JSON shows only directory binds"
    why_human: "Needs a real login and Docker. Whether CLAUDE_CONFIG_DIR really puts .claude.json inside the config dir for the pinned 2.1.285 is a runtime fact no grep can show."
  - truth: "SC4: commands typed in the container shell are still in `history` after the container is removed and recreated"
    test: "Run H-08"
    expected: "Marker typed in a shell left open across `down`/`up` appears in `history` of a new shell and in $SBX_DIR/state/shell/bash_history"
    why_human: "State-transition invariant (PROMPT_COMMAND `history -a` writing through to the bind mount). ENV is present and wired, but nothing exercises it."
  - truth: "SC5: after `docker compose down` and a fresh `up`, every file in workspace and state is still on the Mac, and `docker volume ls` shows no volume holding sandbox data"
    test: "Run H-09 and H-11"
    expected: "All files intact; `docker volume ls` lists nothing for the sandbox; Mounts JSON all Type bind"
    why_human: "Static side holds (no VOLUME, only five binds, no `-v` in docs), but the post-recreate state is a runtime invariant."
human_verification:
  - test: "Run the full host checklist H-00..H-13 plus Coexistence from SANDBOX.md on the Mac and fill in the Record your results table (include `docker compose version` and Docker Desktop version)"
    expected: "Every check meets its stated pass condition. This is the only evidence for SC1-SC5. The user deferred it to Phase 2 on 2026-10-01 (\"I'm going to skip manually testing this, and will test on phase 2\"); it has NOT been run."
    why_human: "Docker unavailable in the dev sandbox; the deferral is a deferral, not an approval."
  - test: "H-10: start with a nonexistent SBX_DIR"
    expected: "`up` errors and the path is not created. If Docker creates the folders, `create_host_path: false` is not honored by the user's Compose and the env_file-sentinel follow-up (needs user approval) becomes a gap-closure item."
    why_human: "Depends on the user's Compose version (docker/compose issue 13602). Unknown until run."
  - test: "H-12: installed Claude Code equals the approved pin, and a plain `docker run` is refused"
    expected: "`docker run --rm --entrypoint claude sbx-claude:local --version` prints `2.1.285 (Claude Code)`; plain `docker run ... claude --version` prints `[sbx] ERROR ... not a bind mount` and rc=1"
    why_human: "Closes supply-chain threat T-01-SC. Also the first time the build-time smoke assertion `test \"$(claude --version)\" = \"2.1.285 (Claude Code)\"` is exercised; if the output format differs the Claude image will not build at all."
  - test: "Watch for a false refusal from the entrypoint writability test on VirtioFS"
    expected: "`docker compose up -d --wait` succeeds. If the container exits with `[sbx] ERROR: ... is not writable by sandbox` although the Mac folder is writable, the `[ ! -w ]` check in base/sbx-entrypoint is a false positive on Docker Desktop's ownership mapping."
    why_human: "Docker Desktop ownership mapping cannot be observed here. Not a known defect, a risk the static tier cannot rule out."
  - test: "Judgment-tier prohibitions from 01-01-PLAN.md (non-authoritative LLM verdicts below; human review recommended)"
    expected: "Confirm the four MUST NOT statements hold on the Mac (H-09 `docker inspect` Mounts, H-06/H-07 credentials land in state/ not workspace/)"
    why_human: "unverified-prohibition: judgment tier, no wired enforcement beyond static greps."
---

# Phase 1: Two-Mount Claude Sandbox Verification Report

**Phase Goal:** The user can run a Claude Code sandbox on their Mac. Code lives in `<sandbox>/workspace` and Claude state lives in `<sandbox>/state/claude`. Nothing is mounted over `/home/sandbox`, and the Claude login survives recreating the container and rebuilding the image.
**Verified:** 2026-10-01T19:10:00Z
**Status:** human_needed
**Re-verification:** No, initial verification

## Verdict in one paragraph

The static layer of the goal is real and correct: the files exist, are substantive, and are wired to each other. The layout is exactly two primary directory mounts plus three small state directories, nothing targets `/home/sandbox`, there is no `VOLUME`, the Claude image is a thin layer on the base, and the entrypoint refuses to start without mounts (I ran it here and it exits 1 with the intended message). No gap, stub or debt marker was found. But the phase goal is a runtime promise (builds on arm64, login survives recreate and `--no-cache` rebuild, history persists, no data lost on `down`/`up`), and none of that has been exercised. The user explicitly deferred the Mac checklist H-00..H-13 to Phase 2. SC1-SC5 are therefore present and wired but behavior-unverified, so the status is `human_needed`, not `passed`. REQUIREMENTS.md correctly still shows the runtime-dependent IDs as Pending.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC1: base and Claude images build and run natively on Apple Silicon; sandbox starts with the documented `docker compose` command; `uname -m` is aarch64, no emulation warning | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Present: `base/Dockerfile` `FROM ubuntu:24.04`, arch mapped via `dpkg --print-architecture`, no `platform:`/`--platform` anywhere (static-check PASS); `claude/Dockerfile` `ARG BASE_IMAGE=sbx-base:local` + `FROM ${BASE_IMAGE}`; `compose.yml` uses `image: sbx-claude:local`, `pull_policy: never`; documented `docker compose up -d --wait` in `SANDBOX.md`. Nothing was ever built (no Docker). H-01..H-03 not run. |
| 2 | SC2: non-root `sandbox` shell; `<sandbox>/workspace` at `/home/sandbox/workspace`; `.bashrc` and `.local` visible; no dubious-ownership error | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Present: `useradd -m -u 1000` with `id` assertion, last `USER sandbox` in both Dockerfiles, `git config --system safe.directory '*'` (runs as root before `USER sandbox`, line 66), `useradd -m` seeds `.bashrc`, `.local/state/sbx` created as sandbox, bind target `/home/sandbox/workspace`. Runtime behavior (VirtioFS ownership, git) unexercised. H-04..H-06 not run. |
| 3 | SC3: login and sessions survive container recreate and `--no-cache` rebuild; `.claude.json`, settings, sessions visible in `state/claude`; directory mount | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Present: `ENV CLAUDE_CONFIG_DIR=/home/sandbox/.claude`; compose bind source `${SBX_DIR}/state/claude` to that exact target (cross-file check PASS); long-syntax directory bind, `create_host_path: false`; Claude installed in `/usr/local` (outside any mount). Login persistence is a state-transition invariant that was never exercised. H-07, H-09 not run. |
| 4 | SC4: shell history survives container removal and recreate | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Present: image ENV `HISTFILE=/home/sandbox/.local/state/sbx/shell/bash_history`, `PROMPT_COMMAND="history -a"`, bind of `state/shell` to the parent directory (directory, not file). Ubuntu's skeleton `.bashrc` does not override HISTFILE or PROMPT_COMMAND. Not exercised. H-08 not run. |
| 5 | SC5: after `down` and fresh `up`, workspace and state are intact and no Docker volume holds sandbox data | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Static side verified (truths 6 and 8). The post-recreate outcome and `docker volume ls` are runtime facts. H-09, H-11 not run. |
| 6 | Nothing is mounted over `/home/sandbox`; exactly five bind mounts, all directories, all sourced under `${SBX_DIR}`; no single-file mount | ✓ VERIFIED | `compose.yml` lines 35-65: targets are `/home/sandbox/workspace`, `/home/sandbox/.claude`, and three `.local/state/sbx/{shell,gh,git}`; none equals `/home/sandbox`. Each source ends in a directory path. `bash tests/static-check.sh`: PASS "nothing mounted over /home/sandbox", "every mount source is under SBX_DIR", "exactly five bind mounts", "no short-syntax mounts". |
| 7 | IMG-02: Claude image builds FROM the shared base and adds only agent-specific content | ✓ VERIFIED | `claude/Dockerfile` has a single `FROM ${BASE_IMAGE}` (default `sbx-base:local`); it adds only the npm-pinned `@anthropic-ai/claude-code`, `~/.claude` dir, and ENV. No GSD, no toolchains. |
| 8 | LAY-04 (static half): nothing in the layout or docs can delete sandbox data | ✓ VERIFIED | No `VOLUME` instruction in either Dockerfile; no `volumes:` top-level or named volume in `compose.yml`; `SANDBOX.md` and `compose.yml` contain no `down -v`/`--volumes` (static-check PASS "docs never remove volumes on down"). Runtime half is truth 5. |
| 9 | The entrypoint refuses to start without real mounts, installs nothing, and execs its command | ✓ VERIFIED | Behavioral spot-check, run here: `bash base/sbx-entrypoint echo ran` prints `[sbx] ERROR: /home/sandbox/workspace is not a bind mount; ...` and exits rc=1. File is 100755 in git, ends with `exec "$@"`, contains no package manager call. Dockerfile COPYs it to `/usr/local/bin` (root-owned, 755) and sets `ENTRYPOINT`. (Caveat IN-01: it checks "is a mount point", not "is a bind mount".) The positive path (all mounts present) could not be exercised without Docker. |
| 10 | Coexistence: `ClaudeCode/`, `OpenCode/`, `README.md` unchanged since 934e2c5; no old `cc_` names | ✓ VERIFIED | `git diff --stat 934e2c5 -- ClaudeCode OpenCode README.md` is empty; static-check PASS "old layout untouched", "no old cc_ names". |

**Score:** 5/10 truths verified (5 present, behavior-unverified). No truth FAILED.

### Prohibitions (judgment tier, from 01-01-PLAN.md; NON-AUTHORITATIVE LLM verdicts, human review recommended)

| Prohibition | LLM verdict | Evidence | Flag |
|-------------|-------------|----------|------|
| No host path exposed other than `$SBX_DIR/workspace` and `$SBX_DIR/state/*`; no docker.sock, no host home/.ssh/.claude; no root agent | holds (static) | All five sources under `${SBX_DIR}`; no `docker.sock`; no `sudo`; last `USER sandbox`; `no-new-privileges` + `cap_drop: ALL`. Weak spot: IN-03, a relative `SBX_DIR` would resolve against the repo directory and is not rejected. | unverified-prohibition, human review recommended |
| No credentials stored in `workspace` or a git work tree | holds (static) | Claude, gh, git config paths are all ENV-redirected into `state/*`, a sibling of `workspace/`. | unverified-prohibition, human review recommended |
| No compromised GSD package; no package install at container start | holds | static-check PASS "no compromised GSD package names", "no runtime package runner"; `grep` for `npx|latest|get-shit-done-cc|gsd-build` over `base claude compose.yml` returns nothing. | unverified-prohibition, human review recommended |
| Old-layout sandboxes not disturbed | holds | Truth 10. | unverified-prohibition, human review recommended |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `base/Dockerfile` | ubuntu:24.04 base, Node 24.21.0 and gh 2.102.0 checksum-checked, sandbox uid 1000, safe.directory, history/gh/git ENV, entrypoint | ✓ VERIFIED (static) | 105 lines, substantive, wired by `claude/Dockerfile` FROM and compose binds. Build never run. |
| `base/sbx-entrypoint` | mount check then exec | ✓ VERIFIED | 34 lines, executable, run locally (refusal path). Wired via COPY+ENTRYPOINT and `SBX_MOUNTS`. |
| `claude/Dockerfile` | thin image on base, Claude Code 2.1.285, ENV | ✓ VERIFIED (static) | Wired to `compose.yml` (`CLAUDE_CONFIG_DIR` == bind target). Build never run. |
| `compose.yml` | one-service sandbox, directory binds, hardening | ✓ VERIFIED (static) | `docker compose config` not run (no Docker). |
| `tests/static-check.sh` | Docker-free checks | ✓ VERIFIED | Ran: all PASS, ends "All static checks passed"; shellcheck/hadolint SKIP (not installed). |
| `SANDBOX.md` | quick-start + H-00..H-13 checklist | ✓ VERIFIED | All 14 H-IDs present, commands match `compose.yml`/Dockerfile names. Contains two inaccuracies, see WR-01 and IN-03. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `compose.yml` | `claude/Dockerfile` | `image: sbx-claude:local` / `docker build -t sbx-claude:local claude/` | WIRED | Tag matches in both and in `SANDBOX.md`. |
| `claude/Dockerfile` | `base/Dockerfile` | `ARG BASE_IMAGE` + `FROM ${BASE_IMAGE}` | WIRED | Default `sbx-base:local` matches the documented base build tag. |
| `claude/Dockerfile` | `compose.yml` | `CLAUDE_CONFIG_DIR` == state/claude bind target | WIRED | `/home/sandbox/.claude` in both. |
| `base/Dockerfile` ENV | `compose.yml` | `HISTFILE`, `GH_CONFIG_DIR`, `GIT_CONFIG_GLOBAL` directories == bind targets | WIRED | `/home/sandbox/.local/state/sbx/{shell,gh,git}`. |
| `claude/Dockerfile` | `base/sbx-entrypoint` | `SBX_MOUNTS=/home/sandbox/.claude` read by the loop | WIRED | Entrypoint loop iterates `${SBX_MOUNTS:-}`. |
| `SANDBOX.md` | `compose.yml` | `mkdir state/{claude,shell,gh,git}` creates every bind source | WIRED | Preflight loop lists the same five folders. |

### Data-Flow Trace (Level 4)

Not applicable: no component renders dynamic data. The equivalent here is "state written in the container lands on the Mac", which is exactly the unexercised runtime invariant in truths 3-5.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Static tier | `bash tests/static-check.sh` | All PASS, "All static checks passed" (shellcheck/hadolint SKIP) | ✓ PASS |
| Entrypoint refuses without mounts | `bash base/sbx-entrypoint echo ran; echo rc=$?` | `[sbx] ERROR: /home/sandbox/workspace is not a bind mount ...`, rc=1, `ran` never printed | ✓ PASS |
| Entrypoint executable bit in git | `git ls-files -s base/sbx-entrypoint` | mode 100755 | ✓ PASS |
| Docker build / run / compose | `docker ...` | `docker: command not found` | ? SKIP (routes to human verification) |

### Probe Execution

No `scripts/*/tests/probe-*.sh` exists and no plan declares a probe. SKIPPED.

### Requirements Coverage

All seven phase IDs appear in PLAN frontmatter (01: LAY-01, LAY-02, LAY-04, IMG-02, IMG-05, IMG-06; 02: LAY-03, LAY-02, IMG-05; 03: LAY-04, IMG-06; 04: all seven). REQUIREMENTS.md maps exactly these seven to Phase 1. No orphaned requirements.

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|----------------|-------------|--------|----------|
| LAY-01 | 01-01, 01-04 | `workspace` at `/home/sandbox/workspace`, nothing over home | ? NEEDS HUMAN | Mount layout verified statically (truth 6); visibility of `.bashrc`/`.local` and ownership is H-05, not run. |
| LAY-02 | 01-01, 01-02, 01-04 | Claude state in `state/claude` via `CLAUDE_CONFIG_DIR`, directory mount, survives recreate and rebuild | ? NEEDS HUMAN | Wiring verified; survival is H-07/H-09, not run. |
| LAY-03 | 01-02, 01-04 | Bash history persists | ? NEEDS HUMAN | ENV + directory bind present; H-08 not run. |
| LAY-04 | 01-01, 01-03, 01-04 | Stop/remove/recreate never deletes data | ? NEEDS HUMAN (static half VERIFIED) | No `VOLUME`, no volume flags, five binds (truth 8); H-09/H-11 not run. |
| IMG-02 | 01-01, 01-03, 01-04 | Claude image FROM shared base, agent-only additions | ✓ SATISFIED | Truth 7. |
| IMG-05 | 01-01, 01-02, 01-04 | Native arm64 on Docker Desktop | ? NEEDS HUMAN | No platform override (static); H-01 not run. |
| IMG-06 | 01-01, 01-03, 01-04 | Non-root `sandbox`, no dubious-ownership | ? NEEDS HUMAN | `useradd` uid 1000, `USER sandbox`, system `safe.directory`; H-04/H-06 not run. |

REQUIREMENTS.md leaves the six runtime-dependent IDs Pending and checks none of the seven. That is the honest state and I agree with it; IMG-02 could arguably be ticked but leaving it Pending until the host run is harmless.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (all phase files) | - | `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER` | none found | No debt markers. |
| - | - | stub / empty-return patterns | none found | Shell and YAML only. |

### Code Review Findings (01-REVIEW.md) vs. must-haves

All seven findings are still `open` in `01-REVIEW-DISPOSITION.md` (recorded, not triaged). None is a data-loss or isolation break, and none turns a must-have into FAILED, but three touch claims the phase makes.

| ID | Undermines a must-have? | Assessment |
|----|-------------------------|------------|
| WR-01 history "shared between all open shells" | No. LAY-03 and SC4 require persistence only, and `history -a` delivers persistence. | Confirmed by reading `base/Dockerfile:68-79` and `SANDBOX.md:48`: the sharing claim is false (`history -a` never reads other shells' commands). It is a documentation overclaim. H-08 cannot catch it. Fix the wording or add `history -n`. |
| WR-02 H-06 overwrites real git identity with "T" | No (checklist hazard). | Confirmed at `SANDBOX.md:218`. Running the checklist on a live sandbox silently replaces `user.name` in `state/git/config`. Fix before the user runs it in Phase 2. |
| WR-03 Claude install has no integrity verification; Node/gh checksums share the origin of the tarballs | No for the stated must-have (human approved the pin; checksum comparisons exist). | Real weakness for a project whose constraint is supply-chain safety. Node/gh text says "checksum-verified", which only detects corruption. `claude` is pinned by version only. Accept explicitly or harden; do not leave it as unrecorded. |
| IN-01 entrypoint cannot distinguish bind from tmpfs/named volume | Slightly overstates truth 9 and the LAY-04 guard. | Guard covers the actual accident (no mounts at all). Reword to "is not a mount point". |
| IN-02 orphaned banner comment in `base/Dockerfile` | No | Cosmetic. |
| IN-03 SBX_NAME rule misdescribed; relative `SBX_DIR` accepted | No | A relative `SBX_DIR` would mount a folder under the repo and pass every check. Low likelihood, easy preflight fix. |
| IN-04 hardcoded base commit in static-check | No | Will fail on the first legitimate README edit (Phase 5). Retire or rescope then. |

### Other warnings

- MVP-mode guard: `ROADMAP.md` marks Phase 1 `Mode: mvp`, but the goal line is not an "As a ..., I want to ..., so that ..." user story (the plans noted this and did not invent one). I verified against the stated goal and success criteria as instructed rather than refusing; run `/gsd-mvp-phase 1` if a User Flow Coverage report is wanted.
- `01-VALIDATION.md` is still `status: draft`, `nyquist_compliant: false`, sign-off unticked.
- ROADMAP.md progress table reads "4/4 In Progress" and Phase 1 is unchecked, consistent with the unrun host checks.
- Runtime assumptions that no static check can discharge and that the host run is the first to test: the `npm install -g --allow-scripts=...` flag on the npm bundled with Node 24.21.0; the exact string `2.1.285 (Claude Code)` asserted at build time (a mismatch fails the whole Claude image build); `DISABLE_UPDATES=1` producing "Updates are disabled by your administrator"; `cap_drop: ALL` compatibility; Compose honoring `create_host_path: false` and `${VAR:?}` in the top-level `name`; VirtioFS writability for uid 1000.

### Human Verification Required

See the `human_verification` and `behavior_unverified_items` frontmatter. In short: run `SANDBOX.md` checklist H-00..H-13 and Coexistence on the Mac (deferred by the user to Phase 2 on 2026-10-01, not run), record results and versions, and watch H-10 (missing-folder refusal), H-12 (installed equals pinned version, plain `docker run` refused), and the first `up` for a false writability refusal. Fix WR-02 (and ideally WR-01) in `SANDBOX.md` before the user runs the checklist.

### Gaps Summary

No gaps. Every artifact exists, is substantive and is wired, and every locally testable behavior passes. The phase is not `passed` because SC1-SC5, the actual goal, are runtime claims about Docker on a Mac that nothing has exercised. Phase 1 should be treated as statically complete and runtime-unproven; the deferred host run is the gate, and a failure there becomes input for `/gsd-plan-phase 1 --gaps`. Do not mark LAY-01..LAY-04, IMG-05, IMG-06 complete until it passes.

---

_Verified: 2026-10-01T19:10:00Z_
_Verifier: Claude (gsd-verifier)_
