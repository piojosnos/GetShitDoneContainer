# Phase 1: Two-Mount Claude Sandbox - Pattern Map

**Mapped:** 2026-09-30
**Files analyzed:** 6 (all new; nothing existing is modified)
**Analogs found:** 5 / 6 (all analogs are old-layout files, used for style only, never modified)

The repo has only the old layout (tracked: `ClaudeCode/*`, `OpenCode/*`, `README.md`). No new-layout code exists yet. RESEARCH.md Patterns 1-5 hold the concrete file bodies. This map says which old-file conventions to copy and which to NOT carry over. All analog paths below are git-tracked.

## File Classification

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `base/Dockerfile` | config (image) | build-time | `ClaudeCode/Dockerfile` | role-match (style only) |
| `claude/Dockerfile` | config (image) | build-time | `ClaudeCode/Dockerfile` (lines 25-39) | role-match |
| `base/sbx-entrypoint` | utility (entrypoint) | request-response (check then exec) | `ClaudeCode/docker-entrypoint.sh` | role-match |
| `compose.yml` | config (orchestration) | lifecycle | `ClaudeCode/docker-compose.yml` | role-match (mostly a contrast) |
| `SANDBOX.md` | docs | n/a | `ClaudeCode/README.md` (tone only) | partial |
| `tests/static-check.sh` | test | batch (grep assertions) | none | no analog |

## Pattern Assignments

### `base/Dockerfile` (image, build-time)

**Analog:** `ClaudeCode/Dockerfile`

**Section banner + why-comment style to copy** (lines 3-5, 25-36):
```dockerfile
# --------------------------------------------------------------------------------
# Sandbox + ubuntu packages
# --------------------------------------------------------------------------------
```
Put a "why" comment block above each RUN, as in lines 26-35 (explains that `/usr/local/bin` is outside the mount).

**Chaining and cleanup to copy** (lines 7-23): `RUN a && \ b ... && rm -rf /var/lib/apt/lists/*` (cleanup last). New file adds `--no-install-recommends`.

**Tail ordering to copy** (lines 53-67): `COPY` entrypoint, `chmod`, then `USER sandbox`, `WORKDIR`, `ENTRYPOINT [...]`, `CMD [...]`.

**Do NOT carry over:**
- `FROM ubuntu:latest` (line 1). Use `ubuntu:24.04`.
- `curl ... | bash` (lines 11, 38).
- `VOLUME /home/sandbox` (line 63).
- The apt gh repo block (lines 14-21) is permitted by CONTEXT, but RESEARCH prefers a pinned tarball with `sha256sum -c`.
- `useradd -m -s /bin/bash sandbox` (line 7) becomes `userdel -r ubuntu || true` then `useradd -m -u 1000 -s /bin/bash sandbox`.

**Body source:** RESEARCH.md Pattern 4 (lines 303-374). Copy it nearly verbatim: pinned ARGs, tarball checksum blocks, `git config --system safe.directory '*'`, pre-created mount targets, ENV for `HISTFILE`, `PROMPT_COMMAND`, `GH_CONFIG_DIR`, `GIT_CONFIG_GLOBAL`.

---

### `claude/Dockerfile` (image, build-time)

**Analog:** `ClaudeCode/Dockerfile` lines 25-39 (the "install outside home" comment and the binary-in-`/usr/local` idea).

Copy the intent comment style (why the binary lives outside `/home/sandbox`). Replace the installer (`curl | bash` + `cp`, lines 38-39) with the npm pin. **Do not** reproduce the GSD paragraph (lines 32-35) as behavior: no GSD in Phase 1 (D-05). A short comment noting GSD arrives in Phase 2 is fine.

**Body source:** RESEARCH.md Pattern 5 (lines 377-399): `ARG BASE_IMAGE=sbx-base:local`, `FROM ${BASE_IMAGE}`, `USER root`, `npm install -g --allow-scripts=... @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}`, `ENV CLAUDE_CONFIG_DIR DISABLE_UPDATES SBX_MOUNTS`, `USER sandbox`, build-time `claude --version` assertion.

Note: RESEARCH flags the npm package as SUS (too-new, no-repository) and asks for a `checkpoint:human-verify` before the first install.

---

### `base/sbx-entrypoint` (entrypoint, check then exec)

**Analog:** `ClaudeCode/docker-entrypoint.sh`

**Shebang/strictness to copy** (lines 1-2), upgraded:
```bash
#!/bin/bash
set -e
```
New file uses `#!/usr/bin/env bash` and `set -eu` (RESEARCH Pattern 3).

**Comment-the-why style** (lines 4-13): a block above the logic explaining the design decision.

**Terminal pattern to copy exactly** (lines 23-24):
```bash
# Execute the command
exec "$@"
```

**Do NOT carry over:** the `.initialized` marker gate and any `npx` runtime install (lines 14-21). Forbidden by D-05.

**Body source:** RESEARCH.md Pattern 3 (lines 279-300): `is_mount()` via `awk` over `/proc/self/mountinfo`, loop over mount targets plus `${SBX_MOUNTS:-}`, errors prefixed `[sbx] ERROR:` to stderr. Must be mode 755 in git.

---

### `compose.yml` (orchestration)

**Analog:** `ClaudeCode/docker-compose.yml`

**Copy:** 2-space YAML; `container_name:` with env-var interpolation (line 6: `cc_gsd_${PROJECT_NAME}` becomes `"sbx-${SBX_NAME}"`); a bind mount entry under `volumes:`.

**Do NOT carry over:**
- `${PROJECT_PATH}:/home/sandbox` whole-home mount (line 8). Use five long-syntax mounts.
- `stdin_open` / `tty` / `command: /bin/bash` (lines 9-11). Use `init: true` and `command: ["sleep","infinity"]`.
- `build:` block. Use `image: sbx-claude:local` with `pull_policy: never`.
- Variable names `PROJECT_NAME` / `PROJECT_PATH`. Use `SBX_NAME` / `SBX_DIR` (D-07).
- Any `down -v` and the `cc_` prefix.

**Body source:** RESEARCH.md Pattern 1 (lines 219-267): top-level `name: "sbx-${SBX_NAME:?...}"`, `${SBX_DIR:?...}` on the first mount only, `create_host_path: false` on all five mounts, `security_opt`/`cap_drop` (cap_drop compatibility is unverified; host-check it).

---

### `SANDBOX.md` (docs)

**Analog:** `ClaudeCode/README.md` for tone only (not read in detail). Content comes from RESEARCH.md: build commands (lines 139-146), the `export` note (Pitfall 2), the preflight `for d in ...` loop (Pitfall 1 item 3), the smoke-test bypass `--entrypoint claude` (Pattern 3 consequence), and the host checklist H-00..H-13 (RESEARCH Validation Architecture, lines ~143-175 of the later half). Word the no-delete warning so the literal `-v` flag does not appear (static-check greps docs). Use `docker compose`, never `docker-compose`. Do not edit the root `README.md`.

---

### `tests/static-check.sh` (test, batch)

No analog; the repo has no tests. Follow the project's bash conventions (plain, `set -e`, short). Assertions come from the RESEARCH "Phase Requirements -> Test Map" (e.g. `! grep -nE '^\s*VOLUME\b' base/Dockerfile claude/Dockerfile`, no `get-shit-done-cc|gsd-build`, no `latest` tag, `ClaudeCode/` and `OpenCode/` unchanged via `git diff --quiet`). Optional.

## Shared Patterns

### Why-comments and banners
**Source:** `ClaudeCode/Dockerfile` lines 3-5, 25-36. **Apply to:** both Dockerfiles, entrypoint, compose.yml (`#` comments above non-obvious settings).

### Strict shell + exec tail
**Source:** `ClaudeCode/docker-entrypoint.sh` lines 2, 23-24. **Apply to:** `base/sbx-entrypoint`, `tests/static-check.sh`.

### Env in image ENV, not the entrypoint
**Source:** RESEARCH Pattern 2 (old layout has no equivalent). **Apply to:** both Dockerfiles. `docker exec` shells never run the entrypoint, so `CLAUDE_CONFIG_DIR`, `HISTFILE`, `GH_CONFIG_DIR`, `GIT_CONFIG_GLOBAL` must be ENV.

### Naming
`sbx-<name>` for container and project; `sbx-base:local`, `sbx-claude:local`. Never `cc_`.

### Coexistence
Nothing under `ClaudeCode/`, `OpenCode/`, or root `README.md` is edited.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `tests/static-check.sh` | test | batch | No tests exist in the repo; use RESEARCH Validation Architecture |

## Metadata

**Analog search scope:** all git-tracked files (`git ls-files`); only `ClaudeCode/` and `OpenCode/` contain relevant code.
**Files scanned:** 12 tracked; 4 read in full.
**Pattern extraction date:** 2026-09-30
