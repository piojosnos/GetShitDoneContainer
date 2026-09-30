# Architecture Research

**Domain:** Docker-based sandbox containers for AI coding agents (Claude Code now, OpenCode next, pluggable later) on macOS + Docker Desktop
**Researched:** 2026-09-30
**Confidence:** HIGH on mount layout, `CLAUDE_CONFIG_DIR`, and GSD sync (tested in this session or in official docs). MEDIUM on OpenCode state paths and macOS ownership edge cases. Both need host-side verification, because the dev sandbox cannot run Docker.

## Headline Recommendations

1. **Never mount over `$HOME`.** Mount exactly two host directories per sandbox: `<sbx>/workspace` at `/home/sandbox/workspace` and `<sbx>/state/<agent>` at the agent's config dir (Claude: `/home/sandbox/.claude`). Everything else in `/home/sandbox` (`.bashrc`, `.local`, ...) comes from the image, and it is ephemeral by design.
2. **Set `CLAUDE_CONFIG_DIR=/home/sandbox/.claude` as an image `ENV`.** This moves `~/.claude.json` inside the state directory, so one directory bind mount carries the whole login. No single-file bind mount and no symlink tricks. Tested: with `CLAUDE_CONFIG_DIR=X`, Claude Code 2.1.285 wrote `X/.claude.json` and left `$HOME/.claude.json` untouched.
3. **Bake GSD into the image and re-run its installer on every container start.** `~/.claude` mixes user state with GSD-managed files, so the state directory cannot simply be shadowed by the image. Instead the entrypoint runs `gsd-core --claude --global` from the baked npm package. Measured: about 0.4 s, offline, idempotent. The installer is manifest-driven, upgrades in place, and backs up locally modified GSD files to `gsd-local-patches/`. The image version therefore wins without touching login or history.
4. **One shared `base/` image and thin `claude/` (later `opencode/`) images.** Each agent image is about 15 lines. Agent-specific behavior is confined to that agent's directory (`Dockerfile`, `agent.env`, `entrypoint.d/` drop-ins). Base plus agent are built in order by one script, from one `versions.env` pin file.
5. **One generic `compose.yml`, driven by env files.** The registry file for a sandbox and the agent's `agent.env` are passed as `--env-file`. Do not keep one compose file per agent. An agent needing extras (OpenCode's port) gets a small overlay file.
6. **No UID mapping on Docker Desktop for macOS.** Docker Desktop fakes ownership so the container user can read and write host files. Use a fixed `sandbox` user (UID 1000) and avoid `chown` on bind mounts. Add `git config --system safe.directory '*'` in the base image, because of a known macOS bind-mount ownership glitch that breaks `git`.

## Standard Architecture

### System Overview

```
┌──────────────────────────── macOS host ─────────────────────────────────┐
│                                                                          │
│  Repo (this project)                    Host config (outside all mounts) │
│  ├─ versions.env  (all pins)            ~/.config/gsd-sandbox/           │
│  ├─ base/ claude/ opencode/               sandboxes/<name>.env           │
│  ├─ compose.yml                             SBX_AGENT=claude             │
│  └─ bin/sbx-*  ◄── reads ───────────────    SBX_DIR=/Users/me/Proj       │
│                                                                          │
│  Per-sandbox folder  /Users/me/<Sandbox>/         (host IDE opens this)  │
│  ├─ workspace/          code                                             │
│  └─ state/claude/       login, .claude.json, settings, history, GSD      │
└───────┬──────────────────────────┬───────────────────────────────────────┘
        │ bind mount (rw)          │ bind mount (rw)
┌───────▼──────────────────────────▼───────────────────────────────────────┐
│ Container  sbx-claude image   (user: sandbox, UID 1000, no root)         │
│                                                                          │
│  /home/sandbox/workspace   ◄── host workspace/                           │
│  /home/sandbox/.claude     ◄── host state/claude/  (= CLAUDE_CONFIG_DIR) │
│  /home/sandbox/{.bashrc,.local,...}    image layer, ephemeral            │
│                                                                          │
│  Entrypoint (base) ─ sanity checks ─► entrypoint.d/10-gsd-sync ─► exec   │
│                                                                          │
│  Tools baked in image (root-owned, not shadowed by any mount):           │
│    /usr/local/bin/claude   ccusage   node/npm   java/mvn   git/gh   py   │
│    /usr/local/lib/node_modules/@opengsd/gsd-core   (installer source)    │
└───────┬──────────────────────────────────────────────────────────────────┘
        │ FROM
┌───────▼──────────────────────────────────────────────────────────────────┐
│ sbx-base image:  pinned Ubuntu LTS + Node 24 + JDK 21 + Maven + Python   │
│                  + git/gh + sandbox user + sbx-entrypoint + gitconfig    │
└──────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Owns | Talks to |
|-----------|----------------|------|----------|
| `versions.env` | Single source of truth for every pinned version (Ubuntu tag, Node major, JDK, Maven, Claude Code, GSD core, ccusage) | Pins only | `bin/sbx-build` passes them as `--build-arg` |
| `base/` image | Everything every agent needs: OS packages, toolchains, `sandbox` user, `sbx-entrypoint`, `/etc/gitconfig`, `.bashrc` | Generic tooling and the entrypoint contract | Built first; consumed by `FROM` in agent images |
| `claude/` image | Claude Code (pinned), `@opengsd/gsd-core` (pinned, global), ccusage (pinned, global), `ENV CLAUDE_CONFIG_DIR`, `DISABLE_AUTOUPDATER=1`, the `10-gsd-sync.sh` drop-in | Everything Claude-specific | `FROM sbx-base`; run by compose |
| `agent.env` (per agent) | Declares the seam: `AGENT_IMAGE`, `AGENT_STATE_TARGET`, `AGENT_LAUNCH` | Agent metadata read by scripts and compose | `bin/*`, `compose.yml` |
| `compose.yml` (generic) | Declares the container: image, two bind mounts, labels, `init`, `sleep infinity` | Runtime shape | Docker Engine |
| `sbx-entrypoint` (in base) | Mount sanity checks, run `entrypoint.d/*.sh`, then `exec "$@"` | Start-time contract | Mounts, drop-ins |
| Registry (`~/.config/gsd-sandbox/sandboxes/<name>.env`) | Remember name to agent and host dir (plus optional overrides) | Per-sandbox remembered args | `bin/*` read it; compose gets it via `--env-file` |
| `bin/_lib.sh` + `sbx-*` | Thin lifecycle wrappers: add, up, shell, down, build/upgrade, ls, rm | Nothing persistent | Registry, `docker compose`, `docker exec` |
| Host sandbox folder | Code (`workspace/`) and agent state (`state/<agent>/`) | All user data | Bind-mounted into the container; host IDE reads `workspace/` |

## Recommended Project Structure

```
GetShitDoneContainer/
├── versions.env            # UBUNTU_TAG, NODE_MAJOR, JDK_VERSION, MAVEN_VERSION,
│                           # CLAUDE_CODE_VERSION, GSD_CORE_VERSION, CCUSAGE_VERSION
├── compose.yml             # ONE generic service definition for every agent
├── base/
│   ├── Dockerfile          # ubuntu:<pinned> + toolchains + sandbox user + gitconfig
│   ├── sbx-entrypoint      # -> /usr/local/bin/sbx-entrypoint
│   └── bashrc              # -> /home/sandbox/.bashrc (prompt shows $SBX_NAME)
├── claude/
│   ├── Dockerfile          # ARG BASE_IMAGE; FROM ${BASE_IMAGE}; ~15 lines
│   ├── agent.env           # AGENT_IMAGE=sbx-claude, AGENT_STATE_TARGET=/home/sandbox/.claude, AGENT_LAUNCH=claude
│   └── entrypoint.d/
│       └── 10-gsd-sync.sh  # gsd-core --claude --global; assert VERSION == baked version
├── opencode/               # NEXT MILESTONE, same shape
│   ├── Dockerfile
│   ├── agent.env
│   ├── compose.yml         # overlay: 127.0.0.1:${SBX_PORT}:4096
│   └── entrypoint.d/10-gsd-sync.sh   # gsd-core --opencode --global
├── bin/
│   ├── _lib.sh             # load_sandbox <name>, compose(), is_running()
│   ├── sbx-add             # register name -> agent + host dir, mkdir workspace/ state/<agent>/
│   ├── sbx-up              # compose up -d (creates or recreates)
│   ├── sbx-shell           # up if needed, then docker exec -it ... bash | $AGENT_LAUNCH
│   ├── sbx-down            # compose down (NO -v)
│   ├── sbx-build           # build base, then agent(s); optional --bump; recreate running sandboxes
│   ├── sbx-ls              # docker ps -a --filter label=sbx.name, joined with registry
│   └── sbx-rm              # down + unregister (never deletes the host folder)
└── README.md               # usage + MIGRATION section
```

The current `ClaudeCode/` and `OpenCode/` directories are replaced by `claude/` and `opencode/`. The existing `OpenCode/` stays parked, untouched, until its milestone. It hardcodes a host path and installs the compromised package, so mark it deprecated in the README.

Script names (`sbx-*` versus keeping `cc-*`) are a roadmap-level naming decision. The architectural requirement is only that scripts are agent-neutral and read the agent from the registry.

### Structure Rationale

- **`base/`, `claude/`, `opencode/` as separate directories:** each has its own small build context and independent ownership. Adding an agent means adding a directory, and adding a tool for everyone means editing `base/Dockerfile`. A single multi-target Dockerfile would also work, but it lets agent concerns leak into the base file. The separate-directories choice matches PROJECT.md ("thin per-agent images on top").
- **One `versions.env`:** satisfies "adding a tool or bumping a version is one edit". It is also the mechanism that defeats Docker layer-cache staleness (see Pitfalls below).
- **Generic `compose.yml` and `agent.env`:** the two mounts have the same shape for every agent (`workspace/` and `state/<agent>/`). Only the container-side state path differs, and that is data, not structure.
- **`entrypoint.d/` drop-ins:** the same pattern nginx and postgres images use. The base entrypoint never learns about specific agents, so a new agent adds a file rather than editing shared code.
- **Registry outside the repo and outside every mount:** it holds personal host paths (must not be committed), and the agent must not be able to edit it (it is not under `workspace/` or `state/`). `git pull` on the repo never conflicts with it.

## Mount Layout (the central decision)

### Host layout per sandbox

```
/Users/demian/<Sandbox>/
├── workspace/              -> container /home/sandbox/workspace   (rw)
│   └── MyCode/             project(s); host IDE opens this
└── state/
    └── claude/             -> container /home/sandbox/.claude      (rw)
        ├── .claude.json         OAuth account, onboarding, per-project trust (because CLAUDE_CONFIG_DIR)
        ├── .credentials.json    Linux credential store
        ├── settings.json        user edits + GSD hook entries (merged by installer)
        ├── projects/ sessions/ history.jsonl ...   history; ccusage reads projects/
        └── skills/ agents/ hooks/ gsd-core/ ...    GSD-managed, re-synced from image every start
```

A later OpenCode sandbox adds `state/opencode/` next to `state/claude/`, and both can share one `workspace/`. Optional registry overrides (`SBX_WORKSPACE`, `SBX_STATE`) let a sandbox point at an existing code folder elsewhere. Defaults stay convention-based.

### Why workspace is a directory that can hold projects, not "the repo"

Docker Desktop for macOS has an open issue where the bind-mount **root** intermittently reports UID/GID 0:0 through `lstat()`. Git then fails with "dubious ownership". It only affects the mount root, and it does not occur when the repo is nested one level below. Mounting `workspace/` and keeping projects in `workspace/<proj>/` sidesteps it. `safe.directory '*'` in `/etc/gitconfig` (image-owned) covers the case where someone puts a repo directly at the root. The container is already the isolation boundary, so the blanket setting costs nothing.

### Why not the alternatives

| Option | Verdict | Reason |
|--------|---------|--------|
| Mount over `/home/sandbox` (current) | Reject | Hides `.bashrc`, `.local`, and anything baked into home. This is the root cause of both problems. |
| Bind-mount `~/.claude.json` as a single file | Reject | Claude writes it via temp file plus `rename(2)`. Renaming onto a bind-mounted file inode fails with EBUSY, and the mount would also pin the wrong inode. |
| Symlink `~/.claude.json` into the state dir | Reject | Atomic-rename writes replace the symlink with a regular file (in `$HOME`, ephemeral) and the login is lost on recreate. |
| Bind-mount an allowlist of state subpaths (`projects/`, `.credentials.json`, ...) | Reject | Claude adds new state paths over time, so anything unlisted is silently lost on rebuild. Also still needs a `.claude.json` answer. |
| **`CLAUDE_CONFIG_DIR` plus one directory mount of the whole config dir** | **Choose** | One mount holds everything. GSD's overlap is handled by installer re-sync (below). Directory mounts tolerate atomic renames inside them. |
| Named Docker volume for state instead of a host folder | Reject for state | PROJECT.md requires the state to be inspectable on the laptop and survive `docker` resets. Fine for caches (see Extension Points). |

### Container-side ownership map

| Path | Owner of content | Lifetime | Notes |
|------|------------------|----------|-------|
| `/usr/local/bin`, `/usr/local/lib/node_modules`, `/opt/*` | Image (root) | Replaced on rebuild | Tools. The `sandbox` user cannot modify them, so no drift. |
| `/etc/gitconfig`, `/etc/claude-code/` | Image (root) | Replaced on rebuild | Image-enforced config. `/etc/claude-code/managed-settings.json` is Claude's top-precedence settings layer. |
| `/home/sandbox/*` (except mounts) | Image, then runtime scribbles | **Ephemeral**: reset on container recreate | This is a feature: it makes containers reproducible. |
| `/home/sandbox/workspace` | Host | Permanent | Code. |
| `/home/sandbox/.claude` | Host, plus GSD files written by the entrypoint | Permanent | Mixed ownership. See the next section. |

Because the container path of the state dir stays `/home/sandbox/.claude`, absolute paths that GSD writes into `settings.json` hooks (`/home/sandbox/.claude/hooks/...`) stay valid across recreations and across migration from the old layout.

## "Image Version Wins" for `~/.claude`

`~/.claude` holds user state (credentials, history, `settings.json`, `.claude.json`) and GSD-managed files (`skills/gsd-*`, `agents/gsd-*`, `gsd-core/`, `hooks/gsd-*`). The state directory is a host bind mount, so a copy of GSD baked at that path is invisible. The only image-to-state path is a copy at start time.

### Pattern: bake the installer, sync at start

**What:** `npm install -g @opengsd/gsd-core@${GSD_CORE_VERSION}` at build time. The entrypoint drop-in runs the installer against the live config dir on every start.
**Why it works (verified against gsd-core 1.15.0 in this session):**
- The installer honors `CLAUDE_CONFIG_DIR` and `--config-dir`, which takes priority over the env var.
- It made no network calls in its install path (a grep of `bin/install.js` found no fetch or registry calls). Running it from a local copy took about 0.34 s the first time and about 0.43 s the second, with no network access.
- It is idempotent and manifest-driven (`gsd-file-manifest.json`, `gsd-install-state.json`). It upgrades in place and prunes stale GSD files through migrations.
- It saves locally modified GSD files to `gsd-local-patches/` before overwriting, so "image wins" is recoverable.
- `settings.json` is merged rather than replaced. An existing statusline is skipped unless `--force-statusline` is passed.
- It never touches `.claude.json`, `.credentials.json`, `projects/`, or `history.jsonl`.

**Trade-offs:** about half a second added to every container start, and GSD files in `~/.claude` are image-managed, so hand edits to them get backed up and overwritten. That is the intended semantic.

```bash
# claude/entrypoint.d/10-gsd-sync.sh  (sourced by sbx-entrypoint as user sandbox)
if gsd-core --claude --global --config-dir "$CLAUDE_CONFIG_DIR" >/tmp/gsd-sync.log 2>&1; then
  have="$(cat "$CLAUDE_CONFIG_DIR/gsd-core/VERSION" 2>/dev/null || true)"
  [ "$have" = "$GSD_CORE_VERSION" ] || echo "[sbx] WARNING: GSD is $have, image has $GSD_CORE_VERSION" >&2
else
  echo "[sbx] WARNING: GSD sync failed, see /tmp/gsd-sync.log" >&2   # warn loudly, still give a shell
fi
```

Rejected variants:
- **Symlink GSD dirs from an image path into `~/.claude`:** the installer expects real directories, hooks embed absolute paths, and Claude's handling of symlinked skills is not something to depend on.
- **Copy-if-marker-missing (`.initialized`):** this is what causes stale GSD today. Upgrade decisions must come from the version comparison, not from a first-run flag. Delete `.initialized` from the design.
- **`npx -y @opengsd/gsd-core@latest` at runtime:** floating version, needs network at every start, and moves supply-chain trust into the running container.

### Same principle for the other layers

| Thing | Mechanism | Reason |
|-------|-----------|--------|
| Claude Code binary | Pinned in the image (`npm i -g @anthropic-ai/claude-code@X`, or `install.sh \| bash -s X`), plus `ENV DISABLE_AUTOUPDATER=1` | Docs confirm the native install auto-updates in the background. A container that self-updates into `~/.local` defeats "image wins". Setting it via process `ENV` means persisted `settings.json` cannot re-enable it. Also consider `DISABLE_UPDATES=1`. |
| ccusage | `npm i -g ccusage@X` at build time (lands in `/usr/local`) | v20 ships native binaries through per-platform optional dependencies (`@ccusage/ccusage-linux-arm64`). A global install on an arm64 builder resolves the right one. The old failure was `$HOME` install plus mount shadowing, not the package. |
| Settings that must not drift | Optional `/etc/claude-code/managed-settings.json` in the image | Official Linux path. Highest precedence, so nothing in the persisted user settings overrides it. Use sparingly (see Pitfalls). |

## Entrypoint Contract

Split responsibilities so agents plug in without editing shared code.

| Layer | Does | Does NOT do |
|-------|------|-------------|
| `base/sbx-entrypoint` | Verify workspace and state dirs are mounts and writable (warn loudly if a path is not a mount, because data would be lost on recreate). Run `entrypoint.d/*.sh` in order. `exec "$@"`. | Install anything, decide upgrades, know about agents. |
| `<agent>/entrypoint.d/*.sh` | Sync image-provided content into the state dir (GSD). Seed first-run defaults. | Network installs, `chown -R` on mounts. |
| `Dockerfile` `ENV` | Anything shells launched by `docker exec` must see: `CLAUDE_CONFIG_DIR`, `DISABLE_AUTOUPDATER`, `PATH` | (see anti-pattern 5) |
| compose `environment:` | Per-sandbox values: `SBX_NAME`, git identity | Anything static (belongs in the Dockerfile). |

```bash
#!/usr/bin/env bash
# base/sbx-entrypoint
set -euo pipefail
for d in "$HOME/workspace" "${SBX_STATE_DIR:-}"; do
  [ -n "$d" ] || continue
  mountpoint -q "$d" || echo "[sbx] WARNING: $d is not a bind mount; changes are lost on recreate" >&2
  [ -w "$d" ] || { echo "[sbx] ERROR: $d is not writable" >&2; exit 1; }
done
for f in /usr/local/lib/sbx/entrypoint.d/*.sh; do [ -e "$f" ] && . "$f"; done
exec "$@"
```

`docker exec` sessions do not re-run the entrypoint and do not see variables exported by it. Upgrade freshness therefore relies on container recreation (below).

## Generic Compose

```yaml
# compose.yml (repo root). Invoked with:
#   docker compose -p sbx_$NAME -f compose.yml [-f $AGENT/compose.yml] \
#     --env-file ~/.config/gsd-sandbox/sandboxes/$NAME.env --env-file $AGENT/agent.env up -d
services:
  sandbox:
    image: ${AGENT_IMAGE:?agent.env not loaded}
    container_name: ${SBX_AGENT}_${SBX_NAME}
    hostname: ${SBX_NAME}
    init: true                     # reap zombies from agent subprocesses
    command: ["sleep", "infinity"] # sbx-shell uses docker exec; container outlives shells
    working_dir: /home/sandbox/workspace
    environment:
      SBX_NAME: ${SBX_NAME}
      SBX_STATE_DIR: ${AGENT_STATE_TARGET}
    labels:
      sbx.name: ${SBX_NAME}
      sbx.agent: ${SBX_AGENT}
      sbx.dir: ${SBX_DIR}
    volumes:
      - type: bind
        source: ${SBX_DIR:?}/workspace
        target: /home/sandbox/workspace
        bind: { create_host_path: false }   # a typo'd path fails loudly instead of creating an empty dir
      - type: bind
        source: ${SBX_DIR}/state/${SBX_AGENT}
        target: ${AGENT_STATE_TARGET}
        bind: { create_host_path: false }
```

`sbx-add` creates `workspace/` and `state/<agent>/` on the host, so the mount sources always exist. Use `docker compose` (v2). The current scripts call the legacy hyphenated `docker-compose`.

## Data Flow

### Build time (upgrade path)

```
versions.env ──► sbx-build ──► docker build base/    ──► sbx-base:<tag>
   (bump: edit,                └► docker build claude/ ──► sbx-claude:<tag>
    or sbx-build --bump                (--build-arg BASE_IMAGE, *_VERSION)
    queries npm registry
    and rewrites the file)
                               └► for each running sandbox of that agent:
                                  docker compose up -d   (image ID changed => container recreated)
```

### Start time (every create or recreate)

```
sbx-up <name> ─► registry <name>.env + agent.env ─► compose (env files)
   ─► container created with 2 bind mounts
   ─► sbx-entrypoint: mount checks ─► 10-gsd-sync (image GSD ─► state dir, ~0.4 s) ─► sleep infinity
```

### Runtime

```
sbx-shell <name> ─► (up if not running) ─► docker exec -it <container> bash   (or `claude`)
Agent process ◄──rw──► /home/sandbox/workspace ◄──bind──► host workspace/  ◄── host IDE
Agent process ◄──rw──► /home/sandbox/.claude   ◄──bind──► host state/claude/ (login, history)
ccusage ──reads──► $CLAUDE_CONFIG_DIR/projects/*.jsonl  (same mount, no extra plumbing)
Agent ──network──► Anthropic API / GitHub (only egress; nothing else from host is reachable)
```

### Key Data Flows

1. **Login persistence:** `claude` login writes `.claude.json` and `.credentials.json` into the state mount, so they survive any recreate or rebuild.
2. **Upgrade:** a new pin leads to a new image, `up -d` recreates the container, the entrypoint sync overwrites GSD files in the state dir with the new version, and everything else in the state dir is untouched.
3. **Remembered args:** `sbx-add` writes the registry once, and every other script takes only the name.

## Registry

```
~/.config/gsd-sandbox/sandboxes/GSD_StaticSiteGenerator.env     # one KEY=VALUE file per sandbox
    SBX_NAME=GSD_StaticSiteGenerator
    SBX_AGENT=claude
    SBX_DIR=/Users/demian/GSD_StaticSiteGenerator
    # optional: SBX_GIT_NAME=..., SBX_GIT_EMAIL=..., SBX_PORT=4096
```

- **One file per sandbox** rather than one table: no parsing, no locking, and a file is both `source`-able by bash and usable directly as a compose `--env-file`.
- **Keep the location overridable** (`SBX_CONFIG_DIR`). Do not put it under the repo, because it holds personal paths.
- **Host scripts must run on macOS's stock bash 3.2:** use `#!/usr/bin/env bash`, no associative arrays or `mapfile`, no `sed -i` without a suffix argument, and quote every path (host folders may contain spaces).
- **`sbx-ls`** joins `docker ps -a --filter label=sbx.name --format ...` with the registry. Running state comes from Docker labels, not from the registry. This avoids stale-state bugs.

## Scaling Considerations

| Concern | ~4 sandboxes (today) | ~20 | 50+ |
|---------|---------------------|-----|-----|
| Disk | Images shared through layers. State dirs are small (history grows slowly). | Same | Prune state history occasionally. |
| Idle cost | `sleep infinity` under `init` is negligible. | Same | The Docker Desktop VM memory cap limits how many agents run concurrently, not how many exist. |
| Upgrade time | One build, N recreates (about 1 s each plus sync). | `sbx-build` loops over the running sandboxes. | Consider recreating lazily (on next `sbx-shell`) via an image-ID label check. |
| Registry | Plain files | Plain files | Still fine. Do not build a database. |

The design does not scale by adding infrastructure. It stays simple because everything per-sandbox is just two directories and one env file.

## Anti-Patterns

### Anti-Pattern 1: Bind-mounting over `$HOME`
**What people do:** mount the project at `/home/sandbox` (current design).
**Why it's wrong:** hides everything the image puts in home, which forced runtime installs and made the ccusage install fail.
**Do this instead:** mount only `workspace/` and the agent state dir.

### Anti-Pattern 2: Single-file bind mount for `~/.claude.json`
**What people do:** `-v host/.claude.json:/home/sandbox/.claude.json`.
**Why it's wrong:** atomic-rename writes fail with EBUSY, or the mount pins a stale inode.
**Do this instead:** `CLAUDE_CONFIG_DIR` makes it a normal file in the mounted directory.

### Anti-Pattern 3: First-run markers gating upgrades (`.initialized`)
**What people do:** install tools only if a marker is missing.
**Why it's wrong:** it encodes "install once", the opposite of "image version wins".
**Do this instead:** idempotent sync on every start plus a version assertion.

### Anti-Pattern 4: Runtime `npx ...@latest` and `curl | bash` in the entrypoint
**What people do:** fetch tools when the container starts.
**Why it's wrong:** floating versions, network dependency, and a moving supply-chain surface (a compromised GSD package already happened here).
**Do this instead:** pin at build time, run the installer from the baked package.

### Anti-Pattern 5: Entrypoint-only environment
**What people do:** export `PATH` or `CLAUDE_CONFIG_DIR` in the entrypoint or edit `.bashrc` at first run.
**Why it's wrong:** `docker exec` shells inherit the container's configured env, not what the entrypoint exported.
**Do this instead:** put static values in Dockerfile `ENV` and per-sandbox values in compose `environment:`.

### Anti-Pattern 6: `chown -R` on bind mounts
**What people do:** the Linux-era fix for permission errors.
**Why it's wrong:** on Docker Desktop for macOS it is a no-op (ownership is synthesized) and slow on a big workspace.
**Do this instead:** nothing. Ownership works out of the box on macOS. If Linux hosts ever matter, build with `--build-arg SANDBOX_UID=$(id -u)`, and do not remap at runtime.

### Anti-Pattern 7: `docker compose down -v` in the down script
**What people do:** current `cc-down.sh` uses `-v`.
**Why it's wrong:** it deletes named volumes. Bind mounts are safe today, but the first cache volume added later would be wiped without warning.
**Do this instead:** plain `down`.

### Anti-Pattern 8: A copy-pasted compose file per agent
**What people do:** duplicate `docker-compose.yml` for each agent.
**Why it's wrong:** the two hardcoded-path and drift problems already visible in `OpenCode/`.
**Do this instead:** generic `compose.yml`, `agent.env` for data, optional overlay for real differences.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Docker Desktop (macOS, likely Apple Silicon) | `docker build` (native arm64 by default), `docker compose` v2 | Do not pass `--platform amd64`. ccusage and Claude ship per-arch native binaries via optional deps, and a mismatched builder gets the wrong one. Host paths must be inside Docker Desktop's shared paths (defaults include `/Users`). |
| npm registry | Build time only | Pins go through `versions.env`. Runtime containers need no registry access. |
| Anthropic API / claude.ai | Runtime, from inside the container | Login state lives in the state mount. |
| GitHub | Runtime (`gh`, git) | Credential persistence is deliberately out of the core layout. See Extension Points. |
| Host IDE | Through `workspace/` on the host filesystem | No IDE-to-container integration required. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `bin/*` to Docker | `docker compose` and `docker exec` CLI | Scripts hold no state. Docker labels plus the registry are the only sources of truth. |
| Registry / `agent.env` to compose | `--env-file` | Missing required variables fail through `${VAR:?}`. |
| base image to agent image | `FROM ${BASE_IMAGE}` plus the `entrypoint.d/` drop-in directory | The only two coupling points. Keep them documented and stable. |
| Image to state dir | Entrypoint sync only | Nothing else crosses this boundary. |
| Container to host | Two bind mounts only | Any additional mount is an isolation decision and needs an explicit requirement. |

## Extension Points (documented, not built now)

- **Cache volumes:** `~/.m2` and `~/.npm` are lost on every recreate (home is ephemeral), and Maven re-downloads are the likely first complaint. The fix is a Docker named volume per sandbox (faster than VirtioFS for many small files). Create and chown the target directory in the base image so Docker seeds correct ownership on first mount. Add it when it hurts.
- **Git identity:** pass `GIT_AUTHOR_NAME/EMAIL` and `GIT_COMMITTER_*` from the registry through compose `environment:`. Git reads them natively, so no `~/.gitconfig` is needed.
- **`gh` auth:** either `GH_TOKEN` in compose env (visible to the agent, which is inherent) or point `GH_CONFIG_DIR` into the state mount. Decide when needed.
- **OpenCode:** `state/opencode/` mounted at a single container path, with `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME` (and `OPENCODE_CONFIG_DIR`) set under it by Dockerfile `ENV`. This keeps the "one mount" property. Its GSD sync is `gsd-core --opencode --global`. Web mode needs a compose overlay publishing `127.0.0.1:${SBX_PORT}:4096` (loopback only, since the web UI is otherwise reachable from the LAN).
- **Rollback:** tag each build with an immutable stamp (for example `sbx-claude:cc2.1.285-gsd1.15.0`) as well as the moving `:local` tag, and `SBX_IMAGE` overrides `AGENT_IMAGE` for a sandbox.

## Suggested Build Order

Dependencies drive the order. Each step can be verified on the host before the next.

1. **Pins and base image** (`versions.env`, `base/Dockerfile`, `sbx-entrypoint`, `/etc/gitconfig`, `.bashrc`). No dependencies. Verify: `docker run --rm sbx-base:local bash -lc 'java -version; mvn -v; node -v; git --version'` and `ls -la /home/sandbox` shows image dotfiles.
2. **Claude image with GSD and ccusage baked** (`claude/Dockerfile`, `10-gsd-sync.sh`, `agent.env`, `ENV CLAUDE_CONFIG_DIR`). Depends on 1. Verify with a throwaway host directory as the state mount: GSD version matches the pin and `claude --version` matches. Use `sbx-build` from the start, because build ordering is part of the design.
3. **Generic `compose.yml` with the two-mount layout on a fresh sandbox.** Depends on 2. This is the first end-to-end proof: login once, recreate the container, and confirm login and history survive with `.claude.json` inside `state/claude/` on the host. Also check `ccusage daily`, `git status` after restart, and `sbx` output for `mountpoint` warnings.
4. **Registry and lifecycle scripts** (`_lib.sh`, `sbx-add/up/shell/down/ls/rm`). Depends on 3, because the mount layout must be stable before scripts encode it.
5. **Upgrade command** (`sbx-build --bump` plus recreate of running sandboxes). Depends on 2 and 4. Verify by bumping a pin, running one command, and confirming the new GSD version with the login intact.
6. **Migration docs and README correction** (existing sandboxes, `cc-upgrade.sh` reference removed). Depends on 3 to 5, because the steps must be tested on a real old sandbox (see below).
7. **Next milestone: OpenCode** (new directory only). Doing this without editing `base/`, `bin/`, or `compose.yml` (except an overlay) is the test that the seam is right.

Steps 4 and 5 can be swapped or overlapped. The one hard ordering rule is that scripts come after the layout, not before.

### Migration mapping (for the README)

Old sandbox root (was `/home/sandbox`) to new layout:

```
<sbx>/MyCode              ->  <sbx>/workspace/MyCode
<sbx>/.claude/*           ->  <sbx>/state/claude/
<sbx>/.claude.json        ->  <sbx>/state/claude/.claude.json     (the login/account state)
<sbx>/.initialized .npm .cache .local .bashrc ...   ->  delete (image provides or regenerates)
```

Watch two consequences of the path change, because Claude keys per-project data by absolute path:
- `state/claude/projects/-home-sandbox-MyCode` should be renamed to `-home-sandbox-workspace-MyCode`, and the matching key in `.claude.json` (`projects["/home/sandbox/MyCode"]`) rewritten. Otherwise per-project resume and trust prompts start fresh, though the history files remain and ccusage still counts them, since it reads all of `projects/`.
- GSD hook paths in `settings.json` stay valid, because the container path `/home/sandbox/.claude` is unchanged, and the entrypoint sync rewrites them anyway.

## Confidence Notes

| Claim | Confidence | Basis |
|-------|------------|-------|
| `CLAUDE_CONFIG_DIR` relocates `.claude.json` into the config dir | HIGH | Tested here (Claude Code 2.1.285). Also documented in community reports (devcontainer guides). |
| GSD installer honors `CLAUDE_CONFIG_DIR`, is offline, idempotent, and fast | HIGH | Read `bin/install.js` and ran it twice against a scratch dir (gsd-core 1.15.0). |
| gsd-core declares `engines.node >= 24` | HIGH | Package metadata. It ran here under Node 20 with a warning only, but the base image should use Node 24. The current Node 20 image is below spec. |
| ccusage 20.x native per-platform optional deps; reads `~/.claude` by default and `CLAUDE_CONFIG_DIR` | HIGH / MEDIUM | Package metadata inspected. Docs page confirms directories. Verify `ccusage daily` on the host. |
| Managed settings path `/etc/claude-code/managed-settings.json` | HIGH | Official docs. Whether it triggers any prompt in headless use is untested. |
| `DISABLE_AUTOUPDATER=1` via process env stops background updates | MEDIUM | Official docs describe it in `settings.json` `env`. Process env is the usual equivalent. Confirm with `claude doctor` on the host. |
| Docker Desktop macOS fakes ownership, so no UID mapping is needed | MEDIUM | Multiple community reports plus a Docker feedback issue. No official statement found. |
| Bind-mount root intermittently reports UID 0 (git "dubious ownership") | MEDIUM | Docker desktop-feedback issue (reported on Docker Desktop 4.88, arm64), plus a similar Archon report. Mitigated cheaply either way. |
| Renaming onto a bind-mounted single file fails (EBUSY) | HIGH | Standard Linux bind-mount semantics. |
| OpenCode XDG-based state paths and env overrides | MEDIUM | Docs and community references. Deferred to the OpenCode milestone research. |
| Compose `create_host_path`, `additional_contexts`, multiple `--env-file` | HIGH | Compose spec. |

## Open Questions

- Claude Code install method in the image: pinned npm package (uniform with GSD and ccusage; docs say it installs the same native binary and needs Node 22+) versus pinned native installer (`install.sh | bash -s X`, the documented default). Either is compatible with this architecture. Prefer npm for integrity-checked, uniform pinning. STACK research should confirm.
- Whether to use `/etc/claude-code/managed-settings.json` at all, or rely on `ENV` alone. Start with `ENV` only.
- Script naming (`sbx-*` versus `cc-*`) and whether to keep `cc-*` compatibility wrappers for the roughly four existing sandboxes.
- `mountpoint -q` behavior on Docker Desktop VirtioFS bind mounts is expected to work but is unverified. The entrypoint check must be confirmed on the host and may need `/proc/self/mountinfo` instead.

## Sources

- Claude Code docs, advanced setup (install, version pinning, auto-update, npm install, Node 22+): https://code.claude.com/docs/en/setup (HIGH)
- Claude Code docs, managed settings (Linux path `/etc/claude-code/managed-settings.json`, `managed-settings.d/`): https://code.claude.com/docs/en/managed-settings (HIGH)
- Claude Code docs, settings and env vars (`CLAUDE_CONFIG_DIR`, `DISABLE_AUTOUPDATER`, `DISABLE_UPDATES`): https://code.claude.com/docs/en/settings, https://code.claude.com/docs/en/env-vars (HIGH)
- Local experiment: `CLAUDE_CONFIG_DIR=<scratch> claude mcp add --scope user ...` created `<scratch>/.claude.json` and left `~/.claude.json` unchanged (Claude Code 2.1.285) (HIGH)
- Local inspection and runs of `@opengsd/gsd-core@1.15.0`: `bin/install.js` (`--config-dir`, `--portable-hooks`, `saveLocalPatches`, manifest), package `engines`, two installs against a scratch config dir (HIGH)
- `ccusage@20.0.26` package metadata (native optional dependencies) and docs: https://ccusage.com/guide/environment-variables (MEDIUM/HIGH)
- Persisting Claude auth in dev containers (`CLAUDE_CONFIG_DIR` plus a volume, no symlinks): https://devopstar.com/2026/06/13/persisting-claude-and-gh-cli-auth-in-devcontainers/ (MEDIUM)
- anthropics/claude-code issue #14313 (`.claude.json` location in containers): https://github.com/anthropics/claude-code/issues/14313 (MEDIUM)
- Docker desktop-feedback #628 (macOS bind-mount root intermittently reports UID/GID 0): https://github.com/docker/desktop-feedback/issues/628 (MEDIUM)
- Archon #1279 (git "dubious ownership" on macOS bind mounts and the safe.directory fix): https://github.com/coleam00/Archon/issues/1279 (MEDIUM)
- Docker Desktop settings (VirtioFS is the default file sharing): https://docs.docker.com/desktop/settings-and-maintenance/settings/ (HIGH)
- Compose build spec (`additional_contexts`, `service:` references): https://docs.docker.com/reference/compose-file/build/ (HIGH)
- OpenCode config docs (`OPENCODE_CONFIG_DIR`, XDG resolution): https://opencode.ai/docs/config/ (MEDIUM)
- Existing code: `.planning/PROJECT.md`, `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`, `.planning/codebase/CONCERNS.md`, and the current `ClaudeCode/` and `OpenCode/` files (HIGH)

---
*Architecture research for: Docker sandbox containers for AI coding agents (macOS + Docker Desktop)*
*Researched: 2026-09-30*
