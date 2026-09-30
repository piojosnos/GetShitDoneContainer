---
last_mapped_commit: 304f80d1a0705d9ab668ef2ed4acd9fcf65060ac
last_mapped_at: 2026-09-30
---
<!-- refreshed: 2026-09-30 -->

# Architecture

**Analysis Date:** 2026-09-30

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────┐
│                      Host Machine (Developer)                        │
│  Project folder with source code + mounted home (/Users/you/path)   │
└───────────────┬─────────────────────────────────────────────────────┘
                │
         docker-compose up
         bind mount volumes
                │
        ┌───────▼────────────┐        ┌───────────────────────┐
        │   ClaudeCode       │        │    OpenCode           │
        │   Container        │        │    Container          │
        │   (cc_gsd_*)       │        │    (oc_gsd_c)         │
        └───────┬────────────┘        └───────────┬───────────┘
                │                                 │
                │                                 │
        ┌───────▼──────────────────────┐  ┌──────▼─────────────┐
        │   User Layer                  │  │ OpenCode CLI       │
        │   sandbox user at            │  │ @/home/sandbox     │
        │   /home/sandbox               │  │ .opencode/bin      │
        │   (bind-mounted from host)    │  └────────────────────┘
        └───────┬──────────────────────┘
                │
        ┌───────▼──────────────────────────────────────────────────┐
        │   Initialization Layer (docker-entrypoint.sh)             │
        │   - Check .initialized marker                             │
        │   - First-run: Install GSD via npx                        │
        │   - Create ~/.claude for GSD config                       │
        └───────┬──────────────────────────────────────────────────┘
                │
        ┌───────▼──────────────────────────────────────────────────┐
        │   Tool Layer                                              │
        │   ┌──────────────────────┐  ┌──────────────────────────┐ │
        │   │ Claude Code CLI      │  │ OpenCode-AI CLI          │ │
        │   │ /usr/local/bin       │  │ ~/.local/bin             │ │
        │   │ (baked in image)     │  │ (installed by entrypoint)│ │
        │   └──────────────────────┘  └──────────────────────────┘ │
        └───────┬──────────────────────────────────────────────────┘
                │
        ┌───────▼──────────────────────────────────────────────────┐
        │   Runtime Layer                                           │
        │   - Node.js 20 (ClaudeCode)                               │
        │   - Git, wget, curl                                       │
        │   - GitHub CLI (ClaudeCode only)                          │
        │   - bash shell                                            │
        └───────┬──────────────────────────────────────────────────┘
                │
        ┌───────▼──────────────────────────────────────────────────┐
        │   Base Layer: Ubuntu latest                               │
        └───────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| ClaudeCode Container | Run Claude Code CLI with GSD in isolated Linux environment | `ClaudeCode/` |
| OpenCode Container | Run OpenCode CLI with GSD for web-based code editing | `OpenCode/` |
| docker-entrypoint.sh (Claude) | First-run GSD installation, marker-gated initialization | `ClaudeCode/docker-entrypoint.sh` |
| docker-entrypoint.sh (OpenCode) | First-run OpenCode CLI + GSD installation, PATH setup | `OpenCode/docker-entrypoint.sh` |
| Helper Scripts | Lifecycle management (start, shell, stop containers) | `ClaudeCode/cc-*.sh` |
| docker-compose.yml | Service definition, volume binding, port mapping | `ClaudeCode/docker-compose.yml`, `OpenCode/docker-compose.yml` |

## Pattern Overview

**Overall:** Docker-based isolated development environment with language tool CLI installed and project bind-mounted from host.

**Key Characteristics:**
- **Isolation**: Each service (Claude, OpenCode) runs in separate container with independent home and toolchain
- **Host binding**: Project source and developer home bind-mounted from host, survives container restarts
- **Lazy initialization**: GSD and OpenCode CLI installed on first run, not baked into image
- **Marker-gated setup**: `.initialized` file prevents repeated installation after first container start
- **Tool separation**: CLI binaries in image (`/usr/local/bin`), config in bind-mounted home (`~/.claude`, `~/.opencode`)
- **Entrypoint pattern**: Bash script gates setup, then execs the command (keeps bash alive for interactive shells)

## Layers

**Base Layer (Ubuntu):**
- Purpose: Operating system and system packages
- Location: `ubuntu:latest` from Docker Hub
- Contains: Base utilities (apt, bash, curl, wget)
- Depends on: Docker
- Used by: All layers above

**Runtime Layer:**
- Purpose: Language runtimes and essential tools
- Location: Installed via `apt-get` in Dockerfile (ClaudeCode: Node.js 20, Git, GitHub CLI; OpenCode: Node.js)
- Contains: Node.js/npm, git, curl, ca-certificates, GitHub CLI CLI
- Depends on: Base layer
- Used by: Tool layer for CLI installation

**Tool Layer:**
- Purpose: Developer-facing CLIs
- Location: Claude binary in `/usr/local/bin` (baked); OpenCode in `~/.local/bin` (installed by entrypoint)
- Contains: Claude Code CLI, OpenCode CLI
- Depends on: Runtime layer (Node.js, curl)
- Used by: User layer (sandbox user shell)

**Initialization Layer:**
- Purpose: First-run setup of GSD and configuration
- Location: `docker-entrypoint.sh` scripts
- Contains: Shell logic for gated installation via `.initialized` marker
- Depends on: Tool layer (npx from Node.js)
- Used by: Container lifecycle (runs once on start)

**User Layer:**
- Purpose: Sandbox user with project-mounted home
- Location: `/home/sandbox` (bind-mounted from host)
- Contains: Project source, `.claude/` GSD config, `.initialized` marker, `.bashrc`, and developer files
- Depends on: All layers below
- Used by: Developer interacting with `claude` or `opencode` CLI

## Data Flow

### Claude Code + GSD Workflow

1. **Host Setup** (`cc-up.sh`): Developer runs `./cc-up.sh myproj /path/to/project`
2. **Compose Start**: Docker-compose reads `ClaudeCode/docker-compose.yml`, passes `PROJECT_NAME` and `PROJECT_PATH` as env vars
3. **Volume Mount**: Container home `/home/sandbox` is bind-mounted to host `${PROJECT_PATH}`
4. **Entrypoint Runs** (`docker-entrypoint.sh`):
   - Checks for `/home/sandbox/.initialized` file
   - If missing (first run): Runs `npx -y @opengsd/gsd-core@latest --claude --global`
   - GSD installs into live mounted home at `/home/sandbox/.claude`
   - Creates `.initialized` marker to skip install on next start
   - Execs the CMD (bash shell)
5. **User Shell** (`cc-bash.sh`): Developer runs `./cc-bash.sh myproj` to open interactive shell
6. **Claude Command**: Developer runs `claude` command (binary in `/usr/local/bin`)
7. **GSD Available**: Claude loads GSD skills from `~/.claude`, developer can use `/gsd-*` commands

### OpenCode Workflow

1. **Host Setup**: Developer runs `docker-compose up` from `OpenCode/` directory
2. **Volume Mount**: Container home bind-mounted (hardcoded in compose as example)
3. **Entrypoint Runs**:
   - Checks for `.initialized`
   - First run: Installs `opencode-ai` CLI to `~/.local/bin`, installs GSD
   - Adds `~/.local/bin` to `.bashrc` PATH
   - Execs command: `bash -c "opencode web --hostname 0.0.0.0"`
4. **OpenCode Server**: Web server starts on port 4096
5. **Browser Access**: Developer opens `http://127.0.0.1:4096` to access OpenCode IDE

### GSD Installation Flow

**First Container Start:**

```
docker-compose up -d
  → Builds image if needed
  → Creates container volume mount
  → Runs entrypoint.sh as sandbox user
  → Checks /home/sandbox/.initialized (missing)
  → Runs: npx -y @opengsd/gsd-core@latest --claude --global
    → npm registry fetch
    → Downloads and runs installer script
    → Installs into ~/.claude/
    → Creates ~/.claude/get-shit-done/ skills/ agents/
  → Touches .initialized file
  → Execs /bin/bash (keeps shell alive)
```

**Subsequent Starts:**

```
docker-compose up -d
  → Uses existing image
  → Mounts volumes
  → Runs entrypoint.sh
  → Checks .initialized (exists)
  → Skips install
  → Execs /bin/bash
```

## Key Abstractions

**Containerization:**
- Purpose: Isolated Linux environment that runs CLI tools without affecting host system
- Examples: `ClaudeCode/Dockerfile`, `OpenCode/Dockerfile`
- Pattern: Multi-stage implicit (base OS + tools + entrypoint)

**Bind Mount Strategy:**
- Purpose: Project source and developer config persist on host while CLI runs in container
- Examples: `volumes: ${PROJECT_PATH}:/home/sandbox` in docker-compose.yml
- Pattern: Full home directory bind-mount (everything in `/home/sandbox` comes from host)

**Entrypoint Marker Pattern:**
- Purpose: Gate initialization to first run only, avoid repeated install overhead
- Examples: `.initialized` file checked by entrypoint scripts
- Pattern: File existence as idempotency guard

**Helper Script Abstraction:**
- Purpose: Hide docker-compose complexity, provide simple UX (cc-up, cc-bash, cc-down)
- Examples: `ClaudeCode/cc-up.sh`, `cc-bash.sh`, `cc-down.sh`
- Pattern: Thin shell wrappers around docker-compose with environment injection

## Entry Points

**cc-up.sh** (ClaudeCode start):
- Location: `ClaudeCode/cc-up.sh`
- Triggers: Developer runs `./cc-up.sh <project_name> <host_path>`
- Responsibilities: 
  - Exports PROJECT_NAME and PROJECT_PATH as env vars
  - Runs `docker-compose -p "cc_${PROJECT_NAME}" up -d`
  - Builds image if needed, starts container with volumes

**cc-bash.sh** (Shell entry):
- Location: `ClaudeCode/cc-bash.sh`
- Triggers: Developer runs `./cc-bash.sh <project_name>`
- Responsibilities: 
  - Opens interactive bash shell in running container
  - Runs `docker exec -it cc_gsd_${PROJECT_NAME} /bin/bash`

**cc-down.sh** (ClaudeCode stop):
- Location: `ClaudeCode/cc-down.sh`
- Triggers: Developer runs `./cc-down.sh <project_name>`
- Responsibilities: 
  - Stops container and removes volumes
  - Runs `docker-compose -p "cc_${PROJECT_NAME}" down -v`

**docker-entrypoint.sh** (Container initialization):
- Location: `ClaudeCode/docker-entrypoint.sh`, `OpenCode/docker-entrypoint.sh`
- Triggers: Container starts (ENTRYPOINT directive in Dockerfile)
- Responsibilities:
  - Checks for `.initialized` marker in mounted home
  - First run: Installs GSD (ClaudeCode) or OpenCode CLI + GSD (OpenCode)
  - Execs the CMD command (bash or `opencode web`)

**claude CLI** (User-facing command):
- Location: `/usr/local/bin/claude` (baked in ClaudeCode image)
- Triggers: Developer runs `claude` in shell (after `cc-bash.sh`)
- Responsibilities:
  - Loads GSD skills from `~/.claude`
  - Provides `/gsd-*` commands for project automation

## Architectural Constraints

- **Single home bind mount**: Entire `/home/sandbox` is mounted from host. No nested mounts or split directories.
- **Marker-based idempotency**: Initialization relies on `.initialized` file existence. Deleting it forces reinstall.
- **No root access**: Sandbox user intentionally unprivileged for security.
- **Baked vs. dynamic installation**: Claude binary baked to survive mounts; GSD installed to live home so it's preserved on host.
- **Environment variables**: PROJECT_NAME and PROJECT_PATH passed via docker-compose, not baked into image.
- **Hardcoded home path**: Container always uses `/home/sandbox` as home, no configurability.
- **Sequential initialization**: Entrypoint runs once, then execs CMD (no background tasks).

## Anti-Patterns

### Baking GSD into Image

**What happens:** GSD installed in Dockerfile to `~/.claude`, then bind mount shadows it at runtime.
**Why it's wrong:** Developer can never see or use the installed GSD because host mount covers image home directory.
**Do this instead:** Install GSD in `docker-entrypoint.sh` so it populates the LIVE bind-mounted home (`ClaudeCode/docker-entrypoint.sh` lines 14-19).

### Storing Secrets in Dockerfile

**What happens:** API keys or credentials hardcoded in `RUN` commands are baked into image layers.
**Why it's wrong:** Image becomes shareable artifact containing secrets; cleanup commands can still leave traces in layers.
**Do this instead:** Use environment variables or mounted files; don't log secrets in `docker-compose.yml` either.

### Forgetting to Clean apt cache

**What happens:** `apt-get` package lists and archives accumulate in image.
**Why it's wrong:** Bloats image size unnecessarily, slows builds.
**Do this instead:** Remove cache after install: `apt-get install ... && rm -rf /var/lib/apt/lists/*` (both Dockerfiles already do this correctly).

## Error Handling

**Strategy:** Entrypoint uses `set -e` to fail fast on errors.

**Patterns:**
- Entrypoint exits if any command fails (curl, npx, chmod)
- No explicit error handling; failures propagate to `docker-compose up`
- Developer sees error in console and must fix (e.g., network, permissions)
- Idempotency via `.initialized` marker: delete marker and retry to retry install

**Logging:**
- ClaudeCode: Entrypoint echoes status to stdout (visible in `docker logs`)
- OpenCode: Entrypoint writes output to `log` file (not stdout), harder to debug

## Cross-Cutting Concerns

**Logging:** 
- ClaudeCode uses explicit `echo` statements in entrypoint (lines 15, 20)
- OpenCode redirects to `log` file (line 14), less visible
- No structured logging; simple text output to console or file

**Volume Binding:**
- ClaudeCode: Parameterized via env vars in docker-compose
- OpenCode: Hardcoded example path in compose (line 10 shows example only)
- Both expect developer to ensure host path exists

**Security (Sandbox User):**
- Both Dockerfiles create unprivileged `sandbox` user (non-root)
- Switch to sandbox user before ENTRYPOINT (USER sandbox directive)
- Prevents container from modifying files as root

**Path Execution:**
- Claude binary in `/usr/local/bin` (always in PATH)
- OpenCode in `~/.local/bin` (added to PATH by entrypoint's `.bashrc` modification)
- GSD lives in `~/.claude` (loaded by Claude CLI on startup)

---

*Architecture analysis: 2026-09-30*
