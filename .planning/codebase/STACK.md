---
last_mapped_commit: 304f80d1a0705d9ab668ef2ed4acd9fcf65060ac
last_mapped_at: 2026-09-30
---
# Technology Stack

**Analysis Date:** 2026-09-30

## Languages

**Primary:**
- Bash - Shell scripting for container entrypoints and helper scripts (`docker-entrypoint.sh`, `cc-up.sh`, `cc-bash.sh`, `cc-down.sh`)

**Secondary:**
- YAML - Docker Compose configuration files

## Runtime

**Environment:**
- Docker & Docker Compose - Containerization platform for isolated environments
- Ubuntu Linux (ubuntu:latest) - Base OS for both ClaudeCode and OpenCode containers

**Package Manager:**
- npm (Node Package Manager) - Installed via NodeSource for ClaudeCode container
- Node.js 20 - JavaScript runtime for ClaudeCode container only
- Node.js (generic) - Installed in OpenCode container without explicit version

## Frameworks

**CLI Tools:**
- Claude Code CLI - Installed from `https://claude.ai/install.sh` into ClaudeCode container (`/usr/local/bin/claude`)
- GitHub CLI (gh) - Installed from GitHub's package repository in ClaudeCode container for git operations
- OpenCode CLI - Installed from `https://opencode.ai/install` in OpenCode container

**GSD (Get Shit Done):**
- @opengsd/gsd-core - Installed into ClaudeCode container via `npx -y @opengsd/gsd-core@latest --claude --global`
- get-shit-done-cc - Installed into OpenCode container via `npx -y get-shit-done-cc --opencode --global`

## Key Dependencies

**Critical Infrastructure Packages:**
- curl - Used for downloading installation scripts and binaries
- ca-certificates - Required for HTTPS/TLS connections
- git - Version control client for repository operations
- wget - Alternative download tool for GPG keyrings
- gpg - GPG signature verification for GitHub CLI

## Configuration

**Environment Variables:**
- `PROJECT_NAME` - Name identifier for the Docker project (used in docker-compose container naming)
- `PROJECT_PATH` - Host filesystem path to mount as `/home/sandbox` inside container (sandbox working directory)
- `PATH` - Extended in OpenCode container to include `/home/sandbox/.opencode/bin`

**Build Configuration:**
- `Dockerfile` - Container image definition for ClaudeCode (`ClaudeCode/Dockerfile`) and OpenCode (`OpenCode/Dockerfile`)
- `docker-compose.yml` - Service orchestration in both `ClaudeCode/docker-compose.yml` and `OpenCode/docker-compose.yml`

**Initialization:**
- `.initialized` - Marker file in mounted home directory (`/home/sandbox/.initialized`) that gates first-run setup
  - Prevents re-installation of GSD and other tools on container restart
  - Deleted on host to force fresh install

## Platform Requirements

**Development:**
- Docker Engine and Docker Compose installed on host machine
- Linux, macOS, or Windows (with Docker Desktop)
- Sufficient disk space for container images and mounted project volumes

**Production/Usage:**
- Deployment target: Docker containers running on any Docker-capable host
- Container images built from Ubuntu base
- Network access required for:
  - Installation scripts (claude.ai, opencode.ai, GitHub, npm registry)
  - GitHub API (via GitHub CLI for gh commands)
  - Claude API (via Claude Code CLI)

## Mount Points & Volumes

**ClaudeCode Container:**
- `/home/sandbox` - Mounted from host via `${PROJECT_PATH}` volume binding
- `/home/sandbox/.claude` - Contains Claude credentials and GSD installation (populated at runtime by entrypoint)
- `/home/sandbox/.initialized` - Marker file for first-run initialization

**OpenCode Container:**
- `/home/sandbox` - Mounted from host (currently hardcoded to `/Users/demian/GSD_StaticSiteGenerator` in compose file)
- `/home/sandbox/.local/bin` - Added to PATH for opencode-ai CLI

---

*Stack analysis: 2026-09-30*
