---
last_mapped_commit: 031448ea8249fe34f6bd172818ba1c2807eaed35
last_mapped_at: 2026-11-16
---
<!-- refreshed: 2026-11-16 -->

# Architecture

**Analysis Date:** 2026-11-16

## System Overview

The sbx sandbox system isolates AI coding agents in Docker containers. One container runs per project; each container sees only one bind-mounted folder from the Mac. The container runs a init process that validates the mount, checks sandbox state, runs startup hooks, and enters the project folder. Compose templates and host-side shell scripts manage the container lifecycle and registry.

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                      Host (macOS)                                        │
│                                                                          │
│  ~/.config/sbx/sandboxes/   SBX Tools Repo   $SBX_DIR/                  │
│  (registry files)           (bin/, compose,  (project folders)          │
│                             build.sh)                                   │
│                                                                          │
│  sbx-add, sbx-start,                                                    │
│  sbx-upgrade (shell)     compose.yml,        <name>/                    │
│                          build.sh,           state/                     │
│                          Dockerfiles         best-practices/            │
└─────────────────────────────────────────────────────────────────────────┘
         │                       │
         │ reads registry        │ uses compose and builds images
         │                       │
         ▼─────────────────────▼
┌──────────────────────────────────────────────────────────────────────────┐
│             Docker Desktop                                               │
│                                                                          │
│  Images: sbx-base, sbx-claude, sbx-cursor (local or test tags)          │
│                                                                          │
│  Container: sbx-<name>                                                  │
│  Mount: /home/sandbox/workspace = $SBX_DIR                              │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Container Start (PID 1: tini)                                   │   │
│  │                                                                 │   │
│  │ sbx-entrypoint (bash script)                                   │   │
│  │  ├─ check_workspace_mount()                                    │   │
│  │  ├─ check_sandbox_name()                                       │   │
│  │  ├─ check_project_and_state_folders()                          │   │
│  │  ├─ create_state_dirs()                                        │   │
│  │  ├─ run_start_hooks() -> /etc/sbx/start.d/*                    │   │
│  │  │   ├─ 05-gsd (sync GSD into config)                          │   │
│  │  │   ├─ 10-best-practices (link bundle skills)                 │   │
│  │  │   └─ [agent-specific hooks: Cursor self-update off, etc]    │   │
│  │  └─ exec "$@" (run command, usually bash)                      │   │
│  │                                                                 │   │
│  │ Environment: HOME=/home/sandbox, HISTFILE=state/shell/...,     │   │
│  │ CLAUDE_CONFIG_DIR=state/claude, etc.                           │   │
│  │                                                                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Host Scripts | Register sandboxes, manage lifecycle (start, stop, upgrade); invoke Docker Compose | `bin/sbx-add`, `bin/sbx-start`, etc. |
| Registry | Store sandbox metadata (host path, agent type) outside every mount | `~/.config/sbx/sandboxes/<name>` |
| Compose Template | Define container service, mount point, image, entrypoint | `compose.yml` |
| Base Image | OS packages, toolchains, GSD, shared commands, selfcheck framework | `base/Dockerfile` |
| Agent Images | Agent-specific CLI, wrappers, start hooks, checks | `claude/Dockerfile`, `cursor/Dockerfile` |
| Entrypoint | Validate mount and state folders, run hooks, enter project folder | `base/sbx-entrypoint` |
| Start Hooks | Agent-specific setup (sync GSD, link skills, disable self-update) | `*/start.d/*` |
| Selfcheck | Validate image state, tools, mounts, ownership before operation | `base/selfcheck/runner.py` and `checks/` |

## Pattern Overview

**Overall:** Immutable Docker images with mutable state folders. The host manages multiple isolated sandboxes; each container validates its environment at startup before the agent runs.

**Key Characteristics:**

- Isolation: one container, one project folder, no cross-sandbox access
- Reproducibility: pinned toolchain versions in `versions.env`; smoke tests at build time verify all pins
- Idempotency: start hooks are reentrant; existing state folders and configs are reused
- Validation: entrypoint checks mount, folders and sandbox name before running hooks; selfcheck validates image state
- Composition: base image includes GSD and shared helpers; agent images add their CLI and checks

## Layers

**Image Layer: Base (`base/Dockerfile`)**

- Purpose: Provides operating system, toolchains, GSD, and shared infrastructure
- Location: `base/Dockerfile` builds `sbx-base:local`
- Contains: Ubuntu 24.04, Node.js, Python, JDK 21, Maven, uv, git, gh, GSD, sbx-selfcheck framework
- Depends on: Official Docker images (Ubuntu, Temurin, Node, Python)
- Used by: `sbx-claude:local` and `sbx-cursor:local`
- Key State: `/etc/sbx/versions.env` (pins), `/etc/sbx/tool-versions` (display line), `/etc/sbx/start.d/` (hook folder)

**Image Layer: Agent (`claude/Dockerfile` or `cursor/Dockerfile`)**

- Purpose: Adds agent-specific CLI and configuration
- Location: Builds `sbx-claude:local` (Claude) or `sbx-cursor:local` (Cursor)
- Contains: Claude Code or Cursor CLI, agent-specific start hooks, managed settings, agent checks
- Depends on: `sbx-base:local`
- Used by: Containers running the agent
- Key State: Environment variables for agent config directory, start hooks in `/etc/sbx/start.d/`

**Container Layer: Runtime**

- Purpose: Validates state and runs the agent
- Location: Launched from `compose.yml` by host scripts
- Contains: Mounted project folder, mounted state folders (caches, login, git identity)
- Depends on: Agent image
- Used by: Developer and GSD execution
- Key Flow: entrypoint validation, hook execution, agent CLI

**Host Layer: Registry and Management**

- Purpose: Track sandbox registrations and provide CLI for sandbox operations
- Location: Registry in `~/.config/sbx/sandboxes/`; scripts in `bin/`
- Contains: Per-sandbox metadata (folder path, agent type)
- Depends on: Installed Docker Desktop, `compose.yml`, agent images
- Used by: Developer running `sbx-*` commands

## Data Flow

### Sandbox Registration and First Start

1. Developer runs `sbx-add demo /Users/you/sbx-demo` (from `bin/sbx-add`)
2. Script validates name (against sandboxNamePattern from `base/sbx-start-lib.sh`)
3. Script creates `/Users/you/sbx-demo/demo` and `/Users/you/sbx-demo/state`
4. Script writes registry entry: `~/.config/sbx/sandboxes/demo` (two lines: `SBX_DIR=`, `SBX_AGENT=`)
5. Developer runs `sbx-upgrade demo` (from `bin/sbx-upgrade`)
6. Script invokes `./build.sh` to build agent images (if not present)
7. Script invokes `docker compose up` with `SBX_NAME=demo SBX_DIR=/Users/you/sbx-demo`
8. Compose starts container `sbx-demo` with mount `/Users/you/sbx-demo` at `/home/sandbox/workspace`

### Container Startup

1. PID 1 (tini) waits for the command (`sleep infinity`)
2. Entrypoint script runs: `base/sbx-entrypoint`
3. Entrypoint sources `base/sbx-start-lib.sh` for check functions
4. Checks execute in order (mount, name, folders); each failing check stops the start
5. `create_state_dirs` ensures `state/shell`, `state/gh`, `state/git`, `state/claude` (or `state/cursor`) exist
6. `run_start_hooks` runs each executable in `/etc/sbx/start.d/` by name order
   - `05-gsd`: Runs `gsd-core --claude --global` to sync GSD into `state/claude/gsd-core`
   - `10-best-practices`: Links `state/best-practices` folder into `state/claude/rules` and `state/claude/skills`
   - Agent-specific hooks (e.g., Cursor disables self-update)
7. Each hook can fail; a failure stops the start with an error message
8. After hooks succeed, entrypoint changes to project folder and execs the command

### Agent Operation

1. Developer runs `sbx-shell demo` (from `bin/sbx-shell`) to open a bash prompt
2. Docker execs bash into the running container: `docker exec -it -w /home/sandbox/workspace/demo sbx-demo bash`
3. Bash reads `/etc/bash.bashrc` (image-provided); this prints the tool versions line
4. Developer runs `claude` or `cursor-agent` (depending on agent type)
5. Agent reads config from `CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude` or `CURSOR_CONFIG_DIR=/home/sandbox/workspace/state/cursor`
6. Agent runs; history, logins, and settings persist in `state/` across container recreates

### Container Validation (sbx-selfcheck)

1. Developer runs `sbx-selfcheck` in a sandbox shell
2. Python runner loads checks from `/usr/local/lib/sbx-selfcheck/checks/` (base) and `/etc/sbx/selfcheck.d/<agent>/` (agent-specific)
3. Each check runs and returns PASS or FAIL
4. Failures include remediation hints (e.g., rebuild or mount issue)
5. Exit code is 0 (all pass) or non-zero (failures); useful in scripts and CI

## Key Abstractions

**Sandbox**

- Purpose: Isolates one project and one agent session
- Examples: `~/.config/sbx/sandboxes/demo` (registry), `/Users/you/sbx-demo/` (host folder), `sbx-demo` (container)
- Pattern: Registry entry + host folders + container instance; name rules prevent collisions

**Mount Point**

- Purpose: Binds the host project folder into the container without hiding image contents
- Examples: `$SBX_DIR` on Mac; `/home/sandbox/workspace` in container
- Pattern: `compose.yml` uses `create_host_path: false` to fail fast if the folder is missing

**State Folders**

- Purpose: Preserve agent login, settings, caches, and history across container recreates
- Examples: `state/claude`, `state/gh`, `state/shell`, `state/cache/npm`, `state/m2`
- Pattern: Created at startup by `create_state_dirs`; persisted on the host under `state/`; environment variables direct tools to use them

**Start Hooks**

- Purpose: Run agent-specific setup tasks atomically at container start
- Examples: `05-gsd` syncs GSD; `10-best-practices` links skills
- Pattern: Executable shell scripts in `/etc/sbx/start.d/` run in name order; failure stops the start

**Self-Check Framework**

- Purpose: Validate image state and container setup before the agent operates
- Examples: Check tool versions, mount point, ownership, environment variables
- Pattern: Python modules in `base/selfcheck/checks/` and agent-specific `*/selfcheck/` define `CHECK_LIST`; runner collects and runs them

**Registry**

- Purpose: Persist sandbox metadata outside the project folder
- Examples: `SBX_DIR=/Users/you/sbx-demo`, `SBX_AGENT=claude`
- Pattern: One file per sandbox in `~/.config/sbx/sandboxes/<name>`; sourced by host scripts

## Entry Points

**Host-side (macOS)**

- `sbx-add`: Registers a new sandbox; validates name and paths; creates folders; writes registry entry
- `sbx-start`: Starts a sandbox (docker compose up) without rebuilding images
- `sbx-upgrade`: Rebuilds images and starts the sandbox
- `sbx-shell`: Execs a bash shell into the running container at the project folder
- `sbx-list`: Lists all registered sandboxes
- `sbx-stop`, `sbx-rm`: Stop and remove containers

**Container-side (Linux)**

- Entrypoint: `base/sbx-entrypoint` validates mount and state, runs start hooks, then execs the user command
- Start hooks: Located in `/etc/sbx/start.d/`, run in name order (e.g., `05-gsd`, `10-best-practices`)
- Agent CLI: `claude` or `cursor-agent` (not managed by sbx; the agent runs as a subprocess)
- Selfcheck: `sbx-selfcheck` validates the image and container state

## Architectural Constraints

- **One mount**: Entire `/home/sandbox/workspace` is mounted; no nested mounts or subtree separations
- **Sandbox name rule**: Names start with a lowercase letter, then lowercase, digits or hyphens, 31 chars max (`^[a-z][a-z0-9-]{0,30}$`). Prevents Docker naming errors and sandbox folder collisions
- **Reserved names**: `state` and `best-practices` are reserved; a sandbox cannot use them as its project name
- **No root access**: The container runs the unprivileged `sandbox` user; image files are root-owned and immutable
- **Immutable image paths**: Image-provided binaries in `/usr/local/bin` and libraries are read-only to the sandbox user
- **Non-interactive entrypoint**: Start hooks must succeed or the container fails to start; no interactive recovery
- **Pins are not defaults**: Every version in `versions.env` must be provided; `build.sh` stops without them
- **Registry outside mounts**: Registry in `~/.config/sbx/` prevents a sandbox from rewriting its own entry
- **No state pollution**: Start hooks are idempotent; rerunning them does not create duplicates or corrupt existing state

## Anti-Patterns

### Baking Mutable State into the Image

**What happens:** GSD, agent logins, or caches are installed into the image at build time.

**Why it is wrong:** On container recreate, the state is lost because the container layer is discarded. Developers lose their login and settings.

**Do this instead:** Put state in mounted folders (`state/claude`, `state/cache/npm`). Sync or initialize the state folder at startup via start hooks. Environment variables redirect tools to use the state folder.

### Storing Secrets in the Dockerfile or Environment

**What happens:** API keys, passwords or tokens appear in `ARG`, `ENV` or the Dockerfile itself.

**Why it is wrong:** Docker layers are versioned and logged; the image retains the secret even after it is deleted. The registry sees every build command.

**Do this instead:** Secrets come from the environment only. The host provides them at runtime; the container never stores them. Use `sbx-gh-login` for gh credentials; Claude Code stores its login in the state folder on the host.

### Hard-Coding the Agent Type into the Base Image

**What happens:** The base image includes Claude-specific tools (Claude Code, ccusage, managed settings).

**Why it is wrong:** A second agent (Cursor) cannot use the same base. Each agent requires its own image build and its own Dockerfile.

**Do this instead:** The base image includes only tools all agents use: GSD, git, gh, toolchains. Agent-specific tools go in agent images that inherit from the base. Agent-specific start hooks go in `/etc/sbx/start.d/` in the agent image; the base entrypoint runs them without knowing the agent type.

### Mounting the Home Directory Directly

**What happens:** `/home/sandbox` is mounted from the host instead of just `/home/sandbox/workspace`.

**Why it is wrong:** The mount hides image-provided home folders, caches and config directories. dotfiles, shells and `.bashrc` from the host override the image. The agent loses its settings and history.

**Do this instead:** Mount only the project and state folder together at one point: `/home/sandbox/workspace`. Keep home directories in the image. Use symlinks from home into state folders (e.g., `~/.m2 -> state/m2`).

## Error Handling

**Entrypoint Validation**

- Mount point must be mounted; failing here means the developer used `docker run` directly instead of `docker compose up`
- Sandbox name must follow the rule; failing here prevents name collisions and Docker compose errors
- Project and state folders must exist; failing here indicates a missing or mistyped path or a broken registry entry
- State directories are created; failures here stop the start (permission issue with the mount)

**Start Hooks**

- Hooks run in sequence; the first failure stops the start and is reported on stderr
- A missing hook file is silently skipped; only regular executable files run
- Each hook exit code is checked; a non-zero exit stops the start
- Hook output is not captured; stdout and stderr go to the container log for debugging

**Image Builds**

- Smoke tests at build time verify every version pin (node version, GSD version, etc.)
- Version mismatches cause build failure; the image is not produced
- Missing versions are named in the error; `versions.env` must provide them
- Syntax errors in Python files (selfcheck checks) cause build failure

**Container Startup Errors**

- Errors are printed to stderr with `[sbx] ERROR:` prefix
- Exit code is 1; the container does not start
- Developer sees the error in `docker compose up` output or `docker logs sbx-<name>`
- Remediation hints are in the error message (e.g., "rebuild the images" or "check the mount")

## Cross-Cutting Concerns

**Logging**

- Container startup: Errors go to stderr via `echo ... >&2` in the entrypoint and start hooks
- Selfcheck: Results are printed to stdout (PASS/FAIL per check); remediation hints follow failures
- Image builds: Verbose output from curl, tar, compilation tools; layer cache hits are shown
- History: Bash history is saved to `state/shell/bash_history` across sessions

**Environment Configuration**

- `SBX_NAME`: Set by `compose.yml` from the `--name` Docker Compose project name
- `SBX_DIR`: Set by host scripts; passed to `compose.yml`; binds the mount point
- `SBX_AGENT`: Set by host scripts (defaults to `claude`); selects the image (`sbx-claude` or `sbx-cursor`)
- `SBX_IMAGE_TAG`: Defaults to `local`; `test` is used for test images; any other value is refused
- Tool-specific: `CLAUDE_CONFIG_DIR`, `CURSOR_CONFIG_DIR`, `GH_CONFIG_DIR`, etc.; all point into `state/`

**Security**

- No capabilities in the container; `cap_drop: ALL`
- Non-root user; `sandbox` uid 1000
- Image binaries are root-owned, immutable by the sandbox user
- Mount is read-write; the sandbox user can read and write project files
- Registry outside every mount; the sandbox user cannot modify its own registration
- Repos behind a proxy trust the proxy's root certificate (if `SBX_CA_CERT` is set); this is configurable per build

---

*Architecture analysis: 2026-11-16*
