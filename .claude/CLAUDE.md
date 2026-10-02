<!-- GSD:project-start source:PROJECT.md -->

## Project

**GSD Agent Sandbox Containers**

A Docker-based sandbox for running AI coding agents (Claude Code today, OpenCode next, others later) plus GSD on a macOS laptop without installing those agents on the host. Each project gets its own container that can only see one bind-mounted host folder, so the agent can't touch the rest of the laptop. The code stays a regular folder on the Mac, so any host IDE can open it directly. Small shell scripts (`cc-up`, `cc-bash`, `cc-down`, …) drive the container lifecycle.

**Core Value:** **Rebuilding the image must reliably deliver new or updated tools into a project sandbox without losing the agent's login, settings, or history, and without the host mount hiding anything the image provides.**

### Constraints

- **Security**: Agents never run on the host, and each container sees only its project's mount. Why: this isolation is the reason the project exists.
- **Security**: GSD comes only from `@opengsd/gsd-core`. Never use `get-shit-done-cc` or `gsd-build`. Why: the old package was compromised.
- **Platform**: Must work on macOS + Docker Desktop (likely arm64), with bind mounts. Why: that's the user's only host.
- **Simplicity**: Keep shell scripts short and plain bash. Why: the user wants to grow the tooling slowly and keep it understandable.
- **Toolchains**: JDK 21 LTS, Maven, Node.js, and Python in the shared base. Why: these are the stacks the user develops in.
- **Verification**: Docker isn't available inside the dev sandbox, so plans must include host-side manual verification steps.
- **Coexistence**: The old layout (`ClaudeCode/`, `cc-*` scripts, the whole-home mount) stays untouched until Phase 5. New work goes in new directories, and new containers, images, and compose projects use a name prefix different from `cc_gsd_<name>` / `cc_<name>`, so old and new sandboxes can run side by side. Why: the user keeps working in existing sandboxes (including the one this repo is developed in) while the new layout is built.

<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->

## Technology Stack

## Languages

- Bash - Shell scripting for container entrypoints and helper scripts (`docker-entrypoint.sh`, `cc-up.sh`, `cc-bash.sh`, `cc-down.sh`)
- YAML - Docker Compose configuration files

## Runtime

- Docker & Docker Compose - Containerization platform for isolated environments
- Ubuntu Linux (ubuntu:latest) - Base OS for both ClaudeCode and OpenCode containers
- npm (Node Package Manager) - Installed via NodeSource for ClaudeCode container
- Node.js 20 - JavaScript runtime for ClaudeCode container only
- Node.js (generic) - Installed in OpenCode container without explicit version

## Frameworks

- Claude Code CLI - Installed from `https://claude.ai/install.sh` into ClaudeCode container (`/usr/local/bin/claude`)
- GitHub CLI (gh) - Installed from GitHub's package repository in ClaudeCode container for git operations
- OpenCode CLI - Installed from `https://opencode.ai/install` in OpenCode container
- @opengsd/gsd-core - Installed into ClaudeCode container via `npx -y @opengsd/gsd-core@latest --claude --global`
- get-shit-done-cc - Installed into OpenCode container via `npx -y get-shit-done-cc --opencode --global`

## Key Dependencies

- curl - Used for downloading installation scripts and binaries
- ca-certificates - Required for HTTPS/TLS connections
- git - Version control client for repository operations
- wget - Alternative download tool for GPG keyrings
- gpg - GPG signature verification for GitHub CLI

## Configuration

- `PROJECT_NAME` - Name identifier for the Docker project (used in docker-compose container naming)
- `PROJECT_PATH` - Host filesystem path to mount as `/home/sandbox` inside container (sandbox working directory)
- `PATH` - Extended in OpenCode container to include `/home/sandbox/.opencode/bin`
- `Dockerfile` - Container image definition for ClaudeCode (`ClaudeCode/Dockerfile`) and OpenCode (`OpenCode/Dockerfile`)
- `docker-compose.yml` - Service orchestration in both `ClaudeCode/docker-compose.yml` and `OpenCode/docker-compose.yml`
- `.initialized` - Marker file in mounted home directory (`/home/sandbox/.initialized`) that gates first-run setup

## Platform Requirements

- Docker Engine and Docker Compose installed on host machine
- Linux, macOS, or Windows (with Docker Desktop)
- Sufficient disk space for container images and mounted project volumes
- Deployment target: Docker containers running on any Docker-capable host
- Container images built from Ubuntu base
- Network access required for:

## Mount Points & Volumes

- `/home/sandbox` - Mounted from host via `${PROJECT_PATH}` volume binding
- `/home/sandbox/.claude` - Contains Claude credentials and GSD installation (populated at runtime by entrypoint)
- `/home/sandbox/.initialized` - Marker file for first-run initialization
- `/home/sandbox` - Mounted from host (currently hardcoded to `/Users/demian/GSD_StaticSiteGenerator` in compose file)
- `/home/sandbox/.local/bin` - Added to PATH for opencode-ai CLI

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

## Naming Patterns

- Shell scripts use lowercase with hyphens: `cc-up.sh`, `cc-bash.sh`, `cc-down.sh`
- Docker-related files follow standard naming: `Dockerfile`, `docker-compose.yml`, `docker-entrypoint.sh`
- Configuration files follow standard conventions: `.gitignore`, `.initialized` (marker files)
- Shell functions use lowercase with hyphens for clarity
- No formal shell functions defined in provided scripts; scripts use command sequences
- Environment variables use UPPERCASE with underscores: `PROJECT_NAME`, `PROJECT_PATH`, `PATH`
- Local shell variables use lowercase: `sandbox` (username)
- Variables are explicitly exported when needed for subprocesses: `export PROJECT_NAME=$1`
- No type system (shell scripts and Dockerfiles are dynamically typed)
- Docker image tags follow semantic conventions (e.g., `ubuntu:latest`)

## Code Style

- Shell scripts use consistent 2-space or 4-space indentation (ClaudeCode/cc-up.sh uses 4-space)
- Docker RUN commands chain with `&&` for layer optimization
- Line continuation uses backslash `\` for readability in Dockerfile
- Docker compose YAML uses 2-space indentation
- No linting tools configured (bash linter, hadolint, yamllint not present)
- Code style is enforced through conventions in documentation

## Import Organization

- Docker PATH extensions via ENV: `ENV PATH="/home/sandbox/.opencode/bin:$PATH"` (OpenCode/Dockerfile)
- System binaries placed in standard locations: `/usr/local/bin` for user-accessible tools

## Error Handling

- All critical shell scripts use `set -e` to exit on first error: `docker-entrypoint.sh`, `cc-up.sh`
- Marker file pattern for idempotent setup (`.initialized`):
- Exit status is checked implicitly by `set -e`; explicit error checking not used
- Commands that redirect output use `>> log 2>&1` to capture both stdout and stderr (OpenCode/docker-entrypoint.sh:14)

## Logging

- Info messages printed directly: `echo "Fresh home detected -- installing GSD into ~/.claude ..."`
- Completion messages echo status: `echo "GSD install complete."`, `echo "Environment setup complete!"`
- Errors are implicit (script exits via `set -e`)
- Verbose output captured in log file for non-critical operations: `>> log 2>&1` (OpenCode entrypoint)

## Comments

- Explain non-obvious design decisions (why something is placed here, not there)
- Document the rationale for complex sections
- Explain security implications (e.g., trusted package sources)
- Mark experimental or disabled code with `# XXX:` prefix
- ClaudeCode/Dockerfile (lines 4-35): Multi-line comment block explaining installation strategy and mount behavior
- ClaudeCode/docker-entrypoint.sh (lines 4-13): Detailed comment explaining why GSD is installed in entrypoint, not Dockerfile
- ClaudeCode/Dockerfile (lines 41-47): `# XXX: Experimental` marks disabled code for future consideration
- Not applicable (shell scripts, Dockerfiles, YAML; no TypeScript/JavaScript code)

## Function Design

- Scripts are very small (1-8 lines), each doing a single task
- Example: `cc-up.sh` is 8 lines total, exports variables and calls docker-compose
- Passed as positional arguments: `$1`, `$2`
- Exported to environment when used by child processes: `export PROJECT_NAME=$1`
- Usage documented in comments: `# Usage: ./cc-up.sh <project_name> <host_path>`
- Scripts use exit codes implicitly via `set -e`
- Forward process exit via `exec "$@"` (docker-entrypoint.sh:24)
- Commands using pipes capture output implicitly: `curl ... | bash`

## Module Design

- Environment variables explicitly exported: `export PROJECT_NAME`, `export PROJECT_PATH`
- No shared sourcing of helper scripts (each script is standalone)
- Entrypoint script is centralized in `/usr/local/bin/docker-entrypoint.sh`
- No barrel file pattern (not applicable to this infrastructure codebase)

## Docker-Specific Conventions

- Clear section markers using comment blocks with dashes:
- Comments explain decisions above the RUN commands they describe (lines 4-9, 26-35)
- RUN commands chain with `&&` to reduce layer count
- Cleanup commands placed at end of RUN chain: `rm -rf /var/lib/apt/lists/*`
- USER and WORKDIR set near end of file, after tools are installed
- ENTRYPOINT specifies the script path; CMD can be overridden
- Services section contains all service definitions
- Comments explain configuration options inline:
- Environment variable substitution via `${VAR_NAME}`
- Volume mounts bind host paths to container paths
- Container naming follows pattern: `[prefix]_[suffix]_${PROJECT_NAME}`

## Version Management

- Use latest stable tag: `ubuntu:latest` (ClaudeCode/Dockerfile, OpenCode/Dockerfile)
- NodeSource for Node 20: `setup_20.x` (ClaudeCode/Dockerfile:11)
- npm and nodejs installed from ubuntu repos (OpenCode/Dockerfile:9)

<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

## System Overview

```text

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

- **Isolation**: Each service (Claude, OpenCode) runs in separate container with independent home and toolchain
- **Host binding**: Project source and developer home bind-mounted from host, survives container restarts
- **Lazy initialization**: GSD and OpenCode CLI installed on first run, not baked into image
- **Marker-gated setup**: `.initialized` file prevents repeated installation after first container start
- **Tool separation**: CLI binaries in image (`/usr/local/bin`), config in bind-mounted home (`~/.claude`, `~/.opencode`)
- **Entrypoint pattern**: Bash script gates setup, then execs the command (keeps bash alive for interactive shells)

## Layers

- Purpose: Operating system and system packages
- Location: `ubuntu:latest` from Docker Hub
- Contains: Base utilities (apt, bash, curl, wget)
- Depends on: Docker
- Used by: All layers above
- Purpose: Language runtimes and essential tools
- Location: Installed via `apt-get` in Dockerfile (ClaudeCode: Node.js 20, Git, GitHub CLI; OpenCode: Node.js)
- Contains: Node.js/npm, git, curl, ca-certificates, GitHub CLI CLI
- Depends on: Base layer
- Used by: Tool layer for CLI installation
- Purpose: Developer-facing CLIs
- Location: Claude binary in `/usr/local/bin` (baked); OpenCode in `~/.local/bin` (installed by entrypoint)
- Contains: Claude Code CLI, OpenCode CLI
- Depends on: Runtime layer (Node.js, curl)
- Used by: User layer (sandbox user shell)
- Purpose: First-run setup of GSD and configuration
- Location: `docker-entrypoint.sh` scripts
- Contains: Shell logic for gated installation via `.initialized` marker
- Depends on: Tool layer (npx from Node.js)
- Used by: Container lifecycle (runs once on start)
- Purpose: Sandbox user with project-mounted home
- Location: `/home/sandbox` (bind-mounted from host)
- Contains: Project source, `.claude/` GSD config, `.initialized` marker, `.bashrc`, and developer files
- Depends on: All layers below
- Used by: Developer interacting with `claude` or `opencode` CLI

## Data Flow

### Claude Code + GSD Workflow

### OpenCode Workflow

### GSD Installation Flow

```

```

```

```

## Key Abstractions

- Purpose: Isolated Linux environment that runs CLI tools without affecting host system
- Examples: `ClaudeCode/Dockerfile`, `OpenCode/Dockerfile`
- Pattern: Multi-stage implicit (base OS + tools + entrypoint)
- Purpose: Project source and developer config persist on host while CLI runs in container
- Examples: `volumes: ${PROJECT_PATH}:/home/sandbox` in docker-compose.yml
- Pattern: Full home directory bind-mount (everything in `/home/sandbox` comes from host)
- Purpose: Gate initialization to first run only, avoid repeated install overhead
- Examples: `.initialized` file checked by entrypoint scripts
- Pattern: File existence as idempotency guard
- Purpose: Hide docker-compose complexity, provide simple UX (cc-up, cc-bash, cc-down)
- Examples: `ClaudeCode/cc-up.sh`, `cc-bash.sh`, `cc-down.sh`
- Pattern: Thin shell wrappers around docker-compose with environment injection

## Entry Points

- Location: `ClaudeCode/cc-up.sh`
- Triggers: Developer runs `./cc-up.sh <project_name> <host_path>`
- Responsibilities: 
- Location: `ClaudeCode/cc-bash.sh`
- Triggers: Developer runs `./cc-bash.sh <project_name>`
- Responsibilities: 
- Location: `ClaudeCode/cc-down.sh`
- Triggers: Developer runs `./cc-down.sh <project_name>`
- Responsibilities: 
- Location: `ClaudeCode/docker-entrypoint.sh`, `OpenCode/docker-entrypoint.sh`
- Triggers: Container starts (ENTRYPOINT directive in Dockerfile)
- Responsibilities:
- Location: `/usr/local/bin/claude` (baked in ClaudeCode image)
- Triggers: Developer runs `claude` in shell (after `cc-bash.sh`)
- Responsibilities:

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

### Storing Secrets in Dockerfile

### Forgetting to Clean apt cache

## Error Handling

- Entrypoint exits if any command fails (curl, npx, chmod)
- No explicit error handling; failures propagate to `docker-compose up`
- Developer sees error in console and must fix (e.g., network, permissions)
- Idempotency via `.initialized` marker: delete marker and retry to retry install
- ClaudeCode: Entrypoint echoes status to stdout (visible in `docker logs`)
- OpenCode: Entrypoint writes output to `log` file (not stdout), harder to debug

## Cross-Cutting Concerns

- ClaudeCode uses explicit `echo` statements in entrypoint (lines 15, 20)
- OpenCode redirects to `log` file (line 14), less visible
- No structured logging; simple text output to console or file
- ClaudeCode: Parameterized via env vars in docker-compose
- OpenCode: Hardcoded example path in compose (line 10 shows example only)
- Both expect developer to ensure host path exists
- Both Dockerfiles create unprivileged `sandbox` user (non-root)
- Switch to sandbox user before ENTRYPOINT (USER sandbox directive)
- Prevents container from modifying files as root
- Claude binary in `/usr/local/bin` (always in PATH)
- OpenCode in `~/.local/bin` (added to PATH by entrypoint's `.bashrc` modification)
- GSD lives in `~/.claude` (loaded by Claude CLI on startup)

<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
