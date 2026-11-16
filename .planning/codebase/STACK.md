---
last_mapped_commit: 031448ea8249fe34f6bd172818ba1c2807eaed35
last_mapped_at: 2026-11-16
---
# Technology Stack

**Analysis Date:** 2026-11-16

## Languages

**Primary:**
- Bash 3.2+ (POSIX compatible): Shell scripts for container entrypoints, build orchestration, host CLI wrappers, test harnesses; runs on macOS and Linux
- Python 3.12+: Selfcheck framework for validating container setup; tests via pytest

**Secondary:**
- YAML: Docker Compose service definitions and Dockerfile linting configuration
- Dockerfile: Multi-stage container image definitions for base, Claude agent, and Cursor agent images
- JavaScript/Node.js: Runtime for CLI tools installed via npm; no source code (executables only)

## Runtime

**Environment:**
- Docker Engine and Docker Compose: Container orchestration and service definition
- Ubuntu 24.04: Base Linux distribution for all container images; specified by SHA-256 pinned digest in `versions.env`

**Package Managers:**
- npm: JavaScript package manager bundled with Node.js; manages GSD Core, Claude Code, and ccusage CLI tools
- uv: Python package manager and runtime manager; v0.12.21; installed in base image via container copy from official image
- Lockfile: `versions.env` contains all tool version pins; no package-lock.json or similar

## Frameworks

**Testing:**
- pytest 9.2.0: Unit testing framework for Python selfcheck modules and integration tests
- uv run pytest: Test runner; configured in `pyproject.toml` with no cache provider

**Build/Dev:**
- Docker multi-stage builds: Base image (`sbx-base`) layered with agent-specific configurations (`sbx-claude`, `sbx-cursor`)
- Dockerfile with BuildKit cache mounts: Optional certificate injection during build via bind mounts
- shell linting with shellcheck v0.11.0: Guard tests validate shell script syntax
- Dockerfile linting with hadolint v2.15.1: Guard tests validate Dockerfile correctness

## Key Dependencies

**Critical (Pinned):**
- Node.js 24.21.0: JavaScript runtime for all npm-installed CLIs; downloaded from nodejs.org and verified against SHASUMS256.txt
- GitHub CLI (gh) v2.102.0: Git operations, GitHub API access; downloaded from cli/cli releases and verified against checksums
- Apache Maven 3.9.11: Java project build tool; from Maven Central; note: v3.9.12+ fails on Docker Desktop mounts
- JDK 21 (Temurin) 21.0.12_8: Java runtime; copied from eclipse-temurin:21.0.12_8-jdk-noble image
- @opengsd/gsd-core 1.15.0: GSD CLI framework; installed via npm globally into base image
- uv 0.12.21: Python package manager; copied as binary from official uv image
- shellcheck v0.11.0: Static analysis for shell scripts; copied as binary from official image
- hadolint v2.15.1: Dockerfile linter; copied as binary from official image

**Infrastructure (Agent-Specific):**
- @anthropic-ai/claude-code 2.1.285: Claude Code CLI; installed in `sbx-claude` image only
- ccusage 20.0.26: Usage analytics tool for Claude; installed in `sbx-claude` image only
- cursor-agent 2026.11.11-b912975: Cursor IDE agent CLI; installed in `sbx-cursor` image only
- `get-shit-done-cc`: the old GSD package; never used (it was compromised); GSD comes only from `@opengsd/gsd-core`

**System packages (apt):**
- ca-certificates: TLS certificate store; extended with optional custom root certificates
- curl, wget: Download tools for fetching binaries and checksums
- git: Version control; configured with safe.directory='*' for macOS mount compatibility
- jq: JSON processor for parsing and reporting
- ripgrep: Fast file search
- procps, xz-utils, zip, unzip: Utilities for process info, compression, and archive handling
- openssh-client: SSH client for git operations
- make, build-essential: Compilation toolchain for native modules
- less: Pager for command output
- tzdata: Timezone database
- python3, python3-venv, python3-pip: Python runtime and packaging tools

## Configuration

**Environment:**
- `versions.env`: Single source of truth for all tool version pins; sourced by `build.sh`; no defaults for any pin
- `.python-version`: Python version hint (3.12) for uv
- `pyproject.toml`: Python project metadata; requires Python 3.12+; pytest configured with testpaths, pythonpath (includes selfcheck modules), and no cache provider
- `.dockerignore`: Files excluded from Docker build context
- `.hadolint.yaml`: Hadolint configuration
- `.shellcheckrc`: Shellcheck configuration for bash linting

**Build:**
- `build.sh`: Main build orchestration; reads `versions.env`, collects pins, optionally injects extra CA certificates, builds three images in sequence
- `Dockerfile` (base): Shared base layer; installs system packages, downloads and verifies all tools, sets up `sandbox` user (UID 1000), creates mount point
- `Dockerfile` (claude): Claude-specific layers; installs Claude Code and ccusage; links home directories to persistent state folders
- `Dockerfile` (cursor): Cursor-specific layers; installs cursor-agent CLI; links home directories to persistent state folders
- `docker-compose.yml`: Service definition; accepts `SBX_NAME`, `SBX_DIR`, `SBX_AGENT`, `SBX_IMAGE_TAG` environment variables; binds single host folder to `/home/sandbox/workspace`

**Container Startup:**
- `sbx-entrypoint` (shell script): Root-owned init script; sources `sbx-start-lib.sh`; runs start hooks in `/etc/sbx/start.d/` in name order; execs CMD
- Start hooks in `/etc/sbx/start.d/`:
 ; Base image: no hooks
 ; Claude image: 05-gsd (syncs GSD from @opengsd/gsd-core), 10-bundle (sets up best-practices repository links), 20-settings (manages Claude Code settings)
 ; Cursor image: 05-gsd, 10-bundle, 15-auto-update-off (disables self-update), 20-settings (Cursor-specific settings)
- `.initialized` marker file: Idempotency guard; prevents repeated setup of mounted home directory

## Platform Requirements

**Development:**
- macOS or Linux host with Docker Desktop or Docker Engine
- BSD sed and grep (macOS); shell scripts tested on both BSD and GNU variants
- Bash 3.2+ (POSIX compatible)

**Production/Container:**
- Docker image run target: any Docker-capable host with Docker Compose
- CPU architecture support: x86_64 (amd64) and arm64 (detected at build time; handled per tool)
- Minimum memory: 4GB (not enforced; recommended)
- Network access required for: Node.js downloads, Maven Central, npm registry, GitHub, cursor downloads, optional custom CA certificate

**Smoke Tests (at image build time):**
- Node version matches `NODE_VERSION` pin
- GSD runtime identity matches `GSD_CORE_VERSION` pin
- GitHub CLI version matches `GH_VERSION` pin
- Maven version matches `MAVEN_VERSION` pin
- Temurin JDK detected in Java version output
- uv and python3 versions printable without error
- shellcheck and hadolint binaries present and runnable
- Mount point `/home/sandbox/workspace` is empty before final RUN (no files leaked from build)

---

*Stack analysis: 2026-11-16*
