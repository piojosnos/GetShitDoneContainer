---
last_mapped_commit: 304f80d1a0705d9ab668ef2ed4acd9fcf65060ac
last_mapped_at: 2026-09-30
---
# External Integrations

**Analysis Date:** 2026-09-30

## APIs & External Services

**Anthropic Claude API:**
- Claude Code CLI - Installed from `https://claude.ai/install.sh`
  - SDK/Client: Claude Code binary (`/usr/local/bin/claude`)
  - Auth: API key stored in `~/.claude.json` and `~/.claude/.credentials.json` (persisted in mounted home)
  - Usage: Core LLM interaction for Claude Code development environment

**GitHub:**
- GitHub CLI (gh) - Installed from GitHub's official package repository
  - SDK/Client: `gh` command-line tool
  - Auth: GitHub credentials managed by gh CLI (typically via `gh auth login`)
  - Purpose: Git operations, GitHub API access, repository management

**OpenCode (OpenAI-based):**
- OpenCode CLI - Installed from `https://opencode.ai/install`
  - SDK/Client: `opencode` command-line tool
  - Installation: Installed in OpenCode container only
  - Web Interface: Runs on port 4096 via `opencode web --hostname 0.0.0.0`
  - Purpose: Alternative code development interface with web UI

## Package Registries

**npm Registry:**
- @opengsd/gsd-core - GSD (Get Shit Done) framework for Claude Code
  - Installation command: `npx -y @opengsd/gsd-core@latest --claude --global`
  - Purpose: GSD skills, commands, and orchestration framework
  - Installed into: `~/.claude` directory structure

- get-shit-done-cc - OpenCode-specific GSD integration
  - Installation command: `npx -y get-shit-done-cc --opencode --global`
  - Purpose: GSD support for OpenCode environment
  - Installed into: `~/.local/bin` (OpenCode container)

## Data Storage

**Databases:**
- Not used - No persistent database integration detected

**File Storage:**
- Local filesystem only - All project work stored in mounted volume at container's `/home/sandbox`
- Host path mounted via `${PROJECT_PATH}` environment variable (set at runtime)

**Credential Storage:**
- Local files in mounted home:
  - `~/.claude.json` - Claude API credentials
  - `~/.claude/.credentials.json` - Claude authentication tokens
  - `~/.bashrc` - Shell environment setup (OpenCode container)
  - `~/.initialized` - First-run marker file

**Caching:**
- None detected - No explicit caching layer configured

## Authentication & Identity

**Auth Provider:**
- Multiple independent auth systems:
  - Claude Code: API key-based auth via `~/.claude.json` and `~/.claude/.credentials.json`
  - GitHub CLI: OAuth token-based auth managed by `gh` CLI
  - OpenCode: Credentials managed by opencode-ai CLI (implementation details not exposed)

**Implementation:**
- Credentials stored in mounted home directory, persisted across container restarts
- First-run setup installs CLI tools with auth configuration
- User runs `gh auth login` and Claude authentication separately after container starts

## Monitoring & Observability

**Error Tracking:**
- Bash error handling via `set -e` in entrypoint scripts (exits on first error)

**Logs:**
- Entrypoint installation logs redirected to `log` file: `npx ... >> log 2>&1` (OpenCode only)
- No centralized logging service configured
- Docker container stdout/stderr accessible via `docker logs`

## CI/CD & Deployment

**Hosting:**
- Docker containers (local Docker Engine or cloud providers supporting Docker)
- Container naming: `cc_gsd_${PROJECT_NAME}` for ClaudeCode, `oc_gsd_c` for OpenCode

**Container Orchestration:**
- Docker Compose used for service definition and startup
- Single-service configuration per container type
- No Kubernetes or advanced orchestration detected

**CI Pipeline:**
- Not configured - No CI/CD pipeline detected in this repository

## Environment Configuration

**Required env vars (ClaudeCode):**
- `PROJECT_NAME` - Project identifier for container naming
- `PROJECT_PATH` - Absolute host filesystem path to mount as sandbox

**Startup Scripts:**
- `ClaudeCode/cc-up.sh` - Brings up ClaudeCode container with project-specific configuration
- `ClaudeCode/cc-bash.sh` - Attaches bash shell to running container
- `ClaudeCode/cc-down.sh` - Stops and removes container

**Secrets location:**
- `.claude.json` and `.claude/.credentials.json` in mounted home
- GitHub credentials managed by `gh` CLI (location varies by system)
- OpenCode credentials stored by opencode-ai installation

**Important:** Environment files (`.env`) are not tracked and contain local configuration only. The system does not load `.env` files automatically in containers.

## Network Configuration

**Ports:**
- ClaudeCode container: No ports exposed (direct host mount for bash access)
- OpenCode container: Port 4096 exposed to host for web interface access

**Connection Requirements:**
- Internet access for initial installation scripts:
  - `https://claude.ai/install.sh`
  - `https://deb.nodesource.com` (Node.js repository)
  - `https://cli.github.com/packages` (GitHub CLI repository)
  - `https://opencode.ai/install`
  - npm registry for `npx` package installation

## Webhooks & Callbacks

**Incoming:**
- None detected

**Outgoing:**
- None detected

---

*Integration audit: 2026-09-30*
