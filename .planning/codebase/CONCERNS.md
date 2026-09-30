---
last_mapped_commit: 304f80d1a0705d9ab668ef2ed4acd9fcf65060ac
last_mapped_at: 2026-09-30
---
# Codebase Concerns

**Analysis Date:** 2026-09-30

## Tech Debt

### Floating Docker Image Tags

**Issue:** Both `ClaudeCode/Dockerfile` and `OpenCode/Dockerfile` use `FROM ubuntu:latest` without version pinning.

**Files:** 
- `ClaudeCode/Dockerfile:1`
- `OpenCode/Dockerfile:1`

**Impact:** 
- Builds created at different times will have different base OS versions
- No reproducible builds across team members or CI/CD environments
- Security patches or breaking changes in Ubuntu could silently affect production containers

**Fix approach:** Pin to a specific Ubuntu version (e.g., `ubuntu:22.04` or `ubuntu:24.04`) with clear documentation of why that version was chosen and a schedule for upgrades.

### Unversioned Package Installation

**Issue:** Both Dockerfiles install packages without version pinning:
- `ClaudeCode/Dockerfile:9` - `apt-get install -y curl ca-certificates git wget gpg`
- `OpenCode/Dockerfile:9` - `apt-get install -y curl nodejs npm`

**Files:**
- `ClaudeCode/Dockerfile:9`
- `OpenCode/Dockerfile:9`

**Impact:**
- APT upgrades could introduce breaking changes or security vulnerabilities
- Inconsistent behavior across different build times
- Difficult to debug version-specific issues

**Fix approach:** Pin critical packages to specific versions using `apt-get install -y package=version` syntax. At minimum, pin Node.js version in OpenCode.

### Internet-Sourced Install Scripts Without Checksums

**Issue:** Both Dockerfiles download and execute shell scripts directly from the internet without signature verification:
- `ClaudeCode/Dockerfile:38` - `curl -fsSL https://claude.ai/install.sh | bash`
- `ClaudeCode/Dockerfile:11` - `curl -fsSL https://deb.nodesource.com/setup_20.x | bash`
- `OpenCode/docker-entrypoint.sh:14` - `curl -fsSL https://opencode.ai/install | bash`

**Files:**
- `ClaudeCode/Dockerfile:38, 11`
- `OpenCode/docker-entrypoint.sh:14`

**Impact:**
- Vulnerable to man-in-the-middle attacks if HTTPS is compromised
- No way to verify the script hasn't been tampered with or changed unexpectedly
- Could execute arbitrary code from untrusted sources

**Fix approach:** 
- Download scripts and verify checksums before execution
- Store verified installation scripts in the repository
- Use signed releases from package managers where available
- Consider using package managers instead of shell script installs

## Known Bugs

### Hardcoded User Path in OpenCode

**Issue:** `OpenCode/docker-compose.yml:10` contains a hardcoded absolute path to a specific user's project.

**Files:** `OpenCode/docker-compose.yml:10`

**Trigger:** The service definition reads:

```yaml
volumes:
  - /Users/demian/GSD_StaticSiteGenerator:/home/sandbox

```

**Symptoms:**
- Container will fail to start on any machine that doesn't have this exact path
- Binds to a specific user's directory without parameterization
- Cannot be reused by other team members

**Workaround:** Manually edit `docker-compose.yml` to the correct path, or use the parameterized approach from `ClaudeCode/docker-compose.yml`.

### Missing cc-upgrade.sh Script

**Issue:** `README.md` (lines 53, 72-103) documents a `cc-upgrade.sh` script that does not exist in the repository.

**Files:** 
- `README.md:53` (documented in usage table)
- `README.md:72-103` (upgrade section)
- Missing from `/ClaudeCode/`

**Symptoms:**
- Users following README instructions will get "command not found" error
- Documented workflow cannot be completed as written

**Workaround:** Users must manually execute the steps documented in the README (stop container, delete `.initialized`, restart container).

### Inconsistent GSD Package Distribution

**Issue:** `ClaudeCode/docker-entrypoint.sh:17` uses `@opengsd/gsd-core@latest` while `OpenCode/docker-entrypoint.sh:17` uses `get-shit-done-cc`.

**Files:**
- `ClaudeCode/docker-entrypoint.sh:17` (correct)
- `OpenCode/docker-entrypoint.sh:17` (potentially incorrect)

**Symptoms:** According to security notes in `README.md:41-44`, `get-shit-done-cc` (from `github.com/gsd-build`) is the **old compromised package** and should not be used.

**Fix approach:** Update `OpenCode/docker-entrypoint.sh:17` to use `@opengsd/gsd-core@latest` like ClaudeCode, and document why this change was made.

## Security Considerations

### Compromised Package Risk in OpenCode Setup

**Risk:** `OpenCode/docker-entrypoint.sh:17` installs the old compromised GSD package (`get-shit-done-cc`).

**Files:** `OpenCode/docker-entrypoint.sh:17`

**Current mitigation:** README explicitly warns against this (lines 41-44), but the code does it anyway.

**Recommendations:**
- Update to `@opengsd/gsd-core@latest`
- Add a comment referencing the security issue
- Consider adding a git hook or CI check to prevent reintroduction

### Personal User Directory Exposure

**Risk:** Hardcoded path `/Users/demian/GSD_StaticSiteGenerator` in `OpenCode/docker-compose.yml:10` exposes a specific user's file system.

**Files:** `OpenCode/docker-compose.yml:10`

**Current mitigation:** Only affects local development machines.

**Recommendations:**
- Parameterize like `ClaudeCode` version
- Use environment variables with `.env` file (gitignored)
- Document in `.env.example` (if added)

### Unverified Script Downloads

**Risk:** Installation scripts are downloaded over HTTPS but not cryptographically verified before execution.

**Files:** 
- `ClaudeCode/Dockerfile:11, 38`
- `OpenCode/docker-entrypoint.sh:14`

**Current mitigation:** HTTPS provides transport security but not content verification.

**Recommendations:**
- Publish checksums for install scripts
- Verify before execution: `curl ... | sha256sum -c -`
- Pin script versions in URLs if available
- Consider vendoring critical scripts in the repository

## Performance Bottlenecks

### Large Base Image Size

**Issue:** `ubuntu:latest` is a full OS image (~75MB+) when lightweight alternatives exist.

**Files:** 
- `ClaudeCode/Dockerfile:1`
- `OpenCode/Dockerfile:1`

**Problem:** Slower pulls, larger storage footprint, larger attack surface.

**Improvement path:** Consider `ubuntu:24.04-minimal` or `debian:bookworm-slim` for reduced image size, or Alpine if Node.js requirements allow it.

### NPX Download on Every First Run

**Issue:** `ClaudeCode/docker-entrypoint.sh:17` and `OpenCode/docker-entrypoint.sh:17` use `npx -y` which downloads packages on first run.

**Files:**
- `ClaudeCode/docker-entrypoint.sh:17`
- `OpenCode/docker-entrypoint.sh:17`

**Cause:** `npx` fetches from npm registry every time (even with `-y`), adding network latency to container startup.

**Improvement path:** 
- Pre-download and cache npm packages in the image
- Use `npm install -g` with pinned versions instead of `npx -y`
- Document expected startup time for first-run setup

## Fragile Areas

### Shell Script Argument Handling

**Component:** Helper scripts (`cc-up.sh`, `cc-bash.sh`, `cc-down.sh`)

**Files:** 
- `ClaudeCode/cc-up.sh`
- `ClaudeCode/cc-bash.sh`
- `ClaudeCode/cc-down.sh`

**Why fragile:** 
- No validation of `PROJECT_NAME` or `PROJECT_PATH` arguments
- Empty or special-character-containing values will cause unexpected behavior
- Script will silently proceed with invalid arguments

**Safe modification:** Add input validation at the start of each script:

```bash
if [ -z "$1" ]; then
  echo "Error: PROJECT_NAME required"
  exit 1
fi
```

**Test coverage:** No tests exist for these scripts; they're only manually tested.

### Docker Entrypoint Initialization Logic

**Component:** First-run setup via `.initialized` marker file

**Files:**
- `ClaudeCode/docker-entrypoint.sh:14-21`
- `OpenCode/docker-entrypoint.sh:5-22`

**Why fragile:**
- Deletion of `.initialized` during a long-running container will NOT re-run setup (only on new container start)
- No atomic check-and-set operation; race condition possible if container is started twice simultaneously
- Network failure during GSD install leaves `.initialized` missing but partial install state

**Safe modification:**
- Use a lockfile or temporary marker during setup
- Verify installation success before marking `.initialized`
- Add rollback logic if installation fails midway

**Test coverage:** Untested; behavior only verified manually.

### Inconsistent Package Sets Across Containers

**Component:** APT package installation differences

**Files:**
- `ClaudeCode/Dockerfile:9` (includes git, wget, gpg, ca-certificates)
- `OpenCode/Dockerfile:9` (only curl, nodejs, npm)

**Why fragile:** 
- Scripts or user workflows that assume git/wget/gpg availability will fail silently in OpenCode container
- Difficult to debug when behavior differs between container types

**Safe modification:** Align package sets or document why they differ explicitly.

## Missing Critical Features

### Missing Upgrade Script

**Feature gap:** Documented `cc-upgrade.sh` script is missing.

**Blocks:** Users cannot follow the documented "routine GSD upgrade" workflow from `README.md:72-103`.

**Workaround exists:** Manual steps work, but the convenience script doesn't.

**Priority:** Medium - documented feature that users expect.

## Test Coverage Gaps

### No Tests for Shell Scripts

**Untested area:** All shell scripts (`cc-up.sh`, `cc-bash.sh`, `cc-down.sh`, docker entrypoints).

**Files:**
- `ClaudeCode/cc-*.sh`
- `ClaudeCode/docker-entrypoint.sh`
- `OpenCode/docker-entrypoint.sh`

**Risk:** 
- Argument errors go undetected
- Breaking changes to Docker commands aren't caught
- Environment variable handling bugs silently fail
- First-run initialization bugs only appear on fresh containers

**Priority:** High - entrypoint failures block users from using containers entirely.

### No Tests for Dockerfile Builds

**Untested area:** Docker image builds and layer caching behavior.

**Files:**
- `ClaudeCode/Dockerfile`
- `OpenCode/Dockerfile`

**Risk:**
- Package installation failures only discovered when building
- Security vulnerabilities in dependencies go undetected until runtime
- Build performance regressions (layer cache misses) not monitored

**Priority:** High - broken builds block the entire workflow.

### No Documentation of Expected Behavior

**Untested area:** Container startup behavior, GSD installation success criteria, expected failure modes.

**Files:** All Docker/compose files and entrypoints

**Risk:** Users can't distinguish between "still initializing" and "failed"—containers silently hang with unclear error states.

**Priority:** Medium - impacts user experience during first setup.

---

*Concerns audit: 2026-09-30*
