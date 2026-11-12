---
phase: 01-two-mount-claude-sandbox
verified: 2026-10-04T03:30:00Z
status: passed
score: 5/5 must-haves verified
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
  - tests/guard.sh
  - tests/host-checklist.md
  - tests/host-selftest.sh
  - tests/host/coexistence.sh
  - tests/host/h00-compose-v2.sh
  - tests/host/h01-native-arch.sh
  - tests/host/h02-claude-on-base.sh
  - tests/host/h03-variable-interpolation.sh
  - tests/host/h04-nonroot-user.sh
  - tests/host/h05-workspace-and-home.sh
  - tests/host/h06-git-and-identity.sh
  - tests/host/h08-history-survives-recreate.sh
  - tests/host/h09-rebuild-keeps-files-no-volumes.sh
  - tests/host/h10-missing-folder-refused.sh
  - tests/host/h11-stop-is-quick-and-safe.sh
  - tests/host/h12-plain-run-refused-pin-installed.sh
  - tests/host/h13-env-and-no-self-update.sh
  - tests/host/lib.sh
  - tests/host/manual/h07-login.sh
  - tests/host/manual/h09-rebuild-resume.sh
  - tests/host/manual/h13-doctor.sh
  - tests/host/run-all.sh
covered_digest: "v2:sha256:66303c52d94e11a9fc20dccd357cd45a92d9a81a2baeda34d244443bf7230cbc"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 5/10
  gaps_closed:
    - "SC1 to SC5 (previously present, behavior-unverified): exercised on the Mac by tests/host/run-all.sh (14/14 PASS) and the three manual helpers, recorded in 01-UAT.md (5/5 pass)"
  gaps_remaining: []
  regressions: []
advisory:
  - finding: "WR-01 (01-REVIEW.md): the entrypoint check that the project folder exists cannot fire, because compose working_dir makes the Docker daemon create a missing $SBX_DIR/<name> before the entrypoint runs. A mistyped SBX_NAME against a valid SBX_DIR leaves an empty folder instead of an error. SANDBOX.md lines 116 and 155 and the comment at compose.yml:21 promise an error."
    category: other
    reason: "No ROADMAP success criterion or requirement states a missing-project-folder refusal. The refusal that matters for data safety (a mistyped or missing SBX_DIR) works: H-10 passed on the Mac. Nothing is lost or exposed by the empty folder. Documentation overclaim plus dead code; fix or reword when convenient."
    evidence_status: "code read (compose.yml:22, base/sbx-entrypoint:32); no host test covers a valid SBX_DIR with a mistyped SBX_NAME"
  - finding: "WR-02: base/Dockerfile says compose 'never creates anything on the Mac', but SANDBOX.md records that some Compose versions ignore create_host_path: false"
    category: other
    reason: "Comment overclaim only. On the user's Compose (2.40.0-desktop.1) H-10 passed: the flag is honored. On a Compose that ignores it, the entrypoint still refuses to start. No stated truth depends on the comment."
    evidence_status: "code read plus 01-UAT.md item 2"
  - finding: "WR-03: Claude Code is installed by exact version pin only, with no npm integrity hash; Node and gh checksums come from the same origin as the tarballs"
    category: security
    reason: "No success criterion or requirement demands integrity pinning. The pin was approved by the user at the plan 01 supply-chain checkpoint, and H-12 passed on the Mac (installed version equals the pin). Worth hardening for a project whose constraint is supply-chain safety; accept explicitly or schedule it, do not leave it unrecorded."
    evidence_status: "code read (claude/Dockerfile:17, base/Dockerfile:23-41)"
  - finding: "SC3 says the image is rebuilt with --no-cache. 01-UAT.md does not record whether the Mac run used SBXTEST_NO_CACHE=1 or the helper's --no-cache; both default to a cached rebuild."
    category: other
    reason: "Not a gap: login and sessions live in the bind-mounted state/claude, outside every image layer, so cache use cannot change whether they survive. The images were also first built on the Mac by that run, so the full Dockerfile (including the build-time claude --version assertion) did execute from scratch. Optional confirmation: run bash tests/host/manual/h09-rebuild-resume.sh --no-cache once."
    evidence_status: "code read (tests/host/lib.sh build_images, manual/h09-rebuild-resume.sh) and UAT text"
  - finding: "Bookkeeping: REQUIREMENTS.md still shows LAY-01..LAY-04, IMG-02, IMG-05, IMG-06 unchecked and Pending, and ROADMAP.md shows Phase 1 unchecked, '4/4 In Progress'"
    category: other
    reason: "These can now be ticked: every requirement is backed by a passing Mac check. Left for the orchestrator's phase-complete step; this verifier does not edit them."
    evidence_status: "REQUIREMENTS.md lines 125-134, ROADMAP.md progress table"
---

# Phase 1: Two-Mount Claude Sandbox Verification Report

**Phase Goal:** The user can run a Claude Code sandbox on their Mac. The sandbox folder `<sandbox>` is the container's only mount: code lives in `<sandbox>/<name>` and Claude state lives in `<sandbox>/state/claude`. Nothing is mounted over `/home/sandbox`, and the Claude login survives recreating the container and rebuilding the image.
**Verified:** 2026-10-04T03:30:00Z
**Status:** passed
**Re-verification:** Yes. The previous report (2026-10-01) was `human_needed`, 5/10, because the Mac checks could not run. It was stale: the layout moved from five mounts to one sandbox folder mount, `SANDBOX.md` was split, and `tests/static-check.sh` was replaced by `tests/guard.sh`. This report re-derives everything from the current code and the ROADMAP success criteria.

## Verdict in one paragraph

The goal is achieved. The code on disk matches the single-mount design: one bind mount of `$SBX_DIR` at `/home/sandbox/workspace`, nothing over `/home/sandbox`, state redirected into `state/` by image ENV, no `VOLUME`, a thin Claude image on the shared base, a non-root `sandbox` user, and an entrypoint that refuses to start without the mount. The Docker-dependent claims (SC1 to SC5) are no longer unexercised: Phase 1.1 turned the Mac checklist into `tests/host/run-all.sh` and three attended helpers, and `01-UAT.md` records the user running them on the Mac (M1, Docker Desktop 4.48.0, Compose 2.40.0-desktop.1): 14 passed, 0 failed, 0 not run, plus the three manual helpers passing. I read every check script and confirmed each one asserts the behavior its success criterion names, and that `base/`, `claude/` and `compose.yml` have not changed since before that run (last commit 2026-10-02). `bash tests/guard.sh` and `bash tests/host-selftest.sh` pass here. None of the three code-review warnings breaks a stated truth; they are recorded as advisory.

## Goal Achievement

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC1: base image, then Claude image `FROM` it, built on the Mac; sandbox started with the documented `docker compose` command; native arm64 (`uname -m` aarch64), no platform warning | VERIFIED | Code: `base/Dockerfile` `FROM ubuntu:24.04`, arch from `dpkg --print-architecture`, no `platform:` or `--platform` anywhere (guard passes); `claude/Dockerfile` `ARG BASE_IMAGE=sbx-base:local` + `FROM ${BASE_IMAGE}`. Mac evidence: `run-all.sh` builds both images (`build_images`), starts the sandbox with the exact documented `docker compose up -d --wait` (`compose_up`); H-02 PASS (Claude image layers start with every base layer, one `FROM ${BASE_IMAGE}` line); H-01 PASS (both images report the daemon's native arch, `uname -m` in the container equals the daemon's `aarch64`, and no "does not match" platform warning in any build or up log). |
| 2 | SC2: non-root `sandbox` shell; sandbox folder at `/home/sandbox/workspace`; shell starts in `/home/sandbox/workspace/<name>`; `ls -a /home/sandbox` shows `.bashrc` and `.local`; `git status` has no dubious-ownership error | VERIFIED | Code: `useradd -m -u 1000` with an `id` assertion, last `USER sandbox` in both Dockerfiles, `git config --system safe.directory '*'`, `compose.yml` `working_dir: /home/sandbox/workspace/${SBX_NAME}`. Mac evidence: H-04 PASS (`uid=1000(sandbox) gid=1000(sandbox)`); H-05 PASS (`touch x.txt` with no `-w` lands in `$RUN/hosttest` on the Mac, which proves both the mount and the default working directory; `.bashrc` and `.local` listed; `.local` and `.local/state` owned by `sandbox`); H-06 PASS (git repo made on the host, `git status` in the container exits 0 with no "dubious ownership", system `safe.directory` is `*`). |
| 3 | SC3: login once, then container recreate and image rebuild; `claude` still logged in, earlier sessions resumable; `.claude.json`, settings and sessions visible in `<sandbox>/state/claude`, inside the one directory mount | VERIFIED | Code: `ENV CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude` (claude/Dockerfile), `SBX_STATE_DIRS=claude` makes the entrypoint create the folder, the only mount is a directory bind (guard rule `exactly_one_mount_and_not_over_home`), Claude itself lives in `/usr/local` outside the mount. Mac evidence (attended): `manual/h07-login.sh` PASS x3 (`.claude.json`, `.credentials.json`, `projects/` exist in `.../state/claude` on the Mac; `claude auth status` loggedIn true; no `~/.claude.json` in the container home); `manual/h09-rebuild-resume.sh` PASS x2 (rebuild both images, down, up, `auth status` still loggedIn true, `claude --continue` resumed the earlier session); H-09 PASS (exactly one mount, type bind, destination `/home/sandbox/workspace`). Caveat recorded as advisory: cache use on the rebuild is not recorded; it cannot affect state that lives in the bind mount. |
| 4 | SC4: commands typed in the container shell are still in `history` after the container is removed and recreated | VERIFIED | Code: image ENV `HISTFILE=/home/sandbox/workspace/state/shell/bash_history`, `PROMPT_COMMAND="history -a"`. Mac evidence: H-08 PASS. It holds a first `bash -i` open, waits for the marker to reach `state/shell/bash_history` on the Mac while that shell is still open (proves write-through), runs `compose down` then `up`, and requires the marker in a fresh shell's `history` output. This is the state-transition invariant the previous report could not exercise. |
| 5 | SC5: after `docker compose down` and a fresh `up`, every file in `<sandbox>/<name>` and `<sandbox>/state` is still on the Mac, and `docker volume ls` shows no volume holding sandbox data | VERIFIED | Code: no `VOLUME` and no `volumes:` or `type: volume` (guard), no `down -v` or `--volumes` in `SANDBOX.md` or `compose.yml` (grep). Mac evidence: H-11 PASS (sentinel files in both `hosttest/` and `state/` intact after `compose down`, stop under 10 s, container gone); H-09 PASS (sentinels in both folders survive a full rebuild plus down and up, `docker volume ls -q` identical before and after, the container's only mount is the bind). |

**Score:** 5/5 truths verified, 0 behavior-unverified.

### Supplementary truths from the plans (superseded wording noted)

The four PLAN files predate the move from five mounts to one mount; their `must_haves` still say `$SBX_DIR/workspace`, `state/claude` as a separate mount, "exactly five bind mounts" and `tests/static-check.sh`. Where they conflict with the ROADMAP contract, the ROADMAP wins. The still-valid plan truths were checked against the current code:

| Plan truth | Status | Evidence |
|-----------|--------|----------|
| IMG-02: Claude image builds `FROM` the shared base and adds only agent-specific content | VERIFIED | One `FROM ${BASE_IMAGE}`; adds only the pinned npm `@anthropic-ai/claude-code`, a `~/.claude` symlink fallback, three ENV vars, and a build-time version assertion. No GSD, no toolchains. H-02 PASS on the Mac. |
| Nothing in the layout can delete sandbox data | VERIFIED | See SC5. |
| The entrypoint refuses to start without the mount, installs nothing, and execs its command | VERIFIED | Run here: `bash base/sbx-entrypoint echo ran` prints `[sbx] ERROR: /home/sandbox/workspace is not a bind mount; ...`, exit 1, `ran` never printed. File is mode 100755 in git, ends in `exec "$@"`, guard rule `no_installs_at_container_start` passes. Mac: H-12 PASS (a plain `docker run` is refused with `[sbx] ERROR` and `not a bind mount`, rc 1). Weak wording: it tests "is a mount point", not "is a bind mount" (review IN-01, info). |
| Installed Claude Code equals the approved pin, self-update is off | VERIFIED | H-12 PASS (`2.1.285 (Claude Code)`), H-13 PASS (five env vars visible to `docker exec`, `claude update` says updates are disabled, no `~/.local/share/claude`), manual `claude doctor` PASS. |
| Coexistence: `ClaudeCode/`, `OpenCode/`, `README.md` untouched, no old `cc_` names | VERIFIED | `git diff --quiet 304f80d1 -- ClaudeCode OpenCode README.md` exits 0 (run here); guard rule `old_layout_untouched` passes; Coexistence PASS on the Mac (old containers and folders untouched). |

### Prohibitions (judgment tier, from 01-01-PLAN.md)

Non-authoritative LLM verdicts, each now backed by Mac evidence recorded in `01-UAT.md` or by a deterministic guard rule. No prohibition is left unresolved, so none is flagged.

| Prohibition | Verdict | Evidence |
|-------------|---------|----------|
| No host path exposed beyond the sandbox's own `$SBX_DIR`; no docker.sock, host home, `.ssh`, host `.claude`; no root agent | holds | One bind, source `${SBX_DIR}`; guard `no_docker_socket_or_sudo` and `runs_without_privileges` pass; `no-new-privileges` and `cap_drop: ALL` present. Mac: H-09 inspected the container mounts (one bind of the run folder); UAT item 5 pass. Plan text says `$SBX_DIR/workspace` and `$SBX_DIR/state/*`; in the one-mount layout that is simply `$SBX_DIR`. |
| No Claude, gh or git credentials inside the project folder or a git work tree | holds | All three tools are redirected by image ENV into `state/` (`claude`, `gh`, `git`), a sibling of `<name>/`. Mac: H-07 shows the credentials in `state/claude`; H-06 shows the identity in `state/git/config`; UAT item 5 pass. |
| No compromised GSD package; no package install at container start | holds | Guard rules `no_compromised_gsd_package`, `no_installs_at_container_start`, `no_floating_latest_versions` pass (deterministic). |
| Old-layout sandboxes not disturbed | holds | Coexistence PASS on the Mac plus guard `old_layout_untouched`. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `base/Dockerfile` | ubuntu:24.04 base, pinned Node and gh with checksum checks, sandbox uid 1000, system `safe.directory`, state ENV, entrypoint | VERIFIED | 86 lines, substantive, wired (`claude/Dockerfile` `FROM`, compose binds, entrypoint COPY). Built on the Mac by `run-all.sh`. |
| `base/sbx-entrypoint` | mount, writability and state-folder check, then exec | VERIFIED | Executable, run here (refusal path); positive path exercised on the Mac (the sandbox starts, H-05 and H-08 run inside it). |
| `claude/Dockerfile` | thin image on the base, Claude Code 2.1.285, ENV | VERIFIED | Wired to `compose.yml` through the image tag and `CLAUDE_CONFIG_DIR` under the one bind target. Built on the Mac, including the build-time version assertion. |
| `compose.yml` | one service, one directory bind, hardening | VERIFIED | `docker compose config` and `up` exercised by H-03, H-10 and the whole run. |
| `tests/guard.sh` | Docker-free rule guard | VERIFIED | Ran here: 15/15 PASS, "All rules hold." |
| `tests/host/*` and `tests/host/manual/*` | automated and attended Mac checks | VERIFIED | Read in full; each asserts what its success criterion names. `bash tests/host-selftest.sh` against a fake docker passes ("All cases pass"). |
| `SANDBOX.md` | quick start, layout, safety notes | VERIFIED | Matches `compose.yml` and the Dockerfiles. Two statements overclaim (WR-01 doc lines); see advisory. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `compose.yml` | `claude/Dockerfile` | `image: sbx-claude:local`, `pull_policy: never` | WIRED | Same tag in `SANDBOX.md`, `lib.sh build_images`, H-02, H-12. |
| `claude/Dockerfile` | `base/Dockerfile` | `ARG BASE_IMAGE=sbx-base:local`, `FROM ${BASE_IMAGE}` | WIRED | H-02 asserts the layer prefix and the single `FROM` line. |
| `compose.yml` bind target | image ENV | `/home/sandbox/workspace` is the prefix of `HISTFILE`, `GH_CONFIG_DIR`, `GIT_CONFIG_GLOBAL`, `CLAUDE_CONFIG_DIR` | WIRED | All four paths sit under `/home/sandbox/workspace/state/`; H-07, H-08, H-06 confirm the files land on the Mac. |
| `claude/Dockerfile` `SBX_STATE_DIRS` | `base/sbx-entrypoint` loop | `for d in shell gh git ${SBX_STATE_DIRS:-}` | WIRED | `state/claude` is created at start; H-07 finds it on the Mac. |
| `compose.yml` `working_dir` | shell start folder | `/home/sandbox/workspace/${SBX_NAME}` | WIRED | H-05: a file created with no `-w` appears in `$RUN/hosttest`. |
| `run-all.sh` | every check script | the three lists plus the fatal and final checks | WIRED | Guard rule `host_checks_declare_dependencies` requires each check to be named in `run-all.sh`. |

### Data-Flow Trace (Level 4)

Not applicable: no component renders dynamic data. The equivalent invariant, "state written in the container lands on the Mac", is exactly what H-05, H-06, H-07 and H-08 assert from the host side and what the Mac run recorded as PASS.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Guard rules | `bash tests/guard.sh` | 15 PASS, "All rules hold." | PASS |
| Host check logic against a fake docker | `bash tests/host-selftest.sh` | "All cases pass." | PASS |
| Entrypoint refuses without the mount | `bash base/sbx-entrypoint echo ran` | `[sbx] ERROR: ... is not a bind mount ...`, rc 1 | PASS |
| Entrypoint mode in git | `git ls-files -s base/sbx-entrypoint` | 100755 | PASS |
| Old layout unchanged | `git diff --quiet 304f80d1 -- ClaudeCode OpenCode README.md` | rc 0 | PASS |
| Docker build, run, compose | `docker ...` | not available in this sandbox | SKIP; covered by the Mac run in `01-UAT.md` |

### Probe Execution

No `scripts/*/tests/probe-*.sh` exists and no plan declares one. SKIPPED.

### Requirements Coverage

All seven IDs appear in PLAN frontmatter (01-01: LAY-01, LAY-02, LAY-04, IMG-02, IMG-05, IMG-06; 01-02: LAY-03, LAY-02, IMG-05; 01-03: LAY-04, IMG-06; 01-04: all seven). `REQUIREMENTS.md` maps exactly these seven to Phase 1. No orphaned requirements.

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|----------------|-------------|--------|----------|
| LAY-01 | 01-01, 01-04 | Sandbox folder is the only mount at `/home/sandbox/workspace`; nothing over home; image `.bashrc` and `.local` visible | SATISFIED | Guard `exactly_one_mount_and_not_over_home`; H-05, H-09 (one bind, correct destination) PASS on the Mac. |
| LAY-02 | 01-01, 01-02, 01-04 | Claude state in `state/claude` via `CLAUDE_CONFIG_DIR`, directory mount, survives recreate and rebuild | SATISFIED | Truth 3: H-07 and manual H-09 PASS on the Mac. |
| LAY-03 | 01-02, 01-04 | Bash history persists across recreate | SATISFIED | Truth 4: H-08 PASS on the Mac. |
| LAY-04 | 01-01, 01-03, 01-04 | Stop, remove, recreate never deletes data | SATISFIED | Truth 5: guard (no `VOLUME`, no volume flags) plus H-09 and H-11 PASS on the Mac. |
| IMG-02 | 01-01, 01-03, 01-04 | Claude image `FROM` the shared base, agent-only additions | SATISFIED | H-02 PASS; Dockerfile read. |
| IMG-05 | 01-01, 01-02, 01-04 | Native arm64 on Docker Desktop | SATISFIED | H-01 PASS on an M1 Mac. |
| IMG-06 | 01-01, 01-03, 01-04 | Non-root `sandbox`, no dubious-ownership errors | SATISFIED | H-04 and H-06 PASS on the Mac. |

`REQUIREMENTS.md` still shows all seven as unchecked and Pending. That is stale bookkeeping, not a missing implementation; see the last advisory item.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| all phase files | - | `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, `PLACEHOLDER` | none | The only `XXX` matches are `mktemp` templates in `tests/host/lib.sh:81` and `tests/host-selftest.sh:14`, not debt markers. |
| all phase files | - | stub or empty-return patterns | none | Shell, YAML and Dockerfiles only. |

### Code Review Findings (01-REVIEW.md) against the truths

Three warnings and four info items, all `open` in `01-REVIEW-DISPOSITION.md`. None turns a truth into FAILED.

| ID | Defeats a truth or success criterion? | Assessment |
|----|---------------------------------------|------------|
| WR-01 project-folder check is dead because of `working_dir` | No. SC2 requires the shell to start in the project folder, which `working_dir` delivers (H-05). No SC or requirement states a refusal on a missing project folder. | Real defect, advisory. Consequence is an empty folder created for a mistyped `SBX_NAME`, no data loss. `SANDBOX.md` lines 116 and 155 and `compose.yml:21` promise an error that cannot occur. Either move the `cd` into the entrypoint (and give `docker exec` shells `-w`), or drop the check and reword the docs. |
| WR-02 Dockerfile comment overclaims `create_host_path` | No. H-10 PASS on Compose 2.40.0-desktop.1 shows the flag is honored there, and the entrypoint is the backstop elsewhere. | Reword the comment. |
| WR-03 Claude Code installed by version pin only | No. No criterion requires integrity hashes; the pin was user-approved and H-12 confirms the installed version. | Consider an npm integrity hash or an explicit risk acceptance; this project exists partly because a package was compromised. |
| IN-01 to IN-04 | No | Wording, absolute-path preflight, base image digest, friendlier error. All low risk. |

### Human Verification Required

None outstanding. The previous report's five human items are closed by `01-UAT.md` (5/5 pass, run on the Mac on 2026-10-03, after the last change to `base/`, `claude/`, `compose.yml` and `tests/host/`). The only optional follow-up is the `--no-cache` confirmation noted in the advisory list.

### Gaps Summary

No gaps. Every ROADMAP success criterion is backed by code that matches the single-mount design and by a Mac check that asserts the criterion's behavior and passed. `01-VALIDATION.md` is still `status: draft`; that is process metadata and does not affect goal achievement. The ROADMAP marks Phase 1 `Mode: mvp`, but the goal is not an "As a ..., I want to ..., so that ..." user story (`user-story.validate` returns false), so verification used the five success criteria instead of a User Flow Coverage table; run `/gsd-mvp-phase 1` if one is wanted.

Next step for the orchestrator: tick LAY-01..LAY-04, IMG-02, IMG-05, IMG-06 in `REQUIREMENTS.md` and mark Phase 1 complete in `ROADMAP.md`.

---

_Verified: 2026-10-04T03:30:00Z_
_Verifier: Claude (gsd-verifier)_
