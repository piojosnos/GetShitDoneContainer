---
last_mapped_commit: 304f80d1a0705d9ab668ef2ed4acd9fcf65060ac
last_mapped_at: 2026-09-30
---
# Testing Patterns

**Analysis Date:** 2026-09-30

## Test Framework

**Runner:**
- No automated test framework present (Jest, Vitest, pytest, etc. not used)
- This is an infrastructure repository (Docker, shell scripts, docker-compose configs)
- Testing is manual and documentation-based

**Test Location:**
- No dedicated test directory (`__tests__`, `tests/`, `spec/`) found
- Tests are implicitly documented in `README.md` and inline script validation

**Run Commands:**

```bash

# Manual verification steps from ClaudeCode/README.md:

./cc-up.sh myproj /path/to/project     # Start container
./cc-bash.sh myproj                    # Attach shell
docker ps -a                           # Verify container running
docker logs cc_gsd_myproj              # Check entrypoint output
ls ~/.claude                           # Verify GSD installed (inside container)
```

## Test File Organization

**Location:**
- No test files (infrastructure is self-validating through entrypoint and docker-compose)

**Naming:**
- Not applicable

**Structure:**
- Not applicable

## Verification Strategy

**Manual Smoke Tests:**

The repository uses a documentation-driven verification approach. The README.md contains the definitive test cases:

1. **Container startup** (`README.md` lines 18-31):
   ```bash
   ./cc-up.sh ssg /Users/demian/GSD_StaticSiteGenerator/
   docker ps -a  # Verify container is running
   ```
   Expected: Container appears in `docker ps` output with status `Up`

2. **Shell attachment** (`README.md` lines 33-38):
   ```bash
   ./cc-bash.sh myproj  # Attach shell
   ```
   Expected: Interactive bash prompt appears in running container

3. **Container cleanup** (`README.md` lines 42-46):
   ```bash
   ./cc-down.sh myproj
   ```
   Expected: Container is stopped and removed, volumes destroyed (`-v` flag)

4. **GSD Installation** (ClaudeCode/README.md lines 128-138):
   - Check within container: `ls ~/.claude/get-shit-done` and `ls ~/.claude/skills/gsd-*`
   - Verify GSD commands load in Claude Code: `/gsd:*` commands available
   - Troubleshoot via entrypoint logs: `docker logs cc_gsd_myproj`

## Entrypoint Self-Validation

**ClaudeCode entrypoint** (`docker-entrypoint.sh`):

```bash
if [ ! -f /home/sandbox/.initialized ]; then
    # Setup runs once
    npx -y @opengsd/gsd-core@latest --claude --global
    touch /home/sandbox/.initialized
fi
exec "$@"  # Pass through to main command
```

**Self-validation mechanisms:**
- Marker file `.initialized` prevents re-running setup (idempotent)
- `npx -y` fetch from npm registry; failure causes container startup to fail (exit code non-zero)
- `set -e` in entrypoint propagates errors (line 2)
- `exec "$@"` passes through to main CMD so container fails if exec fails

**OpenCode entrypoint** (`OpenCode/docker-entrypoint.sh`):

```bash

# Additional validation: PATH setup and logging

echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/sandbox/.bashrc
chmod 755 /home/sandbox/.bashrc
curl -fsSL https://opencode.ai/install | bash >> log 2>&1
npx -y get-shit-done-cc --opencode --global >> log 2>&1
```

**Validation:**
- Logs output to `log` file for post-run inspection
- `chmod 755` ensures shell profile is readable (permission validation)

## Integration Points

**Docker Compose Validation** (`docker-compose.yml`):

The docker-compose configuration validates:
- Volume mounting: host path binds correctly to `/home/sandbox` in container
- Terminal allocation: `stdin_open: true` and `tty: true` allow interactive shells
- Container naming: `container_name: cc_gsd_${PROJECT_NAME}` constructs valid name
- Command execution: CMD or custom command runs after entrypoint

**Expected outcome:** Container starts, entrypoint runs, GSD installs (if fresh), command executes.

## Upgrade Path Validation

**From ClaudeCode/README.md (lines 71-95):**

Routine upgrade test case:

```bash
./cc-down.sh myproj
rm -f /Users/you/path/to/project/.initialized
./cc-up.sh myproj /Users/you/path/to/project
./cc-bash.sh myproj
```

**Validation:**
- `.initialized` marker file cleared → entrypoint re-runs
- GSD installer upgrades in place (no `.claude/get-shit-done` wipe needed)
- Claude login persists (`.claude.json` and `.credentials.json` untouched)
- Marker file recreated → idempotency works

**Full reset test case** (lines 108-118):

```bash
rm -rf /Users/you/path/to/project/.claude /Users/you/path/to/project/.initialized
./cc-up.sh myproj /Users/you/path/to/project
./cc-bash.sh myproj
claude  # Re-login happens
```

**Validation:**
- Entire `.claude` directory deleted
- Fresh GSD install occurs
- Claude CLI prompts for login (user interaction required)

## Known Test Gaps

**Areas without automated testing:**
- Dockerfile layer optimization (no build performance benchmarks)
- GPG key fetch reliability (no retry logic for GitHub CLI installation)
- Multi-architecture builds (Dockerfile assumes single platform)
- Network failure scenarios (npx registry failures not handled gracefully)
- Container resource limits (no CPU/memory constraint testing)
- Volume permission inheritance (bind mounts may have host/container permission mismatches)

**Manual verification recommended for:**
- First-time setup on new host
- After Dockerfile changes (build locally, verify entrypoint output)
- Before upgrading GSD or Claude version

## CI/CD Integration

**Status:** No CI/CD pipeline present

- No GitHub Actions workflows (`.github/workflows/` not present)
- No GitLab CI configuration
- No automated builds or deployments
- No containerization in CI environment

**Recommended CI testing approach:**
- Build Dockerfile locally: `docker build -t cc-code:test .`
- Run smoke tests: start container, verify GSD installs, verify CLI available
- Check entrypoint logs for errors
- Validate volume mount behavior

## Error Scenarios

**Docker startup fails:**
- Check entrypoint logs: `docker logs <container_name>`
- Verify network access for `curl` and `npx` commands
- Ensure host path is readable (volume permission issue)

**GSD commands not found:**
- Check GSD installed: `docker exec -it <container> ls ~/.claude/get-shit-done`
- Restart Claude CLI (loads skills at startup)
- Force reinstall: delete `.initialized` and restart container

**Shell access fails:**
- Verify container is running: `docker ps`
- Check for tty issues: `docker logs <container>`
- Ensure stdin/stdout not redirected

---

*Testing analysis: 2026-09-30*
