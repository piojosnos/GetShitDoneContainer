# Roadmap: GSD Agent Sandbox Containers

## Overview

This milestone makes the ClaudeCode sandbox solid. Each phase is a vertical slice that leaves the user with a sandbox they can actually use on the Mac, and each later phase builds on it. Phase 1 replaces the whole-home mount with one sandbox folder mount: code in `<name>/` and all state (Claude, history, gh, git) in `state/`. The home directory is no longer hidden, and login survives recreating the container and rebuilding the image. Phase 1.1 (inserted) automates the Mac host checks, so every later image change is verified by one script run. Phase 1.2 (inserted) ships the user's best-practices bundle (skills, standing rules, memories) in the image, synced into `~/.claude` on every start; Phase 2.1 (inserted) later moves that bundle to its own git repo so any sandbox can update it through a PR. Phase 2 bakes the full pinned toolchain, GSD, and ccusage into the image, so "upgrade = rebuild" becomes true and the image version always wins. Phases 3 and 4 add the small `sbx-*` scripts in the user's priority order: remembered args and one-command upgrade first, then jump-in, then list and cleanup. Phase 5 migrates the roughly four existing sandboxes, retires the old `cc-*` layout, and brings the README in line with reality. Docker doesn't run inside the dev sandbox, so every success criterion below is checked on the Mac.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Two-Mount Claude Sandbox** - A Claude sandbox that runs on the Mac with code and state in separate host folders, a visible image home, and a login that survives rebuilds (completed 2026-10-04)
- [x] **Phase 1.1: Automated host tests** (INSERTED) - One unattended command on the Mac runs every automatable host check (H-00 to H-13) with a PASS/FAIL line each; login, resume and doctor are a short manual pass with helper scripts (completed 2026-10-04)
- [ ] **Phase 1.2: Best-practices bundle baked into the image (stopgap)** (INSERTED) - New sandboxes start with the user's skills, standing rules, and shared memories installed, taken from files in this repo
- [ ] **Phase 2: Pinned Toolchain, GSD, and ccusage** - Every tool is baked in at a version pinned in `versions.env`, the image's GSD wins over persisted state, and `ccusage` reports real usage
- [ ] **Phase 2.1: Best-practices from git, editable from any sandbox** (INSERTED) - The bundle moves to its own repo; each sandbox keeps its own clone, starts with the latest, and sends changes back as PRs
- [ ] **Phase 3: Remembered Sandboxes and One-Command Upgrade** - Register a sandbox once, start and stop it by name, and upgrade everything with one command without losing login
- [ ] **Phase 4: Jump-In and Sandbox Housekeeping** - One command drops you into a sandbox shell or Claude, and you can list and clean up sandboxes safely
- [ ] **Phase 5: Migration, Docs, and Old-Layout Retirement** - Existing sandboxes move over with history intact, the old `cc-*` layout is gone, and the README matches the repo
- [ ] **Phase 6: Automated checks (CI)** - GitHub runs the guard on every PR push and shows it as a PR check

## Phase Details

### Phase 1: Two-Mount Claude Sandbox

**Goal**: The user can run a Claude Code sandbox on their Mac. The sandbox folder `<sandbox>` is the container's only mount: code lives in `<sandbox>/<name>` and Claude state lives in `<sandbox>/state/claude`. Nothing is mounted over `/home/sandbox`, and the Claude login survives recreating the container and rebuilding the image.
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: LAY-01, LAY-02, LAY-03, LAY-04, IMG-02, IMG-05, IMG-06
**Success Criteria** (what must be TRUE):
  1. On the Mac, the user builds a minimal shared base image and a Claude image `FROM` it, then starts a sandbox for a host folder using the documented `docker compose` command. There are no helper scripts yet. The container runs natively on Apple Silicon: `uname -m` prints `aarch64` and there is no platform/emulation warning.
  2. Inside the container, the shell runs as the non-root `sandbox` user. The sandbox folder on the Mac appears at `/home/sandbox/workspace`, and the shell starts in the project folder `/home/sandbox/workspace/<name>`. `ls -a /home/sandbox` still shows the image's `.bashrc` and `.local`. `git status` in a repo under the workspace works without a "dubious ownership" error.
  3. The user logs in to `claude` once, then removes and recreates the container and rebuilds the image with `--no-cache`. `claude` is still logged in and earlier sessions can be resumed. `.claude.json`, settings, and session files are visible in `<sandbox>/state/claude` on the Mac, inside the one directory mount (no single-file mount).
  4. Commands typed in the container shell are still in `history` after the container is removed and recreated.
  5. After `docker compose down` and a fresh `up`, every file in `<sandbox>/<name>` and `<sandbox>/state` is still on the Mac, and `docker volume ls` shows no volume holding sandbox data.

**Plans:** 4/4 plans complete

Plans:
**Wave 1**
- [x] 01-01-PLAN.md — Supply-chain gate, then the tracer: base image, Claude image, compose with workspace and state/claude mounts, static check, quick-start doc

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 01-02-PLAN.md — Bash history, gh login and git identity survive recreate (the rest of the D-12 state layout)

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 01-03-PLAN.md — Fail-safe start: mount-check entrypoint, missing-folder preflight, no-new-privileges and cap_drop

**Wave 4** *(blocked on Wave 3 completion)*
- [x] 01-04-PLAN.md — Host verification checklist H-00..H-13 in SANDBOX.md, then the user runs it on the Mac

### Phase 01.1: Automated host tests (INSERTED)

**Goal**: Every Mac host check that needs no human runs from one unattended command. The user runs `tests/host/run-all.sh` on the Mac and gets a PASS or FAIL line per check plus a summary, with no required environment variables. The few steps that need a human (Claude login, resume, doctor) are a short manual pass, each driven by a helper script.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: HT-01, HT-02, HT-03, HT-04, HT-05
**Success Criteria** (what must be TRUE):
  1. `tests/host/` has one script per automated host check (H-00 to H-13, plus Coexistence). Each prints `PASS: H-xx <what it proves>` or `FAIL: H-xx <what went wrong>`, exits 0 or 1, states its dependencies in a `# Depends on:` line, and can also be run on its own.
  2. `tests/host/run-all.sh` never waits for input. It builds the images, creates a throwaway sandbox (a fresh `mktemp` folder and a fixed test name), runs the independent checks first and the chained ones after, prints a summary, and exits non-zero if any check failed. It never deletes files: it ends by printing the manual-pass commands and a cleanup command to copy and paste. It needs no exported variables; optional variables only override defaults (for example a slow `--no-cache` rebuild).
  3. The steps that need a human (Claude login for H-07, login and `claude --continue` after a rebuild for H-09, `claude doctor` for H-13) are listed in `tests/host-checklist.md` and run through helper scripts in `tests/host/manual/`, which check everything they can automatically.
  4. The scripts run on the Mac with stock bash 3.2 and Docker Desktop, and never touch the user's real sandboxes, real git identity, or old-layout containers.
  5. On the Mac, `tests/host/run-all.sh` passes every check. This also closes Phase 1's deferred host verification. `tests/host-checklist.md` shrinks to "run `tests/host/run-all.sh`", the manual pass, and how to read a failure.

**Plans:** 4/4 plans complete

Plans:
**Wave 1**
- [x] 01.1-01-PLAN.md: Tracer: lib.sh, run-all.sh, H-00/H-02/H-03/H-04/H-12, fake-docker self-test, guard rules (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 01.1-02-PLAN.md: Remaining automated checks H-01, H-05, H-06, H-13, chain H-08/H-11/H-09/H-10, Coexistence (wave 2)
- [x] 01.1-03-PLAN.md: Manual helpers (login, rebuild and resume, doctor), shrunk checklist, SANDBOX.md pointer (wave 2)

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 01.1-04-PLAN.md: Mac run of run-all.sh and the manual pass, H-10 decision if needed, close Phase 1 UAT (wave 3, checkpoint)

### Phase 01.2: Best-practices bundle baked into the image (stopgap) (INSERTED)

**Goal**: Every new sandbox starts with the user's best-practices bundle already installed: the `/pr-reply` and `/merged` skills, and the standing rules (general rules always loaded, language rules loaded when Claude touches a matching file). This is a stopgap: the bundle comes from files committed in this repo (restructured from `claude-best-practices-export.tar.gz`) until Phase 2.1 moves it to its own git repo.
**Mode:** mvp
**Depends on**: Phase 1.1 (its image change is verified with `tests/host/run-all.sh`)
**Requirements**: BP-01, BP-02
**Success Criteria** (what must be TRUE):
  1. The bundle is committed in this repo as plain files (not a tarball), so every change to it shows up in a diff. The Claude image copies it to a path outside every mount (for example `/opt/sbx/best-practices`).
  2. In a fresh sandbox, `/pr-reply` and `/merged` work, Claude follows the bundle's always-on rules, and loads a language rule when it touches a matching file, with no manual install step.
  3. A rule or skill removed or renamed in a later image is gone from the sandbox after a rebuild and restart, while GSD's skills and the user's own skills are untouched. The bundle ships no memories; a memory that proves general is promoted into a bundle rule by PR.
  4. After the agent learns a new memory, a container recreate and a `--no-cache` rebuild keep it. Skills and rules are refreshed from the image on every start, so the image version wins, and an accidental edit to a synced file is undone by the next start.
  5. Container start still works with networking disabled, and the Phase 1 mount checks and layout still pass.

**Plans:** 2/6 plans executed

Plans:
**Wave 1**
- [x] 01.2-01-PLAN.md: Tracer: one rule from best-practices/ reaches Claude through the image start path (hook folder, sync, repo-root build)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 01.2-02-PLAN.md: Full bundle: every rule and both skills, header and no dash punctuation, held by guard rules

**Wave 3** *(blocked on Wave 2 completion)*
- [ ] 01.2-03-PLAN.md: Start path proven on the Mac: H-15 synced and visible to Claude, H-17 offline start and failing hook

**Wave 4** *(blocked on Wave 3 completion)*
- [ ] 01.2-04-PLAN.md: Image wins, user data spared: full sync scenarios, H-16 restart refresh, H-09 memory sentinel

**Wave 5** *(blocked on Wave 4 completion)*
- [ ] 01.2-05-PLAN.md: Edit protection (managed deny), H-14 bundle in image, SANDBOX.md and checklist docs, h19 manual helper

**Wave 6** *(blocked on Wave 5 completion)*
- [ ] 01.2-06-PLAN.md: H-18 fake-API proof of on-demand language rules and the deny under bypass (last, droppable)

### Phase 2: Pinned Toolchain, GSD, and ccusage

**Goal**: The sandbox has the full development toolchain plus Claude Code, GSD, and ccusage baked into the image at versions pinned in one `versions.env`. Rebuilding with changed pins delivers the new versions into the sandbox while login and history persist.
**Mode:** mvp
**Depends on**: Phase 1.2 (reuses its start-time sync into `~/.claude` for GSD)
**Requirements**: IMG-01, IMG-03, IMG-04, TOOL-01, TOOL-02, TOOL-03, USE-01
**Success Criteria** (what must be TRUE):
  1. In the container shell, `git`, `gh`, `node -v` (24.x), `python3`, `uv`, `java -version` (Temurin 21), and `mvn -v` all work as native arm64 binaries. They come from the shared base image, not the Claude image.
  2. Every version (base OS tag, toolchains, Claude Code, GSD, ccusage) is set in `versions.env`, and no Dockerfile uses a floating `latest`. Bumping a pin, or adding a new tool with a one-line change, then rebuilding and recreating puts that version in use.
  3. After a rebuild, `claude --version` matches the pin, Claude reports that self-updating is disabled, and `~/.local` contains no self-installed Claude copy.
  4. After the GSD pin is bumped and the image rebuilt, starting the container syncs the image's `@opengsd/gsd-core` into the persisted `~/.claude`. The GSD version matches the new pin, the Claude login and session history are unchanged, and start-up works with networking disabled, with no `npx` or `@latest` installs in the start logs.
  5. `ccusage daily`, `ccusage monthly`, and `ccusage session` run in the container shell and report this project's real Claude usage from `<sandbox>/state/claude`.

**Plans**: TBD

### Phase 02.1: Best-practices from git, editable from any sandbox (INSERTED)

**Goal**: The best-practices bundle lives in its own GitHub repo. Every sandbox keeps its own clone in its sandbox folder, starts with the latest version, and can send improvements back as PRs. Updates survive restarts and rebuilds, and reach other sandboxes only after the user reviews and merges them.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: BP-03, BP-04, BP-05
**Success Criteria** (what must be TRUE):
  1. The bundle repo exists on GitHub, and this repo no longer carries its own copy of the bundle (one source of truth).
  2. Each sandbox has its own clone of the bundle repo in its sandbox folder (for example `<sandbox>/best-practices`, a plain subfolder of the one mount, so no compose change). Edits there survive container recreate and image rebuild.
  3. From inside the sandbox, the user can edit a skill or rule in the clone, commit on a branch, push, and open a PR against the bundle repo using the sandbox's persisted gh login.
  4. Creating a sandbox pulls the latest bundle with a best-effort `git pull --ff-only`. With no network the start still succeeds, using the clone as it is. Running `git pull` in the clone updates a running sandbox, through the same sync rules as Phase 1.2.
  5. No folder is shared read-write between sandboxes: a change made in one sandbox reaches another only after its PR is merged and the other sandbox pulls.

**Plans**: TBD

### Phase 3: Remembered Sandboxes and One-Command Upgrade

**Goal**: The user registers each sandbox once, then starts, stops, and upgrades it by name alone. One command rebuilds the images and recreates the sandbox, and login and history survive.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: SCR-01, SCR-02, SCR-03, SCR-07
**Success Criteria** (what must be TRUE):
  1. `sbx-add <name> <host_path>` registers a sandbox once. It records the agent as `claude` by default and creates `<name>/` and `state/` under the host path. After that, no script needs the host path again.
  2. The user starts and stops a sandbox with only its name, and stopping never deletes anything in `<name>/` or `state/`.
  3. One command rebuilds the base image, then the Claude image, then recreates the sandbox. Afterwards Claude is still logged in and past sessions are still there.
  4. The versions of Claude Code, GSD, ccusage, Node, JDK, Maven, and Python are printed at the end of a rebuild and whenever a bash shell opens in the sandbox.
  5. All `sbx-*` scripts run under macOS's stock bash (3.2) and work with a host path that contains spaces.

**Plans**: TBD

### Phase 4: Jump-In and Sandbox Housekeeping

**Goal**: The user gets into any registered sandbox with one command, and can see and clean up their sandboxes without risking code, login, or history.
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: SCR-04, SCR-05, SCR-06
**Success Criteria** (what must be TRUE):
  1. On a stopped sandbox, the jump-in command starts it and opens a bash shell in `/home/sandbox/workspace/<name>`. On a running sandbox, it just opens the shell.
  2. The same command can launch `claude` directly instead of a shell, already logged in.
  3. The user lists all registered sandboxes with their host path and running or stopped status, and the status matches what `docker ps -a` shows.
  4. The user removes a sandbox's container, and optionally its registration. Its `<name>/` and `state/` folders on the Mac are left untouched, and re-registering the same path brings back the login and history.

**Plans**: TBD

### Phase 5: Migration, Docs, and Old-Layout Retirement

**Goal**: The user's existing sandboxes run on the new layout with login and history intact. The repo contains only the new layout, and the README describes exactly what exists, including its security limits.
**Mode:** mvp
**Depends on**: Phase 4
**Requirements**: SCR-08, DOC-01, DOC-02, DOC-03, DOC-04
**Success Criteria** (what must be TRUE):
  1. The user follows the README migration steps for an existing sandbox (for example `GSD_StaticSiteGenerator`, with code at `/home/sandbox/MyCode`): move code into `<name>/`, move state (including `.claude.json`) into `state/claude`, and rename the history project path. After jumping in, `claude` is logged in, old sessions show up for resume, and `ccusage` shows pre-migration usage.
  2. The old `cc-*` scripts and the whole-home-mount compose and entrypoint files are gone from the repo. Every script, file, and command the README mentions actually exists, and there is no phantom `cc-upgrade.sh`.
  3. The README explains the two-mount layout, the `sbx-*` scripts, and the upgrade flow (edit `versions.env`, then run one rebuild command).
  4. The README has a short threat-model section covering what's isolated, the credential-exfiltration risk under skip-permissions, and files the agent can plant that the Mac later executes (git hooks, IDE run configs).
  5. A host-side verification checklist exists, and the user can run it end-to-end on the Mac. It confirms that login survives a rebuild, versions match the pins, ccusage works, and the home directory is not hidden.

**Plans**: TBD

### Phase 6: Automated checks (CI)

**Goal**: The repo's automated checks run on their own. GitHub runs `tests/guard.sh` on every push to a PR and shows the result as a check on the PR, without running anything on the Mac or in a sandbox container.
**Mode:** mvp
**Depends on**: Phase 5
**Requirements**: CI-01
**Success Criteria** (what must be TRUE):
  1. Every push to a PR runs `tests/guard.sh` on GitHub's machines, and the PR shows it as a passing or failing check.
  2. Breaking a guard rule on a PR branch turns the check red; fixing it turns it green.
  3. Nothing runs on the Mac or in a sandbox container: no git hook, nothing the agent could edit that the Mac executes.
  4. Running `bash tests/guard.sh` by hand still works the same way.
  5. Candidates to add when planned: shellcheck for the scripts, hadolint for the Dockerfiles.

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 1.1 → 1.2 → 2 → 2.1 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Two-Mount Claude Sandbox | 4/4 | Complete    | 2026-10-04 |
| 1.1. Automated host tests | 4/4 | Complete    | 2026-10-04 |
| 1.2. Best-practices bundle baked into the image (stopgap) | 2/6 | In Progress|  |
| 2. Pinned Toolchain, GSD, and ccusage | 0/TBD | Not started | - |
| 2.1. Best-practices from git, editable from any sandbox | 0/TBD | Not started | - |
| 3. Remembered Sandboxes and One-Command Upgrade | 0/TBD | Not started | - |
| 4. Jump-In and Sandbox Housekeeping | 0/TBD | Not started | - |
| 5. Migration, Docs, and Old-Layout Retirement | 0/TBD | Not started | - |
| 6. Automated checks (CI) | 0/TBD | Not started | - |
