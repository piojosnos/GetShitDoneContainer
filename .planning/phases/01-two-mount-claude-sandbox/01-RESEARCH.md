# Phase 1: Two-Mount Claude Sandbox - Research

**Researched:** 2026-09-30
**Domain:** Docker image layering (Ubuntu 24.04 + Node 24 + npm-pinned Claude Code), Docker Compose v2 bind-mount layout, per-sandbox persisted state on macOS/Docker Desktop (Apple Silicon)
**Confidence:** MEDIUM-HIGH. Image contents, versions, env-var wiring, and git/history/Claude file behavior were verified by running them in this dev sandbox. Compose refusal behavior (D-10) and `cap_drop` compatibility could NOT be verified here (no Docker) and are MEDIUM/LOW with explicit host checks.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Repo layout & naming**
- **D-01:** The new files go at the repo root: `base/Dockerfile`, `claude/Dockerfile`, `compose.yml`. Later phases add `versions.env` and `bin/sbx-*` beside them. `ClaudeCode/` and `OpenCode/` stay byte-for-byte untouched.
- **D-02:** The name prefix is `sbx`. The container is named `sbx-<name>` with no agent in the name. The compose project is `sbx-<name>`. Images are `sbx-base:local` and `sbx-claude:local`. This must never collide with the old `cc_<name>` / `cc_gsd_<name>`. — **Reversibility:** costly — the Phase 3/4 scripts and the Phase 5 migration docs all key on these names.

**Phase 1 image contents**
- **D-03:** The minimal base is `ubuntu:24.04` (a pinned tag, not `latest`) with curl, ca-certificates, git, gh, and Node 24. It also carries the `sandbox` user (UID 1000, non-root) and `git config --system safe.directory '*'`. JDK 21, Maven, Python, and uv wait for Phase 2.
- **D-04:** Claude Code is installed with `npm install -g @anthropic-ai/claude-code@<pinned version>` as root, so it lands outside home, and `ENV DISABLE_UPDATES=1` is set. For now the pin is a Dockerfile `ARG` default. Phase 2 moves it into `versions.env`. The native `curl | bash` installer is not used.
- **D-05:** There is no GSD in the Phase 1 image or sandbox. The Phase 1 sandbox is a test bed for the layout. The user keeps doing GSD work in the old sandboxes until Phase 2 bakes and syncs GSD. There must be no `npx` / runtime install of anything.
- **D-06:** Set `ENV CLAUDE_CONFIG_DIR=/home/sandbox/.claude` in the Claude image Dockerfile, not in the entrypoint only, so `docker exec` shells see it too. There's no `VOLUME` instruction for home or for state.

**Running without scripts**
- **D-07:** `compose.yml` is driven by env vars with fixed names: `SBX_NAME` and `SBX_DIR`. `SBX_AGENT` comes later. In Phase 1 the user passes them inline:
  `SBX_NAME=foo SBX_DIR=/Users/demian/Foo docker compose up -d`.
  The Phase 3 registry file (`~/.config/gsd-sandbox/sandboxes/<name>.env`) will hold these same lines and be passed with `--env-file`, and `compose.yml` must not need to change for that. — **Reversibility:** costly — the variable names become the registry file format.
- **D-08:** Set the project name inside `compose.yml` (top-level `name: sbx-${SBX_NAME}`) so `-p` is never needed. Also set `container_name: sbx-${SBX_NAME}`. Mark the variables as required (`${SBX_DIR:?...}`) so a missing variable fails loudly.
- **D-09:** The container stays alive with `sleep infinity` and `init: true`. The user opens any number of shells with `docker exec -it sbx-<name> bash`, and `docker compose down` stops it. This is the same workflow the user has today, minus bash-as-PID-1 and its ~10 s stop delay.
- **D-10:** Refuse to start if `<SBX_DIR>/workspace` or `<SBX_DIR>/state/claude` is missing, with a clear error. This stops Docker from silently creating empty folders after an `SBX_DIR` typo. For Phase 1 the documented setup is a one-time `mkdir -p`. Phase 3's `sbx-add` will create the folders.
- **D-11:** Never use `down -v` in docs or commands, unlike the old `cc-down.sh`. Stopping or removing the container never deletes workspace or state (LAY-04).

**State folder shape**
- **D-12:** The host layout per sandbox:
  ```
  <SBX_DIR>/
  ├── workspace/              -> /home/sandbox/workspace
  └── state/
      ├── claude/             -> /home/sandbox/.claude   (CLAUDE_CONFIG_DIR; .claude.json lands here)
      ├── shell/bash_history  (HISTFILE)
      ├── gh/                 (GH_CONFIG_DIR — gh auth login persists)
      └── git/config          (GIT_CONFIG_GLOBAL — git user.name/email persist)
  ```
  Only directory mounts are used, never single-file mounts. — **Reversibility:** costly — the Phase 5 migration docs and the users' existing state folders follow this shape.
- **D-13:** Persisting `gh` auth and git identity is in scope for Phase 1. The user chose it because today they survive by accident through the whole-home mount, and the new layout would otherwise silently lose them on recreate. Env vars point the tools at state, so nothing shadows home.

### Claude's Discretion
- Mount mechanics: either one `<SBX_DIR>/state` mount plus env vars pointing into subdirectories, or separate per-subdirectory mounts, as long as `/home/sandbox/.claude` stays the container path of Claude state. The same freedom covers whether `state/shell`, `state/gh`, and `state/git` are required up front (D-10) or auto-created on start when missing. Only `workspace/` and `state/claude/` must be required.
- Entrypoint shape: a base entrypoint for mount sanity checks, and whether to introduce the `entrypoint.d/` drop-in pattern now or in Phase 2.
- How HISTFILE is wired (image `/etc/bash.bashrc`, `/etc/profile.d`, or ENV), and whether history appends immediately (`PROMPT_COMMAND='history -a'`) so it's shared across concurrent exec shells.
- How the Node 24 binary is installed (official tarball with checksum is recommended by research), and the exact Claude Code pin.
- Where the Phase 1 usage and verification steps are documented (a short section in a new README or a doc next to `compose.yml`), as long as the old README content isn't broken for the old layout.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. gh/git persistence was treated as part of the "state survives recreate" goal, not as a new capability.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LAY-01 | `<sandbox>/workspace` appears at `/home/sandbox/workspace`; nothing mounted over `/home/sandbox`, so image `.bashrc`, `.local` are visible | Compose long-syntax bind to `/home/sandbox/workspace`; image pre-creates mount targets under `~/.local/state/sbx/*` so `.local` exists in the image; static check that no mount `target:` is `/home/sandbox` |
| LAY-02 | Claude login/settings/sessions in `<sandbox>/state/claude` via `CLAUDE_CONFIG_DIR`, dir mount, survive recreate + rebuild | Verified: with `CLAUDE_CONFIG_DIR` set, `.claude.json` (+ `.claude.json.lock/`, `backups/`) is written inside the config dir and `$HOME` stays empty; `.credentials.json` goes under the same dir on Linux (docs); Dockerfile `ENV`; dir mount at `/home/sandbox/.claude` |
| LAY-03 | Bash history persists in state and survives recreate | Verified locally: Dockerfile `ENV HISTFILE` + `ENV PROMPT_COMMAND="history -a"` gives immediate append and cross-shell sharing; `state/shell` dir mount |
| LAY-04 | Stop/remove/recreate never deletes workspace or state (no `down -v`, no `VOLUME /home/sandbox`) | Bind mounts only, no named/anonymous volumes; no `VOLUME` instruction; `down` docs: `-v` removes named + anonymous volumes (never documented/used) |
| IMG-02 | Claude image builds `FROM` the shared base and adds only agent-specific tools | `claude/Dockerfile`: `ARG BASE_IMAGE=sbx-base:local` + `FROM ${BASE_IMAGE}`; only Claude Code npm pkg + its ENV |
| IMG-05 | Images build and run natively on Apple Silicon | No `--platform`/`platform:` anywhere; arch mapped via `dpkg --print-architecture`; Node/gh/Claude arm64 artifacts verified to exist and run on aarch64 |
| IMG-06 | Agent runs as non-root `sandbox`; git works on mounted repos without "dubious ownership" | `userdel -r ubuntu` + `useradd -u 1000`; `git config --system safe.directory '*'` (honored in system scope per git docs) |
</phase_requirements>

## Summary

Phase 1 is a pure infrastructure phase: two small Dockerfiles, one `compose.yml`, one tiny entrypoint, and a usage/verification document. Everything it needs was checked against live artifacts this session: Node `24.21.0` arm64 tarball (SHA256 verified), `gh 2.102.0` arm64 tarball (checksum verified), and `@anthropic-ai/claude-code@2.1.285` installed via npm under Node 24 / npm 11 on aarch64 and run. The npm route installs the native `linux-arm64` binary (hard-linked over the `bin/claude.exe` placeholder by a network-free postinstall), so D-04 works as decided. `DISABLE_UPDATES=1` demonstrably blocks `claude update` ("Updates are disabled by your administrator"), and `CLAUDE_CONFIG_DIR` relocates `.claude.json` into the config dir while leaving `$HOME` empty.

The dev sandbox itself is a Docker Desktop macOS container with a VirtioFS whole-home mount (`virtiofs0` in `/proc/self/mountinfo`), so several "Mac bind-mount" behaviors were observable directly: `.claude.json` atomic writes, `mkdir`-style lock dirs, git config lockfile+rename, history appends, and rename-within-directory all work on a VirtioFS directory mount; `git status` works with no `safe.directory` configured at all (so "dubious ownership" is intermittent, not constant; keep the `*` setting anyway); `/proc/self/mountinfo` reliably identifies bind mounts.

Two findings change what the planner should assume. (1) **`bind.create_host_path: false` is not a reliable refusal mechanism**: Compose issue docker/compose#13602 (open, reported on Compose v5.0.2, still reproducing on Docker Desktop 4.70/4.71 per comments) shows a missing host path still being auto-created. D-10 therefore needs layered defenses plus a mandatory host-side test of what the user's actual Docker Desktop does. (2) **Compose requires the same variables for every subcommand** (`down`, `ps`, `config`), because the whole file is interpolated; the documented workflow should `export SBX_NAME SBX_DIR` once per terminal.

**Primary recommendation:** Build `base/` (Ubuntu 24.04, Node 24.21.0 tarball, gh 2.102.0 tarball, `sandbox` uid 1000, `safe.directory '*'`, image-level `ENV` for `HISTFILE`/`PROMPT_COMMAND`/`GH_CONFIG_DIR`/`GIT_CONFIG_GLOBAL`, pre-created mount targets, mount-checking entrypoint) and `claude/` (`FROM ${BASE_IMAGE}`, `npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code@2.1.285`, `CLAUDE_CONFIG_DIR`, `DISABLE_UPDATES=1`). Use **five per-directory bind mounts** in long syntax (workspace, state/claude, state/shell, state/gh, state/git), all required up front with one `mkdir -p`, and verify every success criterion on the Mac with the host commands in the Validation Architecture section.

## Project Constraints (from CLAUDE.md)

Extracted from `/home/sandbox/GetShitDoneContainer/.claude/CLAUDE.md` (read this session). Treated with the same authority as locked decisions.

- **Security:** Agents never run on the host; each container sees only its project's mount. No docker.sock, host `~/.ssh`, host `~/.claude`, or whole host home mounts.
- **Security:** GSD comes only from `@opengsd/gsd-core`; never `get-shit-done-cc` or `gsd-build`. (Phase 1 installs no GSD at all, D-05; add a grep guard so the bad names cannot appear.)
- **Platform:** macOS + Docker Desktop, likely arm64, bind mounts.
- **Simplicity:** plain bash, short scripts; Phase 1 has no helper scripts beyond the container entrypoint.
- **Verification:** Docker is not available in the dev sandbox; plans must include host-side manual verification steps.
- **Coexistence:** `ClaudeCode/`, `OpenCode/`, `cc-*` scripts stay untouched until Phase 5. New names must not collide with `cc_gsd_<name>` / `cc_<name>`. New work goes in new directories.
- **Conventions to follow in new files:** dashed section-banner comments in Dockerfiles with "why" comments above `RUN` steps; `RUN` chains with `&&` and apt-list cleanup at the end of the chain; `USER`/`WORKDIR` near the end; `ENTRYPOINT` in the Dockerfile and `CMD` overridable; shell scripts use `set -e` (plus `-u` here) and end with `exec "$@"`; YAML uses 2-space indentation; `# XXX:` marks experimental/disabled code.
- **Do not carry over:** `VOLUME /home/sandbox`, `stdin_open`/`tty` + bash-as-command, `down -v`, `ubuntu:latest`, `curl | bash`, hyphenated `docker-compose`.
- **GSD workflow enforcement:** edits to the repo happen through a GSD command (`/gsd-execute-phase` for planned phase work).

## Architectural Responsibility Map

Tiers for this container/infra domain (the web tiers in the template do not apply).

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Code (workspace) persistence and host IDE access | Host filesystem (bind mount) | Compose (mount declaration) | Must be a plain Mac folder; survives everything Docker does |
| Claude login/settings/history persistence | Host filesystem (`state/claude` dir mount) | Image `ENV CLAUDE_CONFIG_DIR` | One directory mount holds `.claude.json`, `.credentials.json`, `projects/`; env var makes it land inside the mount |
| Shell history / gh auth / git identity persistence | Host filesystem (`state/{shell,gh,git}` dir mounts) | Image `ENV` (HISTFILE, GH_CONFIG_DIR, GIT_CONFIG_GLOBAL) | Files inside directory mounts tolerate lockfile+rename; ENV reaches `docker exec` shells |
| Tools (node, gh, claude, git) | Image (build time, `/usr/local`) | — | Outside `/home/sandbox`, so no mount can hide them; image wins by rebuild |
| Non-root user, git `safe.directory` | Image (build time) | — | `/etc/gitconfig` is image-owned and cannot be edited by the agent |
| Static shell/tool environment | Image `ENV` | — | `docker exec` shells inherit image ENV but never run the entrypoint |
| Mount sanity check (is this really a bind mount, writable) | Entrypoint (start time) | — | Detects `docker run` without mounts (silent data loss) |
| Missing-host-dir refusal (D-10) | Compose `create_host_path: false` (prevention) | Entrypoint + documented preflight (detection) | No single mechanism is reliable on all Compose versions (see Pitfall 1) |
| Container lifecycle (name, project, init, keep-alive) | Compose (`name:`, `container_name`, `init`, `command`) | — | Replaces bash-as-PID-1; `docker compose down` is the only teardown |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ubuntu base image | `ubuntu:24.04` (tag locked by D-03) | OS | LTS, multi-arch (arm64 resolves natively on Apple Silicon); ships an `ubuntu` user at UID 1000 that must be removed [CITED: github.com/crops/poky-container/issues/115, github.com/devcontainers/images/issues/1056] |
| Node.js | `24.21.0` (Krypton LTS), official tarball | Runtime for npm install of Claude Code; user projects | [VERIFIED: nodejs.org/dist/index.json] latest v24.x is `v24.21.0 Krypton 2026-09-07`; tarball `node-v24.21.0-linux-arm64.tar.xz` SHA256 `6ad1325edbdb5649c379b75a237147a666c95d4f9ae8d340fef2d1575d289ad2` checked with `sha256sum -c` and extracted/run here (`v24.21.0`, npm `11.19.0`) |
| GitHub CLI | `2.102.0`, release tarball | `gh` | [VERIFIED: api.github.com/repos/cli/cli/releases/latest] v2.102.0 (published 2026-09-30); `gh_2.102.0_linux_arm64.tar.gz` verified against `gh_2.102.0_checksums.txt` and run here. The cli.github.com apt repo does carry arm64 (`InRelease` lists `Architectures: i386 amd64 armhf arm64`) but only serves the current version, so it cannot be pinned |
| `@anthropic-ai/claude-code` | `2.1.285` (npm dist-tag `stable`; `latest` is `2.1.286`, published 2026-09-30) | Claude Code CLI | [VERIFIED: npm view] installed with Node 24.21.0 / npm 11.19.0 on aarch64, `claude --version` printed `2.1.285 (Claude Code)`. Same version this dev sandbox runs (`/usr/local/bin/claude`). Needs Node >=22 only for the install step; the binary itself does not use Node [CITED: code.claude.com/docs/en/setup#install-with-npm] |
| Docker Compose | v2 (`docker compose`), latest upstream `v5.5.1` (2026-09-03) | Runtime shape | [VERIFIED: api.github.com/repos/docker/compose/releases/latest]. The version on the user's Mac is unknown — Phase 1 docs must say to run `docker compose version` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| apt packages | distro versions: `ca-certificates curl git less procps xz-utils` | Minimal base tooling | `xz-utils` is required to extract the Node `.tar.xz`; `git` on 24.04 is well above 2.35.3 (needed for `safe.directory '*'`) and 2.32 (`GIT_CONFIG_GLOBAL`) [ASSUMED: 24.04 ships git 2.43] |
| hadolint | `v2.15.1` (linux-arm64 binary) | Dockerfile lint in the dev sandbox | Optional Wave 0 static check; downloaded to a scratch dir, not a project dependency. [VERIFIED: ran here] |
| shellcheck | `v0.11.0` (`linux.aarch64.tar.gz`; the `.tar.xz` needs `xz`, which is absent in the dev sandbox) | Lint `base/sbx-entrypoint` | Optional Wave 0 static check. [VERIFIED: ran here] |
| js-yaml | `4.x` | Parse `compose.yml` in a static check (no `docker compose config` in the dev sandbox) | Optional; `npm install` into a scratch dir |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Node tarball + same-origin `SHASUMS256.txt` | GPG-verify `SHASUMS256.txt.asc` (what the official `nodejs/docker-node` Dockerfile does) [CITED: raw.githubusercontent.com/nodejs/docker-node/main/24/trixie-slim/Dockerfile] | Stronger authenticity but needs `gnupg` + key import; Phase 2 can harden by putting per-arch SHA256 values in `versions.env` |
| gh release tarball | cli.github.com apt repo (reuse of old `ClaudeCode/Dockerfile` block) | Fewer lines, but floating "latest" gh; contradicts the no-floating-versions goal (IMG-03 lands in Phase 2) |
| Five per-directory mounts | One `state/` mount at a neutral path + `.claude` symlink | Fewer compose lines, but `CLAUDE_CONFIG_DIR=/home/sandbox/.claude` would be a symlink into the mount (untested with Claude Code's realpath/lock handling) and it is what D-06 explicitly avoids. Rejected |
| Five per-directory mounts | `state/` mounted at a neutral path AND `state/claude` mounted again at `.claude` | 3 mounts, but the same host dir is exposed at two container paths and the typo-detection benefit (Docker never creates `state/claude`) is lost. Rejected |
| npm install of Claude Code | `curl https://claude.ai/install.sh \| bash -s <ver>` | Forbidden by D-04 |

**Installation (build + run, from the repo root on the Mac):**
```bash
docker build -t sbx-base:local   base/
docker build -t sbx-claude:local claude/
export SBX_NAME=demo SBX_DIR=/Users/demian/sbx-demo
mkdir -p "$SBX_DIR"/workspace "$SBX_DIR"/state/{claude,shell,gh,git}
docker compose up -d --wait
docker exec -it "sbx-$SBX_NAME" bash
```

**Version verification (run this session):**
```bash
npm view @anthropic-ai/claude-code dist-tags   # stable: 2.1.285, latest/next: 2.1.286
npm view @anthropic-ai/claude-code time        # 2.1.285 published 2026-09-29T17:32:09Z
curl -s https://nodejs.org/dist/index.json      # v24.21.0 Krypton 2026-09-07
gh release list (API)                           # v2.102.0 2026-09-30
```

## Package Legitimacy Audit

Only one external package is installed from a registry in Phase 1 (the Node tarball and gh tarball are checksum-verified release assets, not registry packages; the `@anthropic-ai/claude-code-linux-arm64` optional dependency is pulled in automatically).

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `@anthropic-ai/claude-code` | npm | first published 2025-02-24 (registry `created`); pinned version 2.1.285 is 1 day old | ~14.0M/wk | `homepage: https://github.com/anthropics/claude-code` (registry `repository` field is null) | SUS (`too-new`, `no-repository`) | Flagged — planner adds a `checkpoint:human-verify` before the first install. Mitigating evidence below |
| `@anthropic-ai/claude-code-linux-arm64` (optional dep, installed transitively) | npm | latest published 2026-09-30 | ~638K/wk | none in registry | SUS (`too-new`, `no-repository`) | Flagged with the parent; not installed directly |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** `@anthropic-ai/claude-code`, `@anthropic-ai/claude-code-linux-arm64` — `gsd_run query package-legitimacy check` returns SUS purely from `too-new` (the registry's *latest* version was published hours ago) and `no-repository` (registry metadata omits `repository`). Mitigating evidence gathered this session: the package and the `npm install -g` command are documented by Anthropic [CITED: code.claude.com/docs/en/setup#install-with-npm]; the version is pinned to 2.1.285, the same version already running in the dev sandbox; npm registry signatures exist for it (`dist.signatures` present; `npm audit signatures` is available); the postinstall script (`node install.cjs`, 223 lines) was read and contains no network calls, only a local link/copy plus a `sysctl` probe. The planner should still insert the human-verify checkpoint the audit protocol requires, and run `npm audit signatures` if desired.

## Architecture Patterns

### System Architecture Diagram

```
Mac (host)                                  Docker Desktop VM (Linux, arm64)
──────────                                  ────────────────────────────────
<SBX_DIR>/                                   docker compose up -d --wait
 ├─ workspace/ ──────────────┐               (env: SBX_NAME, SBX_DIR; name: sbx-$SBX_NAME)
 └─ state/                   │ bind (rw)             │
     ├─ claude/ ─────────────┤                        ▼
     ├─ shell/  ─────────────┤              container sbx-$SBX_NAME  (init: true → sleep infinity)
     ├─ gh/     ─────────────┤                ENTRYPOINT sbx-entrypoint: for each mount target
     └─ git/    ─────────────┘                  is_mount? writable? ──no──► print error, exit 1
                                                     │ yes
   docker exec -it sbx-<name> bash  ───────────────► exec "$@"  (sleep infinity)
   (inherits image ENV only; does NOT run entrypoint)
                                                     │
   mounts inside the container:                      ▼
     /home/sandbox/workspace            ◄─ workspace/        (cwd; repos live here)
     /home/sandbox/.claude              ◄─ state/claude/     (CLAUDE_CONFIG_DIR)
     /home/sandbox/.local/state/sbx/shell ◄─ state/shell/    (HISTFILE=…/bash_history)
     /home/sandbox/.local/state/sbx/gh    ◄─ state/gh/       (GH_CONFIG_DIR)
     /home/sandbox/.local/state/sbx/git   ◄─ state/git/      (GIT_CONFIG_GLOBAL=…/config)
   everything else in /home/sandbox (.bashrc, .local, …) = image layer, ephemeral, NOT hidden

Build time:  docker build base/  ──► sbx-base:local ──FROM──► docker build claude/ ──► sbx-claude:local
             (ubuntu:24.04 + node + gh + user)              (npm -g claude-code, ENV CLAUDE_CONFIG_DIR, DISABLE_UPDATES)
```

### Recommended Project Structure
```
GetShitDoneContainer/
├── base/
│   ├── Dockerfile          # FROM ubuntu:24.04; node, gh, sandbox user, ENV, mount targets, entrypoint
│   └── sbx-entrypoint      # mount sanity checks, then exec "$@" (mode 755 in git)
├── claude/
│   └── Dockerfile          # ARG BASE_IMAGE=sbx-base:local; FROM ${BASE_IMAGE}; claude-code + ENV
├── compose.yml             # one generic service; name: sbx-${SBX_NAME}
├── SANDBOX.md              # Phase 1 usage + host verification (folded into README in Phase 5)
├── tests/static-check.sh   # optional: dev-sandbox grep/lint assertions (see Validation Architecture)
├── ClaudeCode/  OpenCode/  # UNTOUCHED (coexistence)
└── README.md               # old-layout README, UNTOUCHED until Phase 5
```
Use `SANDBOX.md` (not `README.md`) so the old-layout README is not broken (CONTEXT discretion item). `docker build -t … base/` uses `base/` as the build context, so `COPY sbx-entrypoint …` is relative to `base/`, not the repo root.

### Pattern 1: Five per-directory bind mounts, long syntax, all required up front
**What:** One `volumes:` entry per state subdirectory, `type: bind`, `bind.create_host_path: false`, sources derived from `${SBX_DIR}`.
**When to use:** Always in this phase. Long syntax also survives host paths containing `:`; interpolation happens after YAML parse so spaces in `SBX_DIR` are fine.
**Why five, not one `state/` mount:** keeps `/home/sandbox/.claude` a real directory mount (D-06), every mount source is required and uniform, and no symlink is needed.
**Example:** (lint-checked only — YAML parsed with js-yaml; never run through `docker compose config`)
```yaml
# compose.yml (repo root). Phase 1 usage, no scripts:
#   export SBX_NAME=foo SBX_DIR=/Users/me/Foo
#   docker compose up -d --wait
# Every subcommand (up, down, ps, config) needs both variables: the whole file is interpolated.
# Never pass the volumes flag to `down`.
name: "sbx-${SBX_NAME:?SBX_NAME is required (lowercase letters, digits, - and _)}"

services:
  sandbox:
    image: sbx-claude:local
    pull_policy: never             # missing image = clear error, never a pull from Docker Hub
    container_name: "sbx-${SBX_NAME}"
    init: true                     # tini as PID 1: reaps zombies, SIGTERM stops `sleep` at once
    command: ["sleep", "infinity"] # shells come from `docker exec -it sbx-<name> bash`
    working_dir: /home/sandbox/workspace
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    labels:
      sbx.name: "${SBX_NAME}"
    volumes:
      - type: bind
        source: "${SBX_DIR:?SBX_DIR is required (absolute host path of the sandbox folder)}/workspace"
        target: /home/sandbox/workspace
        bind:
          create_host_path: false
      - type: bind
        source: "${SBX_DIR}/state/claude"
        target: /home/sandbox/.claude
        bind:
          create_host_path: false
      - type: bind
        source: "${SBX_DIR}/state/shell"
        target: /home/sandbox/.local/state/sbx/shell
        bind:
          create_host_path: false
      - type: bind
        source: "${SBX_DIR}/state/gh"
        target: /home/sandbox/.local/state/sbx/gh
        bind:
          create_host_path: false
      - type: bind
        source: "${SBX_DIR}/state/git"
        target: /home/sandbox/.local/state/sbx/git
        bind:
          create_host_path: false
```
`${VAR:?err}` semantics [CITED: docs.docker.com/reference/compose-file/interpolation/]: "substitutes the variable if set and non-empty, otherwise exits with an error message". `init: true` [CITED: docs.docker.com/reference/compose-file/services/]: "Runs an init process (PID 1) inside the container that forwards signals and reaps processes." `container_name` is global in the engine; Compose will not scale beyond one container (fine here).

### Pattern 2: Static environment in image `ENV`, never in the entrypoint
**What:** `HISTFILE`, `PROMPT_COMMAND`, `GH_CONFIG_DIR`, `GIT_CONFIG_GLOBAL` in `base/Dockerfile`; `CLAUDE_CONFIG_DIR`, `DISABLE_UPDATES` in `claude/Dockerfile`.
**Why:** `docker exec` shells inherit image ENV but never run `ENTRYPOINT`. Claude Code additionally "ignores a copy [of `CLAUDE_CONFIG_DIR`] delivered through a settings `env` block", so it must be in the process environment [CITED: code.claude.com/docs/en/env-vars].
**HISTFILE wiring (resolves the CONTEXT discretion item):** image `ENV` only — no edits to `/etc/bash.bashrc`, `~/.bashrc`, or `/etc/profile.d`. Verified locally with bash 5.3.9: with `HISTFILE` and `PROMPT_COMMAND='history -a'` exported and the stock `/etc/skel/.bashrc` (which sets `histappend`, `HISTCONTROL=ignoreboth`, `HISTSIZE=1000`, and does not touch `HISTFILE`/`PROMPT_COMMAND`) loaded, shell A's commands appear in the file before shell A exits, and shell B's `history` lists them. `history -a` per prompt is what makes history survive a container removed while a shell is still open (shells killed by `docker compose down` never run their exit-time history write). [ASSUMED: Ubuntu 24.04's bash 5.2 behaves the same.]

### Pattern 3: Entrypoint = mount sanity check + `exec "$@"`
**What:** a ~20-line bash entrypoint that fails loudly if a mount target is not a mount or not writable; no installs, no chown, no GSD. Use `/proc/self/mountinfo` field 5 instead of `mountpoint` (no dependency on the util-linux binary; verified here that it identifies the VirtioFS mount: `/home/sandbox: mount`, `/home/sandbox/GetShitDoneContainer: not mount`).
**entrypoint.d/ drop-ins:** defer to Phase 2 (no consumer in Phase 1). Keep a single optional extension point, `SBX_MOUNTS`, so the agent image can add `/home/sandbox/.claude` to the checked list without the base knowing about Claude.
```bash
#!/usr/bin/env bash
# base/sbx-entrypoint  (shellcheck 0.11.0 clean; behavior of the failing path verified in the dev sandbox)
set -eu

is_mount() { awk -v p="$1" '$5==p { f=1 } END { exit !f }' /proc/self/mountinfo; }

# SBX_MOUNTS: extra mount targets an agent image wants checked (e.g. /home/sandbox/.claude)
for d in /home/sandbox/workspace /home/sandbox/.local/state/sbx/shell \
         /home/sandbox/.local/state/sbx/gh /home/sandbox/.local/state/sbx/git ${SBX_MOUNTS:-}; do
  if ! is_mount "$d"; then
    echo "[sbx] ERROR: $d is not a bind mount; its data would be lost on recreate." >&2
    echo "[sbx]        Start the sandbox with 'docker compose up' (see SANDBOX.md)." >&2
    exit 1
  fi
  if [ ! -w "$d" ]; then
    echo "[sbx] ERROR: $d is not writable by $(id -un)." >&2
    exit 1
  fi
done

exec "$@"
```
Consequence: `docker run --rm sbx-claude:local claude --version` exits 1 (no mounts). Smoke tests must bypass it: `docker run --rm --entrypoint claude sbx-claude:local --version`. Document this in `SANDBOX.md`.

### Pattern 4: `base/Dockerfile`
```dockerfile
# Shared base for every sbx agent image. Nothing agent-specific belongs here.
FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG NODE_VERSION=24.21.0
ARG GH_VERSION=2.102.0

# --------------------------------------------------------------------------------
# OS packages (one layer, no recommends, apt lists removed)
# --------------------------------------------------------------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git less procps xz-utils \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------------------
# Node.js from the official tarball, checked against nodejs.org's SHASUMS256.txt.
# dpkg's arch names (amd64/arm64) are mapped to Node's (x64/arm64).
# --------------------------------------------------------------------------------
RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in amd64) node_arch=x64 ;; arm64) node_arch=arm64 ;; *) echo "unsupported arch: $arch" >&2; exit 1 ;; esac \
    && f="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
    && curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${f}" \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" | grep " ${f}\$" | sha256sum -c - \
    && tar -xJf "$f" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "$f"

# --------------------------------------------------------------------------------
# GitHub CLI from the release tarball (the cli.github.com apt repo cannot be pinned)
# --------------------------------------------------------------------------------
RUN arch="$(dpkg --print-architecture)" \
    && d="gh_${GH_VERSION}_linux_${arch}" \
    && curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${d}.tar.gz" \
    && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_checksums.txt" | grep " ${d}.tar.gz\$" | sha256sum -c - \
    && tar -xzf "${d}.tar.gz" -C /usr/local/bin --strip-components=2 --no-same-owner "${d}/bin/gh" \
    && rm "${d}.tar.gz"

# --------------------------------------------------------------------------------
# sandbox user. ubuntu:24.04 ships an "ubuntu" user/group at UID/GID 1000: remove it first.
# --------------------------------------------------------------------------------
RUN (userdel -r ubuntu || true) \
    && useradd -m -u 1000 -s /bin/bash sandbox \
    && test "$(id -u sandbox):$(id -g sandbox)" = "1000:1000"

# safe.directory in /etc/gitconfig (image-owned): bind-mounted repos never trigger "dubious ownership"
RUN git config --system safe.directory '*'

# Mount targets, pre-created and owned by sandbox so Docker never creates them as root.
# Creating them also makes ~/.local exist in the image.
RUN install -d -o sandbox -g sandbox \
      /home/sandbox/workspace \
      /home/sandbox/.local/state/sbx/shell \
      /home/sandbox/.local/state/sbx/gh \
      /home/sandbox/.local/state/sbx/git

# Static per-shell config: ENV reaches `docker exec` shells too (the entrypoint does not).
ENV HISTFILE=/home/sandbox/.local/state/sbx/shell/bash_history \
    PROMPT_COMMAND="history -a" \
    GH_CONFIG_DIR=/home/sandbox/.local/state/sbx/gh \
    GIT_CONFIG_GLOBAL=/home/sandbox/.local/state/sbx/git/config \
    LANG=C.UTF-8

COPY sbx-entrypoint /usr/local/bin/sbx-entrypoint
RUN chmod 755 /usr/local/bin/sbx-entrypoint

USER sandbox
WORKDIR /home/sandbox/workspace
ENTRYPOINT ["/usr/local/bin/sbx-entrypoint"]
CMD ["bash"]
```
Checks performed on this exact text: `hadolint v2.15.1 --ignore DL3008 --ignore DL3059 --ignore DL3066` clean; the Node-arm64 and gh-arm64 download/verify/extract commands were executed manually with the same flags (`tar -xJf … --strip-components=1 --no-same-owner`, single-member gh extract) and worked. It has NOT been built (no Docker). Additions to consider: `ENV NPM_CONFIG_UPDATE_NOTIFIER=false` is not needed in Phase 1.

### Pattern 5: `claude/Dockerfile`
```dockerfile
ARG BASE_IMAGE=sbx-base:local
FROM ${BASE_IMAGE}

ARG CLAUDE_CODE_VERSION=2.1.285

# Installed as root into /usr/local (outside home, so no mount can hide it). The postinstall
# step links the native arm64/x64 binary; --allow-scripts keeps it working on newer npm.
USER root
RUN npm install -g --allow-scripts=@anthropic-ai/claude-code "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && rm -rf /root/.npm \
    && install -d -o sandbox -g sandbox /home/sandbox/.claude

# Image ENV (not the entrypoint) so `docker exec` shells see these too.
ENV CLAUDE_CONFIG_DIR=/home/sandbox/.claude \
    DISABLE_UPDATES=1 \
    SBX_MOUNTS=/home/sandbox/.claude

USER sandbox
# Build-time smoke test as the runtime user: the pin must match what got installed.
RUN test "$(claude --version)" = "${CLAUDE_CODE_VERSION} (Claude Code)"
```
`SHELL` (pipefail) is inherited from the base image config. The `--allow-scripts=@anthropic-ai/claude-code` flag was run here with Node 24.21.0 / npm 11.19.0: without it npm 11.19 prints `npm warn install-scripts … not yet covered by allowScripts` (the postinstall still ran and the binary worked); with it, no warning. The flag is forward-compatibility insurance in case a later npm blocks unlisted install scripts by default [ASSUMED: future npm behavior]. The build-time `claude --version` assertion catches a skipped postinstall.

### Anti-Patterns to Avoid
- **`VOLUME /home/sandbox` or any `VOLUME`:** creates anonymous volumes that shadow image content and show up in `docker volume ls` (breaks success criterion 5).
- **Single-file bind mounts** (`.claude.json`, `.gitconfig`, `bash_history`): rename/lock semantics break; D-12 mandates directories only.
- **Env in the entrypoint only:** `docker exec` shells would miss `CLAUDE_CONFIG_DIR`, `HISTFILE`, `GH_CONFIG_DIR`, `GIT_CONFIG_GLOBAL`.
- **`chown -R` on mounts:** unnecessary on Docker Desktop for macOS (see Pitfall 5) and slow.
- **Any `npx`, `npm i`, `curl | bash` in entrypoint or `.bashrc`** (D-05).
- **`docker compose down -v`** and any command with the volumes flag (D-11). Word the README warning so a grep for the literal flag stays clean, or exclude docs from that grep.
- **Hyphenated `docker-compose`** (v1, EOL) anywhere in new docs.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Zombie reaping / signal forwarding for `sleep infinity` | A custom PID 1 script with `trap` | Compose `init: true` | Docker's bundled tini; removes the ~10 s `sleep`-as-PID-1 stop delay [CITED: docs.docker.com/reference/compose-file/services/; stop-time effect ASSUMED, verify on host] |
| Project-name/container-name derivation | A wrapper script computing `-p` | Top-level `name:` + `container_name:` in `compose.yml` | No scripts exist yet (D-08); Compose ≥ Jan 2023 interpolates the `name:` value [CITED: compose-spec/compose-go PR #347 "interpolate name set in yaml file", merged 2023-01-17] |
| Missing-variable errors | `if [ -z "$SBX_DIR" ]` in a script | `${VAR:?msg}` in `compose.yml` | Fails before any container/network is created |
| Mount detection in the entrypoint | Parsing `mount` output | `awk` over `/proc/self/mountinfo` field 5 | Verified on VirtioFS; no util-linux dependency |
| Checksum-verified downloads | `curl … \| bash` installers | Release tarball + `sha256sum -c` | Project forbids unpinned remote code as root (PITFALLS 12/23) |
| Git "dubious ownership" handling | Per-repo `git config --global --add safe.directory` at runtime | `git config --system safe.directory '*'` in the image | Runtime `--global` writes land in state (or vanish); system scope is image-owned and is a "protected configuration" scope git honors [CITED: git-scm.com/docs/git-config] |
| Persisting git identity / gh auth | Symlinks or single-file mounts of `~/.gitconfig`, `~/.config/gh/hosts.yml` | `GIT_CONFIG_GLOBAL` and `GH_CONFIG_DIR` pointing into directory mounts | Verified git creates the file itself and uses a lockfile in the same directory |

**Key insight:** every persistence problem in this phase is solved by "point the tool at a directory inside a directory mount via an env var set in the image". Nothing needs symlinks, single-file mounts, or start-time copying.

## Common Pitfalls

### Pitfall 1: `create_host_path: false` does not reliably refuse (D-10)
**What goes wrong:** With a typo'd `SBX_DIR`, Docker/Compose silently creates empty `…/workspace` and `…/state/*` directories at the typo'd path, the container starts, and Claude asks for login in an empty state dir.
**Why it happens:** Short syntax auto-creates missing host paths by design. Long syntax with `create_host_path: false` is *documented* to prevent it ("Creates a directory at the source path on host if there is nothing present. Defaults to `true`." [CITED: docs.docker.com/reference/compose-file/services/]), and the Engine's `--mount` semantics refuse: "By default, `--mount` does not automatically create a directory if the specified mount path does not exist on the host. Instead, it produces an error." [CITED: docs.docker.com/engine/storage/bind-mounts/]. But docker/compose#13602 (open, `kind/bug`, created 2026-02-21) reports that on Compose v5.0.2 (Docker Desktop, WSL2) `create_host_path: false` is ignored and the path is created root-owned. A related regression chain: compose-go PR #836 (2025-11-10) and PR #846 (2026-01-12, "Fix create_host_path default value is true"); a commenter observes the bug in compose-go v2.10.0 and v2.10.1 but not v2.9.1, and another reports no fix on Docker Desktop 4.71 (Compose v5.1.x). Separately, #13500 shows Compose v5.0.0 rendering `bind: {}`, after which the daemon's own `bind source path does not exist` error fires even for short syntax on Linux CI. Behavior therefore varies by Compose and Docker Desktop version, and current upstream latest is Compose v5.5.1 (unknown whether fixed). [VERIFIED: GitHub API issue/PR bodies and comments, this session]
**How to avoid (layered, since no single layer is proven):**
1. Keep `bind.create_host_path: false` on all five mounts (correct where honored; harmless elsewhere).
2. The entrypoint mount check (Pattern 3) guarantees the container never runs without real bind mounts (catches `docker run` and some misconfigurations), but it does NOT detect a Docker-created empty directory.
3. Document a one-line preflight in `SANDBOX.md` right above the `up` command (plain shell, not a script): `for d in workspace state/claude state/shell state/gh state/git; do [ -d "$SBX_DIR/$d" ] || echo "MISSING: $SBX_DIR/$d"; done`. This is the only mechanism independent of Compose behavior until Phase 3's `sbx-up` enforces it.
4. **Mandatory host test (see Validation Architecture H-10):** run `up` with a bogus `SBX_DIR`; expect an error and `ls` of the bogus path to fail afterwards. Record the actual result in the phase verification so Phase 3 knows which layer to rely on.
**Fallback if H-10 shows Docker creates the dirs:** add a required `env_file` pointing at a sentinel file inside `SBX_DIR` (an `env_file` path that does not exist makes Compose fail at load time, before anything is created). This changes the D-12 layout (one extra file at the `SBX_DIR` root, outside both mounts so the agent cannot edit it), so it needs user confirmation. See Open Question 1. [ASSUMED: `env_file` missing-file behavior and its ordering relative to bind-mount creation; not tested here]
**Warning signs:** `ls` of a mistyped `SBX_DIR` exists after a failed/odd start; root-owned dirs on a Linux host.

### Pitfall 2: Every `docker compose` subcommand needs `SBX_NAME` and `SBX_DIR`
**What goes wrong:** `docker compose down` in a fresh terminal errors with the `${SBX_DIR:?…}` message (or, for `ps`/`exec`, the `SBX_NAME` one).
**Why it happens:** The whole file is interpolated before any subcommand runs; the required-variable errors fire regardless of command. [CITED: docs.docker.com/reference/compose-file/interpolation/]
**How to avoid:** `SANDBOX.md` tells the user to `export SBX_NAME=… SBX_DIR=…` once per terminal. For `down`, `SBX_DIR` need not exist (any non-empty absolute value satisfies interpolation). `docker exec -it sbx-<name> bash` (D-09) needs no variables at all.
**Warning signs:** `required variable SBX_DIR is missing a value`.

### Pitfall 3: Top-level `name:` interpolation and project-name rules
**What goes wrong:** (a) On Compose older than early 2023, `name: "${USER}-project"` was interpolated to the variable *name*, not value (docker/compose#10171 on v2.14.1; fixed by compose-go PR #347, merged 2023-01-17). (b) Project names must contain only lowercase letters, digits, dashes, underscores and start with a lowercase letter or digit [CITED: docs.docker.com/compose/how-tos/project-name/]. `SBX_NAME=GSD_StaticSiteGenerator` (the Phase 3 registry example in ARCHITECTURE.md) is an **invalid** project name.
**How to avoid:** Phase 1 docs use lowercase names and state the rule. Host check H-03 runs `docker compose config | head -1` to see the interpolated name. Phase 3's `sbx-add` must validate/lowercase `SBX_NAME` (note for that phase). [ASSUMED: the user's Mac has Compose newer than Jan 2023 — check with `docker compose version`]

### Pitfall 4: Claude sessions are keyed by working directory
**What goes wrong:** After recreate, `claude --resume`/`--continue` shows nothing because the new shell started in a different directory.
**Why it happens:** History under `projects/` is keyed by the encoded absolute cwd (e.g. `-home-sandbox-workspace-hostrepo`). [CITED: .planning/research/PITFALLS.md Pitfall 10, observed live there]
**How to avoid:** `working_dir: /home/sandbox/workspace` so `docker exec` starts there, and host-verification steps always `cd ~/workspace/<same repo>` before `claude`.

### Pitfall 5: Ownership, `chown`, and "dubious ownership" on Docker Desktop macOS
**What goes wrong:** People add `chown -R` or UID-mapping logic.
**Observed here:** this dev sandbox is a Docker Desktop macOS container with a VirtioFS mount (`201 192 0:42 /demian/GetShitDoneContainer /home/sandbox rw,nosuid,nodev,relatime - virtiofs virtiofs0 …` in `/proc/self/mountinfo`). Files whose host owner is the Mac user appear owned by the container user (`sandbox`, uid 1001 here), i.e. ownership is synthetic, and there is no `/etc/gitconfig` and no `safe.directory` anywhere, yet `git status` in the repo succeeds. [VERIFIED: local observation this session] The intermittent root-owned-mount-root report (docker/desktop-feedback#628) is MEDIUM-confidence community evidence, so keep `safe.directory '*'`.
**How to avoid:** no `chown` on mounts; pre-create mount targets in the image owned by `sandbox`; `safe.directory '*'` in `/etc/gitconfig`; test with a repo created **on the Mac** (host-owned) and run `git status` inside (H-06).

### Pitfall 6: `ubuntu:24.04` already owns UID/GID 1000
**What goes wrong:** `useradd -u 1000 sandbox` fails ("UID 1000 is not unique") or silently gets another UID.
**How to avoid:** `userdel -r ubuntu` first (with `|| true` so a differing image layout does not break the build) and assert `id -u sandbox`/`id -g sandbox` equal `1000`/`1000` in the same `RUN` (present in the base Dockerfile above). [CITED: github.com/crops/poky-container/issues/115] [ASSUMED: `userdel -r` also removes the `ubuntu` group in 24.04; the assert would catch it — host build reveals immediately]

### Pitfall 7: Keyless Console login stores credentials outside `CLAUDE_CONFIG_DIR`
**What goes wrong:** If the user logs in with a Claude **Console** account via "Sign in with your Console account" (no API key), Claude Code stores an Anthropic *profile* under `~/.config/anthropic` (`$ANTHROPIC_CONFIG_DIR`), outside the state mount; it is lost on recreate. [CITED: code.claude.com/docs/en/authentication — "Claude Code stores that kind of sign-in outside the configuration directory"; platform.claude.com/docs/en/manage-claude/wif-reference — config dir resolution `$ANTHROPIC_CONFIG_DIR`, then `~/.config/anthropic`]
**How to avoid / scope:** claude.ai subscription logins (Pro/Max/Team/Enterprise) keep `.credentials.json` under `CLAUDE_CONFIG_DIR` on Linux [CITED: code.claude.com/docs/en/authentication]. Document "use a claude.ai login; Console keyless sign-in is not persisted in Phase 1". Do not add a sixth mount for it now. [ASSUMED: the user logs in with a claude.ai account]

### Pitfall 8: An entrypoint that exits 1 is invisible with plain `up -d`
**What goes wrong:** `docker compose up -d` returns before the container exits, so the user sees success and an exited container.
**How to avoid:** document `docker compose up -d --wait` ("Wait for services to be running|healthy. Implies detached mode." [CITED: docs.docker.com/reference/cli/docker/compose/up/]) and `docker compose logs` for the error text. [ASSUMED: `--wait` returns non-zero when the container exits immediately; verify in H-10/H-12]

### Pitfall 9: `docker run` smoke tests now fail by design
The entrypoint refuses to run without the bind mounts (Pattern 3). Use `docker run --rm --entrypoint claude sbx-claude:local --version` or `--entrypoint bash -c '…'` for image-only checks.

### Pitfall 10: Stray `.env` or shell variables silently feed interpolation (Phase 3 note)
Compose loads a project-directory `.env` by default; `--env-file` *replaces* that default [CITED: docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/]. Shell-environment variables have the highest precedence for interpolation, so `SBX_NAME`/`SBX_DIR` exported in the terminal override values in a `--env-file` registry file [CITED: same page; "Variables from your shell environment" listed highest]. Phase 3 scripts should run compose as `env -u SBX_NAME -u SBX_DIR -u SBX_AGENT docker compose --env-file "$registry_file" …` (macOS `env -u` is supported) and registry paths must be absolute with no `~` (env files do not expand it). Phase 1 documents `export` usage only and makes no `.env` file.

### Pitfall 11: Stale `.claude.json.lock` directory
Claude Code uses a directory lock (`.claude.json.lock/`) inside the config dir (observed: created empty on first use, also on VirtioFS). A container killed mid-write could leave one; it is inside the state mount, so it persists. [VERIFIED: local run] Low impact; mention in troubleshooting only (remove `state/claude/.claude.json.lock` if Claude hangs at start).

## Code Examples

### Env wiring check (run inside the container; covers LAY-02/03 and D-06/D-13)
```bash
# Source: local verification + Claude Code docs. Expected: all five variables present via `docker exec`.
docker exec sbx-demo env | grep -E '^(CLAUDE_CONFIG_DIR|DISABLE_UPDATES|HISTFILE|PROMPT_COMMAND|GH_CONFIG_DIR|GIT_CONFIG_GLOBAL)='
```

### What `CLAUDE_CONFIG_DIR` does (verified here on aarch64 and on the VirtioFS mount)
```bash
# Empty HOME + empty config dir; `claude auth status` only creates state, it does not need a login.
HOME=$T/home CLAUDE_CONFIG_DIR=$T/state/claude DISABLE_UPDATES=1 claude auth status
ls -la $T/state/claude   # .claude.json (0600), .claude.json.lock/ (dir), backups/
ls -la $T/home           # empty
HOME=… CLAUDE_CONFIG_DIR=… DISABLE_UPDATES=1 claude update
# -> "Updates are disabled by your administrator. Contact your IT team to get the latest version."
```
`claude auth status` prints JSON with `"loggedIn": false/true`, `"configDirectory"`, `"projectsDirectory"`, so it is a scriptable login check for the host verification.

### git identity persistence (verified)
```bash
GIT_CONFIG_GLOBAL=$T/state/git/config git config --global user.name "T"   # file did not exist: git created it (lockfile + rename in the same dir)
GIT_CONFIG_GLOBAL=$T/nodir/config   git config --global user.name X       # parent dir missing -> "could not lock config file … No such file or directory"
GIT_CONFIG_GLOBAL=$T/state/git/nonexist git config --get user.name; echo $?   # missing file on read: empty, exit 1, no error
```
The parent directory must exist (it does: it is a mount target pre-created in the image and mounted from the host).

### Host-side interactions that matter
```bash
# Login (once) — Claude prints a URL; the browser shows a code; paste it at "Paste code here if prompted"
# (the documented flow for containers) [CITED: code.claude.com/docs/en/authentication]
docker exec -it -w /home/sandbox/workspace/hostrepo sbx-demo claude
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Native `curl \| bash` Claude installer copied to `/usr/local/bin` | `npm install -g @anthropic-ai/claude-code@<pin>` (native binary via per-platform optional dep + postinstall) | documented by Anthropic; v2.1.198+ needs Node 22+ for the install step | Pinnable, no `~/.local/share/claude` copy, no background self-update in `~/.local` |
| Node 20 via NodeSource `setup_20.x` | Node 24 LTS official tarball | Node 20 EOL 2026-04-30 (per PITFALLS); 24 is Active LTS | `@opengsd/gsd-core` (Phase 2) declares `engines.node >=24` |
| `docker-compose` v1 (hyphenated) | `docker compose` v2 plugin | v1 EOL 2023 | Use `docker compose` everywhere |
| Compose short-syntax bind mounts (auto-create) | Long syntax with `bind.create_host_path: false` | spec feature; enforcement unreliable across versions (see Pitfall 1) | Don't rely on it alone |
| npm always runs dependency install scripts | npm 11.19 warns `install-scripts … not yet covered by allowScripts`; `--allow-scripts=<pkg>` | observed with npm 11.19.0 this session | Pass the flag; keep the build-time smoke test |

**Deprecated/outdated:**
- `ubuntu:latest`: drifts series (the dev sandbox is 26.04); D-03 pins 24.04.
- `ClaudeCode/` pattern (`VOLUME /home/sandbox`, whole-home bind mount, `down -v`): superseded by this phase; left untouched until Phase 5.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `userdel -r ubuntu` in `ubuntu:24.04` succeeds (or fails harmlessly) and also removes group `ubuntu`/GID 1000 | Pitfall 6, base Dockerfile | Build fails at the `id` assert; fix is one line (`groupdel`). Surfaces on the first Mac build |
| A2 | Bash 5.2 (Ubuntu 24.04) honors `ENV HISTFILE` and `ENV PROMPT_COMMAND` the same as the tested 5.3.9 | Pattern 2 | LAY-03 fails in H-08; fallback is appending the two assignments to `/etc/bash.bashrc` |
| A3 | `bind.create_host_path: false` is honored by the user's Docker Desktop/Compose | Pitfall 1 | Typo'd `SBX_DIR` silently creates empty dirs; mitigated by the preflight line and fallback sentinel |
| A4 | `cap_drop: [ALL]` and `no-new-privileges` do not break Claude Code, git, node, or VirtioFS writes by uid 1000 | Pattern 1 (compose) | A host step fails for no obvious reason; remove `cap_drop` first, keep `no-new-privileges` |
| A5 | `init: true` + `sleep infinity` stops in well under 10 s (tini forwards SIGTERM; `sleep` exits) | Don't Hand-Roll | `docker compose down` slow; cosmetic (set `stop_grace_period: 2s` if so) |
| A6 | `docker compose up -d --wait` returns non-zero when the entrypoint exits 1 | Pitfall 8 | User must read `docker compose ps`/`logs`; doc wording adjusts |
| A7 | The user logs in with a claude.ai subscription account (credentials land in `CLAUDE_CONFIG_DIR`) | Pitfall 7 | Console keyless login would be lost on recreate; needs a `~/.config/anthropic` mount or `ANTHROPIC_CONFIG_DIR` |
| A8 | The interactive first-run login flow works in the container via the paste-code path (only `claude auth status`/`update`/`--version` were run here; no TTY or browser) | Code Examples | LAY-02 cannot be confirmed until H-07 |
| A9 | `claude doctor` reports auto-updates disabled when `DISABLE_UPDATES=1` is set (docs show the `DISABLE_AUTOUPDATER` `env` form; `claude update` was verified blocked) | Pattern 5 | `claude doctor` line reads differently; `claude update` refusal already proves the behavior |
| A10 | Docker Desktop's default file sharing includes `/Users/demian/...` so `SBX_DIR` under `/Users` mounts without extra config | Pitfall/Installation | "Mounts denied"; add the path in Docker Desktop Settings |
| A11 | The user's Mac has Docker Compose newer than Jan 2023 and `docker compose` v2 | Pitfall 3 | `name:` interpolation wrong; upgrade Docker Desktop |
| A12 | `git` on `ubuntu:24.04` is 2.43.x (≥ 2.35.3 for `safe.directory '*'`, ≥ 2.32 for `GIT_CONFIG_GLOBAL`) | Supporting stack | `safe.directory '*'` ignored; asserted by H-06 |
| A13 | Same-origin `SHASUMS256.txt` (no GPG) is an acceptable integrity check for Phase 1 | Alternatives | Weaker authenticity than the official node image; Phase 2 can pin hashes in `versions.env` |
| A14 | Future npm versions may block unlisted install scripts by default, so `--allow-scripts` is needed | Pattern 5 | None if wrong (flag is harmless); the build assert covers the skipped-postinstall case |

## Open Questions

1. **Which D-10 mechanism actually works on the user's Mac?**
   - What we know: long-syntax `create_host_path: false` is documented to refuse; docker/compose#13602 (open) reports it being ignored on Compose v5.0.2, with comments up to 2026-08 still reproducing; the Engine itself refuses for `--mount` without `bind-create-src`.
   - What's unclear: behavior on the user's exact Docker Desktop + Compose versions.
   - Recommendation: ship `create_host_path: false` + entrypoint + documented preflight line; run H-10 and record the result. If Docker creates the dirs, ask the user to approve the `env_file` sentinel fallback (an extra file at `<SBX_DIR>/` root, outside both mounts), since it amends the D-12 layout. Do not block the plan on this.

2. **Is `cap_drop: [ALL]` acceptable on the user's Docker Desktop?**
   - What we know: nothing in Phase 1's runtime needs capabilities (non-root user, VirtioFS writes performed by the host process).
   - What's unclear: no Docker here to test.
   - Recommendation: include it; H-06/H-07/H-09 exercise git, claude, and file writes. If anything fails only because of it, drop `cap_drop` and keep `no-new-privileges`.

3. **Console keyless login persistence (Pitfall 7)** — confirm the user uses a claude.ai login. If not, add `ANTHROPIC_CONFIG_DIR` + a mount in a later phase.

4. **Script-free D-10 preflight ergonomics** — the user must run a pasted loop each time until Phase 3. Acceptable for a test-bed phase? (If not, the env_file sentinel fallback removes the need.)

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker / `docker compose` (dev sandbox) | building/running images | ✗ | — | Host-side manual verification on the Mac (all success criteria) |
| Docker Desktop + Compose v2 (user's Mac) | everything runtime | ✓ (assumed) | unknown | `docker compose version` is step H-00 |
| Node / npm (dev sandbox) | scratch verification of pins | ✓ | node v20.20.2, npm 10.8.2 | — |
| bash (dev sandbox) | entrypoint lint/run | ✓ | 5.3.9 | — |
| git (dev sandbox) | git behavior tests | ✓ | 2.53.0 | — |
| python3 (dev sandbox) | xz extraction workaround; YAML-free scripting | ✓ | 3.14.4 (no PyYAML, no pip) | — |
| shellcheck (dev sandbox) | lint `sbx-entrypoint` | ✗ installed / ✓ downloadable | v0.11.0 `linux.aarch64.tar.gz` | `bash -n` only |
| hadolint (dev sandbox) | lint Dockerfiles | ✗ installed / ✓ downloadable | v2.15.1 `hadolint-linux-arm64` | `grep` assertions only |
| xz / `file` / `strings` (dev sandbox) | misc | ✗ | — | python `tarfile` for xz; not needed in images (base installs `xz-utils`) |
| Network egress (dev sandbox) | npm/GitHub/nodejs.org downloads | ✓ | — | — |

**Missing dependencies with no fallback:** none for planning; Docker's absence is handled by host-side verification.
**Missing dependencies with fallback:** shellcheck/hadolint (optional static checks; download into a scratch dir, not the repo).

## Validation Architecture

> `workflow.nyquist_validation` is `true` in `.planning/config.json` (read this session), so this section is included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None (infrastructure phase: Dockerfiles, YAML, one bash script). Two tiers: (1) static assertions runnable in the dev sandbox; (2) manual host-side checks on the Mac (human-verify, `human_verify_mode: end-of-phase`) |
| Config file | none — Wave 0 adds `tests/static-check.sh` (plain bash) |
| Quick run command | `bash tests/static-check.sh` |
| Full suite command | `bash tests/static-check.sh` + host checklist H-00..H-13 on the Mac |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LAY-01 | workspace bind at `/home/sandbox/workspace`; no mount over `/home/sandbox`; `.bashrc`/`.local` visible | static + host | static: `grep -Fq 'target: /home/sandbox/workspace' compose.yml` and `! grep -nE 'target: /home/sandbox"?$' compose.yml`; host H-05 | ❌ Wave 0 |
| LAY-02 | state dir mount + `CLAUDE_CONFIG_DIR`, no single-file mount | static + host | static: `grep -q 'CLAUDE_CONFIG_DIR=/home/sandbox/.claude' claude/Dockerfile`; `grep -c 'create_host_path: false' compose.yml` = 5; host H-07, H-09 | ❌ Wave 0 |
| LAY-03 | history persists | static + host | static: `grep -q 'HISTFILE=/home/sandbox/.local/state/sbx/shell/bash_history' base/Dockerfile` and `grep -q 'PROMPT_COMMAND="history -a"' base/Dockerfile`; host H-08 | ❌ Wave 0 |
| LAY-04 | no data deletion paths | static + host | static: `! grep -nE '^\s*VOLUME\b' base/Dockerfile claude/Dockerfile`; `! grep -nE 'down.*(-v|--volumes)' compose.yml SANDBOX.md` (phrase the doc warning to avoid the literal flag); host H-09 (`docker volume ls`) | ❌ Wave 0 |
| IMG-02 | claude image FROM base, agent-specific only | static | `grep -Fxq 'FROM ${BASE_IMAGE}' claude/Dockerfile && grep -Fxq 'ARG BASE_IMAGE=sbx-base:local' claude/Dockerfile` | ❌ Wave 0 |
| IMG-05 | native arm64, no emulation | static + host | static: `! grep -rnE 'platform:|--platform|linux/amd64' base claude compose.yml`; host H-01 (`uname -m` = `aarch64`, image arch `arm64`) | ❌ Wave 0 |
| IMG-06 | non-root uid 1000, `safe.directory` | static + host | static: `grep -Fq "git config --system safe.directory '*'" base/Dockerfile`; host H-04, H-06 | ❌ Wave 0 |
| D-02/D-05/coexistence | names, no GSD/npx, old layout untouched | static | `! grep -rnE 'cc_gsd\|\bcc_' base claude compose.yml`; `! grep -rnE 'get-shit-done-cc\|gsd-build\|\bnpx\b' base claude compose.yml`; `git diff --quiet <phase-base-commit> -- ClaudeCode OpenCode` | ❌ Wave 0 |
| D-03/D-04 pins | no floating versions, no `curl \| bash` | static | `! grep -nE '(:latest\|@latest)' base/Dockerfile claude/Dockerfile compose.yml`; `! grep -nE 'curl[^\|]*\|[[:space:]]*(ba)?sh' base/Dockerfile claude/Dockerfile`; `grep -Fxq 'FROM ubuntu:24.04' base/Dockerfile` | ❌ Wave 0 |
| Syntax | Dockerfile/script/YAML well-formed | static | `bash -n base/sbx-entrypoint`; optional `shellcheck base/sbx-entrypoint`; optional `hadolint --ignore DL3008 --ignore DL3059 --ignore DL3066 base/Dockerfile claude/Dockerfile`; optional js-yaml parse of `compose.yml` (5 bind mounts, all `type: bind`) | ❌ Wave 0 |

All grep patterns above were exercised against the lint-checked draft files in this session (all PASS; note use `grep -Fx` for the literal `${BASE_IMAGE}` lines).

### Host-side verification (copy-paste on the Mac; one line per check)

Setup once:
```bash
cd <repo>
docker compose version                                   # H-00: Compose v2, note version
docker build -t sbx-base:local   base/
docker build -t sbx-claude:local claude/
export SBX_NAME=demo SBX_DIR=/Users/demian/sbx-demo
mkdir -p "$SBX_DIR"/workspace "$SBX_DIR"/state/{claude,shell,gh,git}
docker compose config | head -3                          # H-03: shows `name: sbx-demo`
docker compose up -d --wait
```

| ID | Success criterion | Command(s) on the Mac | Pass condition |
|----|-------------------|-----------------------|----------------|
| H-01 | SC1 native arm64 | `docker image inspect sbx-base:local sbx-claude:local --format '{{.Architecture}}'`; `docker exec sbx-demo uname -m`; watch `build`/`up` output | `arm64` ×2; `aarch64`; no "requested image's platform … does not match" warning |
| H-02 | SC1 FROM chain | `docker history sbx-claude:local \| tail -n +1 \| head -30` and `grep '^FROM' claude/Dockerfile` | claude layers sit on top of the base layers (first `FROM` is `${BASE_IMAGE}`) |
| H-03 | D-08 interpolation | `docker compose config \| head -3`; `SBX_NAME=demo docker compose config` (SBX_DIR unset) | name shows `sbx-demo`; second command fails with the `SBX_DIR is required` message |
| H-04 | SC2 non-root, UID | `docker exec sbx-demo id` | `uid=1000(sandbox) gid=1000(sandbox)` |
| H-05 | SC2 mounts/home | `docker exec sbx-demo sh -c 'touch /home/sandbox/workspace/x.txt; ls -a /home/sandbox'`; `ls "$SBX_DIR/workspace"` | `x.txt` visible on the Mac; `ls -a` shows `.bashrc` and `.local` |
| H-06 | SC2 git | `git init "$SBX_DIR/workspace/hostrepo"` (on the Mac, host-owned); `docker exec -w /home/sandbox/workspace/hostrepo sbx-demo git status`; `docker exec sbx-demo git config --system --get-all safe.directory`; `docker exec sbx-demo sh -c 'git config --global user.name T && cat $GIT_CONFIG_GLOBAL'` | no "dubious ownership"; system value `*`; identity file appears at `$SBX_DIR/state/git/config` |
| H-07 | SC3 login | `docker exec -it -w /home/sandbox/workspace/hostrepo sbx-demo claude` → log in, `/exit`; `ls -la "$SBX_DIR/state/claude"`; `docker exec sbx-demo claude auth status` | `.claude.json`, `.credentials.json`, `projects/` on the Mac; `"loggedIn": true`; `docker exec sbx-demo sh -c 'ls -a $HOME \| grep -c "^\.claude\.json$"'` prints `0` (no `~/.claude.json`) |
| H-08 | SC4 history | `docker exec -it sbx-demo bash` → `echo marker-$RANDOM`, **leave the shell open**; in another terminal `docker compose down && docker compose up -d --wait`; new `docker exec -it sbx-demo bash` → `history \| grep marker` | marker is present; also `grep marker "$SBX_DIR/state/shell/bash_history"` on the Mac |
| H-09 | SC3 recreate+rebuild; SC5 | `docker compose down`; `docker build --no-cache -t sbx-base:local base/ && docker build --no-cache -t sbx-claude:local claude/`; `docker compose up -d --wait`; `docker exec sbx-demo claude auth status`; in shell `cd ~/workspace/hostrepo && claude --continue` (or `--resume`); `ls -R "$SBX_DIR" \| head`; `docker volume ls`; `docker inspect sbx-demo --format '{{json .Mounts}}'` | still `loggedIn: true`; earlier session resumable; all workspace/state files still on the Mac; `docker volume ls` lists no volume for this sandbox; every Mount is `"Type":"bind"` with a directory source, none single-file |
| H-10 | D-10 refusal | `SBX_NAME=demo SBX_DIR=/Users/demian/does-not-exist docker compose up -d --wait; echo rc=$?; ls /Users/demian/does-not-exist` | `up` errors and the path does NOT exist afterwards. If the path exists, Pitfall 1's fallback is needed — record the Compose/Docker Desktop versions |
| H-11 | D-09 | `time docker compose down`; `docker ps -a --filter name=sbx-demo` | returns in a few seconds (not ~10 s); container gone; `$SBX_DIR/{workspace,state}` intact |
| H-12 | Entry check | `docker run --rm sbx-claude:local claude --version; echo rc=$?` and `docker run --rm --entrypoint claude sbx-claude:local --version` | first: error "not a bind mount", rc=1; second: `2.1.285 (Claude Code)` |
| H-13 | Env + no self-update | `docker exec sbx-demo env \| grep -E '^(CLAUDE_CONFIG_DIR\|DISABLE_UPDATES\|HISTFILE\|GH_CONFIG_DIR\|GIT_CONFIG_GLOBAL)='`; `docker exec sbx-demo claude update`; `docker exec -it sbx-demo claude doctor`; `docker exec sbx-demo sh -c 'ls ~/.local/share/claude 2>&1'` | all vars present via `exec`; "Updates are disabled by your administrator"; doctor shows auto-updates disabled; no `~/.local/share/claude` |

Coexistence on the Mac: `docker ps` still lists any running `cc_gsd_*` containers untouched; `git status` in the repo shows no changes under `ClaudeCode/` or `OpenCode/`.

### Sampling Rate
- **Per task commit:** `bash tests/static-check.sh`
- **Per wave merge:** `bash tests/static-check.sh` (+ optional `shellcheck`/`hadolint` if downloaded)
- **Phase gate:** static checks green, then the user runs H-00..H-13 on the Mac before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `tests/static-check.sh` — the assertions in the map above (plain bash; exit non-zero on the first failure); covers LAY-01..04, IMG-02, IMG-05, IMG-06, naming, pins, coexistence
- [ ] `SANDBOX.md` — Phase 1 usage (build, `export`, `mkdir -p`, preflight loop, `up -d --wait`, `docker exec`, `down`) and the H-00..H-13 checklist
- [ ] Optional scratch-dir tool downloads (not committed): `shellcheck v0.11.0 linux.aarch64.tar.gz`, `hadolint v2.15.1 hadolint-linux-arm64`

## Security Domain

> `security_enforcement` is not `false` in `.planning/config.json` (`security_asvs_level: 1`, `security_block_on: high`), so this section applies.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (delegated) | Login is Claude Code's own OAuth flow; no auth code written in this phase |
| V3 Session Management | no | — |
| V4 Access Control | yes (isolation) | Exactly five bind mounts, nothing else from the host (no docker.sock, no `~/.ssh`, no host home); non-root user; `no-new-privileges`; `cap_drop: [ALL]` (host-verify) |
| V5 Input Validation | yes (small) | `SBX_NAME`/`SBX_DIR` flow into a project name and mount sources: `${VAR:?}` for presence, Compose's project-name rules for `SBX_NAME`, long-syntax mounts so a `:` in a path cannot reshape a short-syntax spec; Phase 3 validates names |
| V6 Cryptography / supply chain | yes | Node and gh downloads verified with `sha256sum -c` against upstream checksum files; Claude Code pinned to an exact npm version (registry signatures present); no `curl \| bash`; no runtime installs |
| V14 Configuration | yes | Pinned base tag, no `latest`, no `VOLUME`, no secrets in Dockerfile/compose, non-root `USER`, image-owned `/etc/gitconfig` |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Supply-chain code execution via unpinned installers | Tampering | Exact version pins, checksum-verified tarballs, build-time `claude --version` assertion; grep guard forbids `npx`, `@latest`, `curl \| bash`, `get-shit-done-cc`, `gsd-build` |
| Container escape / host reach via extra mounts (docker.sock, home, `~/.ssh`) | Elevation of privilege | Only the five declared mounts; static check `! grep docker.sock`; `docker inspect … .Mounts` in H-09 |
| Credentials readable by the agent (`.credentials.json`, gh `hosts.yml` plaintext fallback in `state/gh`) | Information disclosure | Inherent to running the agent with its own login; state lives in `state/`, a sibling of (not inside) `workspace/` so it is not inside any git work tree; `.credentials.json` is written 0600 [CITED: code.claude.com/docs/en/authentication]. gh falls back to a plain-text file when no credential store exists [CITED: cli.github.com/manual/gh_auth_login] — document as accepted risk (DOC-03 in Phase 5) |
| Agent plants `.git/hooks`, IDE run configs in `workspace/` that the Mac later executes | Tampering / EoP | Out of scope for Phase 1; noted for the Phase 5 threat-model README (DOC-03) |
| `safe.directory '*'` weakens git's ownership check | Spoofing | Accepted: single-user, single-mount container (PITFALLS "Technical Debt Patterns") |
| Silent creation of host dirs at a mistyped path | Tampering (clutter) | Layered D-10 defenses (Pitfall 1) |
| Root-owned files / privilege via running as root | EoP | `USER sandbox`; `useradd` uid 1000; `--dangerously-skip-permissions` is refused as root anyway [CITED: PITFALLS.md, Claude docs] |

## Sources

### Primary (HIGH confidence)
- Local verification in this session (aarch64, Docker Desktop macOS VirtioFS container): installed `@anthropic-ai/claude-code@2.1.285` with Node 24.21.0/npm 11.19.0 and npm 10.8.2; `claude --version`, `claude auth status`, `claude update` with `CLAUDE_CONFIG_DIR`/`DISABLE_UPDATES`; git `GIT_CONFIG_GLOBAL` create/lock/missing-parent cases; bash `HISTFILE`/`PROMPT_COMMAND` with the stock skel `.bashrc`; `/proc/self/mountinfo` mount detection; hadolint/shellcheck/js-yaml runs on the drafts
- https://code.claude.com/docs/en/setup — npm install (Node 22+, per-platform optional dep, postinstall link, "Do NOT use sudo npm install -g" workstation warning), auto-update and `DISABLE_AUTOUPDATER`/`DISABLE_UPDATES`, Ubuntu 20.04+ support
- https://code.claude.com/docs/en/env-vars — `CLAUDE_CONFIG_DIR` (requires v2.1.227+; ignored when delivered via settings `env`), `DISABLE_UPDATES`, `DISABLE_AUTOUPDATER`
- https://code.claude.com/docs/en/authentication — Linux credentials under `CLAUDE_CONFIG_DIR` (`.credentials.json`, 0600), paste-code login in containers, keyless Console sign-in stored outside the config dir
- https://platform.claude.com/docs/en/manage-claude/wif-reference — `$ANTHROPIC_CONFIG_DIR` then `~/.config/anthropic`
- https://docs.docker.com/reference/compose-file/services/ — `create_host_path`, `init`, `container_name`, `command`, `working_dir`
- https://docs.docker.com/reference/compose-file/interpolation/ — `${VAR:?err}`
- https://docs.docker.com/engine/storage/bind-mounts/ — `-v` auto-creates, `--mount` errors
- https://docs.docker.com/compose/how-tos/project-name/ — name precedence and character rules
- https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/ — shell env over file values, `--env-file` replaces default `.env`, `docker compose config`
- https://docs.docker.com/reference/cli/docker/compose/up/ and …/down/ — `--wait`, `--force-recreate`, `down -v` semantics
- https://git-scm.com/docs/git-config — `safe.directory` honored only in system/global/command scope; `*` wildcard; `GIT_CONFIG_GLOBAL`
- https://cli.github.com/manual/gh_help_environment and …/gh_auth_login — `GH_CONFIG_DIR`, plain-text fallback
- https://raw.githubusercontent.com/nodejs/docker-node/main/24/trixie-slim/Dockerfile — tarball install pattern, `--no-same-owner`, arch mapping
- GitHub API: docker/compose issues #13602 (open), #13500, #13310, #12176, #10171; compose-go PRs #836, #846, #347; docker/compose latest release v5.5.1; cli/cli v2.102.0 assets; koalaman/shellcheck v0.11.0; hadolint v2.15.1
- nodejs.org dist index + `SHASUMS256.txt` for v24.21.0; `npm view` for `@anthropic-ai/claude-code` (dist-tags, engines, optionalDependencies, time, scripts, signatures)
- In-repo (read this session): `.planning/phases/01-two-mount-claude-sandbox/01-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/research/{ARCHITECTURE,STACK,PITFALLS}.md`, `.claude/CLAUDE.md`, `ClaudeCode/Dockerfile`, `ClaudeCode/docker-compose.yml` (line 6: `container_name: cc_gsd_${PROJECT_NAME}`), `ClaudeCode/cc-up.sh` (line 7: `docker-compose -p "cc_${PROJECT_NAME}" up -d`), `.planning/config.json`

### Secondary (MEDIUM confidence)
- https://github.com/crops/poky-container/issues/115 and https://github.com/devcontainers/images/issues/1056 — `ubuntu:24.04` ships user `ubuntu` at UID 1000 (`userdel -r ubuntu` workaround); the Ubuntu 26.04 dev sandbox shows the same (`getent passwd 1000` → `ubuntu`)
- https://github.com/docker/desktop-feedback/issues/628 (via ARCHITECTURE.md) — intermittent UID 0 on bind-mount root

### Tertiary (LOW confidence / ASSUMED)
- See Assumptions Log A1–A14; the notable ones are Docker-side behaviors that cannot run in the dev sandbox (create_host_path on the user's Docker Desktop, `cap_drop`, `init` stop time, `--wait` exit status).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every pin and download path was executed or checksum-verified on aarch64 this session (except the Docker build itself)
- Architecture (mount layout, ENV wiring, file-behavior on VirtioFS): HIGH for what was run here; MEDIUM for Docker/Compose semantics not runnable here
- Pitfalls: MEDIUM-HIGH — Compose `create_host_path` state is from live GitHub issue data and explicitly flagged as needing a host test

**Research date:** 2026-09-30
**Valid until:** ~7 days for version pins (Claude Code ships roughly daily; `latest` is already 2.1.286; Node 26 becomes LTS 2026-10-28 per STACK.md), 30 days for the layout/Compose findings
