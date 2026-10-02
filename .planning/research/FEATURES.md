# Feature Landscape

**Domain:** Docker-based sandbox containers for AI coding agents (Claude Code now, OpenCode next) on a macOS developer laptop
**Researched:** 2026-09-30
**Overall confidence:** MEDIUM-HIGH (Anthropic devcontainer docs, Docker `sbx` docs and ccusage docs read directly; claudebox/sbox behavior is from their READMEs and not tested)

## Comparable tools surveyed

| Tool | What it is | Relevance |
|------|-----------|-----------|
| Anthropic devcontainer (reference + Dev Container Feature) | Official way to run Claude Code in a container | Defines the persistence recipe (volume at `~/.claude` + `CLAUDE_CONFIG_DIR`), pinning and no-autoupdate guidance |
| Docker Sandboxes (`sbx run/ls/stop/rm`) | Docker's own microVM agent sandbox, many agents (claude, codex, gemini, opencode, shell...) | Sets UX expectations: one command, reconnect-by-workspace, `ls`/`rm`, agents are NOT upgraded by image/CLI updates |
| RchGrav/claudebox | Per-project Docker images, profiles, slots | The feature-heavy end of the spectrum; useful mostly as a list of things not to copy |
| bpeterme/claudebox (`cbox`) | Per-project containers, `cbox`, `shell`, `stop`, `reset`, `list`, `rebuild`, `oc` for opencode | Closest to the target UX (small verb set, both agents) |
| streamingfast/sbox | Wrapper with remembered per-project config, `run/info/shell/stop/clean` | Confirms "remember project args" as a standard feature |
| psyb0t/docker-claudebox | Claude in Docker with HTTP/MCP/Telegram/cron interfaces | Mostly out of scope; shows the feature-creep ceiling |
| ccusage | Reads agent session JSONL, reports daily/weekly/monthly/session/blocks; also reads Codex/OpenCode | Directly usable; path controlled by `CLAUDE_CONFIG_DIR` / `OPENCODE_DATA_DIR` |

## Table Stakes

Features users expect. Missing = the sandbox is annoying or unsafe enough to abandon.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Non-root user in the container | Claude Code rejects `--dangerously-skip-permissions` as root; every comparable tool does this | Low | Already done (`sandbox` user). Confidence HIGH (Anthropic docs) |
| Project folder bind-mounted at a fixed workspace path (e.g. `/workspace`) and NOT over `$HOME` | claudebox uses `/workspace`; Anthropic devcontainer bind-mounts the repo as workspace; mounting over home is the documented cause of "login lost / tools vanished" | Low | This is Active problem 1. Pick one path and keep it stable: Claude keys session history per working directory, so a fixed path keeps history consistent across restarts. Confidence HIGH |
| Agent state persisted outside the container filesystem (login, settings, history survive `down`/rebuild) | Anthropic's docs: home is discarded on rebuild, so mount `~/.claude`; every tool has a persistence story | Low-Med | Core Value. Two-part gotcha: `~/.claude.json` lives OUTSIDE `~/.claude`, so mounting only the directory doesn't keep login. Fix per Anthropic: mount the state dir and set `CLAUDE_CONFIG_DIR` to it so `.claude.json` is written inside. Bind a directory, never a single file (host/container atomic-rename of a single-file mount produces stale or lost writes). Confidence HIGH |
| State is per project, not shared globally | Anthropic reference uses `claude-code-config-${devcontainerId}`; claudebox/sbox key state per project/hash | Low | Falls out of "one container per project" plus a per-project state folder. Host folder (not named volume) is the user's chosen form: inspectable and backup-able |
| All tools baked into the image; nothing installed into the mount at runtime | Anthropic recommends installing in the Dockerfile; runtime installs into a mount are what broke ccusage and GSD here | Med | Active problem 2. Removes the `.initialized` entrypoint gate |
| Image version wins over persisted state (rebuild delivers new tool versions) | Docker `sbx` explicitly does NOT update agents in existing sandboxes and users complain; the requirement here is stronger | Med | Needs: `DISABLE_AUTOUPDATER=1` (Anthropic-documented) so the in-container self-updater doesn't diverge from the image; GSD/skills/commands that get copied into persisted `~/.claude` must be refreshed from the image on start (idempotent sync), not gated by a one-time marker. This is the hard, project-specific part |
| Explicit version pinning (base image tag, build args for Claude Code, GSD, ccusage, JDK, Maven, Node) | Anthropic: pin via `npm install -g @anthropic-ai/claude-code@X.Y.Z` for reproducible builds | Low-Med | "Pinned by default, bump = edit one build arg + rebuild". Avoids floating `latest` (see CONCERNS.md) |
| One-command rebuild-to-upgrade | claudebox `rebuild`/`update`, cbox `rebuild`; devcontainers "Rebuild Container" | Low | `rebuild` = `docker compose build [--pull --no-cache]` + recreate container. Must not touch the state folder |
| Adding a tool = one-file edit + rebuild | claudebox `install`/`add` (via a command), devcontainer Features (one JSON line) | Low | For this project: one Dockerfile/`ARG` line in the shared base. No command needed |
| `--dangerously-skip-permissions` usable inside | The point of the container is unattended operation | Low | Already works; document it, don't wrap it |
| Multi-arch/arm64-correct image | Apple Silicon host | Low | Known past failure (arm64 ccusage binary). Use package-manager installs that resolve the arch |
| Jump-in: start if needed, then shell | Docker `sbx run` reconnects to the existing sandbox for a workspace; cbox does this by default | Low | Top-priority helper. `up`-if-not-running then `docker exec -it ... bash` (optionally `claude`) |
| Remembered project arguments (name -> host path) | sbox persists per-project config; `sbx` keys by workspace | Low | A plain key=value/TSV file (e.g. `~/.config/<tool>/projects`). Every later helper reads it |
| List sandboxes / status | `sbx ls`, `cbox list`, `sbox info` | Low | `docker ps -a --filter name=cc_gsd_` plus the remembered name/path mapping |
| Stop and remove a sandbox | `sbx stop/rm`, `cbox stop/reset`, `sbox clean` | Low | `down` exists; add remove/cleanup. Removing a container must never delete the state folder or the code |
| Working `ccusage` for the project's Claude sessions | Users of Claude in containers ask for cost/usage visibility; ccusage reads `~/.claude/projects` or `$CLAUDE_CONFIG_DIR` | Low-Med | Install globally in the image (`npm i -g ccusage@<pin>`), and make sure `CLAUDE_CONFIG_DIR` points at the persisted dir so it reads real sessions. Baked install avoids network at run time. Confidence HIGH on env var behavior (ccusage docs) |
| README that matches reality + migration notes | Housekeeping and existing-sandbox migration are stated requirements | Low | Includes how to move login/history from the old `${PROJECT_PATH}:/home/sandbox` layout |

## Differentiators

Features that go beyond the baseline. Not expected for a "small bash scripts" project, but valued. Candidates ordered by value/cost for this project.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Shared base image + thin per-agent images | One place for git/gh/JDK 21/Maven/Node/Python; adding OpenCode = a ~10-line Dockerfile. Most comparable tools use one image with profiles; layering is cleaner and cheaper | Med | Already decided. Build order dependency: base must be built before agent images (script/compose needs to enforce) |
| Same script UX for every agent (`<agent> up/bash/down`, or one script with an agent arg) | cbox `oc` and Docker `sbx` (one CLI, many agents) show this is what users like | Low-Med | Only worth doing once OpenCode is revived. Design remembered-args file with an agent field so it is not a rewrite later |
| Per-agent state dirs under one project state folder (`state/claude`, `state/opencode`) | OpenCode keeps auth in `~/.local/share/opencode/auth.json`, config in `~/.config/opencode`, sessions under `~/.local/share/opencode`; Claude uses `~/.claude` + `~/.claude.json`. Separate mounts keep them from colliding | Low | Set `CLAUDE_CONFIG_DIR` for Claude; mount the two XDG dirs (or set `XDG_DATA_HOME`/`XDG_CONFIG_HOME` under one host folder) for OpenCode. Needs a small check on the real OpenCode version |
| ccusage covering more than Claude | ccusage also reads OpenCode (`OPENCODE_DATA_DIR`) and Codex (`CODEX_HOME`) | Low | Free once agents share the base image. Keep per-project only (cross-project aggregation is Out of Scope) |
| Upgrade with `--pull --no-cache` option and a "what changed" print (tool versions after rebuild) | Confirms the upgrade really delivered new versions; Docker `sbx` docs show users confused by agents not updating | Low | `--versions` / post-build `claude --version; ccusage --version; gsd ...` echo. Cheap trust builder |
| `cc-status`-style one-liner showing: container state, host path, state folder, image build date/tool versions | Combines list + version check | Low | Only after list exists |
| "Clean up old sandboxes" with confirmation and dry-run | sbox `clean`, claudebox `clean`, `sbx rm` (confirms unless `--force`) | Low-Med | Print what will be removed; never auto-delete state without an explicit prompt |
| Baked-in shell niceties (history file in persisted state, tmux, zsh/prompt showing project name) | claudebox and the Anthropic reference ship zsh; shell history persistence is a frequent request | Low | Persisting `.bash_history` needs a persisted location (e.g. `HISTFILE` under the state dir). Cheap and nice; keep bash |
| Egress network allowlist (Anthropic `init-firewall.sh`) | The only real mitigation for prompt-injection exfiltration of `~/.claude` credentials while running with skip-permissions | High | Needs `NET_ADMIN`/`NET_RAW`, iptables/ipset, domain allowlist maintenance. Anthropic itself says it is optional. Defer; record as a later milestone candidate |
| Mount at the same absolute path as the host (Docker `sbx` style) | Paths printed by the agent match the host, so IDE links and stack traces work | Low-Med | Nice-to-have but conflicts with "fixed `/workspace`". Prefer fixed `/workspace`; only revisit if path mismatch actually hurts |
| Managed settings baked into the image (`/etc/claude-code/managed-settings.json`) | Anthropic-documented way to enforce settings that persisted `~/.claude` can't override; also a clean answer to "image wins" for settings | Low | Useful for env/permission defaults; not for GSD skills. Consider only if settings drift becomes a problem |
| Non-interactive/unattended run (`claude -p`) wrapper | docker-claudebox programmatic mode | Low | Trivial via `docker exec`; no need for a feature |

## Anti-Features

Features to explicitly NOT build. The user wants small, plain bash scripts grown incrementally.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Profile/slot systems (claudebox `profiles`, `add`, `slot`, `revoke`) | Large state machine, hard to understand; one container per project already gives isolation | Edit the Dockerfile in the shared base and rebuild |
| A `install <apt-pkg>` runtime command that installs into a running container | Undoes "image is the source of truth"; the tool vanishes on rebuild | Dockerfile line + rebuild |
| Runtime self-update of Claude Code / GSD inside the container (autoupdater on, "update once per day on first use" like cbox) | Makes versions non-reproducible and lets persisted state diverge from the image, which is exactly the bug being fixed | `DISABLE_AUTOUPDATER=1`; upgrade only by rebuild |
| Mounting host `~/.ssh`, `~/.aws`, host `~/.claude`, or the whole host home | Anthropic warns credentials in the container can be exfiltrated under skip-permissions; defeats the isolation purpose | Per-project scoped tokens (gh token env var or a dedicated deploy key inside the state folder) if git push is needed |
| Single-file bind mounts for `~/.claude.json` | Rename-on-write breaks bind mounts (stale/lost writes); flaky on Docker Desktop | `CLAUDE_CONFIG_DIR` pointing into the mounted state directory |
| Global config/YAML layering (sbox-style global + repo + project configs) | Overkill for ~4 sandboxes | One flat name -> path file; upgrade later only if needed |
| Multi-project-per-container | Already Out of Scope; weakens isolation | One container per project |
| Docker-in-Docker / mounting `/var/run/docker.sock` | Root-equivalent on the Docker VM; kills the isolation story | Don't offer; run builds with Maven/Node inside the container |
| Passwordless sudo / root shell as default | Removes the non-root guarantee; skip-permissions refuses root | Bake tools in the image; use `docker exec -u root` manually when debugging |
| HTTP API, OpenAI-compatible endpoint, MCP server, Telegram bot, cron scheduler around the agent (docker-claudebox) | Different product (agent as a service) | Out of scope |
| Config/history sync across machines (claudedot-style git remote) | Sensitive data, extra moving parts; one laptop only | Host state folder can be backed up by normal means |
| microVM / custom template distribution / cloud sandboxes (Docker `sbx`, templates, `sbx move`) | Requires Docker's product; templates can embed credentials | Plain Docker Desktop + compose |
| A migration script (this milestone) | Only ~4 sandboxes; already decided | Documented manual steps |
| Pluggable agent framework / plugin system (this milestone) | Premature; ClaudeCode first, OpenCode next | Shared base + one thin Dockerfile per agent |
| Aggregated cross-project ccusage dashboard (this milestone) | Already deferred | Per-project `ccusage` inside each container |
| Auto-generated tooling (a Go/Python CLI wrapper, TUI, Homebrew formula) | Contradicts the "small plain bash" constraint | Keep scripts short; put shared bits in one sourced `lib.sh` only if duplication actually hurts |

## Feature Dependencies

```
Fixed workspace mount (not over $HOME)
   -> Image-provided home stays visible (.bashrc, .local, global npm bin)
        -> Tools baked into image (Claude, GSD, ccusage, JDK, Maven, Node, Python)
             -> ccusage works (binary visible, not hidden by mount)
             -> "Image wins" upgrade flow
                  -> Pinned versions via build args (+ DISABLE_AUTOUPDATER)
                  -> One-command rebuild + recreate

Agent state dir on host (bind directory)
   + CLAUDE_CONFIG_DIR -> state dir (keeps .claude.json inside)
        -> Login/history survive rebuild
        -> ccusage reads real sessions (same dir)
        -> Image-managed content (GSD files in ~/.claude) refreshed at start, from the image

Shared base image
   -> ClaudeCode image (this milestone)
   -> OpenCode image (next milestone; needs @opengsd/gsd-core, its own state dirs)

Remembered project args (name -> host path [-> agent])
   -> jump-in (up-if-needed + shell/claude)
   -> list/status
   -> cleanup
   -> rebuild/upgrade for a named project
   -> (later) per-agent selection

Manual migration doc depends on: fixed workspace path + state dir layout being final
```

Notes on ordering: the mount layout decision blocks everything else (ccusage, upgrades, README). The remembered-args file blocks the other helpers but is independent of the image work, so it can be developed in parallel or right after.

## MVP Recommendation

Prioritize (in order):

1. Mount layout: code at a dedicated workspace path, state in a host directory, `CLAUDE_CONFIG_DIR` set to it. (unblocks all)
2. Bake everything into the image with pinned build args, `DISABLE_AUTOUPDATER=1`, shared base + ClaudeCode image; refresh image-owned files in `~/.claude` on start. (Core Value)
3. ccusage in the image, verified against real sessions. (cheap once 1 and 2 hold)
4. Helpers, smallest first: remembered project args, `rebuild`/upgrade, jump-in, then list/status/cleanup.
5. README rewrite plus manual migration steps (last, because it documents the final layout).

One cheap differentiator to include: print tool versions after rebuild (confirms "image wins"). Second candidate if time allows: persist shell history in the state dir.

Defer:
- OpenCode revival, per-agent state dirs, ccusage for OpenCode: next milestone (design the remembered-args file with room for an agent field now).
- Egress firewall: real security value under skip-permissions but High complexity; revisit as its own milestone.
- Managed settings file, cleanup dry-run polish, zsh/tmux niceties: only if a concrete need shows up.

## Confidence and open questions

| Claim | Confidence | Basis |
|-------|------------|-------|
| `~/.claude.json` is outside `~/.claude`; `CLAUDE_CONFIG_DIR` moves it inside | HIGH | Anthropic devcontainer docs |
| `DISABLE_AUTOUPDATER=1` and pinned npm install are the supported pinning path | HIGH | Anthropic devcontainer docs |
| Single-file bind mounts of `.claude.json` are fragile | MEDIUM | Community reports; not verified on Docker Desktop for Mac |
| Docker `sbx` does not update agents in existing sandboxes; one sandbox per workspace by default | HIGH | Docker docs |
| ccusage honors `CLAUDE_CONFIG_DIR`, `OPENCODE_DATA_DIR`, `CODEX_HOME` and supports comma-separated paths | HIGH | ccusage docs |
| ccusage recommends Bun/npx style execution; a global npm install in the image should also work | MEDIUM | Verify in the phase (arm64, Node version, offline behavior); it failed before |
| claudebox / cbox / sbox command sets | MEDIUM | READMEs summarized via fetch; not run |
| OpenCode state locations (`~/.local/share/opencode`, `~/.config/opencode`) | MEDIUM | Third-party docs; verify against the installed version |

Questions to resolve in phase-level research:
- Claude Code keys history per working directory; moving code from `/home/sandbox/MyCode` to the new workspace path changes the project key. Verify whether `--resume`/history for existing sandboxes needs a rename of the `projects/<encoded-path>` folder during migration (inference, unverified).
- Which files does GSD install into `~/.claude` (skills/commands/hooks), and can they be refreshed idempotently at container start from the image copy without clobbering user edits?
- Confirm the exact `CLAUDE_CONFIG_DIR` behavior with the existing state folder contents (does it need `.claude.json` moved into it during migration?).

## Sources

- Anthropic, Development containers: https://code.claude.com/docs/en/devcontainer (HIGH)
- Anthropic, Explore the .claude directory: https://code.claude.com/docs/en/claude-directory (HIGH)
- Docker Sandboxes overview and usage: https://docs.docker.com/ai/sandboxes/ and https://docs.docker.com/ai/sandboxes/usage/ (HIGH)
- RchGrav/claudebox: https://github.com/RchGrav/claudebox (MEDIUM)
- bpeterme/claudebox (`cbox`): https://github.com/bpeterme/claudebox (MEDIUM)
- streamingfast/sbox: https://github.com/streamingfast/sbox (MEDIUM)
- psyb0t/docker-claudebox: https://github.com/psyb0t/docker-claudebox (MEDIUM)
- ccusage getting started / data sources: https://ccusage.com/guide/getting-started and https://ccusage.com/guide/opencode/ (HIGH)
- Community notes on `~/.claude.json` in containers: https://github.com/todofixthis/paddock/pull/13 , https://dev.to/sukkergris/persisting-claude-cli-login-between-container-builds-55cl (LOW-MEDIUM)
- OpenCode config/data locations: https://opencode.ai/docs/config/ and https://opencode.ai/docs/troubleshooting/ (MEDIUM)
