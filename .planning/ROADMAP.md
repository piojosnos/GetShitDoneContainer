# Roadmap: GSD Agent Sandbox Containers

## Overview

This milestone makes the ClaudeCode sandbox solid. Each phase is a vertical slice that leaves the user with a sandbox they can actually use on the Mac, and each later phase builds on it. Phase 1 replaces the whole-home mount with one sandbox folder mount: code in `<name>/` and all state (Claude, history, gh, git) in `state/`. The home directory is no longer hidden, and login survives recreating the container and rebuilding the image. Phase 1.1 (inserted) ships the user's best-practices bundle (skills, standing rules, memories) in the image, synced into `~/.claude` on every start; Phase 2.1 (inserted) later moves that bundle to its own git repo so any sandbox can update it through a PR. Phase 2 bakes the full pinned toolchain, GSD, and ccusage into the image, so "upgrade = rebuild" becomes true and the image version always wins. Phases 3 and 4 add the small `sbx-*` scripts in the user's priority order: remembered args and one-command upgrade first, then jump-in, then list and cleanup. Phase 5 migrates the roughly four existing sandboxes, retires the old `cc-*` layout, and brings the README in line with reality. Docker doesn't run inside the dev sandbox, so every success criterion below is checked on the Mac.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Two-Mount Claude Sandbox** - A Claude sandbox that runs on the Mac with code and state in separate host folders, a visible image home, and a login that survives rebuilds
- [ ] **Phase 1.1: Best-practices bundle baked into the image (stopgap)** (INSERTED) - New sandboxes start with the user's skills, standing rules, and shared memories installed, taken from files in this repo
- [ ] **Phase 2: Pinned Toolchain, GSD, and ccusage** - Every tool is baked in at a version pinned in `versions.env`, the image's GSD wins over persisted state, and `ccusage` reports real usage
- [ ] **Phase 2.1: Best-practices from git, editable from any sandbox** (INSERTED) - The bundle moves to its own repo; each sandbox keeps its own clone, starts with the latest, and sends changes back as PRs
- [ ] **Phase 3: Remembered Sandboxes and One-Command Upgrade** - Register a sandbox once, start and stop it by name, and upgrade everything with one command without losing login
- [ ] **Phase 4: Jump-In and Sandbox Housekeeping** - One command drops you into a sandbox shell or Claude, and you can list and clean up sandboxes safely
- [ ] **Phase 5: Migration, Docs, and Old-Layout Retirement** - Existing sandboxes move over with history intact, the old `cc-*` layout is gone, and the README matches the repo

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

**Plans:** 4/4 plans executed

Plans:
**Wave 1**
- [x] 01-01-PLAN.md — Supply-chain gate, then the tracer: base image, Claude image, compose with workspace and state/claude mounts, static check, quick-start doc

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 01-02-PLAN.md — Bash history, gh login and git identity survive recreate (the rest of the D-12 state layout)

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 01-03-PLAN.md — Fail-safe start: mount-check entrypoint, missing-folder preflight, no-new-privileges and cap_drop

**Wave 4** *(blocked on Wave 3 completion)*
- [x] 01-04-PLAN.md — Host verification checklist H-00..H-13 in SANDBOX.md, then the user runs it on the Mac

### Phase 01.1: Best-practices bundle baked into the image (stopgap) (INSERTED)

**Goal**: Every new sandbox starts with the user's best-practices bundle already installed: the `/pr-reply` and `/merged` skills, the standing rules (`AGENTS.md`, `code-conventions.md`, loaded through a user-level `CLAUDE.md`), and the shared memories. This is a stopgap: the bundle comes from files committed in this repo (taken from `claude-best-practices-export.tar.gz`) until Phase 2.1 moves it to its own git repo.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: BP-01, BP-02
**Success Criteria** (what must be TRUE):
  1. The bundle is committed in this repo as plain files (not a tarball), so every change to it shows up in a diff. The Claude image copies it to a path outside every mount (for example `/opt/sbx/best-practices`).
  2. In a fresh sandbox, `/pr-reply` and `/merged` work, and Claude loads `AGENTS.md` and `code-conventions.md` as standing rules, with no manual install step.
  3. The shared memories appear in the memory folder of the sandbox's project (`/home/sandbox/workspace/<name>`), each with one pointer line in `MEMORY.md`.
  4. After the agent learns a new memory and the user edits `MEMORY.md`, a container recreate and a `--no-cache` rebuild keep both. Bundle memories are seeded only if missing; skills and standing rules are refreshed from the image on every start, so the image version wins.
  5. Container start still works with networking disabled, and the Phase 1 mount checks and layout still pass.

**Plans**: TBD

### Phase 2: Pinned Toolchain, GSD, and ccusage

**Goal**: The sandbox has the full development toolchain plus Claude Code, GSD, and ccusage baked into the image at versions pinned in one `versions.env`. Rebuilding with changed pins delivers the new versions into the sandbox while login and history persist.
**Mode:** mvp
**Depends on**: Phase 1.1 (reuses its start-time sync into `~/.claude` for GSD)
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
  3. From inside the sandbox, the user can edit a skill or memory in the clone, commit on a branch, push, and open a PR against the bundle repo using the sandbox's persisted gh login.
  4. Creating a sandbox pulls the latest bundle with a best-effort `git pull --ff-only`. With no network the start still succeeds, using the clone as it is. Running `git pull` in the clone updates a running sandbox, through the same sync rules as Phase 1.1.
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

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 1.1 → 2 → 2.1 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Two-Mount Claude Sandbox | 4/4 | In Progress|  |
| 1.1. Best-practices bundle baked into the image (stopgap) | 0/TBD | Not started | - |
| 2. Pinned Toolchain, GSD, and ccusage | 0/TBD | Not started | - |
| 2.1. Best-practices from git, editable from any sandbox | 0/TBD | Not started | - |
| 3. Remembered Sandboxes and One-Command Upgrade | 0/TBD | Not started | - |
| 4. Jump-In and Sandbox Housekeeping | 0/TBD | Not started | - |
| 5. Migration, Docs, and Old-Layout Retirement | 0/TBD | Not started | - |
