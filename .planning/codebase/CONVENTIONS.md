---
last_mapped_commit: 304f80d1a0705d9ab668ef2ed4acd9fcf65060ac
last_mapped_at: 2026-09-30
---
# Coding Conventions

**Analysis Date:** 2026-09-30

## Naming Patterns

**Files:**
- Shell scripts use lowercase with hyphens: `cc-up.sh`, `cc-bash.sh`, `cc-down.sh`
- Docker-related files follow standard naming: `Dockerfile`, `docker-compose.yml`, `docker-entrypoint.sh`
- Configuration files follow standard conventions: `.gitignore`, `.initialized` (marker files)

**Functions:**
- Shell functions use lowercase with hyphens for clarity
- No formal shell functions defined in provided scripts; scripts use command sequences

**Variables:**
- Environment variables use UPPERCASE with underscores: `PROJECT_NAME`, `PROJECT_PATH`, `PATH`
- Local shell variables use lowercase: `sandbox` (username)
- Variables are explicitly exported when needed for subprocesses: `export PROJECT_NAME=$1`

**Types:**
- No type system (shell scripts and Dockerfiles are dynamically typed)
- Docker image tags follow semantic conventions (e.g., `ubuntu:latest`)

## Code Style

**Formatting:**
- Shell scripts use consistent 2-space or 4-space indentation (ClaudeCode/cc-up.sh uses 4-space)
- Docker RUN commands chain with `&&` for layer optimization
- Line continuation uses backslash `\` for readability in Dockerfile
- Docker compose YAML uses 2-space indentation

**Linting:**
- No linting tools configured (bash linter, hadolint, yamllint not present)
- Code style is enforced through conventions in documentation

## Import Organization

**Order (Docker RUN statements):**
1. System package updates: `apt-get update`
2. System packages installation: `apt-get install -y`
3. Repository setup (keys, sources): GPG keys, PPA sources
4. Tool-specific installations: Node, GitHub CLI, Claude
5. Cleanup: `rm -rf /var/lib/apt/lists/*`

**Path Aliases:**
- Docker PATH extensions via ENV: `ENV PATH="/home/sandbox/.opencode/bin:$PATH"` (OpenCode/Dockerfile)
- System binaries placed in standard locations: `/usr/local/bin` for user-accessible tools

## Error Handling

**Patterns:**
- All critical shell scripts use `set -e` to exit on first error: `docker-entrypoint.sh`, `cc-up.sh`
- Marker file pattern for idempotent setup (`.initialized`):
  ```bash
  if [ ! -f /home/sandbox/.initialized ]; then
      # Setup runs once
      touch /home/sandbox/.initialized
  fi
  ```
- Exit status is checked implicitly by `set -e`; explicit error checking not used
- Commands that redirect output use `>> log 2>&1` to capture both stdout and stderr (OpenCode/docker-entrypoint.sh:14)

## Logging

**Framework:** POSIX `echo` for simple logging

**Patterns:**
- Info messages printed directly: `echo "Fresh home detected -- installing GSD into ~/.claude ..."`
- Completion messages echo status: `echo "GSD install complete."`, `echo "Environment setup complete!"`
- Errors are implicit (script exits via `set -e`)
- Verbose output captured in log file for non-critical operations: `>> log 2>&1` (OpenCode entrypoint)

## Comments

**When to Comment:**
- Explain non-obvious design decisions (why something is placed here, not there)
- Document the rationale for complex sections
- Explain security implications (e.g., trusted package sources)
- Mark experimental or disabled code with `# XXX:` prefix

**Examples from codebase:**
- ClaudeCode/Dockerfile (lines 4-35): Multi-line comment block explaining installation strategy and mount behavior
- ClaudeCode/docker-entrypoint.sh (lines 4-13): Detailed comment explaining why GSD is installed in entrypoint, not Dockerfile
- ClaudeCode/Dockerfile (lines 41-47): `# XXX: Experimental` marks disabled code for future consideration

**JSDoc/TSDoc:**
- Not applicable (shell scripts, Dockerfiles, YAML; no TypeScript/JavaScript code)

## Function Design

**Size:** 
- Scripts are very small (1-8 lines), each doing a single task
- Example: `cc-up.sh` is 8 lines total, exports variables and calls docker-compose

**Parameters:**
- Passed as positional arguments: `$1`, `$2`
- Exported to environment when used by child processes: `export PROJECT_NAME=$1`
- Usage documented in comments: `# Usage: ./cc-up.sh <project_name> <host_path>`

**Return Values:**
- Scripts use exit codes implicitly via `set -e`
- Forward process exit via `exec "$@"` (docker-entrypoint.sh:24)
- Commands using pipes capture output implicitly: `curl ... | bash`

## Module Design

**Exports:**
- Environment variables explicitly exported: `export PROJECT_NAME`, `export PROJECT_PATH`
- No shared sourcing of helper scripts (each script is standalone)
- Entrypoint script is centralized in `/usr/local/bin/docker-entrypoint.sh`

**Barrel Files:**
- No barrel file pattern (not applicable to this infrastructure codebase)

## Docker-Specific Conventions

**Dockerfile Structure:**
- Clear section markers using comment blocks with dashes:
  ```dockerfile
  # --------...
  # [Section Name]
  # --------...
  ```
- Comments explain decisions above the RUN commands they describe (lines 4-9, 26-35)
- RUN commands chain with `&&` to reduce layer count
- Cleanup commands placed at end of RUN chain: `rm -rf /var/lib/apt/lists/*`
- USER and WORKDIR set near end of file, after tools are installed
- ENTRYPOINT specifies the script path; CMD can be overridden

**Docker Compose Structure:**
- Services section contains all service definitions
- Comments explain configuration options inline:
  ```yaml
  stdin_open: true   # keeps stdin open (like -i)
  tty: true          # allocates a pseudo-TTY (like -t)
  ```
- Environment variable substitution via `${VAR_NAME}`
- Volume mounts bind host paths to container paths
- Container naming follows pattern: `[prefix]_[suffix]_${PROJECT_NAME}`

## Version Management

**Docker Base Images:**
- Use latest stable tag: `ubuntu:latest` (ClaudeCode/Dockerfile, OpenCode/Dockerfile)
- NodeSource for Node 20: `setup_20.x` (ClaudeCode/Dockerfile:11)
- npm and nodejs installed from ubuntu repos (OpenCode/Dockerfile:9)

**Package Installation Methods:**
1. apt-get (system packages)
2. curl-based installers: `curl -fsSL https://... | bash` (Claude CLI, OpenCode CLI, uv)
3. npx for npm packages: `npx -y @opengsd/gsd-core@latest` (ClaudeCode/docker-entrypoint.sh:17)

---

*Convention analysis: 2026-09-30*
