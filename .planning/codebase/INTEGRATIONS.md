---
last_mapped_commit: 031448ea8249fe34f6bd172818ba1c2807eaed35
last_mapped_at: 2026-11-16
---
# External Integrations

**Analysis Date:** 2026-11-16

## APIs & External Services

**Node.js Downloads:**
- nodejs.org: Official source for Node.js LTS binaries
- Service: `https://nodejs.org/dist/v${NODE_VERSION}/` (e.g., v24.21.0)
- Verification: SHA256 checksums from `SHASUMS256.txt`
- Architecture support: Detects amd64 or arm64 at build time; downloads appropriate binary

**GitHub API & Version Control:**
- GitHub CLI (gh): Enables git operations and GitHub API access
 ; Service: GitHub at `https://github.com/cli/cli/releases/` for CLI downloads
 ; Verification: Checksums from `gh_${GH_VERSION}_checksums.txt` (e.g., v2.102.0)
 ; Authentication: `sbx-gh-login` command in `/home/sandbox/workspace/state/gh/` (stored on host mount)
 ; Used by: `sbx-gh-login`, host test scripts, agent workflows

**Maven Artifact Repository:**
- Maven Central: Java dependency and build tool repository
- Service: `https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/`
- Maven tool: v3.9.11 (pinned; v3.9.12+ fails on Docker Desktop mounts)
- Verification: SHA-512 checksums from Maven Central
- Repository: Mounted at `/home/sandbox/.m2` (linked to `~/.m2`) for persistent caching

**npm Package Registry:**
- npm registry (default): Package manager for Node.js tools
- Packages installed globally:
 ; `@opengsd/gsd-core@${GSD_CORE_VERSION}` (1.15.0): GSD framework
 ; `@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}` (2.1.285): Claude Code CLI (Claude image only)
 ; `ccusage@${CCUSAGE_VERSION}` (20.0.26): Usage analytics (Claude image only)
- Cache location: `/home/sandbox/workspace/state/cache/npm` (mounted; survives rebuild)
- Config: `cafile=/etc/ssl/certs/ca-certificates.crt` in `/usr/local/etc/npmrc` (for optional CA certs)

**Cursor Downloads:**
- downloads.cursor.com: Vendor-hosted Cursor agent CLI releases
- Service: `https://downloads.cursor.com/lab/${CURSOR_AGENT_VERSION}/linux/${arch}/agent-cli-package.tar.gz` (e.g., 2026.11.11-b912975)
- Verification: Checksums from `.tar.gz.sha256` file
- Architecture support: x64 (amd64) or arm64 (detected at build time)
- Installation: Extracted to `/usr/local/lib/cursor-agent` (read-only to sandbox user)

**Official Docker Images (Base Layers):**
- eclipse-temurin: Java Development Kit
 ; Image: `eclipse-temurin:21.0.12_8-jdk-noble@sha256:...` (Temurin 21.0.12_8 on Ubuntu noble)
 ; Copied to: `/opt/java/openjdk` in base image

- ubuntu: Base OS
 ; Image: `ubuntu:24.04@sha256:...`
 ; Used as: Final base for all sbx images

- astral-sh/uv: Python package and runtime manager
 ; Image: `ghcr.io/astral-sh/uv:0.12.21@sha256:...`
 ; Binary copied to: `/usr/local/bin/`

- koalaman/shellcheck: Shell script linter
 ; Image: `koalaman/shellcheck:v0.11.0@sha256:...`
 ; Binary copied to: `/usr/local/bin/shellcheck`

- hadolint/hadolint: Dockerfile linter
 ; Image: `hadolint/hadolint:v2.15.1@sha256:...`
 ; Binary copied to: `/usr/local/bin/hadolint`

## Data Storage

**Databases:**
- None used; no persistent data store

**File Storage:**
- Local filesystem only; host-mounted at `/home/sandbox/workspace`
- Persistent state folders mounted from host:
 ; `.claude/` or `state/claude/`: Claude Code login, settings, skills, caches
 ; `state/cursor/`: Cursor IDE login, settings, skills
 ; `state/gh/`: GitHub CLI credentials and configuration
 ; `state/git/`: Git configuration (global)
 ; `state/cache/npm`: npm package cache
 ; `state/cache/uv`: uv package cache
 ; `state/m2/`: Maven repository (linked to `~/.m2`)
 ; `state/shell/bash_history`: Bash history

**Caching:**
- npm cache: `NPM_CONFIG_CACHE=/home/sandbox/workspace/state/cache/npm`
- uv cache: `UV_CACHE_DIR=/home/sandbox/workspace/state/cache/uv`
- Build-time only: `/tmp/npm-cache`, `/tmp/sbx-pycache` (throwaway)

## Authentication & Identity

**Git & GitHub:**
- Authentication provider: GitHub OAuth token (via `gh auth login`)
- Storage: `/home/sandbox/workspace/state/gh/` (symlinked from `~/.config/gh/`)
- Setup command: `sbx-gh-login [gh options]`: Interactive; stores token and prompts for git name/email
- Identity: git config stored in `/home/sandbox/workspace/state/git/config` (via `GIT_CONFIG_GLOBAL`)

**Claude Code:**
- Authentication: Managed by Claude Code itself via login flow
- Storage: `/home/sandbox/workspace/state/claude/` (symlinked from `~/.claude/`)
- Config directory: `CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude`
- Settings: Managed settings at `/etc/claude-code/managed-settings.json` (read-only to agent; prevents unmanaged edits to skill list)

**Cursor IDE:**
- Authentication: Managed by Cursor agent CLI
- Storage: `/home/sandbox/workspace/state/cursor/` (symlinked from `~/.cursor/` and `~/.config/cursor/`)
- Config directory: `CURSOR_CONFIG_DIR=/home/sandbox/workspace/state/cursor`
- Self-update: Disabled by start hook (not applicable for container-managed CLI)

## Monitoring & Observability

**Error Tracking:**
- None configured; not used

**Logs:**
- Bash scripts: Direct stdout/stderr output; captured in host test logs
- Python selfcheck: Prints PASS/FAIL to stdout; exit codes indicate overall status (0=all pass, 1=failure, 2=usage error)
- Container startup: Entrypoint logs visible via `docker logs sbx-${SBX_NAME}`
- Host mount: Bash history preserved at `/home/sandbox/workspace/state/shell/bash_history`
- Tool versions: Printed on shell startup from `/etc/sbx/tool-versions` (cat command added to `.bashrc`)

## CI/CD & Deployment

**Hosting:**
- Container deployment target: Any Docker-capable host (local development, CI/CD runner, etc.)
- Images: Built locally on macOS with `./build.sh`; pushed to no registry (local tags: `sbx-base:local`, `sbx-claude:local`, `sbx-cursor:local` or `test`)

**CI Pipeline:**
- Build: `./build.sh [options]` on macOS or Linux with Docker
- Optional: `SBX_CA_CERT=/path/to/cert.pem ./build.sh` for extra root certificate injection
- Optional: `SBX_IMAGE_TAG=test ./build.sh` for test tag
- Image tag defaults: `local` (development) or `test` (CI)

**Testing:**
- Guard tests in `tests/guard/`: Run in Docker container; validate build and runtime
- Host tests in `tests/host/`: Run on macOS host via `./host-test.sh`; validate container orchestration, isolation, mount behavior
- Selftest Python tests in `tests/selftest/selfcheck/`: Run via `uv run pytest` on development machine

## Environment Configuration

**Required env vars (build time):**
- All pins must be present in `versions.env` (no defaults; build stops if missing)
- Build ARGs passed via `build.sh`: `TEMURIN_IMAGE`, `UV_IMAGE`, `UBUNTU_IMAGE`, `SHELLCHECK_IMAGE`, `HADOLINT_IMAGE`, `NODE_VERSION`, `GH_VERSION`, `MAVEN_VERSION`, `GSD_CORE_VERSION`, `BUNDLE_REPO_URL`, `CLAUDE_CODE_VERSION`, `CCUSAGE_VERSION`, `CURSOR_AGENT_VERSION`

**Required env vars (runtime):**
- `SBX_NAME`: Sandbox name; passed by host scripts and docker-compose
- `SBX_DIR`: Host folder path; passed to docker-compose
- `SBX_AGENT`: Agent image name (claude or cursor); defaults to claude if unset
- `SBX_IMAGE_TAG`: Image tag (local or test); defaults to local if unset

**Set in container image (ENV directives):**
- `HISTFILE=/home/sandbox/workspace/state/shell/bash_history`
- `PROMPT_COMMAND="history -a"`: Write history after each command
- `GH_CONFIG_DIR=/home/sandbox/workspace/state/gh`
- `GIT_CONFIG_GLOBAL=/home/sandbox/workspace/state/git/config`
- `JAVA_HOME=/opt/java/openjdk`
- `NPM_CONFIG_CACHE=/home/sandbox/workspace/state/cache/npm`
- `UV_CACHE_DIR=/home/sandbox/workspace/state/cache/uv`
- `UV_LINK_MODE=copy`: uv copies files instead of symlinking (Windows/mount compatibility)
- `LANG=C.UTF-8`: UTF-8 locale
- `SBX_STATE_DIRS="cache/npm cache/uv m2"`: Base; appended by agent images
- `CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude` (Claude image only)
- `CURSOR_CONFIG_DIR=/home/sandbox/workspace/state/cursor` (Cursor image only)
- `DISABLE_UPDATES=1` (Claude image only)

**Secrets location:**
- No secrets baked into images
- All credentials stored in host-mounted `/home/sandbox/workspace/state/` folders
- Git token: `state/gh/hosts.yml` (GitHub CLI manages format)
- Custom CA certificates: Optional; mounted at build time via `SBX_CA_CERT` env var; stored in image at `/etc/sbx/extra-ca.pem` and individual `.crt` files in `/usr/local/share/ca-certificates/`

## Webhooks & Callbacks

**Incoming:**
- None configured

**Outgoing:**
- None; container images do not initiate outbound callbacks
- Agent (Claude Code or Cursor) may make outbound calls to GitHub, npm, or configured APIs based on user interactions

---

*Integration audit: 2026-11-16*
