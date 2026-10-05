# GSD Agent Sandbox Containers

## What This Is

A Docker-based sandbox for running AI coding agents (Claude Code today, OpenCode next, others later) plus GSD on a macOS laptop without installing those agents on the host. Each project gets its own container that can only see one bind-mounted host folder, so the agent can't touch the rest of the laptop. The code stays a regular folder on the Mac, so any host IDE can open it directly. Small shell scripts (`cc-up`, `cc-bash`, `cc-down`, …) drive the container lifecycle.

## Core Value

**Rebuilding the image must reliably deliver new or updated tools into a project sandbox without losing the agent's login, settings, or history, and without the host mount hiding anything the image provides.**

## Requirements

### Validated

<!-- Inferred from the existing code (commit 304f80d). -->

- ✓ Claude Code CLI runs inside an Ubuntu container as an unprivileged `sandbox` user — existing
- ✓ One container per project: `cc-up.sh <proj> <host_path>` starts `cc_gsd_<proj>` with the host folder bind-mounted — existing
- ✓ The container sees only the mounted host folder; the rest of the laptop is not exposed — existing
- ✓ Code lives on the host filesystem and can be edited with a host IDE while the agent works in the container — existing
- ✓ Claude login persists across container restarts (it lives in the mounted folder) — existing
- ✓ GSD (`@opengsd/gsd-core`) is installed into the live home on first run, gated by a `.initialized` marker — existing (to be replaced)
- ✓ `cc-bash.sh` opens a shell and `cc-down.sh` stops the container — existing
- ✓ The host mount no longer covers `/home/sandbox`: one sandbox folder is mounted at `/home/sandbox/workspace`, so the image's `.bashrc` and `.local` stay visible — Phase 1
- ✓ Agent state (Claude login, `~/.claude.json`, settings, session history, shell history) lives in `<sandbox>/state` on the host and survives recreate and rebuild — Phase 1
- ✓ Every new sandbox starts with the best-practices bundle (standing rules, path-scoped language rules, `/pr-reply` and `/merged`), synced from the image at each start; the image version wins and user skills, memories and `CLAUDE.md` are never touched — Phase 1.2

### Active


**Upgrade flow (problem 2)**
- [ ] All tools (Claude Code, GSD, ccusage, JDK 21, Maven, Node.js, Python) are baked into the image. Nothing is installed into the mounted folder at runtime.
- [ ] The image version always wins: after a rebuild, the new GSD/tool versions are the ones in use, even though `~/.claude` state persists on the host.
- [ ] One command does the whole upgrade: rebuild the image with fresh tool versions, then restart the container. Login and history survive.
- [ ] Adding a new tool means editing one file (a Dockerfile line or build arg) and rebuilding.
- [ ] Tool versions are controlled explicitly (pinned base image, build args) instead of floating `latest`.

**Shared base (problem 4, groundwork)**
- [ ] Tools that every agent image needs (Linux utilities, git, gh, Node.js, Python, JDK 21, Maven) are defined in one shared base image. Agent images (ClaudeCode, later OpenCode) build on top of it.

**ccusage (problem 3)**
- [ ] `ccusage` (e.g. `ccusage`, `ccusage daily`) runs from the container shell and reports real usage for that project's Claude sessions.

**Helper scripts (problem 5), in priority order and kept small**
- [ ] Scripts remember a project's arguments (name → host path), so you don't have to pass them on every call.
- [ ] Simple rebuild/upgrade script.
- [ ] One command to jump in: start the container if needed, then open a shell (optionally launching `claude`).
- [ ] See which sandboxes exist or are running, and clean up old ones.

**Migration**
- [ ] The README documents how to move an existing sandbox (about 4 today, e.g. `GSD_StaticSiteGenerator` with code at `/home/sandbox/MyCode`) to the new layout while keeping login and history.

**Housekeeping**
- [ ] README matches reality. For example, it currently documents a `cc-upgrade.sh` that doesn't exist.

### Out of Scope

- OpenCode container revival in this milestone. It comes next, on top of the shared base, and must switch to `@opengsd/gsd-core` (it currently installs the compromised `get-shit-done-cc`).
- Pluggable support for more agents (Codex, Gemini, …). Comes after OpenCode. The shared-base design should make it easy, but we're not building it now.
- ccusage usage aggregated across all projects. Deferred until the containers are stable.
- A multi-project-per-container layout. The model is one container per project.
- Long or complex shell tooling. Scripts stay small and grow step by step, starting with what saves the most effort.
- A migration script. We document the manual migration first and write a script only if the manual steps turn out to be painful.

## Context

- Host: macOS with Docker Desktop, using host paths like `/Users/demian/<Sandbox>/`. The sandbox folder is passed to `cc-up.sh`.
- Current design: `docker-compose.yml` mounts `${PROJECT_PATH}:/home/sandbox`, so the whole home comes from the host. That hides everything the image puts in the home directory, which is why GSD is currently installed by `docker-entrypoint.sh` on first run and gated by `.initialized`.
- The Claude binary is copied to `/usr/local/bin` so the mount doesn't hide it.
- An earlier ccusage attempt (commented out in `ClaudeCode/Dockerfile`) failed. It used `npm install` into `$HOME` plus an arm64 binary symlink, and the mount hid it. ccusage reads Claude's session JSONL files under `~/.claude/projects` (or `$CLAUDE_CONFIG_DIR`), so it has to see the persisted agent state.
- The Docker Desktop host is probably Apple Silicon (the earlier attempt referenced `ccusage-linux-arm64`), so images must build for arm64.
- The codebase map is in `.planning/codebase/`. `CONCERNS.md` lists floating tags, unpinned packages, `curl | bash` installers, the hardcoded path in the OpenCode compose file, and the compromised GSD package in OpenCode.
- This repo is itself developed inside one of these sandboxes (`/home/sandbox/GetShitDoneContainer`), so the dev environment can't run Docker. Verification has to happen on the host.

## Constraints

- **Security**: Agents never run on the host, and each container sees only its project's mount. Why: this isolation is the reason the project exists.
- **Security**: GSD comes only from `@opengsd/gsd-core`. Never use `get-shit-done-cc` or `gsd-build`. Why: the old package was compromised.
- **Platform**: Must work on macOS + Docker Desktop (likely arm64), with bind mounts. Why: that's the user's only host.
- **Simplicity**: Keep shell scripts short and plain bash. Why: the user wants to grow the tooling slowly and keep it understandable.
- **Toolchains**: JDK 21 LTS, Maven, Node.js, and Python in the shared base. Why: these are the stacks the user develops in.
- **Verification**: Docker isn't available inside the dev sandbox, so plans must include host-side manual verification steps.
- **Coexistence**: The old layout (`ClaudeCode/`, `cc-*` scripts, the whole-home mount) stays untouched until Phase 5. New work goes in new directories, and new containers, images, and compose projects use a name prefix different from `cc_gsd_<name>` / `cc_<name>`, so old and new sandboxes can run side by side. Why: the user keeps working in existing sandboxes (including the one this repo is developed in) while the new layout is built.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Stop mounting over `/home/sandbox`. Mount one sandbox folder at `/home/sandbox/workspace`; image ENV points agent state into `<sandbox>/state` | Fixes the hidden home directory and lets image-provided home content stay visible | Good: Phase 1 verified on the Mac (14 of 14 host checks) |
| Persist agent state (login, settings, history) in a host folder | Rebuilds must never log the user out, and the state stays inspectable on the laptop | Good: login and history survived recreate and rebuild on the Mac (Phase 1) |
| Bake all tools into the image. The image version wins over persisted state | "Upgrade = rebuild" becomes true, and runtime installs into the mount go away | — Pending |
| One container per project | Matches the current `cc-up.sh` model and the isolation goal | — Pending |
| Shared base image for common tools, with thin per-agent images on top | One place for Linux tools, JDK, Maven, etc. Sets up OpenCode and future agents | — Pending |
| ClaudeCode first, OpenCode next, pluggable later | Get one sandbox solid before generalizing | — Pending |
| Migration is documented, not scripted | Only about 4 existing sandboxes. Script only if it proves painful | — Pending |
| One unattended host test run (`tests/host/run-all.sh`) plus a short manual pass verifies every image change on the Mac | The manual checklist was too slow, and Docker cannot run in the dev sandbox | Good: 14 of 14 checks and the 3 helpers passed on the Mac (2026-10-03) |
| Ship the best-practices bundle as plain files in this repo, baked into the image and synced into the Claude config by a start hook | Stopgap until the bundle gets its own repo (Phase 2.1); every change is a reviewed diff, and a rebuild plus restart delivers it | Good: 19 of 19 host checks and the attended h19 pass on the Mac (Phase 1.2) |
| Guard the synced bundle with managed Edit deny rules, documented as not a security boundary | Stops Claude from rewriting the instructions every later session loads; a script can still write until the next start recopies | Good: deny proven in the real image (H-18) and with a negative control at the pinned Claude |
| A start hook entry that is not an executable regular file stops the container start (folders and dot names are skipped) | A skipped hook means the agent starts with a stale bundle; failing closed makes the fault visible at once | Good: H-17 proves a non-executable hook and a dangling hook link stop the start in the real image (Phase 1.3) |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-10-05 after Phase 1.3*
