# Pitfalls Research

**Domain:** Docker sandbox containers for AI coding agents (Claude Code + GSD + ccusage; OpenCode later) on macOS + Docker Desktop (Apple Silicon, VirtioFS bind mounts)
**Researched:** 2026-09-30
**Confidence:** HIGH for Claude Code / GSD / ccusage behaviour (verified against official docs, package contents, and the live dev sandbox, which is the same kind of container). MEDIUM for Docker Desktop macOS file-sharing behaviour (version dependent, cannot be tested from inside the dev sandbox).

## How to read this file

Phase names below are **provisional labels** so the roadmap can map pitfalls to work. Rename freely.

| Label | Scope |
|-------|-------|
| **P1 Base** | Shared base image, pinned OS, users, toolchains (Node, JDK, Maven, Python, gh) |
| **P2 State** | Mount layout, `CLAUDE_CONFIG_DIR`, persisted agent state |
| **P3 Tools** | Claude Code binary, GSD delivery ("image wins"), ccusage |
| **P4 Lifecycle** | compose file, `cc-*` scripts, upgrade flow, naming |
| **P5 Migrate** | Migration of ~4 existing sandboxes, README, host-side verification |

**Evidence tags:** `[VERIFIED-LIVE]` = observed in the current dev sandbox (a container of this exact design, Ubuntu 26.04, aarch64, whole-home VirtioFS mount) or reproduced by running the package. `[DOCS]` = official Claude Code docs. `[ISSUE]` = upstream issue tracker. `[TRAINING]` = prior knowledge, treat as MEDIUM until checked on the host.

---

## Critical Pitfalls

### Pitfall 1: Bind-mounting `~/.claude.json` as a single file

**What goes wrong:**
Claude Code writes `.claude.json` atomically (write temp file next to it, then `rename()` over it). If `~/.claude.json` is a single-file bind mount, the rename hits a mount point and fails with `EBUSY` / "device or resource busy". If the mount is only read/created at start, the container is pinned to the old inode: it never sees later writes. Symptoms: onboarding wizard on every start, trust dialog every time, settings silently not saved, or (worst) OAuth refresh-token divergence where one side gets a 401 even though the account is fine.

**Why it happens:**
`~/.claude.json` lives *outside* `~/.claude/`, so people who mount only `~/.claude` lose login/onboarding state and "fix" it by mounting the one extra file. Docker allows it; Linux refuses to rename over a mount point.

**How to avoid:**
Never mount a single file that the tool rewrites. Follow the official Claude Code devcontainer guidance `[DOCS]`: mount a **directory** at `/home/sandbox/.claude` and set `CLAUDE_CONFIG_DIR=/home/sandbox/.claude`, so `.claude.json` lands *inside* the mounted directory (`<state>/.claude.json`) and `.credentials.json` sits next to it. Same rule for `~/.gitconfig` and `.git/config` overlays (`git config` uses lockfile+rename and hits the same `EBUSY`).

**Warning signs:**
- `EBUSY` / `Device or resource busy` in `claude --debug` output or logs mentioning `.claude.json.tmp.*`.
- Theme/onboarding/trust prompts reappear after every container restart.
- `~/.claude.json` inside the container differs from the host copy.

**Phase to address:** P2 State. Compose file must contain exactly one state mount (a directory) and zero single-file mounts.

---

### Pitfall 2: `CLAUDE_CONFIG_DIR` set inconsistently (entrypoint-only, or missing in `docker exec`)

**What goes wrong:**
`.claude.json` location depends on `CLAUDE_CONFIG_DIR`: unset -> `~/.claude.json`; set -> `$CLAUDE_CONFIG_DIR/.claude.json` `[DOCS][ISSUE #14313]`. If the variable is exported inside `docker-entrypoint.sh`, then `docker exec -it ... bash` (which is what `cc-bash.sh` does) **does not run the entrypoint** and never sees it. Result: two divergent state files (one in `$HOME`, one in the state dir), Claude "forgets" the login/onboarding in exec shells, and `ccusage` (which honours `CLAUDE_CONFIG_DIR`) reads a different tree than Claude wrote. Related: when `CLAUDE_CONFIG_DIR` is set, ccusage hard-fails if the path lacks `projects/` `[VERIFIED-LIVE]`, it does not fall back to `~/.claude`.

**Why it happens:**
Entrypoint `export` feels like the natural place for env config, but `docker exec` gets only image `ENV` + compose `environment:`.

**How to avoid:**
Set `ENV CLAUDE_CONFIG_DIR=/home/sandbox/.claude` (and `PATH`, `DISABLE_AUTOUPDATER`, `npm_config_*`) in the **Dockerfile**, never in the entrypoint or `.bashrc` only. Keep the container-side path identical to what existing sandboxes already use (`/home/sandbox/.claude`): GSD writes absolute hook paths into `settings.json` (`"/home/sandbox/.claude/hooks/..."` `[VERIFIED-LIVE]`) and plugin/marketplace metadata is path-sensitive, so changing the container-side path breaks existing state.

**Warning signs:**
- `docker exec <c> env | grep CLAUDE_CONFIG_DIR` prints nothing.
- Both `/home/sandbox/.claude.json` and `/home/sandbox/.claude/.claude.json` exist.
- `ccusage` shows "No valid Claude data directories".

**Phase to address:** P2 State (Dockerfile ENV) + P5 (smoke test asserts it via `docker exec`, not via `docker run`).

---

### Pitfall 3: Mounting host state over `~/.claude` hides image-provided GSD (the same bug, relocated)

**What goes wrong:**
The milestone fixes "the mount hides `/home/sandbox`" by mounting only `~/.claude`. But GSD *lives in* `~/.claude` (`skills/`, `agents/`, `hooks/`, `gsd-core/`, `settings.json` hook entries). Anything baked into the image's `~/.claude` is again invisible under the mount, and "bake all tools into the image" quietly degrades back into "install at runtime into the mount".

**Why it happens:**
Claude Code discovers GSD only from the config dir, so GSD cannot simply live elsewhere in the image. Also, `settings.json` is *user state* (persisted) but GSD must merge hook entries into it.

**How to avoid:**
Bake the GSD **package** (not its installed output) at a non-shadowed path: `npm install -g @opengsd/gsd-core@<pinned>` as root during build. In the entrypoint (as `sandbox`), compare the baked version to `$CLAUDE_CONFIG_DIR/gsd-core/VERSION` (and `gsd-file-manifest.json` `version`), and if different or missing run the installer from the baked package: `gsd-core --claude --global --config-dir "$CLAUDE_CONFIG_DIR"`. `[VERIFIED-LIVE]` Running `install.js` from an unpacked package took 0.3 s, needs no registry access, is idempotent, and writes `gsd-file-manifest.json` so it can prune its own stale files. Do **not** gate on an `.initialized` marker (it cannot detect a version change) and do **not** use `npx -y ...@latest` at start (see Pitfall 12).

**Warning signs:**
- After rebuild, `cat ~/.claude/gsd-core/VERSION` still shows the old version.
- `ls ~/.claude/skills` empty in a fresh sandbox.
- GSD commands exist but reference removed workflows (mixed old/new files).

**Phase to address:** P3 Tools (design decision: "reconcile on start from baked package"). Verify in P5 host checklist.

---

### Pitfall 4: Stale GSD state and self-updates fight the image ("image wins" is not automatic)

**What goes wrong:**
Three separate ways persisted state overrides or fights the image:
1. **Old files shadow new ones**: a newer GSD removes/renames a skill, agent or hook; without manifest-based pruning the old file stays in the persisted `~/.claude` and keeps being loaded.
2. **`settings.json` hook paths are absolute** `[VERIFIED-LIVE]`. If the installer runs at *build time* as root, hooks point at `/root/.claude/...` (or a build path) and every hook fails silently at runtime.
3. **GSD's own updater**: the SessionStart hook `gsd-check-update.js` polls npm and the `/gsd:update` command installs a newer GSD *into the persisted dir* `[VERIFIED: package contents]`. A user (or the agent) runs `/gsd:update` inside the container, gets version N+1, then the next container start reconciles back to image version N (silent downgrade) or, if reconcile is version-equal-only, keeps N+1 and the image is no longer the source of truth.

**Why it happens:**
"Persist `~/.claude` on host" and "image version wins" are contradictory unless the entrypoint explicitly reconciles GSD-owned files only, leaving user-owned files (`.credentials.json`, `.claude.json`, `history.jsonl`, `projects/`, personal `settings.json` keys, `CLAUDE.md`) alone.

**How to avoid:**
- Run the installer only at container start, against the real config dir (never at build time into `/root` or a temp HOME). GSD offers `--portable-hooks` (`$HOME`-relative hook paths, "WSL/Docker bind-mount setups") as a belt-and-braces option.
- Always use the installer's own upgrade path (it has a manifest and backs up locally modified files into `gsd-local-patches`), not `rsync`/`cp -r` from a baked copy.
- Decide and document policy: `/gsd:update` inside a sandbox is **unsupported** ("upgrade = rebuild"). Optionally suppress the update-check hook noise; at minimum tell users the banner is expected.
- Make reconcile failure **non-fatal but loud** (print a red line, keep the container alive). With `set -e` a registry/installer hiccup turns into a container restart loop.

**Warning signs:**
- `VERSION` in state dir != `npm ls -g @opengsd/gsd-core` in image.
- Hook errors at session start; `grep -c '/root/' ~/.claude/settings.json` > 0.
- "Update available" banner appears right after a fresh rebuild.

**Phase to address:** P3 Tools.

---

### Pitfall 5: Claude Code auto-updater creates a second copy and fights the baked binary

**What goes wrong:**
`[VERIFIED-LIVE]` in the current sandbox: the baked `/usr/local/bin/claude` is 2.1.285, and the updater/installer *also* placed a 229 MB copy at `~/.local/share/claude/versions/2.1.285` with symlink `~/.local/bin/claude` **inside the host-mounted home**; `.claude.json` records `"installMethod": "native"`. Consequences: per-sandbox disk waste on the host mount, `claude doctor` warnings about multiple installs / non-writable install location, and after a rebuild the "running" version depends on PATH order and on whatever the updater downloaded mid-session, so image version does **not** win. The baked binary is root-owned in `/usr/local/bin`, so an in-place update can never succeed; failed attempts nag ("Auto-update failed - run claude doctor") `[TRAINING]`.

**Why it happens:**
Native installs auto-update by default `[DOCS]`. `DISABLE_AUTOUPDATER` stops only the background check; `claude update` / `claude install` still work. `DISABLE_UPDATES` blocks *all* paths `[DOCS]`.

**How to avoid:**
- Dockerfile: `ENV DISABLE_AUTOUPDATER=1` **and** `ENV DISABLE_UPDATES=1` (image `ENV` cannot be overridden by the persisted `settings.json`). Optionally also write them to `/etc/claude-code/managed-settings.json` (`env` block) as a highest-precedence, image-owned copy that the state dir cannot shadow `[DOCS: managed settings path; MEDIUM that `env` is honoured there, verify with `claude doctor`]`.
- Install at a pinned version to a root-owned, non-home path. Options in order of preference: (a) signed apt repo `downloads.claude.ai/claude-code/apt/stable` with the documented fingerprint `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`; (b) `curl -fsSL https://claude.ai/install.sh | bash -s <X.Y.Z>` then verify against the GPG-signed `manifest.json` checksum. Either way pass the version as a build ARG.
- Do not persist `~/.local` in the state mount; with the new layout `~/.local` is image-owned, so a stray updater copy dies with the container.
- Acceptance test: `claude --version` == build ARG, `claude doctor` reports auto-updates disabled, `ls ~/.local/share/claude` is empty after a session.

**Warning signs:** `~/.local/share/claude/versions/` exists; `which -a claude` lists two paths; `claude --version` differs from the Dockerfile ARG.

**Phase to address:** P3 Tools.

---

### Pitfall 6: Node version: current Dockerfile installs Node 20 (EOL) but GSD needs Node >= 24

**What goes wrong:**
`[VERIFIED-LIVE]` The dev sandbox runs `node v20.20.2` from NodeSource `setup_20.x`. Node 20 hit end-of-life on 2026-04-30 (no security fixes); `@opengsd/gsd-core@1.15.0` declares `engines: node >=24, npm >=10`, and `@anthropic-ai/claude-code` requires Node >=22 (only matters if installed via npm). GSD currently "works" only because `engines` is a warning, not an error. Any hook or `gsd-tools` code using newer Node APIs can break at any GSD release.

**Why it happens:**
Version 20 was copy-pasted from an old tutorial and never revisited (`ubuntu:latest` + floating install script).

**How to avoid:**
Base image pins **Node 24 LTS** (Active LTS until 2028-04-30). Install from a signed apt source (NodeSource keyring added by file, not `setup_XX.x | bash`) or from the official tarball with `SHASUMS256.txt` verification; tarball name is arch-specific (`linux-arm64`), so derive it from `dpkg --print-architecture`. Add a build-time assert: `node -e 'process.exit(+process.versions.node.split(".")[0] >= 24 ? 0 : 1)'`.

**Warning signs:** `EBADENGINE` warnings during install; `node -v` < 24.

**Phase to address:** P1 Base.

---

### Pitfall 7: ccusage: root-installed global package ships a non-executable native binary

**What goes wrong:**
`[VERIFIED-LIVE]` ccusage 20.x is a tiny Node launcher (`src/cli.js`) that spawns a per-platform **native binary** from an optional dependency (`@ccusage/ccusage-linux-arm64/bin/ccusage`). The tarball ships that binary as mode `0644`; the launcher fixes this by `chmod 0755` on first run. If ccusage is installed globally by root at build time (`/usr/lib/node_modules`) and executed by `sandbox`, that chmod fails (`EPERM`, you are not the owner) and you get `ccusage native binary is not executable`. This is very likely the root cause of (or at least a known trap behind) the earlier commented-out attempt, which had a manual `chmod 755 ...ccusage-linux-arm64/bin/ccusage` step.

**Why it happens:**
The native-binary packaging changed ccusage from pure JS (works anywhere) to arch-specific; older recipes and the earlier attempt symlinked binaries by hand.

**How to avoid:**
- Build step (as root): `npm install -g ccusage@<pinned>` then `chmod a+rx "$(npm root -g)"/ccusage/node_modules/@ccusage/*/bin/ccusage` (or `find -path '*@ccusage/*/bin/ccusage' -exec chmod 755 {} +`).
- Immediately smoke-test *as the runtime user*: `RUN ... && su sandbox -c 'ccusage --version'` (or a later `USER sandbox` `RUN ccusage --version`), so the build fails instead of the user.
- Never install into `$HOME` (the old attempt) and never rely on `npx ccusage` at runtime (needs registry access, re-downloads on every recreate).

**Warning signs:** `ccusage: native binary is not executable`; `ls -l .../bin/ccusage` shows `-rw-r--r--`.

**Phase to address:** P3 Tools.

---

### Pitfall 8: ccusage: optional native dependency silently missing (arch/flags)

**What goes wrong:**
The launcher resolves `@ccusage/ccusage-{linux,darwin}-{arm64,x64}` and otherwise prints `ccusage native binary is not available for linux-arm64. Reinstall ccusage so optional native dependencies are installed.` `[VERIFIED-LIVE: source]`. Triggers: `npm install --omit=optional` / `--no-optional` / `npm_config_optional=false`, `npm ci` from a lockfile generated on macOS (lockfile pins only the darwin optional dep on some npm versions), copying `node_modules` between platforms, or building with `--platform linux/amd64` (Rosetta) but running arm64 (or vice versa).

**How to avoid:**
Install ccusage in the same `RUN` layer on the same target platform as it runs; do not use lockfile-driven install for it; do not add global `npm config set optional false` for "speed". Do not set `DOCKER_DEFAULT_PLATFORM` in the scripts unless intentional. Keep `RUN ccusage --version` in the build.

**Warning signs:** the error text above; `ls $(npm root -g)/ccusage/node_modules/@ccusage` is empty.

**Phase to address:** P3 Tools.

---

### Pitfall 9: ccusage data path, network and retention surprises

**What goes wrong:**
- Default search paths are `~/.config/claude/projects` and `~/.claude/projects`; `CLAUDE_CONFIG_DIR` overrides (comma-separated allowed) `[DOCS: ccusage.com]`. With `CLAUDE_CONFIG_DIR=/home/sandbox/.claude` all is well, but a wrong value is a hard error (Pitfall 2).
- Cost calculation fetches pricing online; `--offline` uses bundled pricing `[VERIFIED-LIVE: flag works]`. In a restricted-egress container, or for brand-new models, costs can be missing/0 (MEDIUM, `[TRAINING]`).
- Claude Code prunes old session transcripts after `cleanupPeriodDays` (default 30) `[TRAINING]`, so totals shrink over time and will not match the Anthropic console.
- Numbers are **per sandbox** (state is per project); "usage across all projects" is explicitly out of scope, but users will expect it.
- Because usage is keyed by transcript directory (Pitfall 10), migration that renames the workspace path splits one project's history into two entries.

**How to avoid:** Document per-sandbox scope and `--offline`; raise `cleanupPeriodDays` in the baked/managed settings if long-term totals matter; verify with a known number (session count before vs after migration).

**Phase to address:** P3 Tools (setup), P5 (verification wording in README).

---

### Pitfall 10: Session history is keyed by the container working directory

**What goes wrong:**
`[VERIFIED-LIVE]` `~/.claude/projects/-home-sandbox-GetShitDoneContainer` is the encoded cwd. Per-project trust, "allowed tools", `--continue/--resume`, auto-memory and ccusage grouping all key on the **absolute path Claude was started in**. Moving the code from `/home/sandbox/MyCode` to `/workspace/MyCode` makes Claude treat it as a brand-new project: history invisible to `/resume`, trust and permission prompts again, memory gone (files still exist under the old encoded name, plus the old entry stays in `.claude.json`).

**Why it happens:**
The migration changes the mount target and nobody thinks about cwd being part of the key.

**How to avoid:**
Pick the final workspace path once, ideally per-sandbox stable, and treat it as a public contract in the README. For existing sandboxes, either keep the same absolute container path for the code (`/home/sandbox/<repo>` as a nested mount is legal once the home no longer comes from the host) or, during migration, rename `projects/-home-sandbox-MyCode` to the new encoded name and rewrite the matching key under `projects` in `.claude.json` (JSON edit; keep the copy in `backups/`). Document exactly one option.

**Warning signs:** `/resume` shows nothing after migration; `ls ~/.claude/projects` has two directories for one repo.

**Phase to address:** P2 State (choose path), P5 Migrate (procedure + check).

---

### Pitfall 11: `VOLUME /home/sandbox` in the Dockerfile + compose recreate = stale, invisible home

**What goes wrong:**
The current Dockerfile declares `VOLUME /home/sandbox`. Once the host no longer bind-mounts the whole home, Docker creates an **anonymous volume** for `/home/sandbox` for every container. `docker compose up` re-attaches the previous container's anonymous volume on recreate (only `up -V/--renew-anon-volumes` renews it) `[ISSUE docker/compose #4476, docs]`. The image's `.bashrc`, `.local`, etc. are therefore frozen at whatever the first container copied, i.e. exactly the "mount hides the image" bug, but now invisible and un-inspectable, and `down -v` (used by `cc-down.sh`) destroys it silently.

**How to avoid:**
Delete the `VOLUME` instruction. Declare persistence only in compose (explicit bind mounts for state, explicit named volume for caches). Acceptance check: `docker inspect <c> --format '{{json .Mounts}}'` lists only the intended mounts and no anonymous (hash-named) volume.

**Warning signs:** `docker volume ls` grows with 64-hex names; rebuilt image's new file in `/home/sandbox` does not appear in running container.

**Phase to address:** P1 Base / P2 State.

---

### Pitfall 12: Runtime `npx -y <pkg>@latest` in the entrypoint runs unpinned registry code next to your credentials

**What goes wrong:**
Today the entrypoint executes whatever `@opengsd/gsd-core@latest` is at that moment, as `sandbox`, with `~/.claude/.credentials.json` readable. The project already lived through one compromised GSD package (`get-shit-done-cc`, still installed by `OpenCode/docker-entrypoint.sh`). A compromised `latest` = credential theft on next container start, with no rebuild event to notice. Also unreproducible and slow (569 MB `~/.npm` cache landed on the host mount in the dev sandbox `[VERIFIED-LIVE]`).

**How to avoid:**
All installs happen at **build time** with pinned versions (`npm install -g @opengsd/gsd-core@1.15.0`), optionally `npm ci`-style integrity and `npm audit signatures`. Runtime does zero network installs. Add a repo guard: `grep -rE 'get-shit-done-cc|gsd-build'` in a pre-commit/CI/`cc-doctor` check so the compromised names cannot reappear (also relevant when OpenCode is revived). Set `npm_config_cache` to a path outside the mounted state if any runtime npm use remains.

**Warning signs:** any `npx`, `npm i`, `curl | bash`, `pip install` in an entrypoint or `.bashrc`.

**Phase to address:** P3 Tools (Claude), OpenCode milestone (later).

---

### Pitfall 13: "Rebuild" does not upgrade anything you have already started (and the cache lies)

**What goes wrong:**
Three independent traps make "one command upgrade" a no-op:
1. **Cached layers**: `RUN npm install -g ccusage@latest` or `curl install.sh | bash` is cached by Docker forever as long as the instruction text is unchanged. `docker build` says "fresh" and installs nothing new. Conversely `--no-cache` on everything re-downloads Node/JDK/apt each time.
2. **Old container keeps old image**: `docker restart`, `docker start`, and `docker compose up -d` on an unchanged config keep the existing container (built from the old image). Only recreate picks up the new image ID.
3. **Per-project images**: compose `build:` under `-p cc_<proj>` creates one image tag *per project* (`cc_<proj>-cc-code-service`). Rebuilding one project does not upgrade the other three.

**How to avoid:**
Make versions explicit build ARGs (`ARG CLAUDE_VERSION`, `GSD_VERSION`, `CCUSAGE_VERSION`, `NODE_VERSION`, `MAVEN_VERSION`) declared right before the `RUN` that uses them, so changing an ARG invalidates exactly that layer. The upgrade script resolves the latest versions itself (`npm view <pkg> version`, Claude `latest` endpoint) and passes them as `--build-arg`; that gives "fresh tools" *and* a printed version manifest. Use one shared image tag (`image: cc-sandbox/claude:local`, `pull_policy: never`) built once, then `docker compose up -d --force-recreate` (or `down` then `up`) for each registered sandbox. Rebuild the base with `--pull` so the pinned OS tag's security refresh is included; chain base -> agent.

**Warning signs:** `docker images` shows N near-identical images; `docker inspect -f '{{.Image}}' <container>` != current image ID; `claude --version` unchanged after "upgrade".

**Phase to address:** P4 Lifecycle.

---

### Pitfall 14: `cc-down.sh` uses `down -v` and doesn't pass `PROJECT_PATH`

**What goes wrong:**
`docker-compose -p cc_x down -v` removes named and anonymous volumes declared by the project. Today that only kills the anonymous home volume; after this milestone it would delete any named volume you add (`.m2`, `node_modules`, caches, possibly state if someone chose a named volume for state). Also `cc-down.sh` does not export `PROJECT_PATH`, so compose interpolates it as empty (warning, and an invalid `:/home/sandbox` volume spec on some versions), and the README calls `-v` "useful to change something in the container", which invites habitual use.

**How to avoid:**
Never use `-v` in scripts. Irreplaceable data (login, history, GSD state, anything the user cares about) is a **host bind mount**, never a named volume. Provide `cc-down` = `down` (removes container/network only) and a separate, explicitly named, confirm-prompting `cc-purge` for cache volumes. Give compose sane defaults so an unset variable fails loudly: `${PROJECT_PATH:?PROJECT_PATH is required}`.

**Warning signs:** `docker volume ls` shows caches vanishing after `cc-down`; compose prints `The "PROJECT_PATH" variable is not set`.

**Phase to address:** P4 Lifecycle.

---

### Pitfall 15: Compose naming: invalid project names, container_name collisions, silent recreate on path change

**What goes wrong:**
- `-p "cc_${PROJECT_NAME}"`: compose project names must be lowercase letters, digits, `-`, `_` and start with a letter/digit `[DOCS]`. `cc-up.sh MyProj ...` fails with "invalid project name" (older behaviour accepted it; Compose >= 2.6 is strict), while the hardcoded `container_name: cc_gsd_${PROJECT_NAME}` accepts uppercase, so `cc-bash.sh` and `cc-up.sh` can disagree on the name.
- `container_name` is global in the Docker engine: two sandboxes with the same short name, or an old container from a previous scheme, collide (`Conflict. The container name "/cc_gsd_ssg" is already in use`). Migration will hit this: the old container is in project `cc_ssg`, the new scheme may use a different project, but the *container name* is the same.
- Calling `cc-up.sh ssg /other/path` for an existing name makes compose detect the changed volume and **recreate** the container against the new path without warning. Not destructive (state is on host) but confusing, and it points a login-bearing state dir at a different repo.
- `docker-compose` (v1, hyphen) has been EOL since 2023; Docker Desktop provides `docker compose` (v2). Scripts written for v1 break on new installs or behave differently on `-p`/`.env` handling `[TRAINING]`.

**How to avoid:**
Validate names in one shared function (`[a-z0-9][a-z0-9_-]*`), derive project name, container name and state dir from the same variable, use `docker compose` (v2). Keep a tiny registry file (`name -> host path`, plain text under `~/.config/cc-sandbox/`) and make `cc-up` refuse a mismatched path unless `--force`. Drop `container_name` and address containers via `docker compose -p ... exec`, or keep it but validate collisions first.

**Warning signs:** "invalid project name"; "container name already in use"; `docker ps` shows a container created seconds ago after a plain `cc-up`.

**Phase to address:** P4 Lifecycle.

---

### Pitfall 16: Credentials shared between containers (rotating refresh tokens) or committed via the workspace

**What goes wrong:**
- **Sharing one login dir across all sandboxes** to avoid four logins looks convenient, but OAuth refresh tokens rotate: two containers refreshing independently end with a stale token in one and a 401 "login expired" `[ISSUE hive-mind #2296]`. Symmetric problem: the same state dir used simultaneously by host Claude and container Claude.
- **State inside the code tree**: the milestone says state lives "inside or next to the sandbox path". If it is *inside* the mounted workspace and the repo root is the sandbox folder (as in the current layout where the sandbox folder is the parent of the repo), `.claude/.credentials.json` is visible to host IDE indexers, to `git status`, and one `git add -A` away from being committed.

**How to avoid:**
One state dir per sandbox, never shared and never used concurrently by two Claude processes from different containers. Put it **next to**, not inside, any git work tree: e.g. `<sandbox>/state/claude` and `<sandbox>/code`, mounting only `code` at the workspace path and `state/claude` at `~/.claude`. If a shared login is truly wanted, use `claude setup-token` (one-year, non-rotating `CLAUDE_CODE_OAUTH_TOKEN`) supplied from a `0600` host env file `[DOCS]` (limits: subscription plans only; inference only, no Remote Control / claude.ai connectors). Add `.claude/`, `.credentials.json`, `.claude.json` to the repo's global gitignore as a backstop.

**Warning signs:** intermittent "Login expired" in exactly one sandbox; `git status` shows `.claude/` at the repo root.

**Phase to address:** P2 State.

---

### Pitfall 17: Isolation is one-way: what the agent writes into the mount is later executed by the host

**What goes wrong:**
"The container sees only one folder" is true, but the agent has write access to that folder and the **host** later runs things from it: `.git/hooks/*` (fire on the host when you commit from IntelliJ or the terminal), `.idea/` run configurations and `.vscode/tasks.json`, `package.json` scripts / `postinstall`, `.mvn/wrapper` + `mvnw`, `Makefile`, `.envrc` (direnv), shell scripts you habitually run. With `--dangerously-skip-permissions` (the README's default invocation) a prompt-injected agent can plant any of these. Additionally, official docs warn that with that flag a malicious project can exfiltrate anything readable in the container, including `~/.claude` credentials `[DOCS]`.

**How to avoid:**
- Document it plainly in the README (threat model: container protects the host filesystem *now*, not what you execute *later*).
- Cheap mitigations: mount `${PROJECT_PATH}/.git/hooks` read-only over the workspace (nested `:ro` mount) `[MEDIUM, verify on Docker Desktop]`; review `git diff` and `.git/hooks`, `.idea`, `.vscode` before running host tooling; prefer running builds/tests in the container.
- Baseline hardening in compose: `cap_drop: [ALL]`, `security_opt: [no-new-privileges:true]`, no `privileged`, no `network_mode: host`, no extra `devices`. None of these affect Claude/Maven/Node.
- Optional egress restriction (Anthropic ships `init-firewall.sh` needing `NET_ADMIN`; out of scope now but note it).

**Warning signs:** unexpected files in `.git/hooks/`, `.idea/workspace.xml` tasks, new `postinstall` scripts.

**Phase to address:** P2 State (layout), P5 (README threat-model section).

---

### Pitfall 18: Mounting the Docker socket, `~/.ssh`, cloud creds, or the whole `$HOME` "for convenience"

**What goes wrong:**
`/var/run/docker.sock` inside the container = root-equivalent control of the Docker VM (agent can start privileged containers mounting any path the VM can see, including other sandboxes' state and everything Docker Desktop shares from macOS). `~/.ssh`, `~/.aws`, `~/.gitconfig` with credential helpers, or `gh` tokens with broad scope turn a prompt-injection into repo/cloud compromise. "Testcontainers needs Docker" is the usual excuse.

**How to avoid:**
Never mount the socket; if Testcontainers is ever needed, use a separate rootless DinD sidecar per sandbox, as an explicit later decision. Authenticate git/gh with a **fine-grained, repo-scoped, short-lived PAT** via `GH_TOKEN` (env file, `0600` on host), not host SSH keys or `gh` config. Docker Desktop's file-sharing list should include only the sandbox parent folders, not `/Users/demian`. Add a `cc-doctor` check that fails if any mount source is outside the sandbox folder or is `docker.sock`.

**Warning signs:** `docker inspect` mounts show `/var/run/docker.sock`, `/Users/demian` (home) or `~/.ssh`.

**Phase to address:** P2 State (compose template), P4 (doctor check).

---

## Moderate Pitfalls

### Pitfall 19: Ubuntu 24.04+ ships a uid/gid 1000 `ubuntu` user; `useradd sandbox` silently gets 1001

**What goes wrong:**
`[VERIFIED-LIVE]` in the dev sandbox (Ubuntu 26.04): `ubuntu:x:1000:1000` exists and `sandbox` is uid 1001. On Docker Desktop macOS this is mostly masked (Pitfall 20), so nothing fails, and the assumption "sandbox = 1000" gets baked into docs/scripts. It breaks on any Linux host or CI runner (host user 1000 cannot write files created by uid 1001 and vice versa) and confuses `--user` overrides. Also, `ubuntu:latest` has already drifted to 26.04 (Python 3.14; verify openjdk-21 still available), so the pinned tag decision is real, not cosmetic.

**How to avoid:**
Pin `ubuntu:24.04` (or 26.04) by tag **and** digest in one ARG used by base. Create the user deterministically: `userdel -r ubuntu 2>/dev/null; groupadd -g ${UID} sandbox; useradd -m -u ${UID} -g ${UID} -s /bin/bash sandbox` with `ARG UID=1000`. Never write scripts that assume the uid; never `chown -R` a bind mount at startup (slow across VirtioFS and a no-op on macOS).

**Warning signs:** `id sandbox` says 1001; `getent passwd 1000` returns `ubuntu`.

**Phase to address:** P1 Base.

---

### Pitfall 20: Docker Desktop macOS ownership is synthetic; do not build logic on it

**What goes wrong:**
VirtioFS presents host files with whatever ownership makes access work; `chown` inside the container is effectively ignored (historically also reported as "everything root", docker/for-mac #6243, fixed/varies by version) `[ISSUE][MEDIUM]`. Two consequences: (1) entrypoints that "fix permissions" waste time and can error; (2) the same setup that "just works" on the Mac fails with `Permission denied` for uid mismatches on Linux. Also, mount points Docker has to create (e.g. `/home/sandbox/.claude` when the image doesn't have it) are created root-owned, and **named volumes** inherit ownership from the image directory only if it exists there.

**How to avoid:**
Pre-create every mount target in the image, owned by `sandbox` (`mkdir -p /workspace /home/sandbox/.claude /home/sandbox/.m2 && chown ...`). Run entrypoint as `sandbox`, no `gosu`/`chown`. Keep Claude's own rule in mind: `--dangerously-skip-permissions` is refused when running as root `[DOCS]`.

**Warning signs:** `Permission denied` writing to `~/.m2` or `~/.claude` on first start; `ls -ld` shows root.

**Phase to address:** P1 Base / P2 State.

---

### Pitfall 21: git "dubious ownership", identity and gh login vanish on recreate

**What goes wrong:**
Git (>= 2.35.2) refuses repos whose owner uid differs from the current user: on macOS bind mounts the host uid (501) != container uid, giving `fatal: detected dubious ownership` `[ISSUE Archon #1279]`. `git config --global --add safe.directory` written at runtime lands in `/home/sandbox/.gitconfig`, which is in the container layer and disappears on every recreate. Same fate for `git config --global user.name/email` and `gh auth login` (`~/.config/gh`), now that the home is no longer a host mount (a **regression** vs today where they survived in the mounted home).

**How to avoid:**
Bake `git config --system --add safe.directory '*'` (single-user sandbox; acceptable) or the fixed workspace path into the image (`/etc/gitconfig`). Pass identity via `GIT_AUTHOR_NAME/EMAIL`, `GIT_COMMITTER_*` from the registry or env file. For gh, prefer `GH_TOKEN` (Pitfall 18) or explicitly persist `~/.config/gh` as a second *directory* mount inside the state dir; decide consciously and document. If a host `~/.gitconfig` is ever shared, it must be read-only and never `git config --global`-written.

**Warning signs:** git commands fail after each `cc-up`; `gh auth status` says not logged in after upgrade.

**Phase to address:** P1 Base (system gitconfig), P2 State (gh/identity decision).

---

### Pitfall 22: Bind-mount performance: node_modules and Maven caches on VirtioFS

**What goes wrong:**
VirtioFS is much better than the old gRPC FUSE, but metadata-heavy workloads (tens of thousands of small files) remain several times slower than a named volume `[MEDIUM: CNCF/community benchmarks]`. In the dev sandbox the whole home, including a 569 MB `~/.npm`, sits on the mount. For Java/Node projects the pain is `node_modules/`, `~/.m2/repository`, and `target/`.

**How to avoid (opinionated):**
- **Maven `~/.m2`: persist it, per project, as a Docker named volume** (`m2-<proj>` mounted at `/home/sandbox/.m2`), not on the host bind mount and **not shared across sandboxes** (Maven's default locking is per-JVM, so concurrent containers writing one repo can corrupt partial downloads, and a shared cache lets one compromised project poison artifacts for the others). Cost: invisible on the host and dies with `down -v` (Pitfall 14), so never use `-v`; rebuilds from network if lost, which is cheap.
- **`node_modules`**: if the repo contains a JS build, mount a per-project named volume over `<workspace>/node_modules`, or install only inside the container. Never run `npm install` on both host and container against the same `node_modules`: native optional deps (`esbuild`, `rollup`, `@swc/*`, ccusage-style `*-linux-arm64` vs `*-darwin-arm64`) are platform-specific and the second platform breaks the first.
- `npm_config_cache` -> `/var/cache/npm` (image) so runtime npm does not pollute the host mount.
- Do not spend effort on `:cached`/`:delegated` flags; they are legacy no-ops on VirtioFS.

**Warning signs:** `mvn` cold builds take minutes with CPU idle; `Cannot find module @rollup/rollup-linux-arm64-gnu`.

**Phase to address:** P2 State (mount design), P5 (README).

---

### Pitfall 23: `curl | bash` in Dockerfile: unpinned, unverifiable, and failure-masking

**What goes wrong:**
Beyond the checksum concern in CONCERNS.md there is a concrete failure mode: `curl -fsSL URL | bash -` in a `RUN` uses `/bin/sh` without `pipefail`. If curl fails (rate limit, 403, captive proxy) `bash` reads empty stdin and exits 0. For NodeSource that means the repo is never added and the next `apt-get install -y nodejs` **silently installs Ubuntu's own (different) Node**. Reproducibility also depends on the mutable script.

**How to avoid:**
Replace with (a) signed apt sources with the key fetched to `/etc/apt/keyrings` and fingerprint-checked (gh, NodeSource, Claude's apt repo), or (b) download to a file, verify SHA256/GPG (`manifest.json` for Claude, `SHASUMS256.txt` for Node, Apache checksums for Maven), then execute. Add `SHELL ["/bin/bash", "-o", "pipefail", "-c"]` at the top of every Dockerfile. Assert versions at the end of the build (`node -v`, `claude --version`, `java -version`, `mvn -v`, `ccusage --version`, `gsd-core --help`) and print a version table.

**Warning signs:** `node -v` shows something other than the intended major; build log has curl errors but "succeeds".

**Phase to address:** P1 Base, P3 Tools.

---

### Pitfall 24: Shared base image referenced by an unqualified name

**What goes wrong:**
Agent Dockerfiles do `FROM sandbox-base`. Compose does not build dependencies in order. If the base is not present locally, Docker tries to **pull `docker.io/library/sandbox-base`** (fails with "pull access denied" - or, if that name is ever registered by someone, pulls and runs a stranger's image with your credentials). Also, rebuilding the base does not rebuild agent images, so agent images drift behind base fixes.

**How to avoid:**
Use `ARG BASE_IMAGE=cc-sandbox/base:local` with a namespaced local tag, build base first in the same script (`cc-build`: base -> claude), and set `pull_policy: never` on the agent service so a missing image is an error, not a pull. Compose `additional_contexts` / `docker buildx bake` are alternatives, but plain sequential `docker build` in one script is simplest and adequate for this scale. Base is arch-agnostic in content but built on the host platform; do not hardcode `amd64`/`arm64` strings (e.g., `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64` breaks on the other arch; resolve via `readlink -f "$(command -v javac)"`).

**Warning signs:** "pull access denied for sandbox-base"; agent image lacks a tool you just added to base.

**Phase to address:** P1 Base, P4 Lifecycle.

---

### Pitfall 25: Toolchain installs from apt: Python PEP 668, Maven drags a second JDK, Maven is old

**What goes wrong:**
- Ubuntu 24.04+ marks system Python "externally managed": `pip install` errors (`error: externally-managed-environment`); `--break-system-packages` "fixes" it by corrupting apt-managed packages.
- `apt install maven` depends on `default-jre-headless`/`default-jdk`; besides your JDK 21 you may end up with a second JDK and `update-alternatives` picking the wrong `java`/`javac`. Ubuntu's Maven is old (3.8.x on noble) `[TRAINING, verify]`.
- OpenJDK 21 availability differs per Ubuntu release; `ubuntu:latest` moved to 26.04 whose default JDK is newer `[TRAINING, verify with apt-cache policy]`.

**How to avoid:**
Python: install `python3-venv python3-pip pipx` (or `uv` from a pinned release) and tell agents/users to use venvs; keep `PIP_REQUIRE_VIRTUALENV=1`. Java: install `openjdk-21-jdk-headless` (or Temurin 21 tarball with checksum), install Maven from the Apache binary tarball (pinned `ARG MAVEN_VERSION`, SHA512 verified) into `/opt/maven` with `--no-install-recommends`, set `JAVA_HOME` from `readlink`, and end the build with `java -version && javac -version && mvn -v` asserts.

**Warning signs:** `java -version` != 21; two `openjdk-*` in `dpkg -l`.

**Phase to address:** P1 Base.

---

### Pitfall 26: `docker exec` shells are not login shells and skip the entrypoint

**What goes wrong:**
`cc-bash.sh` uses `docker exec -it ... /bin/bash`: no entrypoint (so no GSD reconcile), non-login shell (`~/.profile` PATH additions ignored), and no init. If the container was started long ago, the reconcile ran on *that* start only. Also, without `init: true` Claude's many subprocesses/`docker exec` children can leave zombies.

**How to avoid:** All PATH/env in Dockerfile `ENV`; `init: true` in compose; make the reconcile idempotent and cheap so `cc-shell` can also call it (`docker exec ... cc-reconcile`) after an image change; ensure "upgrade" always recreates (Pitfall 13).

**Phase to address:** P3 Tools / P4 Lifecycle.

---

### Pitfall 27: Migration mechanics: `.claude.json` location, stale artifacts, running containers, name conflicts

**What goes wrong:**
Existing sandboxes keep state at the sandbox folder root: `<sandbox>/.claude/`, `<sandbox>/.claude.json`, `<sandbox>/.initialized`, `.bashrc`, `.local/share/claude` (229 MB), `.npm` (569 MB), `.cache`. After the layout change:
- `.claude.json` at the root is **ignored** once `CLAUDE_CONFIG_DIR` is set; must be moved to `.claude/.claude.json`, otherwise onboarding/trust reappear (login may survive because `.credentials.json` is in `.claude/`, but do not count on it).
- Migrating while the old container runs copies a half-written state (Claude rewrites `.claude.json` constantly).
- If the sandbox folder root is mounted as the new workspace, the agent still sees `.claude/.credentials.json` at `/workspace/.claude` (double exposure), and the junk directories pollute the repo view.
- Old container name `cc_gsd_<proj>` still exists and blocks the new one (Pitfall 15); old images remain (disk).
- Old `.initialized` and old GSD files (installed by `@latest` on an unknown date) are reconciled correctly only if Pitfall 3's version stamp check is used.

**How to avoid (procedure for README):** `cc-down` old container -> `docker rm` it -> **copy** (not move) state to the new `state/claude/` (`cp -a`), move `.claude.json` inside, apply the cwd/path decision (Pitfall 10) -> delete `.initialized`, `.local`, `.npm`, `.cache`, `.bashrc` only after verification -> `cc-up` -> verify: `claude` opens without login, `/status` shows the account, `--resume` lists old sessions, `ccusage daily` total matches the pre-migration number, `cat ~/.claude/gsd-core/VERSION` == image. Keep the pre-migration copy until verified; Claude also keeps 5 rotating `.claude.json` snapshots in `backups/` `[DOCS]`.

**Warning signs:** first launch shows login/theme picker; ccusage total differs; `docker: container name already in use`.

**Phase to address:** P5 Migrate.

---

## Minor Pitfalls

### Pitfall 28: macOS case-insensitive filesystem and metadata noise
APFS default is case-insensitive; Linux git in the container sees a case-sensitive view of a case-insensitive store, so `Foo.java`/`foo.java` collisions or "modified" noise appear. `.DS_Store` gets written by Finder into the mounted tree. Prevention: keep `.DS_Store` in global gitignore; avoid case-only renames in the container; enable `core.ignorecase`-aware workflow only if needed.

### Pitfall 29: Docker Desktop VM clock drift after Mac sleep `[LOW, TRAINING]`
Reported cause of odd token-expiry/TLS "not yet valid" errors after laptop sleep. Prevention: restart Docker Desktop or the container on unexplained auth/TLS errors before debugging deeper.

### Pitfall 30: Claude's transcript retention shrinks ccusage totals
See Pitfall 9; raise `cleanupPeriodDays` only if long-term cost history matters.

### Pitfall 31: `tty` / `stdin_open` and `CMD /bin/bash` keep-alive hack
Container lifetime tied to an idle bash with `tty: true`; fine, but it means `docker compose logs` shows nothing useful and entrypoint failures are invisible. Prevention: print a one-line versions banner from the entrypoint (`claude/gsd/ccusage/java/node`), log reconcile results to `/tmp/reconcile.log` and surface them in `cc-doctor`.

### Pitfall 32: Recursion between README and reality
README documents `cc-upgrade.sh` that does not exist; the milestone will add scripts with different names. Prevention: generate the script list in README from `ls bin/` in a test, or keep a single "Commands" table checked by a smoke test.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `@latest` / `latest` tags in Dockerfile | Always newest tools | Unreproducible, silent behaviour change, cache lies (P13) | Never in the Dockerfile; only inside the upgrade script that *resolves* then pins as ARGs |
| `npx -y pkg@latest` in entrypoint | No rebuild to update | Runtime supply-chain exposure, network dependency, slow start (P12) | Never |
| `.initialized` marker file | Trivial first-run logic | Cannot detect version change, half-installs (CONCERNS.md) | Never; use version stamp compare |
| Mount whole sandbox folder as `/workspace` | One mount, simple compose | State visible to agent twice, cwd changes, state near git tree (P16, P27) | Only if state is excluded (gitignored) and README says so |
| `git config safe.directory '*'` system-wide | No dubious-ownership errors | Weakens a git safety check | Acceptable here: single-user container, single mount |
| Shared `.m2` across sandboxes | Saves disk/downloads | Cross-project cache poisoning, concurrent-writer corruption | Never; per-project volume |
| One state dir shared by all sandboxes | One login | Refresh-token races (P16) | Only with `CLAUDE_CODE_OAUTH_TOKEN` (non-rotating) |
| `--dangerously-skip-permissions` as default | No prompts | Amplifies P17/P18 | Acceptable only with the mitigations in P17 |
| Skipping host smoke test because dev sandbox has no Docker | Faster iteration | Layout bugs found on the user's laptop | Never; ship a host-side `cc-doctor`/checklist |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Claude Code | Single-file mount of `~/.claude.json`; env only in entrypoint | Directory mount + Dockerfile `ENV CLAUDE_CONFIG_DIR` (P1, P2) |
| Claude Code updater | Relying on `DISABLE_AUTOUPDATER` alone | Also `DISABLE_UPDATES=1`, pinned root-owned install (P5) |
| GSD (`@opengsd/gsd-core`) | Build-time install into `/root/.claude`; runtime `npx @latest` | Bake pinned package; reconcile into real config dir at start (P3, P4, P12) |
| ccusage | Global install by root without `chmod`; `--omit=optional`; wrong `CLAUDE_CONFIG_DIR` | chmod + build-time smoke test as `sandbox` (P7-P9) |
| gh / git | `gh auth login` inside container with ephemeral home; `--global` git config | `GH_TOKEN` env file, `/etc/gitconfig`, env identity (P21) |
| Docker Compose | `-p` with uppercase name; `container_name`; `down -v` | Validate names; drop `-v`; use `docker compose` v2 (P14, P15) |
| Docker Desktop | Assuming uid/chown semantics; sharing broad host folders | Pre-create mount points; share only sandbox parents (P18-P20) |
| npm registry | Trusting `latest`; `npm ci` lockfile from macOS for a Linux tool | Pin exact versions in Dockerfile ARGs; install in-image (P8, P12) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `node_modules` on VirtioFS bind mount | `npm install`/`ng build` several times slower | Per-project named volume over `node_modules` | ~10k+ files (any modern JS project) |
| `~/.m2` on bind mount | Cold `mvn` builds slow, idle CPU | Per-project named volume at `/home/sandbox/.m2` | First large multi-module build |
| `~/.npm` cache on bind mount (569 MB seen) | Host disk bloat, slow `npx` | `npm_config_cache=/var/cache/npm` in image | Immediately, on any runtime `npx` |
| `chown -R` at start | Slow start | Do not chown mounts | Repos with >50k files |
| Rebuilding without ARG-scoped layers | 10+ min rebuilds (JDK/Node/apt re-run) | Order layers: OS/apt -> JDK/Maven -> Node -> tools (volatile last) | Every upgrade |
| Rebuild N per-project images | 4x disk and time | One shared tag (P13) | With >1 sandbox |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Docker socket mounted | Root on the Docker VM, reach other sandboxes | Never mount; doctor check (P18) - HIGH |
| `~/.ssh`, `~/.aws`, host `~/.gitconfig` mounted | Repo/cloud compromise via prompt injection | Repo-scoped PAT via env; nothing from host home (P18) - HIGH |
| Credentials under a git work tree | Accidental commit / IDE indexing | State dir next to, not inside, repo (P16) - HIGH |
| Runtime `npx @latest`, `curl | bash` at start | Supply-chain code execution beside `.credentials.json` (P12) - HIGH |
| Compromised package names returning (`get-shit-done-cc`, `gsd-build`) | Known-bad code | Repo grep guard in `cc-doctor`/CI; fix OpenCode entrypoint in its milestone - HIGH |
| Agent writes `.git/hooks`, `.idea`, `.vscode` tasks, `postinstall` | Host code execution later | Read-only `.git/hooks` mount, review before running on host (P17) - MEDIUM |
| Long-lived tokens in `docker inspect` env | Token disclosure to anyone with docker CLI | `env_file` 0600, not inline `-e`; treat `docker inspect` as sensitive - MEDIUM |
| Unrestricted egress | Exfiltration of workspace/credentials | Accept and document now; firewall later - MEDIUM |
| Sharing `.m2` / caches across sandboxes | Cross-project poisoning | Per-project volumes (P22) - MEDIUM |
| Running the agent as root | `--dangerously-skip-permissions` refused; blast radius | Keep non-root, no sudo - MEDIUM |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Upgrade prints nothing about versions | User cannot tell if upgrade worked | Print a before/after version table (claude, gsd, ccusage, java, node) |
| Silent reconcile failure | Broken GSD with no explanation | Loud banner + `cc-doctor` |
| `cc-up` with a different path silently recreates | Wrong repo bound to a login | Registry mismatch refusal (P15) |
| Needing to re-pass name/path | Friction (priority 1 of scripts) | Registry file `name -> path`; `cc <name>` does up + shell |
| `docker-compose` v1 commands in README | "command not found" on new Docker Desktop | `docker compose` v2 everywhere |
| Per-sandbox login repetition | 4 logins | Explain trade-off; offer setup-token option (P16) |
| Update-available banners from GSD/Claude | Users run `/gsd:update`, break "image wins" | Document "upgrade = rebuild"; suppress where possible (P4, P5) |

## "Looks Done But Isn't" Checklist

Run on the **host** (the dev sandbox cannot run Docker):

- [ ] **Mounts:** `docker inspect <c> --format '{{json .Mounts}}'` shows exactly: workspace bind, state directory bind at `/home/sandbox/.claude`, optional `.m2` named volume. No single-file mounts, no anonymous volumes, no docker.sock, nothing under host `$HOME` outside the sandbox folder.
- [ ] **Env via exec:** `docker exec <c> env | grep -E 'CLAUDE_CONFIG_DIR|DISABLE_AUTOUPDATER|DISABLE_UPDATES'` prints all three (exec, not run).
- [ ] **Login survives:** `cc-down && cc-up && claude` opens with no login/onboarding; also after `upgrade` (recreate) and after a full image rebuild.
- [ ] **`.claude.json` location:** exists at `~/.claude/.claude.json`; no `~/.claude.json` in container.
- [ ] **Image wins (GSD):** downgrade the state (`echo 0.0.0 > ~/.claude/gsd-core/VERSION` on host) or use an older sandbox, restart: `cat ~/.claude/gsd-core/VERSION` == baked version, hooks in `settings.json` reference `/home/sandbox/.claude`, none reference `/root`.
- [ ] **Image wins (Claude):** `claude --version` == Dockerfile ARG after a session; `ls ~/.local/share/claude` absent; `claude doctor` shows auto-updates disabled.
- [ ] **ccusage:** `ccusage --version` and `ccusage daily --offline` work as `sandbox` in an `exec` shell, the totals reflect real sessions, and the number matches before/after migration.
- [ ] **Upgrade actually upgrades:** change one build ARG, run upgrade: new value in container, old container gone, other sandboxes still on old image until upgraded (documented), no dangling per-project images.
- [ ] **Toolchain asserts:** `node -v` (24.x), `java -version` (21), `mvn -v` (pinned), `python3 -m venv` works, `pip install x` outside venv refuses, `gh --version`, `git status` in workspace without dubious-ownership error.
- [ ] **Arch:** `uname -m` = aarch64, no `amd64` hardcoded strings (`grep -rn 'amd64\|x86_64\|linux-x64' ClaudeCode/ base/`).
- [ ] **Persistence after `cc-down`:** state dir and code still on host; `.m2` volume still exists (`docker volume ls`).
- [ ] **Migration:** old sessions resumable at the new path; old container removed; junk (`.npm`, `.local`) gone from the sandbox folder.
- [ ] **README:** every command mentioned exists (`ls`); no `docker-compose` v1, no `-v`, no `cc-upgrade.sh` ghost.
- [ ] **Compromised names:** `grep -rE 'get-shit-done-cc|gsd-build' .` returns only documentation warnings.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Login lost (P1/P2/P16) | LOW | Restore `.claude.json` from `~/.claude/backups/`; else `claude` -> `/login`; consider `setup-token` |
| Wrong `.claude.json` location after migration | LOW | Stop container; `mv` root `.claude.json` into `<state>/.claude/.claude.json`; restart |
| Stale/mixed GSD files | LOW | `gsd-core --claude --global --config-dir ~/.claude --uninstall` then reinstall from baked package, or restart to reconcile; local edits are in `gsd-local-patches` |
| Duplicate Claude binary in home | LOW | `rm -rf ~/.local/share/claude ~/.local/bin/claude` on host state; set DISABLE_UPDATES |
| History invisible after path change (P10) | MEDIUM | Rename `projects/<old-encoded>` to new encoded name; edit `projects` key in `.claude.json`; or remount code at old path |
| `down -v` deleted `.m2` volume | LOW | Just rebuild cache; no irreplaceable data if state is on bind mount |
| Anonymous-volume stale home (P11) | LOW | `docker compose down -v` once (state is on host), remove `VOLUME`, `up` |
| Container name conflict (P15) | LOW | `docker rm -f <old name>`; ensure scheme unified |
| Credentials committed to git (P16) | HIGH | Revoke login (`/logout` + claude.ai session revoke), rotate tokens, purge history (`git filter-repo`), add ignore rules |
| Malicious hook planted in `.git/hooks` (P17) | MEDIUM | Inspect and delete hooks on host, rotate any credentials reachable from host tools, re-clone if unsure |
| ccusage "native binary" errors (P7/P8) | LOW | `chmod a+rx` binary / reinstall with optional deps in image; rebuild |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1 Single-file `.claude.json` mount | P2 State | Mounts inspect shows dir-only; login survives recreate |
| 2 `CLAUDE_CONFIG_DIR` inconsistent | P2 State (+P5 test) | `docker exec env` shows var; only `~/.claude/.claude.json` exists |
| 3 Mount hides GSD in `~/.claude` | P3 Tools | GSD VERSION == image after start with empty state dir |
| 4 Stale GSD / hook paths / self-update | P3 Tools | Downgraded state gets reconciled; no `/root` in `settings.json` |
| 5 Claude auto-updater | P3 Tools | `claude doctor` disabled; no `~/.local/share/claude` |
| 6 Node 20 EOL, GSD needs >= 24 | P1 Base | `node -v` >= 24 assert in build |
| 7 ccusage non-executable binary | P3 Tools | Build-time `ccusage --version` as `sandbox` |
| 8 ccusage optional dep missing | P3 Tools | Same smoke test; no `--omit=optional` in repo |
| 9 ccusage data/offline/retention | P3 Tools + P5 docs | Known-number check; README notes |
| 10 cwd-keyed history | P2 State + P5 Migrate | `/resume` lists old sessions after migration |
| 11 `VOLUME` + anonymous volume | P1/P2 | No anonymous volumes in `inspect` |
| 12 Runtime `npx @latest` | P3 Tools | grep guard: no `npx`/`npm i`/`curl` in entrypoint |
| 13 Rebuild != upgrade | P4 Lifecycle | Change ARG -> version changes in running container |
| 14 `down -v` | P4 Lifecycle | No `-v` in scripts; `.m2` survives `cc-down` |
| 15 Compose naming / collisions | P4 Lifecycle | Uppercase name rejected cleanly; mismatched path refused |
| 16 Shared credentials / state in git tree | P2 State | State outside repo; `git status` clean; per-sandbox state |
| 17 One-way isolation | P2 + P5 docs | README threat-model; `.git/hooks` ro mount test |
| 18 Socket / ssh / host creds | P2 + P4 doctor | `cc-doctor` mount audit passes |
| 19 uid 1000 `ubuntu` user | P1 Base | `id sandbox` == ARG UID; `getent passwd 1000` |
| 20 Synthetic ownership | P1/P2 | Mount points pre-created, no `chown` in entrypoint |
| 21 git safe.directory / gh / identity | P1 + P2 | `git status` works after recreate; identity present |
| 22 Bind-mount performance | P2 State | `.m2` and `node_modules` on named volumes; timing sanity |
| 23 `curl | bash` failure masking | P1/P3 | `pipefail` SHELL; version asserts; checksum steps |
| 24 Unqualified base image | P1 + P4 | `pull_policy: never`; build order in script |
| 25 Python PEP 668 / Maven JDK | P1 Base | `mvn -v` shows JDK 21; venv works |
| 26 exec shells skip entrypoint | P3 + P4 | `init: true`; env visible in exec |
| 27 Migration mechanics | P5 Migrate | Host checklist above, per sandbox |

## Sources

- Claude Code docs, "Development containers" (persisting auth: mount `~/.claude` + set `CLAUDE_CONFIG_DIR`, managed settings path, `DISABLE_AUTOUPDATER`, bypass-permissions warning): https://code.claude.com/docs/en/devcontainer (HIGH)
- Claude Code docs, "Advanced setup" (native install layout, auto-update semantics, `DISABLE_AUTOUPDATER` vs `DISABLE_UPDATES`, version pinning, apt repo + fingerprint, manifest GPG verification): https://code.claude.com/docs/en/setup (HIGH)
- Claude Code docs, "Authentication" (credential storage `.credentials.json`, `CLAUDE_CONFIG_DIR` scoping, `setup-token`, precedence): https://code.claude.com/docs/en/authentication (HIGH)
- Claude Code docs, ".claude directory" and env-vars reference: https://code.claude.com/docs/en/claude-directory , https://code.claude.com/docs/en/env-vars (HIGH)
- anthropics/claude-code #14313 (`.claude.json` written to home when `CLAUDE_CONFIG_DIR` unset with bind-mounted subdirs): https://github.com/anthropics/claude-code/issues/14313 (MEDIUM)
- link-assistant/hive-mind #2296 (single-file credential mounts, stale inode, refresh-token divergence): https://github.com/link-assistant/hive-mind/issues/2296 (MEDIUM)
- Community: rename-over-mountpoint EBUSY family (schubergphilis/claude-docker #1, noogram/cosmon #113) (MEDIUM)
- ccusage docs (data source, `CLAUDE_CONFIG_DIR`): https://ccusage.com/guide/claude/ (HIGH); ccusage@20.0.26 package contents and live run on aarch64 (HIGH, verified 0644 native binary, chmod-on-first-run launcher, optional-dep resolution, hard error on bad `CLAUDE_CONFIG_DIR`)
- `@opengsd/gsd-core@1.15.0` package contents and live install into a scratch config dir (`engines node>=24`, `--config-dir`, `--portable-hooks`, manifest, update-check hook, `/gsd:update`) (HIGH); npm registry metadata for `@anthropic-ai/claude-code` (`engines node>=22`) (HIGH)
- Node.js release schedule (Node 20 EOL 2026-04-30; 24 Active LTS to 2028-04-30): https://endoflife.date/nodejs (HIGH)
- Ubuntu 24.04 `ubuntu` uid 1000 user: crops/poky-container #115, devcontainers/images #1056, jupyterhub/repo2docker #1346 (MEDIUM); verified in dev sandbox `/etc/passwd` (HIGH)
- Docker Compose anonymous volume reuse / `--renew-anon-volumes`: docker/compose #4476, #7320 (MEDIUM)
- Compose project name rules: https://docs.docker.com/compose/how-tos/project-name.md (HIGH)
- Docker Desktop VirtioFS ownership and performance: docker/for-mac #6243, #6812; coleam00/Archon #1279 (git dubious ownership on macOS bind mounts); CNCF "Docker on MacOS is slow and how to fix it" (MEDIUM)
- Docker socket = root-equivalent: Quarkslab, Netdata guides (MEDIUM)
- Live dev sandbox observations (Ubuntu 26.04, aarch64, whole-home virtiofs mount, Node 20.20.2, uid 1001, 229 MB `~/.local/share/claude`, 569 MB `~/.npm`, absolute hook paths in `settings.json`, `installMethod: native`) (HIGH)

---
*Pitfalls research for: Docker sandbox containers for AI coding agents (Claude Code + GSD + ccusage) on macOS + Docker Desktop*
*Researched: 2026-09-30*
