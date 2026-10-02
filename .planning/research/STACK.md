# Technology Stack

**Project:** GSD Agent Sandbox Containers (restructure milestone)
**Researched:** 2026-09-30
**Overall confidence:** HIGH (most claims verified empirically on an aarch64 Linux box against the real npm packages and official docs; Docker-specific behavior could not be run here and is flagged)

## Headline Decisions

1. **Base OS:** `ubuntu:24.04` (noble), pinned by tag and optionally by digest, exposed as a build arg. Not `latest`.
2. **Node.js 24 LTS (Krypton), from the official nodejs.org tarball**, not NodeSource. `@opengsd/gsd-core@1.15.0` declares `engines.node >=24`. The current Dockerfile's Node 20 is below that floor.
3. **Claude Code, GSD and ccusage are all installed with `npm install -g <pkg>@<pinned>` as root into `/usr/local`.** One mechanism, exact-version build args, all outside `/home/sandbox`.
4. **Persist Claude state by mounting a host dir at `/home/sandbox/.claude` AND setting `ENV CLAUDE_CONFIG_DIR=/home/sandbox/.claude` in the image.** With that env var set, `~/.claude.json` moves *inside* the config dir (verified), so one directory mount holds everything. Never bind-mount `.claude.json` as a single file.
5. **GSD: bake the npm package into the image, materialize it into the persisted config dir at container start when the version stamp differs** (`gsd-core --claude --global`, offline, about 0.3 s, verified idempotent and non-destructive). Do not use `--local`, do not use symlinks.
6. **Build layout:** `base/Dockerfile` is defined once; each agent Dockerfile says `FROM base`. Compose wires it with `additional_contexts: base: service:base` (or `docker-image://` for a standalone agent build). All version pins live in one env file and flow in as build args.

## Recommended Stack

### Base image (`gsd-sandbox-base`)

| Technology | Version (verified 2026-09-30) | Purpose | Why | Confidence |
|------------|-------------------------------|---------|-----|------------|
| Ubuntu | `24.04` (noble). Digest of the multi-arch index on 2026-09-18: `sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3` | OS | LTS with support to 2029, broadest third-party compat, `arm64` + `amd64`. `26.04` also exists on Docker Hub and `eclipse-temurin` publishes `-resolute` images, so moving is a one-arg change later. Claude Code supports "Ubuntu 20.04+". | HIGH |
| Node.js | `24.21.0` (Active LTS "Krypton", LTS until 2026-10-20, maintenance to 2028-04-30). Official tarball + SHA256 check | Runtime for npm-installed tools, user projects | Meets gsd-core's `>=24` floor and Claude Code's `>=22`. Node 26 becomes LTS on 2026-10-28; bump `NODE_VERSION` then, not before. Tarball avoids `curl \| bash` and a third-party apt repo. It ships npm 11. | HIGH |
| Eclipse Temurin JDK | `21.0.12_8` via `COPY --from=eclipse-temurin:21.0.12_8-jdk-noble /opt/java/openjdk /opt/java/openjdk` | JDK 21 LTS | Official Temurin image, multi-arch (amd64, arm64), pinnable by tag or digest, no apt repo/key to manage, same noble userland as the base. Set `JAVA_HOME=/opt/java/openjdk`. | MEDIUM-HIGH (see Alternatives) |
| Apache Maven | `3.9.16` from `archive.apache.org/dist/maven/maven-3/<v>/binaries/apache-maven-<v>-bin.tar.gz` + `.sha512` | Build tool | Ubuntu's apt Maven is old (3.8.x on noble). Maven 4.0.0 is still at `rc-7` on Central, so stay on 3.9.x. Tarball is arch-neutral (pure Java). | HIGH |
| uv | `0.12.21` via `COPY --from=ghcr.io/astral-sh/uv:0.12.21 /uv /uvx /usr/local/bin/` | Python tool/venv manager | Documented official pattern; pin to a specific tag (or digest). Faster and cleaner than pip. | HIGH |
| Python | apt `python3`, `python3-venv`, `python3-pip` (3.12 on noble) | System Python | Ubuntu 24.04 is PEP 668 "externally managed", so plain `pip install` is blocked; use `uv` or venvs for project work. `uv python install` gets other versions on demand. | HIGH |
| GitHub CLI (`gh`) | `2.102.0` from the GitHub release tarball (`gh_<v>_linux_${TARGETARCH}.tar.gz`, verify against `gh_<v>_checksums.txt`) | Git hosting ops | The cli.github.com apt repo only serves the latest version (checked), so it cannot be pinned. Release asset names use `amd64`/`arm64`, which equal Docker's `TARGETARCH`, so no arch mapping is needed. | HIGH |
| git, curl, ca-certificates, jq, ripgrep, unzip/zip, xz-utils, less, procps, openssh-client, make, build-essential, tzdata | apt (Ubuntu archive) | "Common Linux tools" | Everything an agent reaches for. `build-essential` is needed for native npm addons and Python wheels. Keep the apt list in **one** `RUN` with `--no-install-recommends` and `rm -rf /var/lib/apt/lists/*`. | HIGH |
| Non-root user | `sandbox`, created after `userdel -r ubuntu` | Unprivileged runtime user | **Ubuntu 24.04 images ship a default `ubuntu` user with UID/GID 1000**, which makes `useradd sandbox` fail or collide. Remove it first, then `useradd -m -u 1000 -s /bin/bash sandbox`. No `sudo` in the image: tools are added by editing the Dockerfile, which is the project's stated model. | HIGH |

### Per-agent image (`gsd-claude`, `FROM base`)

| Technology | Version (verified 2026-09-30) | Purpose | Why | Confidence |
|------------|-------------------------------|---------|-----|------------|
| `@anthropic-ai/claude-code` | `2.1.285` (npm `latest`; `stable` tag is `2.1.280`) | Claude Code CLI | `npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}` installs the *same native binary* as the standalone installer (via per-platform optional dep, e.g. `-linux-arm64`), lands in `/usr/local/bin`, is exact-pinnable, and needs no `curl \| bash` or `cp` from `/root/.local`. Anthropic's own reference devcontainer also installs via npm with a `CLAUDE_CODE_VERSION` build arg. Requires Node >=22 (warn-only on older). | HIGH |
| `@opengsd/gsd-core` | `1.15.0` (npm `latest`; `next` is an old `1.7.0-rc.6`, ignore it) | GSD | The only permitted GSD package. Installed globally, its bin `gsd-core` is the installer (`bin/install.js`), and `gsd-tools`, `gsd_run`, `gsd-mcp-server` are also provided. `engines`: node >=24, npm >=10. | HIGH |
| `ccusage` | `20.0.26` | Usage reports | v20 is a **native binary** distributed through per-platform optional deps (`@ccusage/ccusage-linux-arm64` / `-x64`) with a tiny Node launcher (`src/cli.js`). It detects Claude (and other agents, which helps later for OpenCode). Reads `$CLAUDE_CONFIG_DIR`, `~/.config/claude`, and `~/.claude` (all three verified by running it). | HIGH |

### Environment baked into the image

| ENV | Value | Why |
|-----|-------|-----|
| `CLAUDE_CONFIG_DIR` | `/home/sandbox/.claude` | Forces `.claude.json`, `.credentials.json`, `settings.json`, `projects/` etc. into one directory, which is the one bind-mounted from the host. Set in the Dockerfile (not the entrypoint) so it also reaches `docker exec` shells, which is how `cc-bash` gets in. Mounting at the default path *and* setting the var means tools that ignore the var still land in the same place. |
| `DISABLE_UPDATES` | `1` | Claude Code must not self-update; the image version wins. Documented for "distributing Claude Code through your own channels". Blocks background and manual `claude update`. Confirm with `claude doctor` on the host (MEDIUM: documented as an env var, but only the `settings.json` `env` form is shown in examples). |
| `JAVA_HOME` / `PATH` | `/opt/java/openjdk`, plus `$JAVA_HOME/bin` and Maven `bin` | Toolchains |
| `LANG` | `C.UTF-8` | Ubuntu image has no locale set; avoids mojibake in tool output. |
| `UV_LINK_MODE` | `copy` | uv's cache is on the container filesystem while the project/venv are on the host bind mount; hardlinks across filesystems fail with warnings. |
| `GSD_VERSION`, `CLAUDE_CODE_VERSION`, `CCUSAGE_VERSION` | copied from build args | Lets the entrypoint compare "what the image wants" with "what is in the persisted dir", and makes `docker inspect` show what is baked. |

## How the pieces fit (answers to the research questions)

### (c) Where Claude keeps state, and how to persist it

Verified on Claude Code 2.1.285 (`claude mcp add --scope user ...` with a throwaway `HOME` and `CLAUDE_CONFIG_DIR`): with `CLAUDE_CONFIG_DIR` set, `.claude.json` (and its `backups/`) is written **inside** the config dir; `$HOME` stayed empty.

| Item | Default (no env var) | With `CLAUDE_CONFIG_DIR=X` | Source |
|------|----------------------|----------------------------|--------|
| Global state/config JSON | `~/.claude.json` (outside `~/.claude`) | `X/.claude.json` | Verified by running it |
| Settings, skills, agents, hooks, plugins | `~/.claude/` | `X/` | Docs (env-vars) |
| Session transcripts | `~/.claude/projects/` | `X/projects/` | Docs (env-vars: "All settings, session history, and plugins are stored under this path") |
| Credentials (Linux) | `~/.claude/.credentials.json`, mode 0600 | `X/.credentials.json` | Docs (authentication) |

Consequences for the design:

- **Mount one host directory at `/home/sandbox/.claude`, set `CLAUDE_CONFIG_DIR=/home/sandbox/.claude`.** That is exactly what Anthropic's `.devcontainer/devcontainer.json` does (`CLAUDE_CONFIG_DIR=/home/node/.claude` plus a mount at that path).
- **Do not bind-mount `~/.claude.json` as a file.** Claude Code writes it via temp file + `rename`; `rename(2)` onto a bind-mount target fails with `EBUSY`, and the fallback in-place write can tear the file (multiple public issue reports, e.g. rappdw/sandy#400, noogram/cosmon#113). This is the main reason to prefer `CLAUDE_CONFIG_DIR`.
- **Migration note for the existing ~4 sandboxes:** today `.claude.json` sits at the root of the old mounted home (`<sandbox>/.claude.json`) and the rest in `<sandbox>/.claude/`. Under the new layout `.claude.json` must be **moved into** the state dir (`mv .claude.json .claude/.claude.json`), otherwise Claude will re-onboard (login survives because `.credentials.json` is already in `.claude/`).
- **Watch `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`** (v2.1.251+): it strips `CLAUDE_CONFIG_DIR` from child processes (Bash tool, hooks). Because the mount point equals the default `~/.claude`, `ccusage` and GSD still find the right dir even then, which is another reason to mount at the default path. Do not set the scrub flag unless needed.
- `CLAUDE_CODE_PROJECT_DIR_NAME` (documented) changes the `projects/` subdir name and is only read together with `CLAUDE_CONFIG_DIR`. Not needed here; noted so nobody "fixes" project history by accident.

### ccusage data discovery (verified, ccusage 20.0.26, arm64)

Created a fake session JSONL and ran `ccusage daily --offline` three ways with an empty `HOME`: `CLAUDE_CONFIG_DIR=<dir>`, `HOME/.claude`, and `HOME/.config/claude`. All three produced the same report ("Detected: Claude"). The ccusage website guide only mentions the two default paths; the env var support is in the binary/README and confirmed by the test. So with `CLAUDE_CONFIG_DIR` baked into the image, plain `ccusage`, `ccusage daily`, `ccusage monthly` work from any shell in the container with no extra config. Drop `--offline` in real use (fetches pricing; the container has network).

**Two traps found (both fix in the Dockerfile):**

1. **The native binary is shipped mode 0644** (`-rw-r--r--`) inside `@ccusage/ccusage-linux-*`. The Node launcher tries to `chmod 755` it at first run. In a root-owned global install run by the unprivileged `sandbox` user, that `chmod` fails ("ccusage native binary is not executable"). This is very likely what bit the previous attempt (which hand-chmodded a symlink target). Fix in the image build: `chmod 755 "$(npm root -g)"/ccusage/node_modules/@ccusage/*/bin/ccusage`, then smoke-test as `sandbox`.
2. **Optional dependencies must not be skipped.** `--omit=optional`, `--no-optional`, or an npm config that disables them removes the platform binary. Likewise, do not build with `--platform` different from the host without expecting npm to pick the *target* arch.

### (d) GSD `--global` vs `--local`, and getting it out of the image

Findings from `bin/install.js` (v1.15.0) and from actually running it against a scratch config dir on aarch64:

- `--global` installs into the **runtime's config dir**: `--config-dir <path>` if given, else `$CLAUDE_CONFIG_DIR`, else `~/.claude`. Verified that with only `CLAUDE_CONFIG_DIR` set and an empty `HOME`, everything landed in the config dir and nothing in `$HOME`.
- `--local` installs into `./.claude` of the **current working directory** (i.e., into the project repo on the host mount). `--config-dir` combined with `--local` is rejected ("Cannot use --config-dir with --local"). Wrong for this project: it pollutes the user's repository and is per-project.
- What a global Claude install writes into the config dir (about 17 MB, mostly `gsd-core/`): `skills/` (about 74 skill dirs), `agents/`, `gsd-core/` (workflows, templates, `VERSION`), `hooks/`, `scripts/`, manifest and state files (`gsd-file-manifest.json`, `gsd-install-state.json`, `.gsd-profile`, `.gsd-source`), and it **edits `settings.json`** to register about 20 hooks and a statusLine, with absolute paths to `<config dir>/hooks/...`.
- **It merges, it does not clobber.** I pre-seeded `settings.json` (custom `model`, `env`, a `Stop` hook), `.credentials.json` and `.claude.json`; after the install the user keys and the user hook were preserved (GSD hooks appended), and the credentials and `.claude.json` were byte-identical. Run time about 0.3 s, and no network is needed when run from an already-installed package (the `npx` fetch is the only network step).
- `gsd-core/VERSION` holds the installed version (`1.15.0`), a cheap stamp to compare.

**Recommendation: "bake the package, install the output at start if the stamp differs."**

```bash
# docker-entrypoint.sh (whole GSD story)
set -eu
have="$(cat "$CLAUDE_CONFIG_DIR/gsd-core/VERSION" 2>/dev/null || true)"
if [ "$have" != "$GSD_VERSION" ]; then
  mkdir -p "$CLAUDE_CONFIG_DIR"
  gsd-core --claude --global        # source = image's global npm package; target = $CLAUDE_CONFIG_DIR
fi
exec "$@"
```

- Uses `!=`, not `<`: image wins even if someone ran an in-session `gsd update` to something newer. That is the "image version always wins" requirement.
- The unconditional variant (run it every start) is also viable at 0.3 s and self-heals a deleted dir. Gating is preferred because it avoids rewriting `settings.json` and touching user-modified GSD files on every start (the installer keeps a manifest and backs up local patches).
- Because the entrypoint runs only at container start, the flow is: rebuild image (new `GSD_VERSION`), recreate container, entrypoint sees a different stamp, re-materializes. Login/history are untouched.
- Optional GSD flags to consider (verified present in `--help`): `--profile=core|standard|full` (persisted; default `full` costs about 12k tokens of skill descriptions at cold start) and `--portable-hooks` (writes `$HOME`-relative hook paths; documented for "WSL/Docker bind-mount setups"). Because the container path is fixed at `/home/sandbox/.claude`, absolute paths are fine; treat `--portable-hooks` as an optional hardening to verify on the host, not a requirement.

**Rejected: symlinks** from the persisted dir into an image-side install. GSD must write hook registrations into the *user's* `settings.json` (which lives in the persisted dir), its manifest/update logic expects real files, and a dangling symlink after an image change would silently break skills. **Rejected: installing into the image's own `~/.claude`** (the mount hides it and the settings hooks would still need to be in the persisted file).

### (b) Baking Claude Code, GSD, ccusage into the image

One layer, one mechanism, pinned, root-owned under `/usr/local` (never under `/home/sandbox`):

```dockerfile
ARG CLAUDE_CODE_VERSION
ARG GSD_VERSION
ARG CCUSAGE_VERSION
RUN --mount=type=cache,target=/root/.npm \
    npm install -g \
      @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
      @opengsd/gsd-core@${GSD_VERSION} \
      ccusage@${CCUSAGE_VERSION} \
 && chmod 755 "$(npm root -g)"/ccusage/node_modules/@ccusage/*/bin/ccusage \
 && ! npm ls -g --parseable 2>/dev/null | grep -q 'get-shit-done-cc'   # supply-chain guard
```

Do not add `--ignore-scripts` or `--omit=optional`: Claude Code's install links its native binary in a postinstall step, and Claude Code and ccusage both arrive via per-platform optional dependencies. Follow the install with build-time smoke tests **as the `sandbox` user** (`USER sandbox` then `RUN claude --version && ccusage --version && gsd-core --help >/dev/null && gsd-tools --help >/dev/null`), so permission bugs like the ccusage one fail the build instead of the first session.

## (e) Docker Compose / BuildKit usage

| Feature | Use | Notes |
|---------|-----|-------|
| `# syntax=docker/dockerfile:1` | Top line of every Dockerfile | Enables current BuildKit frontend features (cache mounts). BuildKit is the default in Docker Desktop. |
| Build args from one env file | `build.args: { NODE_VERSION: ${NODE_VERSION:?}, CLAUDE_CODE_VERSION: ${CLAUDE_CODE_VERSION:?} ... }`, values in a single `versions.env` used via `docker compose --env-file versions.env ...` (or a repo-root `.env`) | "Adding or bumping a tool = edit one line and rebuild." Changing an ARG value invalidates exactly the layers that use it, so no `--no-cache` and no `latest` are needed. |
| Shared base via `additional_contexts` | `services: { base: {build: {context: base, ...}, image: gsd-sandbox-base:local}, claude: {build: {context: ClaudeCode, additional_contexts: {base: "service:base"}}} }`. In `ClaudeCode/Dockerfile`: `FROM base`. | Documented syntax in the Compose Build spec. One Dockerfile works for any agent; OpenCode later reuses the same base by pointing its `additional_contexts` at `docker-image://gsd-sandbox-base:local`. The docs do **not** explicitly promise build ordering for `service:` contexts (Compose resolves the dependency in practice); **verify on the host** with `docker compose build claude` from a clean cache, and fall back to `docker compose build base && docker compose build claude` if it doesn't. |
| Image tags as the interface | `image: gsd-sandbox-base:local` and `image: gsd-claude:local`. Per-project run-only compose files reference `image: gsd-claude:local` and do not build. | Build once per host, run N project containers. A per-project `docker compose up` never rebuilds. |
| `--pull` | `docker compose build --pull` in the upgrade script | Refreshes the tag-pinned `ubuntu:24.04` and the `FROM` stages (Temurin, uv) when their tags move. |
| Cache mounts | `RUN --mount=type=cache,target=/root/.npm` (and `/var/cache/apt` with `sharing=locked` if apt is slow) | Optional speed-up. Not required for correctness. |
| Multi-arch | **Do not build multi-platform.** Build natively (Apple Silicon = `linux/arm64`) and keep the Dockerfile arch-neutral through `ARG TARGETARCH` | Only the Node tarball needs `x64`<->`amd64` mapping; `gh`, npm optional deps, uv/JDK images, and Maven are arch-aware or arch-neutral. This keeps amd64 hosts working without `platforms:`. **Do not** set `platform: linux/amd64` on Apple Silicon (QEMU/Rosetta emulation is slow and npm would install the x64 binaries). |
| Remove `VOLUME /home/sandbox` | Delete it from the Dockerfile | It creates anonymous volumes that shadow home content, which is the original bug class. |

Docker was not runnable in the research environment (this sandbox has no Docker); every Compose/BuildKit claim above comes from documentation and needs a host-side smoke test in the plan.

## Skeleton (shape, not final)

```dockerfile
# base/Dockerfile
# syntax=docker/dockerfile:1
ARG UBUNTU_IMAGE=ubuntu:24.04
ARG TEMURIN_IMAGE=eclipse-temurin:21.0.12_8-jdk-noble
ARG UV_IMAGE=ghcr.io/astral-sh/uv:0.12.21
FROM ${TEMURIN_IMAGE} AS jdk
FROM ${UV_IMAGE}      AS uv

FROM ${UBUNTU_IMAGE}
ARG TARGETARCH NODE_VERSION MAVEN_VERSION GH_VERSION
# apt packages (one RUN), userdel -r ubuntu, useradd -u 1000 sandbox
# Node tarball:  node-v${NODE_VERSION}-linux-$([ "$TARGETARCH" = amd64 ] && echo x64 || echo "$TARGETARCH").tar.xz + SHASUMS256 check
# Maven tarball + .sha512 check;  gh tarball (linux_${TARGETARCH}) + checksums check
COPY --from=jdk /opt/java/openjdk /opt/java/openjdk
COPY --from=uv  /uv /uvx /usr/local/bin/
ENV JAVA_HOME=/opt/java/openjdk LANG=C.UTF-8 UV_LINK_MODE=copy
# pre-create /home/sandbox/.claude and /home/sandbox/workspace owned by sandbox (mount targets)
USER sandbox
WORKDIR /home/sandbox/workspace
```

```dockerfile
# ClaudeCode/Dockerfile
# syntax=docker/dockerfile:1
FROM base
USER root
ARG CLAUDE_CODE_VERSION GSD_VERSION CCUSAGE_VERSION
ENV CLAUDE_CONFIG_DIR=/home/sandbox/.claude DISABLE_UPDATES=1 \
    CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION} GSD_VERSION=${GSD_VERSION} CCUSAGE_VERSION=${CCUSAGE_VERSION}
# npm install -g ... (see "Baking" above), COPY docker-entrypoint.sh
USER sandbox
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]
```

## Alternatives Considered

| Category | Recommended | Alternative | Why Not (or when) |
|----------|-------------|-------------|-------------------|
| Base OS | Ubuntu 24.04 | Ubuntu 26.04 | Available and viable (Temurin publishes `-resolute`), but newer and less battle-tested for third-party repos. Switch by changing `UBUNTU_IMAGE` + `TEMURIN_IMAGE` suffix. |
| Base OS | Ubuntu 24.04 | Debian slim / Alpine | Project asked for Ubuntu LTS. Alpine (musl) needs extra Claude Code workarounds (`USE_BUILTIN_RIPGREP=0`, libgcc, libstdc++). |
| Claude install | npm global, pinned | Native installer (`curl \| bash -s <ver>`) | Installs under `/root/.local`, needs a copy, is unpinned unless the arg is passed, and self-updates unless disabled. Keep as the fallback if npm distribution ever regresses. |
| Claude install | npm global, pinned | Anthropic apt repo (`downloads.claude.ai/claude-code/apt/stable`, signed) | Also good: it keeps many old versions (checked: dozens listed), so `apt-get install claude-code=2.1.285-1` pins. Needs key + repo setup; npm keeps all three tools on one mechanism. Reasonable swap if you prefer no-Node-dependency for Claude. |
| JDK | Temurin via `COPY --from` | Adoptium apt repo `temurin-21-jdk` | More conventional and integrates with `update-alternatives` and system `cacerts`, but adds a third-party apt repo/key and pinning depends on that repo retaining old versions (unverified). Use it if `COPY --from` causes TLS/cacerts or font issues (then also install `fontconfig`, `p11-kit`). |
| JDK | Temurin | Ubuntu `openjdk-21-jdk` | Zero extra sources, but the user asked for Temurin and Ubuntu's patch cadence differs. |
| Node | nodejs.org tarball | NodeSource apt (`setup_24.x`) | Existing approach; runs a remote script as root and adds a repo. Tarball is verifiable and pinnable. |
| Node | 24 LTS | 22 LTS (Maintenance) / 26 (LTS from 2026-10-28) | 22 fails gsd-core's `>=24` engine; 26 is not LTS until 4 weeks after this research. |
| Maven | 3.9.16 tarball | Maven 4.0.0-rc-7 | Still a release candidate. |
| Maven | tarball | apt `maven` | Old (3.8.x) and drags in a different default JDK. |
| Python tooling | uv (pinned image copy) | `curl -LsSf astral.sh/uv/install.sh \| sh` | Same tool, but a remote installer script and unpinned by default. |
| Shared base wiring | Compose `additional_contexts: service:` | `buildx bake` HCL with `contexts = { base = "target:base" }` | Bake gives explicit dependency graph and is excellent, but is another file format for a project that wants short, plain tooling. Reconsider if builds grow beyond 2-3 images. |
| Shared base wiring | Compose `additional_contexts` | `ARG BASE_IMAGE=...; FROM ${BASE_IMAGE}` with pre-built tag | Works with no special feature, but the two-step build order is manual. Good fallback. |
| Persisting state | One dir mount + `CLAUDE_CONFIG_DIR` | Two mounts (`~/.claude` dir + `~/.claude.json` file) | Single-file bind mount breaks atomic rename (`EBUSY`) and can corrupt state. |
| Persisting state | Host bind mount | Named Docker volume | User wants the state inspectable/backup-able on the Mac and easy to migrate from the existing folders. Bind mount it is. (The Anthropic devcontainer uses a named volume; different goals.) |
| GSD delivery | Bake pkg, materialize at start if stamp differs | `npx -y @opengsd/gsd-core@latest` at start | Network at every start, floating version, the current design's flaw. |
| GSD delivery | Bake + reconcile | GSD `--local` | Writes into the user's repo, cannot combine with `--config-dir`. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `ubuntu:latest` | Floating base makes rebuilds non-reproducible and can jump LTS series | `ubuntu:24.04` (optionally `@sha256:` digest) via `UBUNTU_IMAGE` arg |
| `get-shit-done-cc`, `gsd-build` (any form) | Compromised package; explicit project constraint | `@opengsd/gsd-core` only. Add the `npm ls -g` grep guard in the build. |
| `npx -y @opengsd/gsd-core@latest` in the entrypoint | Floating version, network at start, image no longer "wins" | `npm i -g @opengsd/gsd-core@${GSD_VERSION}` in the image; entrypoint runs the baked `gsd-core` |
| `.initialized` marker gating | Marker cannot express "version changed" | Compare `gsd-core/VERSION` with `$GSD_VERSION` |
| `VOLUME /home/sandbox` | Anonymous volume shadows home content | Nothing; declare mounts only in Compose |
| Host mount over `/home/sandbox` | Hides image-provided `.bashrc`, `.local`, etc. (the core bug) | Mount code at `/home/sandbox/workspace`, state at `/home/sandbox/.claude` |
| Bind-mounting `~/.claude.json` as a single file | `EBUSY` on atomic rename; torn writes | `CLAUDE_CONFIG_DIR` so it lives inside the mounted dir |
| Node 20 | End of its life window and below gsd-core's `>=24` engine | Node 24 LTS |
| `curl ... \| bash` for Node/uv/claude | Unpinned remote code as root | Pinned tarballs, `COPY --from` images, npm with exact versions |
| Skipping optional deps / scripts on `npm i -g` | Breaks Claude Code and ccusage native binaries | Default npm behavior |
| `sudo` in the image | Weakens the isolation story; tools belong in the Dockerfile | Add the tool to the Dockerfile and rebuild |
| Setting `platform: linux/amd64` on Apple Silicon | Emulation is slow and npm resolves x64 binaries | Native `arm64` build |

## Stack Patterns by Variant

**If the host is Intel Mac or Linux amd64:** same Dockerfiles; `TARGETARCH` resolves to `amd64`, npm picks the `linux-x64` optional deps, Node tarball mapping yields `x64`. No changes.

**If OpenCode goes on the same base (next milestone):** add `opencode-ai@<pin>` (npm `1.18.33` today, same optional-dep native-binary pattern) and `npm i -g @opengsd/gsd-core`, and materialize with `gsd-core --opencode --global` using `OPENCODE_CONFIG_DIR` (installer honors it). Use the identical entrypoint pattern with a per-agent stamp. ccusage already detects other agents.

**If someone truly needs a newer Claude Code without a full image rebuild:** bump `CLAUDE_CODE_VERSION` and rebuild only the agent image; the base layers are cached. Do not enable in-container self-update.

**If the `COPY --from` JDK misbehaves (TLS, fonts):** switch to the Adoptium apt package `temurin-21-jdk`.

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| `@opengsd/gsd-core@1.15.0` | Node >=24, npm >=10 | Installed and ran under Node 20.20 with only an engine warning here, but rely on the documented floor. |
| `@anthropic-ai/claude-code@2.1.285` | Node >=22 for the npm install step only | Runtime binary is native and does not use Node. |
| `ccusage@20.0.26` | Node (for launcher shim) + native `@ccusage/ccusage-linux-{arm64,x64}` | Binary mode 0644 in tarball; chmod in build. |
| Temurin `21.0.12_8-jdk-noble` | Ubuntu 24.04 base | Same distro series; do not mix `-noble` JDK with a 26.04 base (use `-resolute`). |
| Maven 3.9.16 | JDK 21 | Fine; Maven 3.9 supports JDK 8-21+. |
| uv 0.12.21 | Ubuntu 24.04 system Python 3.12 | Static binary; no glibc issues. |

## Installation (pins in `versions.env`, single source of truth)

```bash
# versions.env
UBUNTU_IMAGE=ubuntu:24.04
NODE_VERSION=24.21.0
TEMURIN_IMAGE=eclipse-temurin:21.0.12_8-jdk-noble
MAVEN_VERSION=3.9.16
UV_IMAGE=ghcr.io/astral-sh/uv:0.12.21
GH_VERSION=2.102.0
CLAUDE_CODE_VERSION=2.1.285
GSD_VERSION=1.15.0
CCUSAGE_VERSION=20.0.26

# Find newer versions before an upgrade (run on the host or anywhere with npm/curl)
npm view @anthropic-ai/claude-code dist-tags
npm view @opengsd/gsd-core dist-tags        # use "latest", never "next"
npm view ccusage version

# One-command upgrade shape (per project run compose only recreates)
docker compose --env-file versions.env build --pull
docker compose up -d --force-recreate      # state dir untouched; entrypoint re-materializes GSD
```

## Host-side verification checklist (Docker cannot run in the dev sandbox)

1. `docker compose build claude` from a cold cache builds base then agent; check `docker images` shows `gsd-sandbox-base:local` and `gsd-claude:local`.
2. In a fresh container: `id` (uid 1000 `sandbox`), `node -v` (24.x), `java -version`, `mvn -v`, `uv --version`, `gh --version`, `claude --version`, `claude doctor` (auto-updates disabled), `ccusage --version` **as `sandbox`**.
3. Log in, `docker compose down`, rebuild with a bumped `GSD_VERSION`, `up` again: still logged in, `cat ~/.claude/gsd-core/VERSION` shows the new version, `ls ~/.claude/.claude.json` exists inside the state dir on the Mac.
4. `ccusage daily` shows the earlier session after the rebuild.
5. `echo $HOME; ls -a ~` shows the image's `.bashrc` (home no longer hidden).

## Sources

- Claude Code docs, Advanced setup (install methods, npm, apt repo, versions, auto-update, `DISABLE_AUTOUPDATER`/`DISABLE_UPDATES`): https://code.claude.com/docs/en/setup (HIGH, official)
- Claude Code env vars (`CLAUDE_CONFIG_DIR`, `DISABLE_UPDATES`, `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB`, `CLAUDE_CODE_PROJECT_DIR_NAME`): https://code.claude.com/docs/en/env-vars.md (HIGH, official)
- Claude Code authentication, credential storage on Linux and under `CLAUDE_CONFIG_DIR`: https://code.claude.com/docs/en/authentication.md (HIGH, official)
- Anthropic reference devcontainer (`CLAUDE_CONFIG_DIR`, volume mount, `CLAUDE_CODE_VERSION` build arg): https://raw.githubusercontent.com/anthropics/claude-code/main/.devcontainer/devcontainer.json (HIGH, official)
- Claude Code `.claude.json` inside `CLAUDE_CONFIG_DIR`: verified by running `claude` 2.1.285 with throwaway `HOME`/`CLAUDE_CONFIG_DIR` (HIGH, empirical)
- Single-file bind-mount `EBUSY` issues: https://github.com/rappdw/sandy/issues/400 , https://github.com/noogram/cosmon/issues/113 , https://github.com/anthropics/claude-code/issues/25438 (MEDIUM, community reports, consistent)
- npm registry queries (versions, dist-tags, engines, optionalDependencies) for `@opengsd/gsd-core`, `@anthropic-ai/claude-code`, `ccusage`, `opencode-ai` on 2026-09-30 (HIGH)
- `@opengsd/gsd-core@1.15.0` tarball: `bin/install.js` help text and behavior, run against a scratch config dir on aarch64 (HIGH, empirical); repository https://github.com/open-gsd/gsd-core
- `ccusage@20.0.26` tarball (`src/cli.js`, optionalDependencies) and empirical runs with `CLAUDE_CONFIG_DIR`, `~/.claude`, `~/.config/claude` (HIGH, empirical); https://ccusage.com/guide/ (docs list only the two default paths)
- Node release schedule: https://raw.githubusercontent.com/nodejs/Release/main/schedule.json ; dist index https://nodejs.org/dist/index.json (HIGH)
- Docker Compose build spec (`additional_contexts`, `args`, `platforms`, `pull`): https://docs.docker.com/reference/compose-file/build/ (HIGH, official; build-order guarantee not documented)
- uv Docker guide (`COPY --from`, tag pinning, `UV_LINK_MODE=copy`): https://docs.astral.sh/uv/guides/integration/docker/ (HIGH, official); uv 0.12.21 and gh v2.102.0 from GitHub releases API (HIGH)
- Maven 3.9.16 and 4.0.0-rc-7 status from Maven Central metadata and Apache archive (HIGH)
- Docker Hub tags for `ubuntu` (24.04/26.04, digest) and `eclipse-temurin` (`21.0.12_8-jdk-noble`, `-resolute`, arm64 present) (HIGH)
- Ubuntu 24.04 image default `ubuntu` user (UID 1000): https://github.com/crops/poky-container/issues/115 , https://github.com/devcontainers/images/issues/1056 (MEDIUM-HIGH, multiple corroborating reports)

## Gaps / need host verification

- Compose `service:` context build ordering (documented syntax, ordering not promised in docs).
- `DISABLE_UPDATES=1` as a process env var (documented in the env-var table; examples show the `settings.json` `env` form). Verify with `claude doctor`.
- Temurin `COPY --from` JDK behavior with system TLS/fonts (expected fine, fallback listed).
- Docker Desktop bind-mount permission behavior for the state dir on macOS (VirtioFS normally maps ownership transparently; UID 1000 choice matters mainly on Linux hosts).
- `--portable-hooks` effect on GSD hooks in Docker (present in `--help`, not exercised).
- Files created inside the workspace by the container (`node_modules`, `.venv`, Maven `target/`) are Linux/arm64 artifacts visible to the host IDE; this is an architecture/pitfall topic, not a stack choice.

---
*Stack research for: Docker sandbox images for AI coding agents (Claude Code + GSD), macOS/Docker Desktop*
*Researched: 2026-09-30*
