---
last_mapped_commit: 304f80d1a0705d9ab668ef2ed4acd9fcf65060ac
last_mapped_at: 2026-09-30
---
# Codebase Structure

**Analysis Date:** 2026-09-30

## Directory Layout

```
GetShitDoneContainer/
├── ClaudeCode/             # Claude Code + GSD container configuration
│   ├── Dockerfile          # Ubuntu base, Claude CLI, entrypoint
│   ├── docker-compose.yml  # Service definition with env var volume binding
│   ├── docker-entrypoint.sh # First-run GSD installation script
│   ├── cc-up.sh            # Helper: start container
│   ├── cc-bash.sh          # Helper: open shell in running container
│   ├── cc-down.sh          # Helper: stop and remove container
│   └── README.md           # Usage guide, upgrade instructions, troubleshooting
├── OpenCode/               # OpenCode + GSD container configuration
│   ├── Dockerfile          # Ubuntu base, OpenCode CLI, entrypoint
│   ├── docker-compose.yml  # Service definition (hardcoded example volumes)
│   ├── docker-entrypoint.sh # First-run OpenCode + GSD installation script
│   └── (no helper scripts)
├── README.md               # Root guide: start, attach, stop containers
└── .planning/
    └── codebase/           # Codebase analysis documents (this directory)
        ├── ARCHITECTURE.md
        ├── STRUCTURE.md
        ├── STACK.md
        └── (other docs as needed)
```

## Directory Purposes

**ClaudeCode/**
- Purpose: Container setup for Claude Code CLI with GSD in isolated Linux environment
- Contains: Dockerfile, docker-compose config, entrypoint script, helper shell scripts
- Key files: `Dockerfile` (image definition), `docker-entrypoint.sh` (GSD installation), `docker-compose.yml` (service config)

**OpenCode/**
- Purpose: Container setup for OpenCode IDE with GSD, web-accessible from host
- Contains: Dockerfile, docker-compose config, entrypoint script
- Key files: `Dockerfile` (image definition), `docker-entrypoint.sh` (OpenCode + GSD installation), `docker-compose.yml` (service config)

**.planning/codebase/**
- Purpose: Codebase analysis and architecture documentation
- Contains: ARCHITECTURE.md, STRUCTURE.md, STACK.md, CONCERNS.md
- Key files: Reference documents for maintainers and future Claude instances

## Key File Locations

**Entry Points:**
- `ClaudeCode/cc-up.sh`: Start ClaudeCode container with project binding
- `ClaudeCode/cc-bash.sh`: Open shell in running ClaudeCode container
- `OpenCode/docker-compose.yml`: Start OpenCode container (direct compose command or via docker-compose)

**Configuration:**
- `ClaudeCode/docker-compose.yml`: ClaudeCode service definition, volume binding via env vars
- `OpenCode/docker-compose.yml`: OpenCode service definition, example volume path
- `ClaudeCode/Dockerfile`: ClaudeCode image build definition (Ubuntu, Node 20, Claude CLI)
- `OpenCode/Dockerfile`: OpenCode image build definition (Ubuntu, Node, OpenCode CLI)

**Core Logic:**
- `ClaudeCode/docker-entrypoint.sh`: GSD installation logic, marker-gated (checks `.initialized`)
- `OpenCode/docker-entrypoint.sh`: OpenCode CLI + GSD installation, PATH setup

**Lifecycle Helpers:**
- `ClaudeCode/cc-up.sh`: `docker-compose up -d` with PROJECT_NAME/PROJECT_PATH env vars
- `ClaudeCode/cc-bash.sh`: `docker exec -it` to open shell in running container
- `ClaudeCode/cc-down.sh`: `docker-compose down -v` to stop and remove container

**Documentation:**
- `README.md` (root): Quick start guide, basic docker-compose usage, stop instructions
- `ClaudeCode/README.md`: Detailed walkthrough of how binding works, GSD installation, upgrade procedures

## Naming Conventions

**Files:**
- Shell scripts: `cc-<action>.sh` (ClaudeCode helpers), e.g., `cc-up.sh`, `cc-bash.sh`
- Docker configs: Standard names (`Dockerfile`, `docker-compose.yml`, `docker-entrypoint.sh`)
- Documentation: `README.md` in each directory; analysis docs in `.planning/codebase/` as UPPERCASE.md

**Directories:**
- Service directories: PascalCase (`ClaudeCode/`, `OpenCode/`)
- Hidden directories: Leading dot (`.git/`, `.idea/`, `.planning/`)

**Environment Variables (docker-compose):**
- `PROJECT_NAME`: Short name for project (used in container name, compose project)
- `PROJECT_PATH`: Host folder path to bind as container home
- `PATH` (OpenCode): Extended via entrypoint to include `~/.local/bin`

## Where to Add New Code

**New Container Service:**
- Create new directory: `/path/to/ServiceName/`
- Add files: `Dockerfile`, `docker-compose.yml`, `docker-entrypoint.sh`
- Pattern: Follow `ClaudeCode/` or `OpenCode/` as template
- Helper scripts: Optional; add `*-up.sh`, `*-bash.sh`, `*-down.sh` in service directory if needed

**New Entrypoint Installation Step:**
- Edit: `ClaudeCode/docker-entrypoint.sh` or `OpenCode/docker-entrypoint.sh`
- Pattern: Add steps between `.initialized` check and `exec "$@"` (lines 4-24)
- Idempotency: Wrap in `.initialized` condition or use separate marker files
- Example: Both entrypoints currently install GSD inside the `.initialized` block

**New Base Dependencies:**
- Edit: Service Dockerfile (e.g., `ClaudeCode/Dockerfile`)
- Pattern: Add to `apt-get install -y` command in RUN block (lines 9-23)
- Cleanup: Include `rm -rf /var/lib/apt/lists/*` after install to keep image size down

**New Helper Script:**
- Create: `ClaudeCode/<action>.sh` or `OpenCode/<action>.sh`
- Pattern: 
  ```bash
  #!/bin/bash
  # Usage: ./<action>.sh <project_name> [<other_args>]
  export PROJECT_NAME=$1
  # ... docker-compose or docker exec logic ...
  ```
- Make executable: `chmod +x <action>.sh`
- Document in README.md

**Configuration Changes:**
- Edit: `ClaudeCode/docker-compose.yml` or `OpenCode/docker-compose.yml`
- Pattern: Modify service config (ports, volumes, environment, command)
- Volume binding (ClaudeCode): Use `${PROJECT_PATH}:/home/sandbox` pattern for host binding
- Volume binding (OpenCode): Update hardcoded example path or parameterize via env vars

## Special Directories

**Volume Bind Target (`/home/sandbox` inside container):**
- Purpose: Container's home directory, bind-mounted from host at runtime
- Generated: No (created by container OS)
- Committed: No (host-side files, not repo)
- Contents: Project source, `.claude/` config, `.initialized` marker, developer files
- Lifecycle: Persists on host after container stops; survives container restarts if host folder unchanged

**Image Layer Cache:**
- Purpose: Cached Docker build layers
- Generated: Yes (by `docker build` during image construction)
- Committed: No (local Docker daemon, not in git)
- Lifecycle: Survives container stop/start; invalidated by `docker-compose build --no-cache`

**.planning/codebase/**
- Purpose: Analysis and reference documentation
- Generated: Yes (by GSD's map-codebase command)
- Committed: Yes (should be committed to repo for team visibility)
- Lifecycle: Updated when `/gsd-map-codebase` is run; tracks architecture decisions

## Initialization Sequence (First Container Start)

**1. Build Phase (on first `cc-up.sh`):**

```
ClaudeCode/Dockerfile
  → Base ubuntu:latest
  → Install system packages (curl, git, Node.js, gh)
  → Download and copy Claude CLI to /usr/local/bin
  → Copy docker-entrypoint.sh to /usr/local/bin
  → Create sandbox user
  → Set WORKDIR /home/sandbox
  → Set ENTRYPOINT /usr/local/bin/docker-entrypoint.sh
  → Set CMD /bin/bash
```

**2. Start Phase (on `docker-compose up`):**

```
docker-compose creates container:
  → Mounts PROJECT_PATH as /home/sandbox
  → Runs ENTRYPOINT: /usr/local/bin/docker-entrypoint.sh
  → Execs CMD: /bin/bash
```

**3. Entrypoint Execution (first run):**

```
docker-entrypoint.sh (runs as sandbox user)
  → Check if /home/sandbox/.initialized exists
  → Not found (first run)
  → Run: npx -y @opengsd/gsd-core@latest --claude --global
  → GSD downloads and installs into ~/.claude/
  → Touch /home/sandbox/.initialized
  → exec /bin/bash (keeps shell alive)
```

**4. Developer Usage:**

```
./cc-bash.sh myproj
  → Opens interactive shell in running container
Developer runs: claude
  → Claude CLI loads GSD from ~/.claude/
  → /gsd-* commands available
```

**5. Subsequent Starts (if container stopped, then restarted):**

```
docker-compose up
  → Reuses existing image
  → Mounts same volume
  → Runs entrypoint
  → Check /home/sandbox/.initialized (exists)
  → Skip install
  → exec /bin/bash
  (No reinstall happens)
```

## File Path References

**ClaudeCode Image Binary Path:**
- Claude CLI: `/usr/local/bin/claude` (in image, survives bind mount)

**Mounted Home Paths (inside container):**
- Home directory: `/home/sandbox` (bind-mounted from host)
- GSD config: `/home/sandbox/.claude/` (persists on host)
- Initialization marker: `/home/sandbox/.initialized` (persists on host)
- Project source: `/home/sandbox/` (same as home, from host)

**OpenCode Installation Paths (inside container):**
- Local binaries: `~/.local/bin/` (added to PATH by entrypoint)
- OpenCode config: `~/.opencode/bin` (referenced in Dockerfile PATH, line 25)
- Initialization marker: `/home/sandbox/.initialized`

**Host Paths (from developer's perspective):**
- ClaudeCode directory: `/path/to/GetShitDoneContainer/ClaudeCode/`
- OpenCode directory: `/path/to/GetShitDoneContainer/OpenCode/`
- Project sandbox: Developer-chosen path passed to `cc-up.sh` (e.g., `/Users/you/myproject/`)

---

*Structure analysis: 2026-09-30*
