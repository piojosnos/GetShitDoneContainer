# Walking Skeleton — GSD Agent Sandbox Containers

**Phase:** 1
**Generated:** 2026-09-30

This is an infrastructure project, so the classic web-app skeleton slots (framework, database, UI, routing) are mapped to their container equivalents below. Where a slot has no equivalent, it says so and why.

## Capability Proven End-to-End

On the Mac, the user builds `sbx-base:local` and then `sbx-claude:local`, starts sandbox `sbx-${SBX_NAME}` with one documented `docker compose up -d --wait`, opens a shell in `/home/sandbox/workspace`, and logs in to `claude` once. That login, which lives in `$SBX_DIR/state/claude` on the Mac, still works after the container is recreated and both images are rebuilt with `--no-cache`.

Thinnest slice (plan 01-01, tracer): base image, then Claude image, then compose up with two directory mounts (`workspace/` and `state/claude/`), then `docker exec` shell, then `claude` running with its state on the host. Later slices add shell history, gh, and git identity persistence (01-02), fail-safe start and hardening (01-03), and the host verification checklist (01-04).

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Framework (runtime) | Docker Desktop on macOS (arm64) plus the Compose v2 plugin (`docker compose`). One service (`sandbox`) and one container per sandbox | The user's only host. One container per project is the isolation model (PROJECT.md) |
| Image layering | `sbx-base:local` (Ubuntu 24.04, Node 24.21.0, gh 2.102.0, git, non-root `sandbox` uid 1000, `safe.directory '*'`, shell and tool ENV, mount-check entrypoint). `sbx-claude:local` builds `FROM ${BASE_IMAGE}` and adds only Claude Code 2.1.285 plus its ENV | IMG-02: agents stay thin, the toolchain lives in one shared base, and a future agent is a thin image on the same base. Tools live in `/usr/local`, outside `/home/sandbox`, so no mount can hide them |
| Data layer (persistence) | Host bind mounts only, always directories, never single files. Per sandbox: `$SBX_DIR/workspace` is mounted at `/home/sandbox/workspace`. `$SBX_DIR/state/claude` is mounted at `/home/sandbox/.claude`. `state/shell`, `state/gh`, and `state/git` are mounted under `/home/sandbox/.local/state/sbx/`. Tools are pointed at these through image `ENV` (`CLAUDE_CONFIG_DIR`, `HISTFILE`, `GH_CONFIG_DIR`, `GIT_CONFIG_GLOBAL`). There is no Docker volume and no `VOLUME` | D-06, D-12. Nothing is mounted over `/home/sandbox`, so the image home stays visible (LAY-01). Lockfile-and-rename writes work in directory mounts. Data survives `down`, recreate, and rebuild (LAY-02, LAY-04) |
| Auth | Claude Code's own login (claude.ai account, paste-code flow in the container). Credentials go to `CLAUDE_CONFIG_DIR` in `state/claude`, and `gh auth login` goes to `GH_CONFIG_DIR` in `state/gh`. No auth code is written by this project | The login must survive rebuilds. Console keyless sign-in is stored outside `CLAUDE_CONFIG_DIR` and is a documented limit |
| Deployment target | A local Docker Desktop engine. Images are tagged `:local` and never pushed. `pull_policy: never`. The run command is documented in `SANDBOX.md` (scripts arrive in Phase 3) | A missing image is a clear error, never a Docker Hub pull |
| Naming | Prefix `sbx`: container and compose project `sbx-${SBX_NAME}`, images `sbx-base:local` / `sbx-claude:local`, label `sbx.name`. Compose is driven only by `SBX_NAME` and `SBX_DIR` (`SBX_AGENT` comes later) | D-02, D-07. These names are costly to change because the Phase 3 registry, the Phase 4 scripts, and the Phase 5 migration key on them. They never collide with the old layout's prefixes |
| Process model | `init: true` plus `command: ["sleep", "infinity"]`. Shells come from `docker exec -it sbx-${SBX_NAME} bash`, and `docker compose down` stops the container | D-09. Keeps the user's "start once, attach many shells" habit without bash as PID 1 |
| Directory layout (repo) | Repo root: `base/` (`Dockerfile`, `sbx-entrypoint`), `claude/Dockerfile`, `compose.yml`, `SANDBOX.md`, `tests/static-check.sh`. Later: `versions.env` (Phase 2) and `bin/sbx-*` (Phase 3). `ClaudeCode/`, `OpenCode/`, and `README.md` stay untouched until Phase 5 | D-01 and the coexistence constraint |
| Versions and supply chain | Exact pins as Dockerfile `ARG` defaults: `ubuntu:24.04`, `NODE_VERSION=24.21.0`, `GH_VERSION=2.102.0`, `CLAUDE_CODE_VERSION=2.1.285`. Tarballs are checked with `sha256sum -c` against upstream checksum files. Claude Code comes from an exact-version npm install as root plus a build-time `claude --version` assertion. No pipe-to-shell installers and no runtime installs | D-03, D-04, D-05. Phase 2 moves every pin into `versions.env` without changing this shape |
| Verification | Static tier: `bash tests/static-check.sh` in the dev sandbox (no Docker). Runtime tier: host checklist H-00..H-13 in `SANDBOX.md`, run by the user on the Mac | Docker is not available in the dev sandbox (CLAUDE.md, Verification constraint) |

## Stack Touched in Phase 1

- [ ] Project scaffold: `base/Dockerfile`, `claude/Dockerfile`, `compose.yml`, `base/sbx-entrypoint`, and the lint step `tests/static-check.sh` (the test runner for the static tier)
- [ ] Routing: **not applicable** (no HTTP). The equivalent is the entry path `docker exec -it sbx-${SBX_NAME} bash`, which lands in `/home/sandbox/workspace` (`working_dir`)
- [ ] Database: **equivalent is the persisted state folder**. One real write (the `claude` login writes `.claude.json` / `.credentials.json` into `$SBX_DIR/state/claude`) and one real read (after recreate and a `--no-cache` rebuild, `claude auth status` reports `loggedIn: true` from the same folder)
- [ ] UI: **not applicable as a GUI**. The interactive element is the `claude` TUI login flow in the container shell, which writes to the state layer
- [ ] Deployment: a documented local full-stack run command in `SANDBOX.md` (`docker build` ×2, `export SBX_NAME SBX_DIR`, `mkdir -p`, `docker compose up -d --wait`, `docker exec -it … bash`)

## Out of Scope (Deferred to Later Slices)

- JDK 21, Maven, Python 3, uv, GSD bake-and-sync, ccusage, and `versions.env` (Phase 2)
- `sbx-*` scripts, the sandbox registry (`~/.config/gsd-sandbox/sandboxes/<name>.env`), and name validation and lowercasing (Phase 3)
- Jump-in, list, and cleanup commands (Phase 4)
- Migrating the existing sandboxes, removing the old `cc-*` layout, and the README rewrite with its threat model (Phase 5)
- OpenCode and other agents, the egress firewall, the per-project `~/.m2` cache, and `sbx-doctor` (v2)
- Persisting Console keyless sign-in (`~/.config/anthropic`), documented as a limit only
- The `env_file` sentinel fallback for refusing a missing `SBX_DIR`. This is a conditional follow-up that applies only if host check H-10 shows Docker creating missing folders. It needs user approval because it adds a file to the D-12 layout

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without changing the decisions above:

- Phase 2: every tool pinned in `versions.env`, the full toolchain in `sbx-base`, and GSD baked into the image and synced into the persisted `~/.claude` on start. `ccusage` reports real usage
- Phase 3: `sbx-add` registers a sandbox once, start/stop by name, and a one-command rebuild plus recreate that keeps the login
- Phase 4: one command to jump into a shell or `claude`, list sandboxes, and remove a container safely
- Phase 5: existing sandboxes migrated with history intact, the old layout retired, and a README that matches the repo
