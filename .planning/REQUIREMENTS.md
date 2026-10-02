# Requirements: GSD Agent Sandbox Containers

**Defined:** 2026-09-30
**Core Value:** Rebuilding the image must reliably deliver new or updated tools into a project sandbox without losing the agent's login, settings, or history, and without the host mount hiding anything the image provides.

## v1 Requirements

Requirements for this milestone (ClaudeCode sandbox made solid). Each maps to roadmap phases.

### Layout

- [ ] **LAY-01**: The sandbox folder `<sandbox>` is the container's only mount, at `/home/sandbox/workspace`; code lives in `<sandbox>/<name>` and state in `<sandbox>/state`. Nothing is mounted over `/home/sandbox`, so the image's `.bashrc`, `.local`, etc. are visible
- [ ] **LAY-02**: Claude login, settings, and session history live in `<sandbox>/state/claude` on the Mac (via `CLAUDE_CONFIG_DIR`, inside the one directory mount, never a single-file mount) and survive both container recreate and image rebuild
- [ ] **LAY-03**: Bash history persists in the sandbox state folder and survives container recreate
- [ ] **LAY-04**: Stopping, removing, or recreating a container never deletes workspace or state data (no `down -v`, no `VOLUME /home/sandbox`)

### Image

- [ ] **IMG-01**: A single shared base image provides common Linux tools, git, gh, Node.js 24, Python 3 + uv, JDK 21 (Temurin), and Maven
- [ ] **IMG-02**: The Claude image builds `FROM` the shared base and adds only agent-specific tools
- [ ] **IMG-03**: Every version (base OS tag, toolchains, Claude Code, GSD, ccusage) is pinned in one `versions.env`. No floating `latest` and no runtime installs
- [ ] **IMG-04**: Adding a new tool means editing one line (Dockerfile or `versions.env`) and rebuilding
- [ ] **IMG-05**: Images build and run natively on Apple Silicon (arm64) with Docker Desktop
- [ ] **IMG-06**: The agent runs as the non-root `sandbox` user, and git works on mounted repos without "dubious ownership" errors

### Agent Tools

- [ ] **TOOL-01**: Claude Code is installed at the pinned version with self-updating disabled. After a rebuild, `claude --version` matches the pin and there's no stray copy in `~/.local`
- [ ] **TOOL-02**: GSD comes only from `@opengsd/gsd-core` at the pinned version. On every container start, the image's GSD is synced into the persisted `~/.claude`, so the image version wins, and login and history are untouched
- [ ] **TOOL-03**: Container start needs no network access and runs no `npx`/`@latest` installs

### Usage Monitoring

- [ ] **USE-01**: The user can run `ccusage` (`daily`, `monthly`, `session`, …) in the container shell and see this project's real Claude usage

### Best Practices

The shared agent bundle: skills, standing rules (`AGENTS.md`, `code-conventions.md`), and memories.

- [ ] **BP-01**: The image ships the best-practices bundle (from the repo, not a runtime download) at a path outside every mount, so no host mount can hide it
- [ ] **BP-02**: On every container start, the bundle's skills and standing rules are synced into the persisted `~/.claude` (the image version wins), and its memories are seeded only if missing. Memories the agent learned, and the user's own `MEMORY.md` lines, are never overwritten. Start still needs no network
- [ ] **BP-03**: The bundle lives in its own git repo. Each sandbox keeps its own clone in its sandbox folder, so edits survive container recreate and image rebuild
- [ ] **BP-04**: From inside any sandbox, the user (or agent) can edit the bundle, commit on a branch, push, and open a PR against the bundle repo
- [ ] **BP-05**: A new sandbox starts with the latest bundle from git (a best-effort `git pull --ff-only` that never blocks an offline start), and a manual `git pull` in the clone updates a running sandbox

### Helper Scripts

Generic `sbx-*` scripts: short, plain bash, and runnable with macOS's stock bash.

- [ ] **SCR-01**: The user registers a sandbox once with `sbx-add <name> <host_path>` (the registry records an agent field, defaulting to `claude`). Every other script then takes only `<name>`
- [ ] **SCR-02**: The user can start and stop a sandbox by name
- [ ] **SCR-03**: One command rebuilds the base and agent images and recreates the sandbox, keeping login and history
- [ ] **SCR-04**: One command jumps into a sandbox: it starts the sandbox if needed, then opens a shell, optionally launching `claude` directly
- [ ] **SCR-05**: The user can list all registered sandboxes with their host path and running status
- [ ] **SCR-06**: The user can remove a sandbox's container (and optionally its registration) without touching its workspace or state
- [ ] **SCR-07**: Tool versions (Claude, GSD, ccusage, Node, JDK, Maven, Python) are printed after a rebuild and on shell entry
- [ ] **SCR-08**: The old `cc-*` scripts and the whole-home-mount layout are removed from the repo

### Documentation

- [ ] **DOC-01**: The README describes the new layout, scripts, and upgrade flow, and matches what's in the repo (no phantom `cc-upgrade.sh`)
- [ ] **DOC-02**: The README documents how to migrate an existing sandbox: move code into `<name>/`, move state (including `.claude.json`) into `state/claude`, and rename the history project path so old sessions still show up
- [ ] **DOC-03**: The README has a short threat-model section covering what's isolated, the credential-exfiltration risk under skip-permissions, and files the agent can plant that the Mac later executes (git hooks, IDE run configs)
- [ ] **DOC-04**: A host-side verification checklist exists for the Mac: login survives rebuild, versions match pins, ccusage works, home is not hidden

## v2 Requirements

Deferred. Tracked but not in the current roadmap.

### OpenCode

- **OC-01**: The OpenCode image builds on the shared base, using `@opengsd/gsd-core` (never `get-shit-done-cc`)
- **OC-02**: OpenCode state (auth, config, sessions) persists in `<sandbox>/state/opencode`
- **OC-03**: The `sbx-*` scripts work for OpenCode sandboxes through the registry's agent field

### Agents

- **AGT-01**: Adding another agent (Codex, Gemini, …) takes only a thin image plus an agent env file

### Usage

- **USE-02**: ccusage usage is aggregated across all project sandboxes

### Quality of Life

- **QOL-01**: Per-project named volume for the Maven `~/.m2` cache, so builds don't re-download after recreate
- **QOL-02**: `sbx-doctor` checks isolation (no docker.sock, only the expected mounts) and that versions match the pins

### Security

- **SEC-01**: Egress network allowlist (firewall) limits the container to the required hosts

## Out of Scope

| Feature | Reason |
|---------|--------|
| Several projects in one container | The model is one container per project, for isolation |
| Migration script | Only about 4 sandboxes. Documented manual steps first, script only if they prove painful |
| Runtime `install` commands and in-container self-updates (including `/gsd-update` inside a sandbox) | They break "image wins". Upgrades happen only by rebuilding. The one exception is the best-practices bundle (BP-05): it is config, not tools, and its pull is best-effort |
| One best-practices folder shared read-write by every sandbox | One sandbox could silently change what every other agent loads. Each sandbox keeps its own clone; changes reach the others only through a reviewed PR |
| Mounting docker.sock, host `~/.ssh`, host `~/.claude`, or the whole host home | Each would defeat the isolation that is the reason this project exists |
| Profiles, slots, layered config, CLI framework/TUI | Contradicts "small, plain bash scripts grown incrementally" |
| Old `get-shit-done-cc` / `gsd-build` GSD package | Compromised distribution. Never reintroduce it |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| LAY-01 | Phase 1 | Pending |
| LAY-02 | Phase 1 | Pending |
| LAY-03 | Phase 1 | Pending |
| LAY-04 | Phase 1 | Pending |
| IMG-01 | Phase 2 | Pending |
| IMG-02 | Phase 1 | Pending |
| IMG-03 | Phase 2 | Pending |
| IMG-04 | Phase 2 | Pending |
| IMG-05 | Phase 1 | Pending |
| IMG-06 | Phase 1 | Pending |
| TOOL-01 | Phase 2 | Pending |
| TOOL-02 | Phase 2 | Pending |
| TOOL-03 | Phase 2 | Pending |
| USE-01 | Phase 2 | Pending |
| BP-01 | Phase 1.1 | Pending |
| BP-02 | Phase 1.1 | Pending |
| BP-03 | Phase 2.1 | Pending |
| BP-04 | Phase 2.1 | Pending |
| BP-05 | Phase 2.1 | Pending |
| SCR-01 | Phase 3 | Pending |
| SCR-02 | Phase 3 | Pending |
| SCR-03 | Phase 3 | Pending |
| SCR-04 | Phase 4 | Pending |
| SCR-05 | Phase 4 | Pending |
| SCR-06 | Phase 4 | Pending |
| SCR-07 | Phase 3 | Pending |
| SCR-08 | Phase 5 | Pending |
| DOC-01 | Phase 5 | Pending |
| DOC-02 | Phase 5 | Pending |
| DOC-03 | Phase 5 | Pending |
| DOC-04 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 31 total
- Mapped to phases: 31
- Unmapped: 0 ✓

---
*Requirements defined: 2026-09-30*
*Last updated: 2026-10-02 after inserting Phases 1.1 and 2.1 (BP-01..BP-05)*
