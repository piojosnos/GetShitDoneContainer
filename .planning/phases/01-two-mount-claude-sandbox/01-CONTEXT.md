# Phase 1: Two-Mount Claude Sandbox - Context

**Gathered:** 2026-09-30
**Status:** Ready for planning

<domain>
## Phase Boundary

The user can run a Claude Code sandbox on the Mac using a documented `docker compose` command. There are no helper scripts yet. Code lives in `<SBX_DIR>/workspace` and appears at `/home/sandbox/workspace`. Claude state lives in `<SBX_DIR>/state/claude` and appears at `/home/sandbox/.claude` via `CLAUDE_CONFIG_DIR`. Nothing is mounted over `/home/sandbox`. The Claude login survives both a container recreate and an image rebuild.

Requirements: LAY-01, LAY-02, LAY-03, LAY-04, IMG-02, IMG-05, IMG-06.

Not in this phase: JDK/Maven/Python/uv, GSD, ccusage, `versions.env` (all Phase 2); `sbx-*` scripts and the registry (Phase 3+); touching the old `ClaudeCode/` / `OpenCode/` layout (Phase 5).

</domain>

<decisions>
## Implementation Decisions

### Repo layout & naming
- **D-01:** The new files go at the repo root: `base/Dockerfile`, `claude/Dockerfile`, `compose.yml`. Later phases add `versions.env` and `bin/sbx-*` beside them. `ClaudeCode/` and `OpenCode/` stay byte-for-byte untouched.
- **D-02:** The name prefix is `sbx`. The container is named `sbx-<name>` with no agent in the name. The compose project is `sbx-<name>`. Images are `sbx-base:local` and `sbx-claude:local`. This must never collide with the old `cc_<name>` / `cc_gsd_<name>`. — **Reversibility:** costly — the Phase 3/4 scripts and the Phase 5 migration docs all key on these names.

### Phase 1 image contents
- **D-03:** The minimal base is `ubuntu:24.04` (a pinned tag, not `latest`) with curl, ca-certificates, git, gh, and Node 24. It also carries the `sandbox` user (UID 1000, non-root) and `git config --system safe.directory '*'`. JDK 21, Maven, Python, and uv wait for Phase 2.
- **D-04:** Claude Code is installed with `npm install -g @anthropic-ai/claude-code@<pinned version>` as root, so it lands outside home, and `ENV DISABLE_UPDATES=1` is set. For now the pin is a Dockerfile `ARG` default. Phase 2 moves it into `versions.env`. The native `curl | bash` installer is not used.
- **D-05:** There is no GSD in the Phase 1 image or sandbox. The Phase 1 sandbox is a test bed for the layout. The user keeps doing GSD work in the old sandboxes until Phase 2 bakes and syncs GSD. There must be no `npx` / runtime install of anything.
- **D-06:** Set `ENV CLAUDE_CONFIG_DIR=/home/sandbox/.claude` in the Claude image Dockerfile, not in the entrypoint only, so `docker exec` shells see it too. There's no `VOLUME` instruction for home or for state.

### Running without scripts
- **D-07:** `compose.yml` is driven by env vars with fixed names: `SBX_NAME` and `SBX_DIR`. `SBX_AGENT` comes later. In Phase 1 the user passes them inline:
  `SBX_NAME=foo SBX_DIR=/Users/demian/Foo docker compose up -d`.
  The Phase 3 registry file (`~/.config/gsd-sandbox/sandboxes/<name>.env`) will hold these same lines and be passed with `--env-file`, and `compose.yml` must not need to change for that. — **Reversibility:** costly — the variable names become the registry file format.
- **D-08:** Set the project name inside `compose.yml` (top-level `name: sbx-${SBX_NAME}`) so `-p` is never needed. Also set `container_name: sbx-${SBX_NAME}`. Mark the variables as required (`${SBX_DIR:?...}`) so a missing variable fails loudly.
- **D-09:** The container stays alive with `sleep infinity` and `init: true`. The user opens any number of shells with `docker exec -it sbx-<name> bash`, and `docker compose down` stops it. This is the same workflow the user has today, minus bash-as-PID-1 and its ~10 s stop delay.
- **D-10:** Refuse to start if `<SBX_DIR>/workspace` or `<SBX_DIR>/state/claude` is missing, with a clear error. This stops Docker from silently creating empty folders after an `SBX_DIR` typo. For Phase 1 the documented setup is a one-time `mkdir -p`. Phase 3's `sbx-add` will create the folders.
- **D-11:** Never use `down -v` in docs or commands, unlike the old `cc-down.sh`. Stopping or removing the container never deletes workspace or state (LAY-04).

### State folder shape
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project scope and constraints
- `.planning/PROJECT.md` — core value, constraints (coexistence, security, arm64, plain bash)
- `.planning/REQUIREMENTS.md` — LAY-01..04, IMG-02, IMG-05, IMG-06 definitions
- `.planning/ROADMAP.md` §Phase 1 — the success criteria verified on the Mac

### Architecture and pitfalls (research)
- `.planning/research/ARCHITECTURE.md` — the mount layout, the `CLAUDE_CONFIG_DIR` rationale, the rejected alternatives (single-file mount, symlink, allowlist), the container ownership map, and the macOS "dubious ownership" note
- `.planning/research/PITFALLS.md` — single-file bind mount EBUSY, `CLAUDE_CONFIG_DIR` in entrypoint only, `VOLUME`, `down -v`, UID/ownership
- `.planning/research/STACK.md` — Ubuntu 24.04, Node 24 tarball install, npm-pinned Claude Code, `DISABLE_UPDATES=1`
- `.planning/research/SUMMARY.md` — overview of the above

### Existing code (old layout — reference only, do not modify)
- `ClaudeCode/Dockerfile`, `ClaudeCode/docker-compose.yml`, `ClaudeCode/docker-entrypoint.sh`, `ClaudeCode/cc-*.sh`
- `.planning/codebase/CONCERNS.md` — floating tags, `curl | bash`, and other issues not to repeat

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ClaudeCode/Dockerfile`: its gh apt-repo install block (keyring + sources list) can be reused in `base/Dockerfile`. Its `useradd -m -s /bin/bash sandbox` pattern stays the same.
- The Dockerfile comment style (dashed section banners, and "why" comments above RUN steps) should carry over.

### Established Patterns
- Plain bash with `set -e`, and an entrypoint that ends with `exec "$@"`.
- `docker exec -it <container> /bin/bash` for shells (`cc-bash.sh`). D-09 keeps this workflow.
- The old compose uses `stdin_open`/`tty` plus bash as the command, `VOLUME /home/sandbox`, and `down -v`. Do not carry these over.

### Integration Points
- None with the old layout. The new files are fully separate so both layouts run side by side.
- Phase 2 will add `versions.env`, the rest of the toolchain, GSD bake-and-sync, and ccusage on top of `base/` and `claude/`. Phase 3 wraps `compose.yml` with the registry (D-07).

</code_context>

<specifics>
## Specific Ideas

- Keep the user's current mental model: start once, attach many shells, bring it down.
- Phase 3 registry caveat: variables exported in the user's shell override `--env-file` values, so scripts should rely only on the registry file and not on the terminal's environment.
- Every success criterion is verified manually on the Mac (Docker can't run in the dev sandbox). Plans need explicit host-side verification steps: `uname -m` shows `aarch64`, `ls -a /home/sandbox`, `git status` in a workspace repo, login surviving `--no-cache` rebuild plus recreate, history surviving recreate, and `docker volume ls` shows nothing.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. gh/git persistence was treated as part of the "state survives recreate" goal, not as a new capability.

</deferred>

---

*Phase: 01-two-mount-claude-sandbox*
*Context gathered: 2026-09-30*
