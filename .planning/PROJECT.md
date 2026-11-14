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
- ✓ The test suite is small enough to read and change: guard, host, bundle and entrypoint self-tests are each a folder with a `run-all.sh`, and the fake docker is its own file used only for failure paths (Phase 1.4)
- ✓ A sandbox name must follow one rule, `^[a-z][a-z0-9-]{0,30}$`: `up` refuses an uppercase name before it creates anything, and the entrypoint refuses any other bad name before it uses it as a folder; the host checks are proven against real Docker with 21 of 21 passing (Phase 1.5)
- ✓ All tools (Claude Code, GSD, ccusage, JDK 21, Maven, Node.js, Python) are baked into the image. Nothing is installed into the mounted folder at runtime. (Phase 2)
- ✓ The image version always wins: after a rebuild, the new GSD/tool versions are the ones in use, even though `~/.claude` state persists on the host. (Phase 2)
- ✓ Adding a new tool means editing one file (a Dockerfile line or build arg) and rebuilding. (Phase 2)
- ✓ Tool versions are controlled explicitly (pinned base image, build args) instead of floating `latest`. (Phase 2)
- ✓ Tools that every agent image needs (Linux utilities, git, gh, Node.js, Python, JDK 21, Maven) are defined in one shared base image. Agent images (ClaudeCode, later OpenCode) build on top of it. (Phase 2)
- ✓ `ccusage` (e.g. `ccusage`, `ccusage daily`) runs from the container shell and reports real usage for that project's Claude sessions. (Phase 2)
- ✓ Every pin lives in `versions.env` and `build.sh` passes it to both builds; a build without `build.sh` stops and names the missing pin; the npm, uv and Maven caches live in `<sandbox>/state` and survive recreate; host checks are proven with 25 of 25 passing (Phase 2)
- ✓ The best-practices bundle lives in its own private GitHub repo; each sandbox keeps its own clone in `<sandbox>/best-practices` (via `sbx-gh-login` and `sbx-bundle-clone`), a start links it without network, and an edit goes back as a PR from inside the sandbox with the persisted gh login; proven by 27 of 27 host checks and an attended push and PR (Phase 2.2)
- ✓ `sbx-shell NAME` starts a registered sandbox when needed and opens bash in its project folder without recreating a running one; Claude starts in that shell with `sbx-claude`, and no Mac command launches it (Phase 4)
- ✓ `sbx-list` shows every registered sandbox with its folder and a status that matches `docker ps -a`; `sbx-rm NAME [--unregister]` takes a sandbox down with a plain compose down and keeps its folder, so registering the same path again brings back login and history; proven by 33 of 33 host checks (Phase 4)
- ✓ `MIGRATION.md` moves an old-layout sandbox to the new layout with its code, Claude login and sessions, ccusage history, gh login, git identity and bash history; all four old sandboxes moved with it (Phase 5)
- ✓ The repo holds only the new layout: `ClaudeCode/`, `OpenCode/` and the `cc-*` scripts are gone, and `README.md` is the one main doc and matches what exists, including its security limits; proven by 32 of 32 host checks (Phase 5)
- ✓ A sandbox builds and runs behind a company HTTPS proxy (Zscaler): `SBX_CA_CERT` names one root certificate file that the system store, Java, npm, pip, uv and Node trust; unset, the image content is unchanged; `ZSCALER.md` is the setup guide (Phase 5.2)
- ✓ Test runs use their own image tags: `SBX_IMAGE_TAG` (unset or `local`, or `test`, anything else refused) picks the tag in the `sbx-*` scripts, Compose and `build.sh`; `./host-test.sh` builds and checks `sbx-base:test`, `sbx-claude:test` and `sbx-cursor:test` and leaves the `:local` images alone; 26 of 26 host checks pass on the Mac (Phase 7)

### Active

v2.0 Simple tooling (requirements come from `/gsd-new-milestone`; decisions in `.planning/research/v2-simple-tooling-decisions.md`):
- [ ] Tests check our setup, not Claude, GSD or Docker behaviour; nothing interactive; no fake docker.
- [ ] One self-check inside the image (also the sandbox doctor) replaces most host probes.
- [ ] `sbx-init`, run by the user, replaces the start hooks and the readiness poll.
- [ ] The host side (`bin/sbx-*`, `build.sh`, `host-test.sh`, host tests) is Python run through `uv`, with a JSON registry.
- [ ] CI on GitHub builds the test images and runs the checks that do not need the Mac (carries v1 requirement CI-01).

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

## Current State

v1.0 shipped 2026-11-12 (tag `v1.0`): two-mount Claude sandboxes with a pinned toolchain, GSD and ccusage baked in, the best-practices bundle from its own repo, the `sbx-*` host scripts, and an optional company root certificate. About 2.1k lines of product shell and about 10.9k lines of test shell. The user runs v1.0 on the Mac while v2.0 is built.

## Current Milestone: v2.0 Simple tooling

**Goal:** Make the tests, and the tooling they test, simple: tests check our setup with real Docker and simple proxies, not other people's software.

**Target features:**
- Test diet: delete the manual helpers, the tests of Claude, GSD and Maven Central behaviour, the guard self-test and most of the fake docker
- Test runs build and use their own image tags
- `sbx-selfcheck` in the image (Python), also the sandbox doctor
- `sbx-init`, run by the user, replaces the start hooks and the readiness poll
- Host side in Python through `uv`, with a JSON registry per sandbox
- CI on GitHub builds the test images and runs the Linux-runnable checks

## Constraints

- **Security**: Agents never run on the host, and each container sees only its project's mount. Why: this isolation is the reason the project exists.
- **Security**: GSD comes only from `@opengsd/gsd-core`. Never use `get-shit-done-cc` or `gsd-build`. Why: the old package was compromised.
- **Platform**: Must work on macOS + Docker Desktop (likely arm64), with bind mounts. Why: that's the user's only host.
- **Simplicity**: Anything with logic is Python (through `uv` on the host, the image's `python3` inside); shell stays only for thin `exec` wrappers and Dockerfile `RUN` lines. Why: the v1 bash tooling grew about 10.9k lines of test shell around about 2.1k lines of product shell.
- **Toolchains**: JDK 21 LTS, Maven, Node.js, and Python in the shared base. Why: these are the stacks the user develops in.
- **Verification**: Docker isn't available inside the dev sandbox, so plans must include host-side manual verification steps.
- **Coexistence** (retired in Phase 5): the old layout ran side by side with the new one until every old sandbox moved; it is now deleted, and old `cc_` containers left on the Mac are plain stopped containers.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Stop mounting over `/home/sandbox`. Mount one sandbox folder at `/home/sandbox/workspace`; image ENV points agent state into `<sandbox>/state` | Fixes the hidden home directory and lets image-provided home content stay visible | Good: Phase 1 verified on the Mac (14 of 14 host checks) |
| Persist agent state (login, settings, history) in a host folder | Rebuilds must never log the user out, and the state stays inspectable on the laptop | Good: login and history survived recreate and rebuild on the Mac (Phase 1) |
| Bake all tools into the image. The image version wins over persisted state | "Upgrade = rebuild" becomes true, and runtime installs into the mount go away | Good: the attended GSD 1.15.0 to 1.16.0 bump synced the new GSD, kept the login and resumed the session; H-16 restores a stale GSD (Phase 2) |
| One container per project | Matches the current `cc-up.sh` model and the isolation goal | — Pending |
| Shared base image for common tools, with thin per-agent images on top | One place for Linux tools, JDK, Maven, etc. Sets up OpenCode and future agents | Good: H-22 proves the toolchain sits in `sbx-base:local`; the Claude image adds only Claude Code, GSD and ccusage (Phase 2) |
| ClaudeCode first, OpenCode next, pluggable later | Get one sandbox solid before generalizing | — Pending |
| Migration is documented, not scripted | Only about 4 existing sandboxes. Script only if it proves painful | Good: all four old sandboxes moved with `MIGRATION.md` on 2026-11-08; no script needed (Phase 5) |
| One unattended host test run (`tests/host/run-all.sh`) plus a short manual pass verifies every image change on the Mac | The manual checklist was too slow, and Docker cannot run in the dev sandbox | Good: 14 of 14 checks and the 3 helpers passed on the Mac (2026-10-03) |
| Ship the best-practices bundle as plain files in this repo, baked into the image and synced into the Claude config by a start hook | Stopgap until the bundle gets its own repo (Phase 2.2); every change is a reviewed diff, and a rebuild plus restart delivers it | Superseded in Phase 2.2 by the per-sandbox clone; it served from Phase 1.2 (19 of 19 host checks and the attended h19) |
| Guard the synced bundle with managed Edit deny rules, documented as not a security boundary | Stops Claude from rewriting the instructions every later session loads; a script can still write until the next start recopies | Good: deny proven in the real image (H-18) and with a negative control at the pinned Claude |
| A start hook entry that is not an executable regular file stops the container start (folders and dot names are skipped) | A skipped hook means the agent starts with a stale bundle; failing closed makes the fault visible at once | Good: H-17 proves a non-executable hook and a dangling hook link stop the start in the real image (Phase 1.3) |
| Real Docker runs only on the Mac; `tests/host/run-all.sh` passing there is the gate, and the manual helpers are diagnostic tools, not an ordered pass | Docker cannot run in the dev sandbox, and Actions, dind, a VM and the host socket were each rejected | Good: 19 passed, 0 failed, 0 not run on the Mac at `a821736` (Phase 1.4) |
| Split each suite into a folder with a short `run-all.sh`, shared libraries and one file per check group | A suite of single 1000-line scripts was too big to read; the largest group file is now 182 lines and `prove.sh` shows case-for-case equality with the old scripts | Good: 23 guard, 25 entrypoint, 111 bundle and 295 host self-test cases identical to the baseline (Phase 1.4) |
| The fake docker lives in its own file (`tests/selftest/host/support/fake-docker`) and covers failure paths only | The Mac run covers the success paths, so the fake can stay slim and its knobs sit in one header table | Good: the file answers like the old heredoc across 1922 transcript lines (Phase 1.4) |
| One sandbox name rule, `^[a-z][a-z0-9-]{0,30}$`, defined once in `base/sbx-start-lib.sh`; a `name-check` service in `compose.yml` makes `up` refuse an uppercase name, and the entrypoint refuses the rest | Compose lowercases the project name instead of refusing it, so a mixed-case name could collide with another sandbox; docs and a guard rule read the rule from the code so they cannot drift | Good: H-03 and H-21 pass on the Mac, 21 passed, 0 failed (Phase 1.5) |
| One `versions.env` holds every pin; `build.sh` is the only build path and the Dockerfiles have no defaults; every pin gets a human supply-chain review | One place to bump; a stale default can never be built by accident | Good: H-25 proves the images match `versions.env` and a bare build stops (Phase 2) |
| Hold Maven at 3.9.11 | Maven 3.9.12 and later fail with an Input/output error when the local repository is on the Docker Desktop for Mac mount | Good: H-23 downloads into `state/m2` on the Mac; lift the hold once a release passes H-23 (Phase 2) |
| Each sandbox keeps its own clone of the bundle repo inside its sandbox folder, linked into Claude's config by a start hook; the Mac never runs git on the clone | No compose change and no folder shared between sandboxes; a change reaches another sandbox only through a merged PR and a pull; the clone's `.git` is agent-writable, so host git on it is unsafe | Good: H-14 to H-19 and H-27 pass on the Mac, and PR #2 was opened from a new-layout sandbox (Phase 2.2) |
| `sbx-rm` is the only `bin/` script allowed to take a sandbox down or delete a file, and it runs only a plain `compose down` plus the delete of its own registry entry | Removing a sandbox must never cost code, login or history; a guard rule pins the one allowed delete line and refuses volume or image removal | Good: H-33 shows folders, volumes and images kept and the re-register round trip restores login and history (Phase 4) |
| An optional root certificate reaches the image only through `SBX_CA_CERT` and a named build context, never a file in the repo | The certificate is company specific and changes the trust boundary; an unset variable must leave the image content as it was | Good: home Mac snapshot diff 0 lines with no root, two test roots reached every store, and the work Mac built and ran behind Zscaler (Phase 5.2) |
| Close v1.0 at tag `v1.0` and rebuild the tooling as v2.0 on `main` | The user keeps running v1.0 on the Mac while v2 is built; configs can be recreated, so there is little migration | — Pending (v1.0 close) |
| Docker Desktop must use Docker VMM, not the Apple Virtualization Framework | Under Apple Virtualization the GSD start hook stops with EACCES in its file copy into `state/claude` | Revisit: documented in `ZSCALER.md`; making the hook work under both is a follow-up (Phase 5.2) |
| Write automated tests for new behavior | Reverses the earlier preference for manual README checks; the root certificate feature shipped without tests and that was a gap | ⚠️ Revisit: v1 tests grew larger than the code; v2.0 keeps the rule but tests only our setup, with proxies and real Docker (v1.0 close) |
| One variable, `SBX_IMAGE_TAG`, allow-listed to `local` and `test`, picks the image tag; `./host-test.sh` pins it to `test` | Same image names with another tag keep the test run on the real `build.sh`, Compose and `sbx-*` scripts, with no copy of the repo and no tag rewriting | Good: the `:local` images were untouched by a full Mac run (Phase 7); a leaked `SBX_IMAGE_TAG=test` in the user's shell is accepted silently, open in the code review |

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
*Last updated: 2026-11-14 after Phase 7*
