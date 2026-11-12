# Phase 2: Pinned Toolchain, GSD, and ccusage - Research

**Researched:** 2026-10-08
**Domain:** Docker image build wiring (pins from one env file), pinned toolchains on Ubuntu 24.04 arm64, start-time GSD sync into a bind-mounted config dir, ccusage, tool caches on a bind mount
**Confidence:** HIGH for versions, digests, GSD installer and ccusage behavior (all run in this session on aarch64 Linux with Node 24.21.0); MEDIUM for Dockerfile/BuildKit behavior (docs plus reasoning, Docker cannot run in the dev sandbox); LOW for the items listed in the Assumptions Log (each needs one host-side observation)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Build wiring for `versions.env`
- **D-01:** A short `build.sh` at the repo root builds `sbx-base:local`, then `sbx-claude:local`. It replaces the two bare `docker build` commands in `SANDBOX.md`, and the host tests call it. Phase 3's upgrade command will call it. It follows the shell script layout rule (banners, functions, Main / Entry Point).
- **D-02:** The Dockerfiles carry no default versions. Each pinned `ARG` has no value, and the build stops with a clear message when one is missing, for example `NODE_VERSION is not set; build with ./build.sh`. Both Dockerfiles and `build.sh` carry a short comment saying that `versions.env` is the only place versions live and why there are no defaults.
- **D-03:** `build.sh` passes every pin in `versions.env` to both builds. Adding or bumping a pin never edits `build.sh`; a Dockerfile uses only the args it declares.
- **D-04:** How `build.sh` reads the file (the user rejected a hand-written parser):
  ```bash
  set -a; source versions.env; set +a
  for name in $(grep -oE '^[A-Z_]+' versions.env); do
    buildArgList+=(--build-arg "$name")      # Docker takes the value from the env var
  done
  ```
  No line validation. `versions.env` is plain `NAME=value` lines, valid bash, with blank lines and `#` comments, grouped under a comment per image. Names are uppercase.
- **D-05:** A copy of `versions.env` goes into the image at `/etc/sbx/versions.env`, as a record only (nothing reads it at runtime). It is copied as late as possible in the Dockerfile so a pin bump does not invalidate other layers. A host check may compare it with the repo's file.
- **D-06:** Rejected: `docker compose build` (Compose needs `SBX_NAME` and `SBX_DIR` for every command, and each pin would need a line in a build file), defaults checked by the guard (two copies of every version), and copying `versions.env` into the build and sourcing it in `RUN` steps (`FROM` pins still need build args, and any bump would rebuild every layer).

#### Pin strictness and supply chain
- **D-07:** Ubuntu, Temurin and uv are pinned by tag plus digest in `versions.env` (Temurin and uv via `COPY --from=` their official images, as in `.planning/research/STACK.md`).
- **D-08:** npm tools (Claude Code, `@opengsd/gsd-core`, ccusage) are installed at exact versions.
- **D-09:** Every downloaded tarball (Node, gh, Maven) is checked against its upstream checksum file, as `base/Dockerfile` already does for Node and gh.
- **D-10:** Plain apt packages are not pinned. They follow the pinned Ubuntu release and pick up security fixes on each rebuild. Pinning apt versions is brittle because Ubuntu drops old package versions. The docs say this in one line.
- **D-11:** Each new pin (version and digest) gets a human supply-chain approval checkpoint in the plan, as Claude Code did in Phase 1. This closes the moved Phase 1 findings WR-03 (integrity and checksums) and IN-03 (base image digest); record the outcome in the disposition files.

#### GSD sync at start
- **D-12:** GSD is baked with `npm install -g @opengsd/gsd-core@${GSD_CORE_VERSION}`, and a start hook in `/etc/sbx/start.d` runs its installer against `CLAUDE_CONFIG_DIR` at every start (pattern in `.planning/research/ARCHITECTURE.md`, "bake the installer, sync at start"). No `.initialized` marker, no `npx`, no network.
- **D-13:** A failed GSD sync stops the container start, like any failing start hook (fail closed). A silently stale GSD is the bug this project exists to fix.
- **D-14:** The GSD hook runs before `10-best-practices`, so a bundle skill still wins a name clash (Phase 1.2 rule). Hand edits to GSD files are overwritten by the image's GSD (the installer backs them up to `gsd-local-patches/`); that is the intended "image wins" behaviour.

#### Tool caches across recreate (new requirement IMG-07)
- **D-15:** Add requirement **IMG-07**: the Maven, npm and uv caches survive a container recreate (and so a rebuild/upgrade). Add it to `REQUIREMENTS.md` and the Phase 2 row of `ROADMAP.md`.
- **D-16:** The caches live on the existing bind mount under `<sandbox>/state/`: `NPM_CONFIG_CACHE` and `UV_CACHE_DIR` as image ENV pointing into `state/cache/...`, and `~/.m2` as a symlink into `state/` (the same pattern as the `~/.claude` link; Maven has no clean env var for its local repo). The new folders go into `SBX_STATE_DIRS` so the entrypoint creates them. No Docker named volume: `compose.yml` keeps "no volumes, all data in `$SBX_DIR`". The cost (slower file sharing for many small files, caches can reach GBs per sandbox and may be deleted freely) is accepted and stated in the docs.
- **D-17:** One host check proves a cached file survives a recreate.

#### Base tools and ccusage
- **D-18:** The base apt list adds jq, ripgrep, unzip, zip, openssh-client, make, build-essential and tzdata to today's set (ca-certificates, curl, git, less, procps, xz-utils). Python comes from apt (`python3`, `python3-venv`, `python3-pip`, 3.12 on noble); uv handles projects and other Python versions.
- **D-19:** GSD and ccusage go in the Claude image, not the base (they are agent tools). The base holds only toolchains and Linux tools.
- **D-20:** ccusage keeps its default online price lookup at run time. TOOL-03 covers container start only. It reads `CLAUDE_CONFIG_DIR`, which is the sandbox's own `state/claude`, so it reports this project's usage with no extra wiring.

### Claude's Discretion
- Exact names in `versions.env` (for example `UBUNTU_IMAGE`, `TEMURIN_IMAGE`, `UV_IMAGE`, `MAVEN_VERSION`, `GSD_CORE_VERSION`, `CCUSAGE_VERSION`), the hook file name and number, and the cache folder names under `state/`.
- Which image gets the `/etc/sbx/versions.env` copy (base, claude, or both) as long as a sandbox shell can read it.
- How the host checks prove start with networking disabled (for example `--network none`), the GSD pin bump, the native arm64 binaries and ccusage on real data.

### Deferred Ideas (OUT OF SCOPE)
None. The cache idea first proposed as deferred was folded in (D-15 to D-17).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| IMG-01 | Shared base provides Linux tools, git, gh, Node 24, Python 3 + uv, JDK 21 Temurin, Maven | Standard Stack (verified versions, digests, checksum recipe for Maven), Pattern 2 (base Dockerfile shape), pitfalls on `/etc/profile` PATH and ARG placement |
| IMG-03 | Every version pinned in one `versions.env`; no floating `latest`; no runtime installs | Pattern 1 (`build.sh` + env + per-tool `ARG`), D-02 missing-pin behaviour, guard rewrite list, `InvalidDefaultArgInFrom` directive |
| IMG-04 | Adding a tool is one line plus rebuild | Pattern 1: D-03 passes every pin to both builds; a new tool is one `versions.env` line plus one `RUN` using its `ARG` |
| IMG-07 (new, D-15) | Maven, npm, uv caches survive recreate | Pattern 5 (state/cache layout, `SBX_STATE_DIRS` replace-vs-append trap, build-time npm cache trap), host check design |
| TOOL-01 | Claude Code at pinned version, self-update off, no stray `~/.local` copy | Existing install block carried over; smoke test and H-13 extension (also check `~/.local/bin/claude`) |
| TOOL-02 | GSD only from `@opengsd/gsd-core`, synced at every start, image wins | Pattern 3 (hook design, verified installer behavior incl. the `/proc/no-such-dir` hang), `gsd-tools runtime-identity` as build smoke test |
| TOOL-03 | Start needs no network and no `npx`/`@latest` | Verified by instrumented run: installer makes no socket, DNS or child process call; hook output policy; H-17 extension |
| USE-01 | `ccusage daily/monthly/session` report this project's usage | Verified on arm64: reads `CLAUDE_CONFIG_DIR`; the mode 0644 native binary trap and its fix; host check on a seeded transcript |
</phase_requirements>

## Summary

This phase moves every version out of Dockerfile `ARG` defaults into one `versions.env`, adds the missing toolchains (Temurin 21, Maven, Python/uv, more apt tools) to the base image, adds GSD and ccusage to the Claude image, wires a start hook that runs the baked GSD installer into the persisted `state/claude`, and adds persisted tool caches under `state/`. Almost all mechanisms are plain Dockerfile and bash. The risk is not the tools; it is the many places that today read pins from the Dockerfiles (guard rules, host test library, fake docker, docs) and a handful of traps found while running the real packages in this session.

The most important findings for planning: (1) the `gsd-core` installer works offline, makes no network or child-process call, is idempotent, preserves user settings, credentials and history, and upgrades 1.15.0 to 1.16.0 in place; but it **hangs forever** (not fails) when given an uncreatable config dir such as `/proc/no-such-dir`, which is exactly what host check H-17 uses to provoke a failing hook, so the hook must `mkdir -p` the config dir itself first. (2) The ccusage native binary is shipped mode 0644 on arm64 and the launcher only chmods it when the user owns it, so a root-owned global install needs a build-time `chmod`. (3) Declaring `ARG` without a default is fine in `RUN` steps (use `${NAME:?message}` shell expansion for the clear error) but needs a `# check=skip=InvalidDefaultArgInFrom` directive for `FROM` lines, and the Dockerfile `${var:?}` form is not supported in Dockerfile expansion. (4) Two existing guard rules and the host library break the moment the pins move or a `COPY` carries a flag (`--from`, `--chmod`). (5) `SBX_STATE_DIRS` is an `ENV` that the Claude image currently *replaces*; adding cache folders in the base requires the Claude image to append.

**Primary recommendation:** Keep Phase 1's structure. Add `versions.env` (names below), a thin `build.sh` that follows D-04 with a slightly safer name regex, per-tool `ARG` lines declared immediately above the `RUN` that uses them with `${NAME:?...}` guards inside the same `RUN`, a `05-gsd` start hook that creates the config dir first and prints output only on failure, and update the guard, host library, fake docker and docs in the same plan wave as the Dockerfile change so the Linux-side suites stay green.

## Architectural Responsibility Map

This is image/infrastructure work, so tiers are build and runtime layers rather than web tiers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Single source of version pins | Repo root (`versions.env`) | `build.sh` (reads it), `/etc/sbx/versions.env` (record) | One file, bash-readable, no parser |
| Passing pins into builds | Mac host (`build.sh`) | Dockerfile `ARG` declarations | Docker takes values from the exported environment |
| Toolchains (JDK, Maven, Node, Python, uv, gh, apt tools) | `sbx-base` image | none | D-19: base holds toolchains and Linux tools only |
| Claude Code, GSD package, ccusage binaries | `sbx-claude` image | none | Agent tools, root-owned in `/usr/local`, outside the mount |
| GSD materialized into `~/.claude` | Container start (start hook, runs as `sandbox`) | `state/claude` bind mount (storage) | Image is the source, the mount is the destination; sync at every start |
| Tool caches (npm, uv, Maven) | `state/` on the Mac bind mount | Image `ENV` and one symlink | Survive recreate without a Docker volume (D-16) |
| Usage reporting | `ccusage` in `sbx-claude` | `state/claude/projects` (data) | Reads `CLAUDE_CONFIG_DIR`, no extra wiring |
| Proof of all of the above | Host checks on the Mac (real Docker) | Guard and self-tests on Linux (static / fake docker) | Docker is not available in the dev sandbox |

## Standard Stack

### Core (versions verified 2026-10-08)

| Item | Pin | Source | Why |
|------|-----|--------|-----|
| Ubuntu base | `ubuntu:24.04@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55` | Docker Hub registry API | [VERIFIED: registry-1.docker.io manifest, body sha256 equals header digest; index lists amd64, arm64v8, others]. The digest moved since STACK.md (008173c...), so the tag was rebuilt; the human checkpoint approves whichever digest is current at pin time |
| Temurin JDK 21 | `eclipse-temurin:21.0.12_8-jdk-noble@sha256:4d271cd5e0624598cf563342f47281b09cb364bc13acbbd7251f49f83470018d` | Docker Hub registry API | [VERIFIED: registry manifest; index lists amd64, arm64v8]. Newest 21.0 tag listed; the one before it is `21.0.11_10-jdk-noble` |
| uv | `ghcr.io/astral-sh/uv:0.12.21@sha256:a7aed3216253ee804de3e2d8afa5073baa1a177335345d43845cd4165e43b711` | ghcr registry API | [VERIFIED: manifest digest; amd64 and arm64]. `0.12.23` is current (digest `sha256:61d393e44e249f2e4b526b6c7ddcecce245946826e608e11c93ad4f5bba55b21`); either is fine, the checkpoint chooses |
| Node.js | `24.21.0` | nodejs.org dist index | [VERIFIED: https://nodejs.org/dist/index.json]: newest v24 is v24.21.0 (2026-09-07, Krypton). Node 26 is not LTS until 2026-10-28 per STACK.md, keep 24 |
| gh | `2.102.0` | GitHub releases API | [VERIFIED: api.github.com releases/latest tag v2.102.0, 2026-09-30] |
| Maven | `3.9.16` | Maven Central | [VERIFIED: tarball downloaded in this session, `sha512sum -c` OK against the `.sha512` file; `Maven 4.0.0-rc-7` is still the latest 4.x so stay on 3.9.x] |
| Claude Code | `2.1.285` (carry over the Phase 1 approved pin) | npm | [VERIFIED: npm registry]. It is the `stable` dist-tag; `latest` is 2.1.293 (2026-10-07). Moving is optional and needs a new checkpoint |
| `@opengsd/gsd-core` | `1.15.0` recommended (alternative `1.16.0`) | npm | [VERIFIED: npm registry]. 1.15.0 published 2026-09-26, 1.16.0 published 2026-10-05. Both carry SLSA provenance attestations. 1.16.0 was run in this session (see Pattern 3). Recommend 1.15.0 for age; keep 1.16.0 as the tested bump target |
| ccusage | `20.0.26` | npm | [VERIFIED: npm registry]. Published 2026-09-27, provenance attestation present, latest and only dist-tag |
| Python | apt `python3`, `python3-venv`, `python3-pip` (3.12.3 on noble) | Ubuntu archive | [VERIFIED: ports.ubuntu.com Packages index, noble-updates 3.12.3-0ubuntu2.1]. Note `python3-pip`, `python3-venv` and `ripgrep` are in `universe`, not `main` |

### Supporting apt packages (D-18, unpinned per D-10)

`ca-certificates curl git less procps xz-utils` (today) plus `jq ripgrep unzip zip openssh-client make build-essential tzdata`. [VERIFIED: all exist in noble, noble-updates or noble-security per the Packages indices]. Keep it one `RUN`, `--no-install-recommends`, `rm -rf /var/lib/apt/lists/*`, and put `DEBIAN_FRONTEND=noninteractive` inline on the `apt-get install` command (not as `ENV`) so `tzdata` cannot prompt. [ASSUMED: A4, A5]

### Alternatives considered

| Instead of | Could use | Tradeoff |
|------------|-----------|----------|
| Temurin via `FROM ... AS jdk` + `COPY --from=jdk` | Adoptium apt package `temurin-21-jdk` | Needs a third-party apt repo and key; keep as the fallback if TLS, font or cacerts problems appear on the Mac |
| Pin checksums in `versions.env` | Fetch checksums from upstream at build (D-09, locked) | Stronger against a compromised mirror (WR-03 says checksums share an origin with artifacts) but adds per-arch lines for Node and gh. Locked decision says upstream checksum file; offer the stronger variant only as an Open Question |
| `~/.m2` symlink (D-16, locked) | `MAVEN_ARGS=-Dmaven.repo.local=...` | Env var is cleaner but moves only the repository; the symlink also persists `settings.xml`. Locked; do not revisit |

### Installation (shape, not final)

```bash
./build.sh                 # sources versions.env, builds sbx-base:local then sbx-claude:local
./build.sh --no-cache      # extra flags go straight to docker build
```

## Package Legitimacy Audit

Run with `gsd-tools query package-legitimacy check --ecosystem npm ...` this session.

| Package | Registry | Age of pinned version | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|----------------------|-----------|-------------|---------|-------------|
| `@anthropic-ai/claude-code@2.1.285` | npm | 9 days (2026-09-29) | about 14.8M/wk | none listed in the registry metadata (Anthropic maintainers, no provenance attestation) | SUS (`too-new`, `no-repository`) | Already approved in Phase 1. Keep; planner adds the D-11 checkpoint to re-confirm the carried pin. `postinstall: node install.cjs` is the known native-binary link step |
| `@opengsd/gsd-core@1.15.0` / `1.16.0` | npm | 12 days / 3 days | about 11K/wk | github.com/open-gsd/gsd-core | SUS (`too-new`) | Flagged. `checkpoint:human-verify` before first install. SLSA provenance present, no install scripts, deps `ws` and `@anthropic-ai/claude-agent-sdk` |
| `ccusage@20.0.26` | npm | 11 days | about 197K/wk | github.com/ccusage/ccusage | SUS (`too-new`) | Flagged. `checkpoint:human-verify`. SLSA provenance present, no install scripts |
| `@ccusage/ccusage-linux-arm64@20.0.26` (and `-x64`, `-darwin-*`) | npm | 11 days | 10K/wk (arm64) | github.com/ccusage/ccusage | SUS (`too-new`) | Flagged with its parent; it is the arm64 native binary, installed as an optional dependency. Must not be skipped (`--omit=optional` breaks ccusage) |

**Packages removed due to SLOP verdict:** none.
**Packages flagged SUS:** all four rows above. All SUS reasons are recency (`too-new`) of the latest published version, not name or maintainer anomalies. The plan already has D-11 human approval checkpoints; each must show the exact version, publish date, provenance status and (for images) digest.

[VERIFIED: npm view dist.attestations / publish times, and the package-legitimacy seam, 2026-10-08.] No package here was discovered by WebSearch; all four come from the project's own prior research and CONTEXT.md.

Tarballs and images (not npm): Node, gh, Maven are checked by upstream checksum files in the Dockerfile; Ubuntu, Temurin and uv by digest. Each gets a line in the same approval checkpoint.

`get-shit-done-cc` and `gsd-build` appear nowhere in the stack; the guard `no_compromised_gsd_package` keeps enforcing that.

## Architecture Patterns

### System Architecture Diagram

```
 Mac host
 ┌────────────────────────────────────────────────────────────────────────┐
 │ versions.env (NAME=value, grouped per image)                           │
 │      │ . ./versions.env under set -a  (exported)                       │
 │      ▼                                                                 │
 │ build.sh ── --build-arg NAME (no value => taken from env) ──┐          │
 │      │                                                      │          │
 │      ├─► docker build -f base/Dockerfile   -t sbx-base:local  .        │
 │      └─► docker build -f claude/Dockerfile -t sbx-claude:local .        │
 └──────────────────────────────┬─────────────────────────────────────────┘
                                │ images (arm64 native)
          sbx-base:local                          sbx-claude:local (FROM base)
   FROM jdk(Temurin) / uv stages            npm -g claude-code@pin
   ubuntu@digest + apt tools                npm -g @opengsd/gsd-core@pin
   node, gh, maven tarballs (checksum)      npm -g ccusage@pin (+ chmod 755 binary)
   ENV JAVA_HOME PATH caches                COPY start.d/05-gsd, 10-best-practices
   ~/.m2 -> state/m2 symlink                COPY versions.env -> /etc/sbx/versions.env (last)
                                │
 docker compose up (one bind mount $SBX_DIR -> /home/sandbox/workspace)
                                ▼
   sbx-entrypoint ─ mount/name/folder checks ─ create_state_dirs
        │            (shell gh git + SBX_STATE_DIRS incl. cache/npm cache/uv m2 claude)
        ▼
   run_start_hooks (name order, as sandbox, no network)
        05-gsd:  mkdir -p $CLAUDE_CONFIG_DIR ─► gsd-core --claude --global --config-dir ...
                 (fail closed; output shown only on failure)
        10-best-practices: rules/skills sync (bundle wins a name clash)
        ▼
   enter_project_folder ─► exec sleep infinity ─► docker exec shells (image ENV only)
                                                    ccusage ─ reads CLAUDE_CONFIG_DIR/projects
```

### Recommended file changes

```
versions.env                  NEW  pins only, grouped per image
build.sh                      NEW  banners, functions, Main / Entry Point; bash 3.2 safe
base/Dockerfile               EDIT multi-stage FROM, apt list, JDK, Maven, uv, caches, no ARG defaults
claude/Dockerfile             EDIT gsd-core and ccusage installs, SBX_STATE_DIRS append, versions.env copy
claude/start.d/05-gsd         NEW  GSD sync hook (executable, two-digit name)
.dockerignore                 EDIT add !versions.env
compose.yml                   EDIT comment on line 18 (build command)
SANDBOX.md                    EDIT build + rebuild sections use ./build.sh; one line on unpinned apt; cache note
tests/guard/*.sh              EDIT see "Existing code that must change"
tests/host/lib-docker.sh      EDIT build_images calls build.sh; claude_pin reads versions.env
tests/host/*.sh               EDIT/NEW extend H-01, H-12, H-13, H-17; new checks for toolchain, pins/GSD/ccusage, caches
tests/selftest/host/...       EDIT/NEW matching self-test groups + fake-docker (one group per host check is a guard rule)
tests/host-checklist.md       EDIT rows for every new check ID
.planning/REQUIREMENTS.md     EDIT add IMG-07 (+ traceability), ROADMAP Phase 2 row (D-15)
.planning/phases/01-.../01-REVIEW-DISPOSITION.md   EDIT WR-03 and IN-03 outcomes (D-11)
```

### Pattern 1: `versions.env` + `build.sh` + per-tool `ARG`

**What:** `versions.env` holds `NAME=value` lines. `build.sh` exports them and passes `--build-arg NAME` with no value, so Docker reads the value from the environment (documented behavior: omitting the value takes it from the shell environment). Each Dockerfile declares only the `ARG`s it uses, **immediately above the `RUN` that uses it**, and guards inside that `RUN`.

**Why per-tool placement:** Docker documents that all `RUN`s after an `ARG` receive it implicitly and can miss the cache when its value changes ([CITED: docs.docker.com Dockerfile reference, "Impact on build caching"]; the fetched page did not show the paragraph, so treat the exact BuildKit behavior as [ASSUMED: A1]). Declaring each `ARG` next to its own `RUN` is free and makes D-05's goal ("a pin bump does not invalidate other layers") hold either way. The apt layer comes first with no `ARG` at all. `PITFALLS.md` (Pitfall 13) already recommends this.

**Missing pin message (D-02):** Dockerfile expansion supports only `:-`, `-`, `:+`, `+` (and some pattern forms in pre-release syntax), not `:?` [CITED: docs.docker.com/reference/dockerfile, Environment replacement]. So:
- Inside `RUN`, use shell expansion, which does support `:?`: `: "${NODE_VERSION:?NODE_VERSION is not set; build with ./build.sh}"`. Put it at the start of the same `RUN` that installs the tool (no extra layer).
- For `FROM ${UBUNTU_IMAGE}` and `FROM ${TEMURIN_IMAGE} AS jdk`, `${...:?}` is not available. An empty value makes BuildKit stop with a "base name (${UBUNTU_IMAGE}) should not be blank" style error that already names the variable [ASSUMED: A2; confirm once on the Mac by running a bare `docker build -f base/Dockerfile .`]. Keep that, and add one host check that a bare build fails and names the variable.

**InvalidDefaultArgInFrom:** an `ARG` with no default used in `FROM` triggers the BuildKit check `InvalidDefaultArgInFrom` even when `--build-arg` supplies the value, because the check is static [CITED: docs.docker.com/reference/build-checks/invalid-default-arg-in-from/]. It is a warning, but a clean log is worth a directive. Put it under the syntax line, same form as the documented skip syntax [CITED: docs.docker.com/build/checks/]:

```dockerfile
# syntax=docker/dockerfile:1
# check=skip=InvalidDefaultArgInFrom
```

Build checks need Dockerfile frontend 1.8 / Buildx 0.15 or newer [CITED: same page]; Docker Desktop on the Mac is far past that, but record the Docker Desktop version in the host run as the Phase 1 checklist already does for Compose.

**Unconsumed build args:** D-03 passes every pin to both builds, so each build gets args it does not declare. Docker reports that as a warning (unconsumed build-arg notice), not an error [ASSUMED: A3]. H-01 only greps the logs for two platform phrases, so it is unaffected. Do not try to filter it.

**Example (shape):**

```bash
#!/usr/bin/env bash
# build.sh: builds sbx-base:local, then sbx-claude:local, from the pins in versions.env.
# versions.env is the only place versions live. The Dockerfiles have no defaults so a
# forgotten pin stops the build instead of silently building an old version.
# Extra arguments go to both docker build calls (for example --no-cache).
set -eu

# --------------------------------------------------------------------------------
# Main / Entry Point
# --------------------------------------------------------------------------------
cd "$(dirname "$0")"

set -a
. ./versions.env
set +a

buildArgList=()
for name in $(grep -oE '^[A-Z][A-Z0-9_]*' versions.env); do
  buildArgList+=(--build-arg "$name")
done

docker build -f base/Dockerfile "${buildArgList[@]}" "$@" -t sbx-base:local .
docker build -f claude/Dockerfile "${buildArgList[@]}" "$@" -t sbx-claude:local .
```

Notes for the planner on this shape:
- Use `. ./versions.env`, not `source versions.env`: without a slash, bash searches `PATH` first. [ASSUMED: A14, standard bash behavior]
- D-04 gave `grep -oE '^[A-Z_]+'`; a name containing a digit (for example `JDK21_IMAGE`) would be cut at the digit and passed under the wrong name. `^[A-Z][A-Z0-9_]*` is the same idea without the trap. Either works for the names recommended below; raise it with the user only if they care.
- The file must stay `NAME=value` per line with no `export` prefix, no indentation, and no value containing spaces without quotes; `source` runs it as bash, so it is trusted code on the Mac (same trust as `build.sh`).
- Follow the shell layout rule: 80-column banners, functions, Main / Entry Point block. The sketch above is flat for brevity; the real script needs functions (for example `load_versions`, `collect_build_args`, `build_image NAME`) with full variable names, braces always, blank lines around control flow (project conventions).
- Bash 3.2 safe: `+=()` arrays and `"${buildArgList[@]}"` with a non-empty array are fine in 3.2.

**Names (Claude's discretion, recommended):**

```
# sbx-base
UBUNTU_IMAGE=ubuntu:24.04@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55
TEMURIN_IMAGE=eclipse-temurin:21.0.12_8-jdk-noble@sha256:4d271cd5e0624598cf563342f47281b09cb364bc13acbbd7251f49f83470018d
UV_IMAGE=ghcr.io/astral-sh/uv:0.12.21@sha256:a7aed3216253ee804de3e2d8afa5073baa1a177335345d43845cd4165e43b711
NODE_VERSION=24.21.0
GH_VERSION=2.102.0
MAVEN_VERSION=3.9.16

# sbx-claude
CLAUDE_CODE_VERSION=2.1.285
GSD_CORE_VERSION=1.15.0
CCUSAGE_VERSION=20.0.26
```

These names keep `CLAUDE_CODE_VERSION`, `NODE_VERSION` and `GH_VERSION` unchanged, which minimizes edits in tests that mention them.

### Pattern 2: Base Dockerfile shape

```dockerfile
# syntax=docker/dockerfile:1
# check=skip=InvalidDefaultArgInFrom
ARG TEMURIN_IMAGE
ARG UV_IMAGE
ARG UBUNTU_IMAGE
FROM ${TEMURIN_IMAGE} AS jdk
FROM ${UV_IMAGE} AS uv
FROM ${UBUNTU_IMAGE}
```

- Global `ARG`s before the first `FROM` are usable only in `FROM` lines [CITED: Dockerfile reference]; the JDK and uv stage names are what `COPY --from` uses. `COPY --from` does not document ARG expansion for the source, hence the stage pattern.
- Single `FROM` rule in the Claude Dockerfile stays: host check H-02 requires exactly one `FROM ${BASE_IMAGE}` line there. `ARG BASE_IMAGE=sbx-base:local` keeps its default (it is a local tag, not a version).
- JDK: `COPY --from=jdk /opt/java/openjdk /opt/java/openjdk`; `ENV JAVA_HOME=/opt/java/openjdk`. The official image's own Dockerfile also installs `fontconfig`, `p11-kit`, `tzdata`, `locales`, and writes an `ld.so.conf.d` entry; `COPY --from` of the JDK tree skips those [CITED: github.com/adoptium/containers 21/jdk/ubuntu/noble/Dockerfile]. Maven and plain Java work without them [ASSUMED: A7]; add `fontconfig` to the apt list only if a Mac check shows an AWT or font error. The CDS archive lives under the JDK tree, so it is copied too.
- Maven: download tarball and `.sha512` from `https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/${MAVEN_VERSION}/` (Maven Central keeps every release; `dlcdn.apache.org` drops old ones). The `.sha512` file holds the hash only, no file name, so `sha512sum -c` needs the name added: `echo "$(curl -fsS "$base/apache-maven-${MAVEN_VERSION}-bin.tar.gz.sha512")  apache-maven-${MAVEN_VERSION}-bin.tar.gz" | sha512sum -c -`. [VERIFIED: ran exactly this in the dev sandbox, result `OK`; the tarball is arch-neutral and bundles native libs for all platforms]. Extract with `tar -xzf ... -C /opt/maven --strip-components=1 --no-same-owner`.
- uv: `COPY --from=uv /uv /uvx /usr/local/bin/` [CITED: docs.astral.sh/uv/guides/integration/docker].
- PATH robustness: set `ENV JAVA_HOME=... PATH=/opt/java/openjdk/bin:/opt/maven/bin:${PATH}` for `docker exec` shells, **and** symlink the JDK `bin/*` and `mvn` into `/usr/local/bin`. Debian-style `/etc/profile` resets `PATH` for login shells, and Claude's Bash tool starts shells that can be login shells [ASSUMED: A6; this dev sandbox runs Ubuntu 26.04, where `bash -lc` kept an added PATH entry, so it could not confirm 24.04 behavior]. `/usr/local/bin` is already in every PATH, so symlinks cost nothing.

### Pattern 3: GSD baked, synced at every start

**Verified in this session** (GSD 1.16.0 and 1.15.0 on Node 24.21.0, aarch64 Linux, `HOME` pointed at an empty folder):
- Bins after `npm install -g`: `gsd-core` (the installer, `bin/install.js`), `gsd-tools`, `gsd_run`, `gsd-mcp-server`. [VERIFIED: ran it]
- `gsd-core --claude --global </dev/null` runs non-interactively, exit 0, about 0.3 s, writes `gsd-core/VERSION` (value `1.16.0`, no trailing newline), `skills/` (72 dirs), `agents/`, `hooks/`, `scripts/`, manifest files, and merges `settings.json`. `HOME` stayed empty (only npm's own `.npm`). [VERIFIED: ran it]
- Offline: with a Node preload that throws on any socket connect or DNS lookup and logs every `child_process` call, a full install logged nothing. [VERIFIED: ran it; `unshare -n` was not permitted here, so the preload was the substitute]. The install path makes no network call and spawns nothing.
- Idempotent: a second run left `settings.json` byte-identical. User keys in `settings.json`, a user `Stop` hook, `.credentials.json`, `.claude.json` and `projects/` were untouched by an in-place upgrade from 1.15.0 to 1.16.0; a locally edited GSD skill was backed up to `gsd-local-patches/` and replaced. A non-GSD skill folder (`skills/pr-reply`) was not touched. [VERIFIED: ran it]
- **Hang, not failure:** `gsd-core --claude --global --config-dir /proc/no-such-dir </dev/null` did not exit within 30 s (`timeout` returned 124). An unwritable parent (`chmod 555`) did exit 1. [VERIFIED: ran it]. Host check H-17 provokes a failing hook with `CLAUDE_CONFIG_DIR=/proc/no-such-dir`; since the GSD hook runs *before* `10-best-practices`, an unguarded GSD hook would turn that check into a 60 s timeout. The hook must run `mkdir -p "$configDir"` first, which fails fast on `/proc` (this is how `10-best-practices` already fails there).
- Hook paths in `settings.json` are written as absolute paths of the config dir used for the run (so the container path `/home/sandbox/workspace/state/claude/hooks/...`). Because the sync runs at every start with the same `CLAUDE_CONFIG_DIR`, they stay correct. [VERIFIED: inspected the generated settings]
- `gsd-core --version` does not exist and `gsd-core` with no flags may prompt; **never call it without `</dev/null` and a timeout** (it hung this session). `gsd-tools --version` is refused. `gsd-tools runtime-identity --raw` prints `{"packageName":"@opengsd/gsd-core","version":"1.16.0"}`, which proves both package identity and version for the build smoke test. [VERIFIED: ran it]
- Installer adds `permissions.allow` entries (`Bash(npx gsd-core *)`, `Read(.planning/*)`, ...) and about 20 hooks including a SessionStart update check whose worker does an `npm view` lookup at *session* time. That is outside container start (TOOL-03) and fails soft, but it will announce newer GSD versions inside a sandbox where updates happen only by rebuild. Not a Phase 2 task; mention it in docs only if it confuses the user. [VERIFIED: read hook source]
- Image size: the `gsd-core` global install is about 390 MB on disk, because its dependency `@anthropic-ai/claude-agent-sdk` pulls a 232 MB Claude native binary (`claude-agent-sdk-linux-arm64/claude`). That is a second Claude copy under `/usr/local/lib/node_modules`, not in `~/.local` and not on `PATH`. Accept it; note it in the docs. No dependency in the `gsd-core` plus `ccusage` tree has an install/postinstall script. [VERIFIED: ran it; walked the installed tree]

**Hook design (recommended):**
- Name `claude/start.d/05-gsd` (two digits, runs before `10-best-practices`, D-14). Mode 755; the Dockerfile already runs `chmod 755 /etc/sbx/start.d/*`.
- Same style as `10-best-practices`: `set -eu`, functions, banners, Main / Entry Point.
- `check_inputs`: fail with a `[sbx] ERROR:` line if `CLAUDE_CONFIG_DIR` is empty. Then `mkdir -p "$configDir"` (this is the hang guard).
- Run `gsd-core --claude --global --config-dir "$configDir" </dev/null >"$logFile" 2>&1`. Passing `--config-dir` explicitly also scopes the installer's legacy-artifact scan to that folder (per `--help`). Capture output to a temp file; on success print one line (`[sbx] GSD <version> synced`); on failure print the captured output to stderr and exit 1 (fail closed, D-13). A noisy 40-line coloured installer log at every start is not wanted.
- Optionally wrap the call in `timeout 120` (coreutils on Ubuntu) as a second hang guard; the `mkdir -p` precheck is the part that matters.
- After the call, compare `$configDir/gsd-core/VERSION` with `GSD_CORE_VERSION`/the baked package version and fail if they differ; this makes "image wins" self-checking.
- **Static guard trap:** the guard rule `no_installs_at_container_start` scans `claude/start.d/*` for the whole words `npm|npx|bunx|pip|apt-get|apt|curl|wget`, and `no_floating_latest_versions` scans for `:latest|@latest`. The hook's comments and messages must not contain those words (for example do not write "no npx" in a comment). [VERIFIED: tests/guard/start.sh:13 and tests/guard/supply-chain.sh, quoted in "Existing code that must change"]
- Do not source env-reading logic that the entrypoint does not provide; hooks get the container's image ENV (`CLAUDE_CONFIG_DIR` is image ENV).

### Pattern 4: ccusage

- Install in the same Dockerfile style: `npm install -g "ccusage@${CCUSAGE_VERSION}"` as root, no `--omit=optional`, no `--ignore-scripts` flag needed. The platform binary arrives as `@ccusage/ccusage-linux-arm64` (or `-x64`) optional dependency. [VERIFIED: ran it]
- **Mode trap, confirmed on arm64:** the packaged native binary is `-rw-r--r--`. The launcher `src/cli.js` checks `(mode & 0o111) !== 0` and otherwise tries `chmodSync(binaryPath, 0o755)`, which can only succeed for the file owner. In a root-owned global install the `sandbox` user cannot chmod, so ccusage would fail with "native binary is not executable". In this session the owner (same user) chmod'ed it on first run, which hid the problem; as root-owned it would not. Fix at build, as root, after the install: `chmod 755 "$(npm root -g)"/ccusage/node_modules/@ccusage/*/bin/ccusage`, then smoke test as `sandbox`. [VERIFIED: tarball mode and launcher code read; root-owned failure inferred, not run, because no root here]. This closes the Phase 2 blocker in STATE.md ("confirm ccusage native binary is executable on arm64").
- Smoke test as `sandbox` after `USER sandbox`: `test "$(ccusage --version)" = "ccusage ${CCUSAGE_VERSION}"` (the output observed was `ccusage 20.0.26`). [VERIFIED: ran it]
- Data discovery: with `CLAUDE_CONFIG_DIR=<dir>` and an empty `HOME`, `ccusage daily|monthly|session --offline` (and `--json`) reported a seeded transcript at `<dir>/projects/-home-sandbox-workspace-demo/s1.jsonl`, header "Detected: Claude". [VERIFIED: ran it]. Minimal transcript line that ccusage accepted (use this for the host check fixture):

```json
{"type":"assistant","timestamp":"2026-10-07T10:00:00.000Z","sessionId":"s1","cwd":"/home/sandbox/workspace/demo","requestId":"r1","message":{"id":"m1","model":"claude-sonnet-4-5-20250929","role":"assistant","usage":{"input_tokens":100,"output_tokens":200,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}},"costUSD":0.01}
```
  `ccusage daily --offline --json` then reports `inputTokens` 100, `outputTokens` 200, `totalTokens` 300, `totalCost` 0.01 and `metadata.agents` `["claude"]`; `session --json` reports `period` `s1`. [VERIFIED: ran it]
- Online pricing (D-20): without `--offline`, ccusage fetches the LiteLLM price table from `raw.githubusercontent.com` and caches it in `~/.cache/ccusage` (image home, so it resets on recreate). It ran fine online here. Use `--offline` in the automated host check so the result is deterministic; mention in docs that the default needs network. [VERIFIED: ran it, saw the cache file]

### Pattern 5: Tool caches on the mount (IMG-07, D-16)

Layout: `state/cache/npm`, `state/cache/uv`, `state/m2`. Where each piece lives:

| Piece | Where | Note |
|-------|-------|------|
| `NPM_CONFIG_CACHE`, `UV_CACHE_DIR`, `UV_LINK_MODE=copy` | `ENV` in `base/Dockerfile`, after the build-time installs that need none | npm, uv and Maven are all base toolchains, so the base owns their caches |
| `~/.m2` symlink to `/home/sandbox/workspace/state/m2` | `base/Dockerfile`, as `sandbox`, after `mkdir -p` of home folders | Dangling at build; the entrypoint creates the target at start |
| State folder creation | `SBX_STATE_DIRS` | see trap 1 below |

**Trap 1: the Claude image replaces `SBX_STATE_DIRS`.** [VERIFIED: claude/Dockerfile:28-30]
```
ENV CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude \
    SBX_STATE_DIRS=claude \
    DISABLE_UPDATES=1
```
If the base sets `SBX_STATE_DIRS="cache/npm cache/uv m2"`, this line silently drops it. Use `SBX_STATE_DIRS="${SBX_STATE_DIRS} claude"` in the Claude image (the variable on the right is the inherited value because `ENV` expands before it assigns). The entrypoint splits on spaces and runs `mkdir -p "$state/<entry>"`, so nested names like `cache/npm` work. [VERIFIED: base/sbx-start-lib.sh:71, quote: `read -r -a stateFolderList <<< "shell gh git ${SBX_STATE_DIRS:-}"`]. An alternative that avoids the append is to add the three folders to the hard-coded list `shell gh git` in `sbx-start-lib.sh`; CONTEXT D-16 says "into `SBX_STATE_DIRS`", so follow the append.

**Trap 2: build-time npm cache.** If the base sets `NPM_CONFIG_CACHE` to the mount path, the Claude image's `RUN npm install -g ...` (as root, at build) inherits it and writes a cache under `/home/sandbox/workspace/state/cache/npm` *inside the image layer*, root-owned, under the mount point. Prefix each build-time npm call with `NPM_CONFIG_CACHE=/tmp/npm-cache` and remove it in the same `RUN`. Add a host check that `/home/sandbox/workspace` is empty in the image (`docker run --rm --entrypoint sh sbx-claude:local -c 'ls -A /home/sandbox/workspace'`).

**uv link mode:** `UV_LINK_MODE=copy` avoids hardlink failures between cache and project on different filesystems [CITED: docs.astral.sh uv Docker guide]. Here both live on the same bind mount, where hardlink behavior on the Mac file sharing is unknown, so `copy` is the safe choice [ASSUMED: A9].

**Cost to record in docs (D-16):** many small files over the Mac file sharing are slower than the container's own disk; caches grow to GBs; deleting `state/cache` and `state/m2` is always safe. `PITFALLS.md` (Pitfall 22) recommended a named volume instead; the user chose the bind mount, so do not reopen it.

### Anti-Patterns to Avoid
- **Defaults in Dockerfile ARGs** (D-02): reintroduces two copies of every version.
- **All `ARG` lines at the top of the Dockerfile:** every pin bump can invalidate the apt layer (A1).
- **Copying `versions.env` into the *base* image's last layer:** any pin bump (even Claude's) would change the base image's top layer and force every Claude image layer to rebuild. Put the `/etc/sbx/versions.env` copy at the very end of `claude/Dockerfile` (D-05 leaves the image to discretion; a sandbox shell reads it either way).
- **Calling `gsd-core` or `npx` without `</dev/null` and a timeout** in scripts and tests.
- **Installing at start:** `no_installs_at_container_start` forbids it; the hook only runs the baked installer.

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| Reading `versions.env` | A line parser | `set -a; . ./versions.env; set +a` plus `--build-arg NAME` | User decision D-04; Docker reads the exported value |
| JDK install | apt repo or tarball fetch | `COPY --from=jdk /opt/java/openjdk` from the pinned official image | Pinned by digest, multi-arch, no key management |
| uv install | `curl ... \| sh` | `COPY --from=uv /uv /uvx` | Guard forbids pipe-to-shell; pinned by digest |
| GSD materialization | Own copy script, symlinks, or a version-stamp comparison | The installer `gsd-core --claude --global --config-dir` | Manifest-driven, idempotent, merges `settings.json`, backs up local edits |
| GSD version proof | `cat` of files in `node_modules` | `gsd-tools runtime-identity --raw` | Prints package name and version in one JSON line |
| Usage reports | A transcript parser | `ccusage` | Already handles Claude project folders, pricing and sessions |
| ELF architecture proof in tests | Installing `file` | `od -An -tx1 -j18 -N2 <binary>` (bytes 18-19 are `e_machine`: `b7 00` is AArch64, `3e 00` is x86-64) | `od` is in coreutils; no package needed in the image [ASSUMED: A15, ELF header layout is standard] |
| Checksum checking | Custom compare code | `sha256sum -c -` / `sha512sum -c -` | Same pattern as the existing Node and gh blocks |

**Key insight:** every component here already has a first-party mechanism; the phase is wiring and proof, not new logic.

## Existing code that must change (the hidden cost)

These are in the repo today and break, or become wrong, when pins move out of the Dockerfiles. Quotes are verbatim from files read this session.

| Location | Verbatim today | Needed change |
|----------|----------------|---------------|
| `tests/guard/supply-chain.sh:32-37` | `has_line $BASE 'FROM ubuntu:24.04'` and `grep -Eq '^ARG NODE_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' $BASE` (likewise `GH_VERSION`, and `CLAUDE_CODE_VERSION` in `$CLAUDE`) | Rewrite `versions_are_pinned` to read `versions.env`: every `*_VERSION` is `x.y.z`, every `*_IMAGE` ends in `@sha256:<64 hex>`, and each Dockerfile `ARG` has no `=` default |
| `tests/guard/lib.sh:17-18` | `DOCKERFILES="$BASE $CLAUDE"` / `SANDBOX_FILES="$BASE $CLAUDE $COMPOSE $ENTRY"` | Add `versions.env` and `build.sh` to the scanned sets so the `latest`, pipe-to-shell and compromised-package rules also cover them (keep `$DOCKERFILES` for Dockerfile-only rules) |
| `tests/guard/bundle-wiring.sh:38` | `$(grep -E '^COPY ' "$dockerfile" \| awk '{ print $2 }')` | `$2` becomes `--from=jdk` or `--chmod=644` for new `COPY` forms and the rule would test `[ ! -e "--from=jdk" ]`. Skip option tokens (and skip `--from` sources, which are not build-context paths) |
| `tests/guard/bundle-wiring.sh:15` and `.dockerignore:1-6` | wanted lines `'*' '!base' '!claude' '!best-practices'`; file is `*`, `!base`, `!claude`, `!best-practices`, `**/.DS_Store` | Add `!versions.env` to `.dockerignore`, add it to the wanted list, and allow `versions.env` as a COPY source (its first path segment is not base, claude or best-practices) |
| `tests/guard/start.sh:13` | `nowhere_matches '\b(npm\|npx\|bunx\|pip\|apt-get\|apt\|curl\|wget)\b' $ENTRY claude/start.d/*` | No change to the rule; the new `05-gsd` hook must pass it (no such words in code, comments or messages) |
| `tests/host/lib-docker.sh:20-23` | `docker build ... -f "$REPO_DIR/$imageName/Dockerfile" -t "sbx-$imageName:local" "$REPO_DIR"` (twice, with and without `--no-cache`) | `build_images` calls `"$REPO_DIR/build.sh"` (extra flag passes through) and keeps one log per build prefix; H-01 reads `build-*`, `rebuild-*` logs so a single `build-images.log` name still matches |
| `tests/host/lib-docker.sh:49-53` | `claude_pin() { sed -n 's/^ARG CLAUDE_CODE_VERSION=//p' "$REPO_DIR/claude/Dockerfile" }` | Read `CLAUDE_CODE_VERSION=` from `versions.env`; add a general `pin_of NAME` for the new checks |
| `tests/selftest/host/units.sh:17` | `pinFromFile=$(grep '^ARG CLAUDE_CODE_VERSION=' claude/Dockerfile \| cut -d= -f2)` | Compare with the value in `versions.env` |
| `tests/selftest/host/support/fake-docker:564` | `fakePin=$(sed -n 's/^ARG CLAUDE_CODE_VERSION=//p' "$FAKE_REPO/claude/Dockerfile")` | Read from `$FAKE_REPO/versions.env`; `fake_build` must cope with `build.sh`'s `--build-arg NAME` forms and tags |
| `tests/host/h12-plain-run-refused-pin-installed.sh` header | "the installed Claude Code version is the pinned one from claude/Dockerfile" | Update the comment and message to `versions.env` |
| `tests/host/h02-claude-on-base.sh` | requires `FROM ${BASE_IMAGE}` as the only `FROM` in `claude/Dockerfile` | Keep the Claude Dockerfile single-stage; base may be multi-stage (H-02 only compares layers) |
| `SANDBOX.md:24-25` and `:106-107`, `compose.yml:18` | `docker build -f base/Dockerfile -t sbx-base:local .` etc. | Replace with `./build.sh`; add the one-line unpinned-apt statement (D-10), the cache cost note (D-16), and `cat /etc/sbx/versions.env` |
| `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` Phase 2 row | no IMG-07 | Add IMG-07 and its traceability row (D-15) |
| `01-REVIEW-DISPOSITION.md` (Phase 1) | WR-03 and IN-03 `deferred` | Record the D-11 outcome and flip them when the Mac run passes |

Each new host check must also bring: a same-named group under `tests/selftest/host/` (guard rule `host_checks_have_self_test_groups`), a row in `tests/host-checklist.md` (guard rule `checklist_lists_every_host_check`, which derives IDs from file names and the `chainCheckList` line), and a place in `tests/host/run-all.sh`. Prefer **extending** H-01, H-12, H-13, H-14, H-16 and H-17 over adding many new IDs; add only the checks listed under Validation Architecture.

Also remember the repo guards for source text: `sandbox_code_has_no_planning_ids` (no `D-04`, `IMG-07`, phase numbers in `build.sh`, `versions.env`, Dockerfiles, hooks), ASCII only in source, no dash as punctuation in comments and docs, `host_tests_never_delete` (host tests may not use `rm`, `mv`, `truncate`), and `host_tests_only_name_the_test_sandbox` (only `sbx-hosttest`, `sbx-base`, `sbx-claude` image or container names appear in host scripts; a tag such as `sbx-claude:bump` is allowed because the match stops at the colon).

## Common Pitfalls

### Pitfall 1: The GSD installer hangs on an uncreatable config dir
**What goes wrong:** `gsd-core --claude --global --config-dir /proc/no-such-dir` never returns. H-17's "failing hook" scenario sets `CLAUDE_CONFIG_DIR=/proc/no-such-dir`; the GSD hook runs first and the check times out instead of seeing `[sbx] ERROR: start hook`.
**Why:** the installer does not fail fast on this path (observed, cause not investigated).
**Avoid:** `mkdir -p "$configDir"` first in the hook (fails at once there), optional `timeout`.
**Warning signs:** H-17 prints a timeout line instead of the hook error text.

### Pitfall 2: ccusage fails for `sandbox` only
**What goes wrong:** `ccusage` reports "native binary is not executable" for the unprivileged user while working for root or at build time.
**Why:** the packaged binary is mode 0644; only the file owner can let the launcher chmod it.
**Avoid:** build-time `chmod 755` as root plus a smoke test as `sandbox`. Never skip optional dependencies.

### Pitfall 3: `up --wait` returns before the start hooks finish
**What goes wrong:** a host check that runs right after `compose up -d --wait` reads `gsd-core/VERSION` mid-sync and fails intermittently. `compose.yml` has no healthcheck, so `--wait` means "container running", and the hooks run inside the entrypoint after that. [ASSUMED: A8]
**Why it is new:** the bundle hook finishes in milliseconds, so H-15/H-16 never noticed; GSD writes about a thousand files (0.3 s native, more on the Mac file sharing).
**Avoid:** a poll helper in the host library (up to about 60 s, 1 s steps, no sleeping orphan processes: reuse `run_timeout`) that waits for `$RUN/state/claude/gsd-core/VERSION` to equal the pin before asserting. A readiness healthcheck in `compose.yml` is the structural fix but touches Phase 1 files and the entrypoint self-tests; see Open Question 3.

### Pitfall 4: The Claude image drops the base's state folders
See Pattern 5, trap 1. Add a self-test case in `tests/selftest/entrypoint/start-folders.sh` style or a host check that `state/cache/npm`, `state/cache/uv`, `state/m2` and `state/claude` all exist after a start.

### Pitfall 5: Build-time npm writes a cache into the image under the mount point
See Pattern 5, trap 2.

### Pitfall 6: Layer cache and `ARG` placement
All `ARG`s at the top may invalidate the apt layer on any bump (A1). One `ARG` per tool directly above its `RUN`; the apt `RUN` has none; `/etc/sbx/versions.env` is the last `COPY`.

### Pitfall 7: `docker exec` and login shells lose PATH entries
`ENV PATH` reaches `docker exec` shells but a login shell on 24.04 may reset it. Symlink the JDK and `mvn` binaries into `/usr/local/bin` and check with `docker exec ... bash -lc 'java -version; mvn -v'` (A6).

### Pitfall 8: Pins drift out of sync with their record
`/etc/sbx/versions.env` is only a record. A host check compares it byte for byte with the repo file (`docker run --rm --entrypoint cat sbx-claude:local /etc/sbx/versions.env`). It also catches "forgot to rebuild".

### Pitfall 9: Ubuntu tag digest moves
The 24.04 digest in STACK.md (2026-09-18) is already out of date; the same tag has a new index digest today. Pin tag plus digest, and at each bump re-resolve it. The Mac `docker pull` and `docker buildx imagetools inspect` give the same index digest this research read from the registry API. [VERIFIED: registry]

### Pitfall 10: `tzdata` and other debconf prompts
Use `DEBIAN_FRONTEND=noninteractive` on the install command only (A5).

## Code Examples

### `ARG` next to its `RUN`, with the clear missing-pin message (shape)

```dockerfile
# Node.js: official tarball checked against nodejs.org's SHASUMS256.txt.
ARG NODE_VERSION
RUN : "${NODE_VERSION:?NODE_VERSION is not set; build with ./build.sh}" \
    && arch="$(dpkg --print-architecture)" \
    && case "$arch" in amd64) node_arch=x64 ;; arm64) node_arch=arm64 ;; *) echo "unsupported arch: $arch" >&2; exit 1 ;; esac \
    && f="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
    && curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${f}" \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" | grep " ${f}\$" | sha256sum -c - \
    && tar -xJf "$f" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "$f"
```
(The body is the existing Phase 1 block from `base/Dockerfile`; only the `ARG` loses its default and the guard line is added.)

### Maven (checksum file holds only the hash)

```dockerfile
ARG MAVEN_VERSION
RUN : "${MAVEN_VERSION:?MAVEN_VERSION is not set; build with ./build.sh}" \
    && base="https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/${MAVEN_VERSION}" \
    && f="apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
    && curl -fsSLO "${base}/${f}" \
    && echo "$(curl -fsSL "${base}/${f}.sha512")  ${f}" | sha512sum -c - \
    && mkdir -p /opt/maven \
    && tar -xzf "$f" -C /opt/maven --strip-components=1 --no-same-owner \
    && rm "$f" \
    && ln -s /opt/maven/bin/mvn /usr/local/bin/mvn
```
[VERIFIED: the curl, `sha512sum -c` and tarball listing were run in the dev sandbox; the Dockerfile wrapping is untested.]

### Claude image: three npm tools, each its own layer

```dockerfile
USER root
ARG CLAUDE_CODE_VERSION
RUN : "${CLAUDE_CODE_VERSION:?CLAUDE_CODE_VERSION is not set; build with ./build.sh}" \
    && NPM_CONFIG_CACHE=/tmp/npm-cache npm install -g --allow-scripts=@anthropic-ai/claude-code "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && rm -rf /tmp/npm-cache \
    && ln -s /home/sandbox/workspace/state/claude /home/sandbox/.claude \
    && chown -h sandbox:sandbox /home/sandbox/.claude

ARG GSD_CORE_VERSION
RUN : "${GSD_CORE_VERSION:?GSD_CORE_VERSION is not set; build with ./build.sh}" \
    && NPM_CONFIG_CACHE=/tmp/npm-cache npm install -g "@opengsd/gsd-core@${GSD_CORE_VERSION}" \
    && rm -rf /tmp/npm-cache

ARG CCUSAGE_VERSION
RUN : "${CCUSAGE_VERSION:?CCUSAGE_VERSION is not set; build with ./build.sh}" \
    && NPM_CONFIG_CACHE=/tmp/npm-cache npm install -g "ccusage@${CCUSAGE_VERSION}" \
    && chmod 755 "$(npm root -g)"/ccusage/node_modules/@ccusage/*/bin/ccusage \
    && rm -rf /tmp/npm-cache
```
Source of the Claude block: existing `claude/Dockerfile` lines 16-21 (read this session). The `chmod` line and `GSD`/`ccusage` blocks are from the verified behavior above.

### Build-time smoke tests, as `sandbox`

```dockerfile
USER sandbox
RUN test "$(claude --version)" = "${CLAUDE_CODE_VERSION} (Claude Code)" \
    && test "$(ccusage --version)" = "ccusage ${CCUSAGE_VERSION}" \
    && test "$(gsd-tools runtime-identity --raw)" = "{\"packageName\":\"@opengsd/gsd-core\",\"version\":\"${GSD_CORE_VERSION}\"}"
```
`ARG`s declared earlier in the same stage are visible here. The three expected strings were produced by the real packages in this session (ccusage and gsd-tools run; the claude string is the Phase 1 smoke test).

### GSD start hook (shape)

```bash
#!/usr/bin/env bash
set -eu

# Syncs the image's GSD into the Claude config folder.
# - Runs at every container start, as sandbox, with no network.
# - Runs before 10-best-practices, so a bundle skill still wins a name clash.
# - Hand edits to GSD files are backed up by the installer and then replaced: the image wins.

configDir=${CLAUDE_CONFIG_DIR:-}

# ... banner, check_inputs (error when empty), then:
mkdir -p "$configDir"
logFile=$(mktemp)
if ! gsd-core --claude --global --config-dir "$configDir" </dev/null >"$logFile" 2>&1; then
  cat "$logFile" >&2
  echo "[sbx] ERROR: the GSD sync failed." >&2
  exit 1
fi
echo "[sbx] GSD $(cat "$configDir/gsd-core/VERSION") synced"
```
Keep the real file inside the project's layout rules (banners, functions, Main / Entry Point) and avoid the guard words listed in Pattern 3.

## State of the Art

| Old (repo today) | New (this phase) | Impact |
|------------------|------------------|--------|
| `ARG X=1.2.3` defaults in Dockerfiles | no defaults; `versions.env` plus `build.sh` | One place for versions; a bare `docker build` now fails loudly |
| `FROM ubuntu:24.04` by tag | tag plus digest | Rebuilds are reproducible; the digest is re-resolved at each bump |
| Node 20 era install via NodeSource (old layout) | Node 24 tarball (already done in Phase 1) | Meets `@opengsd/gsd-core` `engines.node >=24` |
| `npx -y @opengsd/gsd-core@latest` at start (old layout) | baked global install plus installer at start | No network at start, pinned version |
| `.initialized` marker | none | Version changes are applied by the every-start sync |

**Deprecated/outdated:** `get-shit-done-cc` and `gsd-build` (compromised); the old `ClaudeCode/` and `OpenCode/` Dockerfiles stay untouched until Phase 5 (coexistence constraint; guard `old_layout_untouched` enforces it).

## Environment Availability

| Dependency | Required By | Available here | Version | Fallback |
|------------|------------|----------------|---------|----------|
| Docker / Compose | all build and host checks | no | n/a | Host-side manual verification on the Mac (project constraint) |
| Node | trying gsd-core, ccusage | yes (20.20.2 system; 24.21.0 downloaded to the scratchpad for this research) | 24.21.0 | `xz` is missing here, so the `.tar.gz` Node archive was used |
| npm registry, GitHub, Maven Central, Docker Hub and ghcr registry APIs | pin research | yes | n/a | none needed |
| `unshare -n` | offline proof | no (EPERM) | n/a | Node preload that blocks sockets and DNS (used) |
| root (to test root-owned installs) | ccusage mode trap | no | n/a | Inference from launcher code plus tarball mode; host check proves it |
| Mac with Docker Desktop (arm64) | everything that needs a real build | user's machine | unknown | none; plans need host-side steps and an explicit human checkpoint |

**Missing with no fallback:** a real Docker build, so every Dockerfile statement in this document is unrun until the first Mac run.

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | BuildKit gives every `RUN` after a declared `ARG` that value implicitly, so a bump can invalidate all later layers | Pattern 1 | Low: per-tool placement is harmless either way; only the cache-hit expectation changes. One manual check: bump one pin and see earlier layers `CACHED` |
| A2 | An empty `FROM` ARG yields a "base name (${NAME}) should not be blank" error that names the variable | Pattern 1 | Medium: if the message is unclear, D-02's "clear message" is not met for the three `FROM` pins; fallback is a wrapper check in `build.sh` or a sentinel default |
| A3 | Unconsumed `--build-arg` names produce a warning, not an error | Pattern 1 | Medium: if it were an error, D-03 (pass every pin to both builds) would break the base build; the first Mac build shows it |
| A4 | `ubuntu:24.04` enables `universe`, so `ripgrep`, `python3-pip`, `python3-venv` install | Standard Stack | Medium: the apt step fails at build and needs a `software-properties`/sources tweak |
| A5 | `tzdata` needs `DEBIAN_FRONTEND=noninteractive` to avoid a prompt in a build | Standard Stack | Low |
| A6 | Ubuntu 24.04 `/etc/profile` resets PATH for login shells | Pattern 2 | Low: the symlinks are harmless if it does not |
| A7 | Copying only `/opt/java/openjdk` (no fontconfig, p11-kit) is enough for Maven and plain Java | Pattern 2 | Low: fallback is adding `fontconfig` or the Adoptium apt package |
| A8 | `docker compose up -d --wait` returns when the container is "running", before the start hooks finish | Pitfall 3 | Medium: if it waits longer, the poll helper is just redundant |
| A9 | Hardlinks between `state/cache/uv` and the project on the Mac file sharing may fail or warn, so `UV_LINK_MODE=copy` is right | Pattern 5 | Low |
| A10 | `mvn -v` with a dangling `~/.m2` symlink works at build time | Pattern 5 | Low: smoke-test only `mvn -v`, nothing that resolves dependencies |
| A11 | `docker compose up` recreates a container whose image changed | Success criterion 2 | Low: Phase 3 owns the upgrade command; H-09 already recreates explicitly |
| A12 | A root `npm install -g` leaves 0755 dirs, 0644 files, so the installer's copies into `state/claude` stay writable for `sandbox` | Pattern 3 | Medium: a 0555 source tree made the installer fail with EACCES in an artificial test; the real image should not have that mode, and the first Mac start proves it |
| A13 | `COPY --from=` does not expand `ARG` in the source reference (hence the stage pattern) | Pattern 2 | Low |
| A14 | `source file` without a slash searches PATH first | Pattern 1 | Low: `. ./versions.env` is correct regardless |
| A15 | ELF header `e_machine` at byte offset 18 is `b7 00` for AArch64 | Don't Hand-Roll | Low |
| A16 | The GSD pin recommended below (1.15.0 over 1.16.0) is acceptable to the user | Standard Stack | Low: a choice for the checkpoint, both work |

## Open Questions

1. **Which GSD version to pin?**
   - Known: 1.15.0 (12 days old, researched in Phase 2 pre-work) and 1.16.0 (3 days old, run this session). Both have provenance. The legitimacy seam flags both `too-new`.
   - Unclear: the user's appetite for a 3-day-old release.
   - Recommendation: 1.15.0, and bump to 1.16.0 later as the real "bump" demonstration (it was shown to upgrade in place). Put the choice in the D-11 checkpoint.

2. **Stronger checksum story for WR-03?**
   - Known: D-09 fixes "upstream checksum file". WR-03's wording says those files share an origin with the artifacts.
   - Recommendation: keep D-09 for this phase and say so in the disposition. If the user wants more, add `NODE_SHA256_ARM64` style lines to `versions.env` later; it is an additive change.

3. **Readiness signal for start hooks.**
   - Known: `compose up --wait` may return before hooks finish (A8).
   - Options: (a) poll in the host library (small, local), (b) healthcheck in `compose.yml` plus a ready marker written by the entrypoint (structural, touches Phase 1 files and entrypoint self-tests).
   - Recommendation: (a) now; revisit with Phase 3's scripts, which will also need to know when a sandbox is ready.

4. **How does the automated host check "bump" the GSD pin?**
   - Known: a second real version means a second approval and goes stale.
   - Recommendation: the automated check plants a stale persisted GSD (`gsd-core/VERSION` set to `0.0.0`, plus a stale file under the installer's manifest) and a login/history sentinel, restarts, and asserts the pin, with the sentinels untouched. One attended Mac run does the real 1.15.0 to 1.16.0 bump (a helper in `tests/host/manual/`, like `h09-rebuild-resume.sh`), because the repo's guard forbids host tests that delete files or edit tracked files in place.

5. **Does `build.sh` need a test hook for another versions file?**
   - Recommendation: no. Keep it to one file; the bump test above does not need it.

## Validation Architecture

> `workflow.nyquist_validation` is `true` in `.planning/config.json`.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Plain bash suites in three layers (no external test framework): guard (static rules), self-tests (Linux, fake docker), host checks (Mac, real Docker) |
| Config file | none; `tests/guard/lib.sh`, `tests/selftest/lib-expect.sh`, `tests/host/lib.sh` |
| Quick run (Linux, seconds) | `bash tests/guard/run-all.sh` |
| Self-test run (Linux) | `bash tests/selftest/guard/run-all.sh`, `bash tests/selftest/entrypoint/run-all.sh`, `bash tests/selftest/host/run-all.sh`, `bash tests/selftest/bundle/run-all.sh` |
| Full suite (Mac only) | `bash tests/host/run-all.sh` (builds images, runs every automated H-check) |

### Phase Requirements to Test Map

| Req | Behavior | Test type | Command | Exists? |
|-----|----------|-----------|---------|---------|
| IMG-03 | Pins live only in `versions.env`; exact versions; images carry digests; Dockerfile `ARG`s have no default; no `latest` | guard (static) | `bash tests/guard/supply-chain.sh` (rewrite `versions_are_pinned`, extend file lists) | rule exists, needs rewrite |
| IMG-03 | A bare `docker build -f base/Dockerfile .` fails and names the missing variable | host | new small check (or part of the toolchain check) | Wave 0 |
| IMG-03 / IMG-04 | `/etc/sbx/versions.env` in the image equals the repo file | host | extend H-14 (bundle in image) or the new pins check: `docker run --rm --entrypoint cat sbx-claude:local /etc/sbx/versions.env` compared to the repo | Wave 0 |
| IMG-01 | `git gh node python3 uv java mvn` work as native arm64 from the base image; Node is 24.x; `java -version` says Temurin; login shell finds `java` and `mvn` | host | new check "toolchain" (`docker run` on `sbx-base:local` and `docker exec` in the sandbox); arch by ELF `e_machine` via `od`, plus `node -p process.arch`, `uname -m` | Wave 0 |
| IMG-01 | Tools come from the base, not the Claude image | host | extend H-02 or the new check: run the same commands against `sbx-base:local` | Wave 0 |
| TOOL-01 | `claude --version` equals the pin; self-update off; no `~/.local/bin/claude` and no `~/.local/share/claude` | host | extend H-12 (pin from `versions.env`) and H-13 (add the `~/.local/bin/claude` absence) | exist, edit |
| TOOL-02 | A start syncs GSD; `gsd-core/VERSION` equals the pin; a planted stale `VERSION` and stale file are replaced; login, history and user settings untouched; a user skill and a bundle skill survive | host | extend H-16 (sync refreshes and spares) with GSD sentinels, using the poll helper | exists, edit |
| TOOL-02 | `10-best-practices` still wins a name clash (hook order) | host | H-16 plants a bundle-named skill and a GSD-style skill; assert the bundle copy after start | exists, edit |
| TOOL-03 | Start with `--network none` syncs GSD and runs; start output has no `npx` or `@latest`; the failing-hook scenario still stops the start promptly | host | extend H-17 (`$RUN/h17/state/claude/gsd-core/VERSION` equals the pin; output scan); keep the `/proc/no-such-dir` case and assert it ends in under the check timeout | exists, edit |
| TOOL-02 (static) | Hook name is two digits, hook is executable and runs before `10-`, hook text has no installer words | guard | `start_hooks_have_two_digit_names`, `no_installs_at_container_start` | exist |
| USE-01 | `ccusage daily|monthly|session --offline --json` report a seeded transcript in `state/claude/projects`, as `sandbox`, in a `docker exec` shell | host | new check "ccusage" (seed the JSONL from Pattern 4, assert 100/200/300 and `claude`) | Wave 0 |
| IMG-07 | A file placed under the npm, uv and Maven cache folders survives `compose down` and `up`; `~/.m2` resolves into `state/m2`; folders exist after a start; image has nothing under `/home/sandbox/workspace` | host | new check "caches" (or extend H-08 history-survives-recreate) | Wave 0 |
| IMG-07 (static) | `SBX_STATE_DIRS` in the Claude image appends and keeps base entries | guard | new rule in `tests/guard/start.sh` or `isolation.sh` | Wave 0 |
| Layer order / cache | A pin bump rebuilds only its own and later layers | manual (attended) | one-time on the Mac, not automated | Wave 0 |

### Sampling Rate
- **Per task commit:** `bash tests/guard/run-all.sh` plus the self-test group(s) for the files touched.
- **Per wave merge:** all four self-test runners and the guard (everything Linux-runnable).
- **Phase gate:** `bash tests/host/run-all.sh` green on the Mac (exit 0), then `/gsd-verify-work`. The planner must mark the plan that needs the Mac as a human checkpoint; the dev sandbox cannot run it.

### Wave 0 Gaps
- [ ] `versions.env`, `build.sh` (new files) and the Dockerfile edits come first; everything else depends on them.
- [ ] Guard rewrite: `versions_are_pinned`, file lists, COPY-flag parsing, `.dockerignore` rule.
- [ ] Host library: `build_images` via `build.sh`, `claude_pin` from `versions.env`, `pin_of NAME`, a poll-until-synced helper, an `elf_machine` helper.
- [ ] Fake docker: knobs for the new host checks (toolchain output, ccusage output, GSD version file, cache survival) and the `versions.env` pin source. Budget real time here: the fake is about 900 lines and every host check needs a self-test group.
- [ ] New host check scripts (suggested IDs follow H-21): toolchain (IMG-01), pins and GSD record (IMG-03, plus bare-build failure), ccusage (USE-01), caches (IMG-07); each with checklist row, `run-all.sh` placement and self-test group.
- [ ] Attended helper in `tests/host/manual/` for the real GSD bump (1.15.0 to 1.16.0) and an optional layer-cache observation.
- [ ] Doc and requirement edits (IMG-07 in REQUIREMENTS and ROADMAP).

## Security Domain

> `security_enforcement` is enabled; ASVS level 1.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V1 Architecture / V14 Configuration (dependencies, build) | yes | Exact pins, digests, checksum files, human approval per pin (D-07 to D-11), no pipe-to-shell (guard) |
| V2 / V3 Authentication, Session | no (no login logic added; credentials in `state/claude` must stay untouched, verified for the installer) | n/a |
| V4 Access Control | yes (carry-over) | Non-root `sandbox`, `no-new-privileges`, `cap_drop: ALL`, one mount; tools root-owned in `/usr/local` and `/opt` |
| V5 Input Validation | yes | `versions.env` is sourced as bash: trusted repo file only; `SBX_NAME` rule unchanged; `${NAME:?}` guards |
| V6 Cryptography | yes | Use `sha256sum -c` / `sha512sum -c`; image digests; never hand-roll |
| V10 Malicious code | yes | Packages come from known names only; guard blocks `get-shit-done-cc` / `gsd-build`; start hooks run only baked code |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Compromised or typosquatted npm package (GSD history) | Tampering | Exact version, publish date and provenance reviewed at the checkpoint; `gsd-tools runtime-identity` asserts `@opengsd/gsd-core` in the build; guard on the old names |
| Floating tag moves under a rebuild | Tampering | Tag plus digest for Ubuntu, Temurin, uv |
| Tampered download | Tampering | Upstream checksum files for Node, gh, Maven (same-origin limitation noted in Open Question 2) |
| Start-time code fetch | Tampering / Elevation | Nothing is installed at start; the hook runs the baked installer, offline (verified), with credentials readable only because the pinned installer is trusted |
| Credential exposure to a compromised installer | Information disclosure | Same trust boundary as Claude itself; pinned and approved; fail closed |
| Shared package cache poisoning across projects | Tampering | Caches live in each sandbox's own `state/`, never shared |
| Maven `settings.xml` with credentials in `state/m2` | Information disclosure | Lives next to other credentials under `state/`; docs already say open `<name>/` in the IDE, not `$SBX_DIR` |
| `versions.env` sourced by the host script | Elevation (host) | Reviewed in PRs like any script; the file holds data only; document that it is code |

## Project Constraints (from CLAUDE.md and AGENTS.md)

- Agents run only in containers; each container sees only its project mount (isolation is the point).
- GSD only from `@opengsd/gsd-core`; never `get-shit-done-cc` or `gsd-build`.
- Simplicity: short, plain bash. Shell scripts follow the layout rule (80-column banners, functions, Main / Entry Point) and run on macOS stock bash 3.2 with BSD tools; executors author on Linux, so avoid GNU-only flags (`sed -i`, `grep -P`, `readlink -f`, `date -d`, `stat -c`).
- Coexistence: the old `ClaudeCode/` layout stays untouched until Phase 5; new names use `sbx-` (guard `old_layout_untouched`).
- Docker is not available in the dev sandbox; plans must include host-side manual verification.
- Code conventions: braces on every `if`/`for`/`while`; full variable names (`buildArgList`, not `args`); collection variables suffixed by shape (`List`, `Array`, `Map`); blank line before and after each control-flow block (the guard enforces this for host tests); imperative over functional style.
- Comments: no history comments, no planning IDs (`D-04`, `IMG-07`, phase numbers) in source, docs or tests (guard `sandbox_code_has_no_planning_ids`); ASCII only in source; no doc comments unless asked.
- Prose: no dashes as punctuation (em or en dash, or `--` as a stand-in; literal flags like `--build-arg` are fine); punctuation goes outside closing quotes; docs match their neighbours and stay short and schematic.
- Git: code, `.planning/` and `.claude/` changes never share a branch or PR; branch from the updated target; `git push` needs explicit per-branch approval; never push `main`; never merge PRs; stage explicit paths.
- Work enters through GSD commands (`/gsd-execute-phase`).

## Sources

### Primary (HIGH confidence)
- Run in this session (aarch64 Linux, Node 24.21.0 tarball from nodejs.org verified against `SHASUMS256.txt`): `npm install -g @opengsd/gsd-core@1.16.0` and `@1.15.0`, `ccusage@20.0.26`; `gsd-core --claude --global` (fresh, idempotent, upgrade, offline instrumented, hang case, unwritable case); `ccusage daily|monthly|session --offline [--json]` on a seeded transcript; `gsd-tools runtime-identity --raw`; Maven 3.9.16 download plus `sha512sum -c`.
- npm registry (`npm view`): versions, dist-tags, publish times, `dist.attestations`, `engines`, `bin`, `scripts`, dependencies for `@anthropic-ai/claude-code`, `@opengsd/gsd-core`, `ccusage`, `@ccusage/*`.
- `gsd-tools query package-legitimacy check --ecosystem npm ...` (verdicts above).
- Registry APIs: Docker Hub (ubuntu, eclipse-temurin) and ghcr.io (astral-sh/uv) manifests, digest recomputed from the body; nodejs.org dist index; GitHub releases API (gh, uv); Maven Central metadata; ports.ubuntu.com Packages indices for noble.
- Repo files read: `base/Dockerfile`, `claude/Dockerfile`, `compose.yml`, `base/sbx-entrypoint`, `base/sbx-start-lib.sh`, `claude/start.d/10-best-practices`, `claude/managed-settings.json`, `.dockerignore`, `tests/guard/{lib,supply-chain,start,isolation,bundle-wiring,host-tests,suites,run-all}.sh`, `tests/host/{lib-docker,run-all}.sh` and checks H-01, H-02, H-12, H-13, H-16, H-17, `tests/selftest/host/{units.sh,h13-*.sh,support/fake-docker}`, `tests/host-checklist.md`, `SANDBOX.md`, REQUIREMENTS, STATE, ROADMAP, `.planning/research/{STACK,ARCHITECTURE,PITFALLS}.md`, `01-REVIEW-DISPOSITION.md`.

### Secondary (MEDIUM confidence, official docs fetched)
- https://docs.docker.com/reference/dockerfile/ (variable modifiers, ARG before FROM, `COPY --from`)
- https://docs.docker.com/reference/build-checks/invalid-default-arg-in-from/ and https://docs.docker.com/build/checks/ (check skip directive, versions)
- https://docs.astral.sh/uv/guides/integration/docker/ (`COPY --from`, digest pinning, `UV_LINK_MODE`, `UV_CACHE_DIR`)
- https://raw.githubusercontent.com/adoptium/containers/main/21/jdk/ubuntu/noble/Dockerfile (what the official Temurin image adds beyond the JDK tree)

### Tertiary (LOW confidence, not directly confirmed)
- General web search on `--build-arg NAME` without a value taking the environment value (consistent with Docker documentation; not quoted from the docs page) and on ARG cache impact (conflicting summaries; see A1).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH, every version, digest and checksum read from its authority this session.
- GSD, ccusage behavior: HIGH, run on the real packages; the one inference is the root-owned ccusage mode failure.
- Dockerfile and BuildKit behavior: MEDIUM, documentation-level; Assumptions A1 to A4, A8, A12 each need one Mac observation.
- Test and guard change list: HIGH, found by reading the current files.
- Pitfalls: HIGH for the ones reproduced (hang, mode, state dirs), MEDIUM for the Docker-side ones.

**Research date:** 2026-10-08
**Valid until:** about 2026-10-22 for version and digest data (npm packages and the Ubuntu tag move weekly); 30 days for the structural findings.
