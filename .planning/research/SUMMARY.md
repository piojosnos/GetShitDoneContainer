# Project Research Summary

**Project:** GSD Agent Sandbox Containers (restructure milestone)
**Domain:** Docker-based sandbox containers for AI coding agents (Claude Code + GSD + ccusage; OpenCode later) on macOS + Docker Desktop
**Researched:** 2026-09-30
**Confidence:** HIGH (Stack, Features, Architecture verified against official docs and live testing; Pitfalls empirically grounded)

## Executive Summary

This project redesigns Docker sandbox containers to isolate AI coding agents while preserving credentials, history, and GSD extensions across rebuild. The core insight is architectural: **never mount over the container home**. Instead, mount only code (`/home/sandbox/workspace`) and agent state (`/home/sandbox/.claude`) as separate directories, set `CLAUDE_CONFIG_DIR` to the state mount, and bake tools into a pinned base image. This fixes critical failures: login lost on rebuild, mounted home hides image tools, ccusage broken, GSD floating versions.

The recommended approach is five phases: (1) shared base image with pinned OS, Node 24, JDK 21, Maven, Python; (2) per-agent thin images (Claude Code 2.1.x, GSD 1.15.0, ccusage 20.x, all npm-pinned); (3) generic Compose with agent-agnostic mounts and `CLAUDE_CONFIG_DIR` Dockerfile `ENV`; (4) lifecycle scripts that remember sandbox names/paths and rebuild safely; (5) migration of ~4 existing sandboxes with careful handling of path-dependent history.

Main risks are architectural missteps during state/mount setup (Pitfalls 1–3: bind-mount mistakes, missing `CLAUDE_CONFIG_DIR`, GSD shadowing) and upgrade logic (Pitfalls 4, 5, 12: stale GSD, Claude auto-updater, runtime `npm install`). All are solved by decisions made in research; phases must enforce them strictly.

## Key Findings

### Recommended Stack

Ubuntu 24.04 (pinned by tag, optionally by digest), Node 24 LTS (official tarball with `SHASUMS256.txt` verification), Eclipse Temurin JDK 21 (`COPY --from` multi-arch, no apt repo), Maven 3.9.16 (Apache tarball, pinned), Python 3.12 (system `python3-venv`), `uv` 0.12.21 (Astral's pinned Docker image).

Claude Code 2.1.285 (npm-pinned into `/usr/local/bin`, same native binary as native installer but integrity-checked). `@opengsd/gsd-core@1.15.0` (engines: Node >=24) baked into image, reconciled at container start. `ccusage@20.0.26` (v20 ships native binary via optional deps, mode 0644; requires `chmod 755` after install).

**Critical changes from current:** Node 24 (not 20 EOL), npm-pinned per-tool (not `@latest`), Claude via npm (not native installer), `CLAUDE_CONFIG_DIR` in Dockerfile `ENV` (not entrypoint-only), GSD from baked package at start (not `npx @latest`), ccusage with chmod + smoke test.

**Stack disagreements:** Claude install via (a) npm pinned (recommended, uniform), (b) native installer script, or (c) apt repo. **Use (a):** integrity-checked, unified with GSD/ccusage, matches Anthropic devcontainer.

### Expected Features

**Must have (table stakes):**
- Non-root `sandbox` user (Claude Code rejects root)
- Fixed workspace mount at `/home/sandbox/workspace` (not over `$HOME`)
- Agent state persisted via one mounted directory + `CLAUDE_CONFIG_DIR` (never single-file mount)
- All tools baked with pinned versions (no runtime `@latest`)
- One-command rebuild that upgrades tools and refreshes GSD without touching login

**Should have (competitive):**
- Shared base image, thin per-agent images
- Remembered project args (name → path) in registry
- Lifecycle scripts matching Docker `sbx` UX
- `ccusage` integration (automatic with `CLAUDE_CONFIG_DIR`)

**Defer (v2+):** OpenCode, per-agent state subdirs, egress firewall, CLI wrappers

### Architecture Approach

One shared `base/` Dockerfile + thin agent images (`claude/`, `opencode/`). `versions.env` is single source of truth. Generic `compose.yml` takes `--env-file` for sandbox registry (name, path, agent) + agent-specific `agent.env` (image, state target, launch). Build order: base first, then agents `FROM base`. No per-project image tags; one shared `:local` per agent.

Mount layout: `/home/sandbox/workspace` ← `<sandbox>/workspace/`, `/home/sandbox/.claude` ← `<sandbox>/state/claude/`. Everything else in home (`.bashrc`, `.local`, `.npm`) is ephemeral from image. `CLAUDE_CONFIG_DIR=/home/sandbox/.claude` in Dockerfile `ENV` moves `.claude.json` inside mounted state, fixing atomic-rename failures.

**Major components:**
1. **`versions.env`** — single source of truth for all pins
2. **Base image** — Ubuntu, Node, JDK, Maven, Python, sandbox user, entrypoint contract
3. **Claude image** — Claude Code, GSD, ccusage (all npm-pinned), `DISABLE_UPDATES=1`, GSD sync drop-in
4. **Generic `compose.yml`** — mounts (code + state), labels, `init: true`, `sleep infinity`
5. **Registry** (`~/.config/gsd-sandbox/sandboxes/<name>.env`) — name → agent + host path
6. **Lifecycle scripts** (`bin/sbx-*`) — thin wrappers using registry, `docker compose`, `docker exec`

### Critical Pitfalls

1. **Single-file bind mount of `~/.claude.json`** — Claude's atomic rename fails with `EBUSY`. Fix: mount directory + `CLAUDE_CONFIG_DIR` so file lands inside mount. **Phase P2.**

2. **`CLAUDE_CONFIG_DIR` in entrypoint only** — `docker exec` doesn't run entrypoint; two divergent state files result. Fix: Dockerfile `ENV CLAUDE_CONFIG_DIR=/home/sandbox/.claude`. **Phase P2.**

3. **Mounting host state over `~/.claude` hides GSD** — Image GSD erased by mount. Fix: bake package, reconcile at start using idempotent installer. **Phase P3.**

4. **Stale GSD files and self-updates** — Old skills persist, `/gsd:update` installs into persisted state. Fix: reconcile only at start (document `/gsd:update` unsupported), use installer's manifest-driven pruning. **Phase P3.**

5. **Claude auto-updater + copies in `~/.local`** — `DISABLE_AUTOUPDATER=1` insufficient; `DISABLE_UPDATES=1` required. Fix: pinned root install + smoke test `~/.local/share/claude` empty. **Phase P3.**

## Implications for Roadmap

### Phase 1: Base Image and Pinned Toolchains
**Rationale:** All phases depend on reproducible base. Resolves Node 20→24, uid collisions, git dubious ownership, curl-pipe security.

**Delivers:** Ubuntu 24.04, Node 24 LTS (tarball verified), JDK 21 (Temurin), Maven 3.9.16, Python, `uv`, gh, git. `versions.env` as ARG source. `sbx-entrypoint` (mount checks, drop-ins). `/etc/gitconfig` safe.directory. `sandbox` UID 1000.

**Pitfalls avoided:** 6 (Node EOL), 19 (uid), 20 (ownership), 21 (git), 23 (curl).

---

### Phase 2: State Mount Layout and CLAUDE_CONFIG_DIR
**Rationale:** Mount layout is critical architectural decision; must validate end-to-end before tool-specific work.

**Delivers:** Generic `compose.yml` with `--env-file` support. Registry format. `claude/Dockerfile` with Dockerfile `ENV CLAUDE_CONFIG_DIR`. Mounts at `/home/sandbox/workspace` and `/home/sandbox/.claude`. End-to-end test: login survives recreate, `.claude.json` inside `state/claude/` on host.

**Pitfalls avoided:** 1 (single-file), 2 (env scoping), 11 (VOLUME), 13-14 (foundation).

---

### Phase 3: Tools and GSD Reconciliation
**Rationale:** Highest-risk phase; stable mounts needed. Auto-updater conflicts must be resolved here.

**Delivers:** npm-install Claude Code, GSD, ccusage (all pinned as root). `ENV DISABLE_UPDATES=1`. `ENV GSD_CORE_VERSION`. `10-gsd-sync.sh` idempotent reconcile with version check. Build-time smoke tests as `sandbox` user. Version assertion banner.

**Test:** Bump GSD, rebuild, recreate, verify version + login intact. `ccusage daily` works. `claude doctor` shows updates disabled.

**Pitfalls avoided:** 3 (GSD shadowing), 4 (stale GSD), 5 (updater), 7 (chmod), 8 (optional deps), 12 (npm).

**Research flag:** Verify `DISABLE_UPDATES=1` via `claude doctor` on macOS. Test optional deps on amd64.

---

### Phase 4: Lifecycle Scripts and Upgrade Flow
**Rationale:** Lock in naming and upgrade behavior before scaling. Phases 4 and 5 can overlap.

**Delivers:** `bin/_lib.sh` (shared functions). `bin/sbx-{add,up,shell,down,build,ls,rm}`. Name validation. Build script: resolve latest, pin as ARGs, rebuild, recreate sandboxes.

**Pitfalls avoided:** 13 (cache), 14 (down -v), 15 (naming), 26 (entrypoint env).

---

### Phase 5: Migration, Documentation, Host Verification
**Rationale:** Final validation on real macOS + Docker Desktop. Migrates ~4 existing sandboxes.

**Delivers:** Migration procedure (move state, clean ephemeral, optionally rename cwd). README rewrite (usage, threat model, extension points). `sbx-doctor` (no docker.sock, no broad host mounts). Host verification checklist.

**Pitfalls addressed:** 9 (ccusage scope), 10 (path identity), 16-17 (threat model), 21 (git identity), 27 (migration).

---

### Phase Ordering Rationale

P1 → P2 → P3 → P4 → P5 (only valid order):
- P1 prerequisite (no image = no container)
- P2 validates architecture before tool logic
- P3 depends on P2's mount (Pitfall 3 prevention)
- P4 depends on P3 working
- P5 final validation; requires prior phases passing

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | npm registry, official docs (Claude/GSD/ccusage), Node schedule, Docker Hub, Apache archives verified. |
| Features | HIGH | Anthropic docs, Docker `sbx` UX, comparable tools assessed. MVP aligns with "small bash" constraint. |
| Architecture | HIGH | Mount layout, `CLAUDE_CONFIG_DIR`, GSD reconciliation verified by source + live testing. Pitfalls from official docs, GitHub issues, package contents. |
| Pitfalls | HIGH | Sourced from official docs, issue trackers, package inspection, live aarch64 testing. Anti-patterns grounded in observed failures. |

**Overall:** HIGH confidence

**Qualification:** Docker Desktop macOS VirtioFS ownership (Pitfall 20) inferred from community reports, not verified here. Phase 2 and P5 validate on real macOS.

### Gaps to Address

1. **Claude Code install method:** Confirm npm produces same native binary as documented installer
2. **GSD `--portable-hooks`:** Test in Phase 3 if hardening desired (optional)
3. **Docker Desktop macOS ownership:** Validate real bind-mount behavior in Phase 5 (Pitfall 20)
4. **OpenCode state paths:** Verify at next milestone
5. **Threat model validation:** Phase 5 README must articulate risk clearly

## Sources

**PRIMARY (HIGH):** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md synthesized from npm registry, official Claude Code/GSD/ccusage/Docker docs, GitHub issues, package source inspection, live aarch64 testing.

**SECONDARY (MEDIUM):** Community reports, OpenCode docs.

**TERTIARY (LOW):** `mountpoint` behavior assumptions, git ownership fix effectiveness.

---

*Research completed: 2026-09-30*
*Ready for roadmap: yes*
