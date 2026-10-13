# Phase 2: Pinned Toolchain, GSD, and ccusage - Pattern Map

**Mapped:** 2026-10-08
**Files analyzed:** 17 (new or modified)
**Analogs found:** 16 / 17

All analogs are git-tracked (checked with `git ls-files`).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `versions.env` | config | batch (read by build) | `base/Dockerfile` lines 8-10 (ARG pins) | role-match |
| `build.sh` | utility (host script) | batch | `tests/host/lib-docker.sh` `build_images` + `claude/start.d/10-best-practices` layout | role-match |
| `base/Dockerfile` | config (image) | batch | itself (Node/gh blocks, lines 19-41) | exact |
| `claude/Dockerfile` | config (image) | batch | itself (lines 1-53) | exact |
| `claude/start.d/05-gsd` | hook | file-I/O | `claude/start.d/10-best-practices` | exact |
| `.dockerignore` | config | n/a | itself | exact |
| `compose.yml`, `SANDBOX.md` | config / docs | n/a | itself (build-command lines) | exact |
| `tests/guard/supply-chain.sh` | test (guard) | transform | itself (`versions_are_pinned`, lines 32-37) | exact |
| `tests/guard/lib.sh` | test lib | n/a | itself (lines 17-18) | exact |
| `tests/guard/bundle-wiring.sh` | test (guard) | transform | itself (lines 11-47) | exact |
| `tests/host/lib-docker.sh` | test lib | request-response | itself (`build_images`, `claude_pin`) | exact |
| `tests/host/h17-start-offline-and-failing-hook.sh` | test (host) | request-response | itself | exact |
| `tests/host/h13-env-and-no-self-update.sh` | test (host) | request-response | itself | exact |
| new host checks (toolchain, pins/GSD/ccusage, caches) | test (host) | request-response | `tests/host/h13-env-and-no-self-update.sh`, `h17-...sh` | role-match |
| `tests/selftest/host/*`, `fake-docker`, `tests/host-checklist.md`, `tests/host/run-all.sh` | test support | n/a | existing groups per check | role-match |
| `.planning/REQUIREMENTS.md`, `ROADMAP.md`, `01-REVIEW-DISPOSITION.md` | docs | n/a | themselves | exact |
| (none) uv/Temurin `COPY --from` stages | config | n/a | no in-repo multi-stage analog | none |

## Pattern Assignments

### `claude/start.d/05-gsd` (hook, file-I/O)

**Analog:** `claude/start.d/10-best-practices`

**Header and env pattern** (lines 1-15): `#!/usr/bin/env bash`, `set -eu`, comment block listing behavior, then
```bash
configDir=${CLAUDE_CONFIG_DIR:-}
```

**Input check pattern** (lines 17-30):
```bash
check_inputs() {
  if [ -z "$configDir" ]; then
    echo "[sbx] ERROR: CLAUDE_CONFIG_DIR is not set." >&2
    exit 1
  fi
  ...
}
```

**Main block** (lines 80-87): 80-col banner `# ---...` then `# Main / Entry Point`, then calls. For 05-gsd: `check_inputs`, `mkdir -p "$configDir"` (hang guard, RESEARCH Pitfall 1), run `gsd-core --claude --global --config-dir "$configDir" </dev/null >"$logFile" 2>&1`, print one line on success, dump log to stderr and `exit 1` on failure.

Traps: guard `no_installs_at_container_start` (tests/guard/start.sh:13) bans the whole words npm, npx, bunx, pip, apt, apt-get, curl, wget in `claude/start.d/*`, comments included. No planning IDs (D-xx, IMG-xx) in source. Full variable names, braces always, blank lines around control flow.

Mode 755 happens via the Dockerfile `chmod 755 /etc/sbx/start.d/*` (claude/Dockerfile:46).

---

### `base/Dockerfile` (image, batch)

**Analog:** itself.

**Checksum tarball pattern to copy for Maven** (lines 19-29, Node):
```dockerfile
RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in amd64) node_arch=x64 ;; arm64) node_arch=arm64 ;; *) echo "unsupported arch: $arch" >&2; exit 1 ;; esac \
    && f="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
    && curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${f}" \
    && curl -fsSL ".../SHASUMS256.txt" | grep " ${f}\$" | sha256sum -c - \
    && tar -xJf "$f" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "$f"
```
Changes: drop the `=value` defaults on lines 9-10; put each `ARG NAME` directly above its `RUN`; start the `RUN` with `: "${NODE_VERSION:?NODE_VERSION is not set; build with ./build.sh}"`. Maven recipe is in RESEARCH "Code Examples".

**Apt layer** (lines 15-17): extend the package list per D-18, keep `--no-install-recommends` and `rm -rf /var/lib/apt/lists/*`, no ARG above it.

**Banner comment style** (lines 19-22, 31-35): `# --- Name ---` followed by `# - ` bullets explaining why.

**ENV pattern** (lines 63-67): image ENV with backslash continuation, for `JAVA_HOME`, `PATH`, `NPM_CONFIG_CACHE`, `UV_CACHE_DIR`, `UV_LINK_MODE`, and `SBX_STATE_DIRS="cache/npm cache/uv m2"`.
```dockerfile
ENV HISTFILE=/home/sandbox/workspace/state/shell/bash_history \
    PROMPT_COMMAND="history -a" \
    ...
```

**Home folder / symlink as sandbox** (lines 92-93): `USER sandbox` then `RUN mkdir -p ...`; add the `~/.m2 -> /home/sandbox/workspace/state/m2` symlink here (mirror of the `~/.claude` link at claude/Dockerfile:19-20).

**FROM** (line 4): becomes the multi-stage form from RESEARCH Pattern 2, with `# check=skip=InvalidDefaultArgInFrom` under the syntax line.

---

### `claude/Dockerfile` (image, batch)

**Analog:** itself.

**npm global install pattern** (lines 16-20):
```dockerfile
USER root
RUN npm install -g --allow-scripts=@anthropic-ai/claude-code "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && rm -rf /root/.npm \
    && ln -s /home/sandbox/workspace/state/claude /home/sandbox/.claude \
    && chown -h sandbox:sandbox /home/sandbox/.claude
```
Copy for `@opengsd/gsd-core@${GSD_CORE_VERSION}` and `ccusage@${CCUSAGE_VERSION}`. Prefix with `NPM_CONFIG_CACHE=/tmp/npm-cache` and remove it in the same RUN (RESEARCH Pattern 5 trap 2). Add `chmod 755` on the ccusage native binary after install (Pattern 4).

**State dirs append, not replace** (lines 28-30): change `SBX_STATE_DIRS=claude` to `SBX_STATE_DIRS="${SBX_STATE_DIRS} claude"`.

**Hook copy** (lines 43, 46): `COPY claude/start.d/ /etc/sbx/start.d/` already picks up 05-gsd; chmod line already covers it.

**Smoke test** (line 53), extend for GSD and ccusage:
```dockerfile
RUN test "$(claude --version)" = "${CLAUDE_CODE_VERSION} (Claude Code)"
```
Add `gsd-tools runtime-identity --raw` and `test "$(ccusage --version)" = "ccusage ${CCUSAGE_VERSION}"`. Last layer: `COPY versions.env /etc/sbx/versions.env`. Keep exactly one `FROM ${BASE_IMAGE}` (H-02) and the `ARG BASE_IMAGE=sbx-base:local` default (a tag, not a version).

---

### `build.sh` (host script, batch)

**Analog for layout:** `claude/start.d/10-best-practices` (banners, functions, `Main / Entry Point`, full names, braces, blank lines around control flow). **Analog for the build call:** `tests/host/lib-docker.sh` lines 11-35 (`docker build -f <dir>/Dockerfile -t sbx-<dir>:local "$REPO_DIR"`, base then claude, stop on failure). Core from D-04, with `. ./versions.env` and regex `^[A-Z][A-Z0-9_]*`. Must be bash 3.2 and BSD-tool safe. Extra args (`--no-cache`) pass through via `"$@"`. Header comment explains versions.env is the only place versions live and why Dockerfiles have no defaults.

---

### `versions.env` (config)

**Analog:** ARG pin block `base/Dockerfile:8-10` and `claude/Dockerfile:4-5`. Plain `NAME=value`, grouped by `# sbx-base` / `# sbx-claude` comments; names in RESEARCH Pattern 1 (`UBUNTU_IMAGE`, `TEMURIN_IMAGE`, `UV_IMAGE`, `NODE_VERSION`, `GH_VERSION`, `MAVEN_VERSION`, `CLAUDE_CODE_VERSION`, `GSD_CORE_VERSION`, `CCUSAGE_VERSION`). Add `!versions.env` to `.dockerignore` (current content: `*`, `!base`, `!claude`, `!best-practices`, `**/.DS_Store`).

---

### `tests/guard/supply-chain.sh` and `lib.sh` and `bundle-wiring.sh` (guard rules)

**Analog:** themselves.

`versions_are_pinned` (supply-chain.sh:32-37) currently greps `^ARG NODE_VERSION=x.y.z$` in the Dockerfiles. Rewrite to read `versions.env` and assert no `=` default on Dockerfile ARGs, same `has_line` / `grep -Eq` style and `run_rules` registration (lines 44-48).

`bundle_reaches_build_context` (bundle-wiring.sh:15, 38): the wanted list is `'*' '!base' '!claude' '!best-practices'`; add `'!versions.env'`. The COPY extraction `awk '{ print $2 }'` must skip `--from=` / `--chmod=` option tokens, and allow `versions.env` as a first segment.

`lib.sh:17-18` (`DOCKERFILES`, `SANDBOX_FILES`): add `versions.env` and `build.sh` to `SANDBOX_FILES`.

---

### `tests/host/lib-docker.sh` (host test lib)

**Analog:** itself. Replace the two `docker build` calls (lines 20, 23) with `"$REPO_DIR/build.sh"` (flag passes through; keep the `$RUN/logs/$logPrefix-*.log` naming and the `print_log_tail` failure path, lines 27-31). Replace `claude_pin` (lines 51-53, `sed -n 's/^ARG CLAUDE_CODE_VERSION=//p'`) with a read of `CLAUDE_CODE_VERSION=` from `versions.env`, plus a general `pin_of NAME`. Host code is bash 3.2 with BSD tools.

---

### New and extended host checks

**Analog (running container assertions):** `tests/host/h13-env-and-no-self-update.sh` lines 1-40: header comment with `Depends on:` / `Needs:`, `. lib.sh`, `host_init`, small functions each calling `add_problem`, a `Main / Entry Point` block ending in `report_check H-NN "<failure>" "<pass text>"`. Uses `in_container`, `run_timeout`, `first_lines`.

**Analog (throwaway `docker run`, offline, failing hook):** `tests/host/h17-start-offline-and-failing-hook.sh` lines 48-52:
```bash
run_restricted_container() {
  run_timeout 60 docker run --rm --network none --cap-drop ALL --security-opt no-new-privileges:true \
    -e SBX_NAME=hosttest --mount "type=bind,source=$RUN/h17,target=/home/sandbox/workspace" \
    "$@" sbx-claude:local sh -c 'echo h17-command-ran' </dev/null 2>&1
}
```
Extend H-17 to also assert `state/claude/gsd-core/VERSION` equals the pin (GSD hook runs first; `/proc/no-such-dir` case relies on the hook's `mkdir -p` failing fast). Extend H-13 for `~/.local/bin/claude` absence and env vars `NPM_CONFIG_CACHE`, `UV_CACHE_DIR`. Cache survival (D-17) can follow the H-08/H-09 recreate pattern.

Each new host check needs a same-named group under `tests/selftest/host/`, a row in `tests/host-checklist.md`, and a slot in `tests/host/run-all.sh` (`noSandboxCheckList` etc.). Host tests may not use `rm`, `mv`, `truncate`; only `sbx-hosttest`, `sbx-base`, `sbx-claude` names allowed.

## Shared Patterns

### Start-hook failure semantics
**Source:** `base/sbx-start-lib.sh` `run_start_hooks` (lines ~82-110). Hooks run in name order, as sandbox; non-zero exit prints `[sbx] ERROR: start hook $hook failed; the container was not started.` and stops start. Apply to `05-gsd`.

### State folder creation
**Source:** `base/sbx-start-lib.sh` lines 70-76:
```bash
read -r -a stateFolderList <<< "shell gh git ${SBX_STATE_DIRS:-}"
for stateFolder in "${stateFolderList[@]}"; do
  mkdir -p "$state/$stateFolder" || return 1
done
```
Apply to cache folders (nested names like `cache/npm` work).

### Pins have no defaults, clear failure
**Source:** RESEARCH Pattern 1. `ARG NAME` above its own `RUN`, `: "${NAME:?NAME is not set; build with ./build.sh}"` first in the RUN. Apply to every versioned tool in both Dockerfiles.

### Source-text rules
Apply to all new source: ASCII only, no dash as punctuation in comments, no planning IDs in code, 80-col banners, braces always, full names, shell must run on macOS (BSD sed, bash 3.2).

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `FROM ... AS jdk` / `AS uv` stages with `COPY --from` in `base/Dockerfile` | config | batch | No multi-stage Dockerfile in the repo; use RESEARCH Pattern 2 |
| Maven block | config | batch | No Maven yet; adapt the Node block (lines 23-29) with the `.sha512` recipe in RESEARCH |

## Metadata

**Analog search scope:** `base/`, `claude/`, `tests/guard/`, `tests/host/`, repo root
**Files read:** base/Dockerfile, claude/Dockerfile, claude/start.d/10-best-practices, base/sbx-start-lib.sh (part), tests/host/lib-docker.sh, h17, h13 (part), run-all.sh (part), tests/guard/supply-chain.sh, bundle-wiring.sh (part), .dockerignore
**Pattern extraction date:** 2026-10-08
