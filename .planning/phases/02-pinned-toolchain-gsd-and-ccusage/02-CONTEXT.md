# Phase 2: Pinned Toolchain, GSD, and ccusage - Context

**Gathered:** 2026-10-08
**Status:** Ready for planning

<domain>
## Phase Boundary

The shared base image (`sbx-base`) gets the full toolchain: JDK 21 (Temurin), Maven, Python 3 with uv, plus the Node 24 and gh it already has. The Claude image (`sbx-claude`) gets Claude Code, GSD and ccusage. Every version is set in one `versions.env` at the repo root, and a short `build.sh` builds both images from it. Every container start syncs the image's GSD into `state/claude` with no network. `ccusage` reports this sandbox's real usage. Tool caches (Maven, npm, uv) survive a recreate.

Requirements: IMG-01, IMG-03, IMG-04, TOOL-01, TOOL-02, TOOL-03, USE-01, plus the new IMG-07 (D-15).

</domain>

<decisions>
## Implementation Decisions

### Build wiring for `versions.env`
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

### Pin strictness and supply chain
- **D-07:** Ubuntu, Temurin and uv are pinned by tag plus digest in `versions.env` (Temurin and uv via `COPY --from=` their official images, as in `.planning/research/STACK.md`).
- **D-08:** npm tools (Claude Code, `@opengsd/gsd-core`, ccusage) are installed at exact versions.
- **D-09:** Every downloaded tarball (Node, gh, Maven) is checked against its upstream checksum file, as `base/Dockerfile` already does for Node and gh.
- **D-10:** Plain apt packages are not pinned. They follow the pinned Ubuntu release and pick up security fixes on each rebuild. Pinning apt versions is brittle because Ubuntu drops old package versions. The docs say this in one line.
- **D-11:** Each new pin (version and digest) gets a human supply-chain approval checkpoint in the plan, as Claude Code did in Phase 1. This closes the moved Phase 1 findings WR-03 (integrity and checksums) and IN-03 (base image digest); record the outcome in the disposition files.

### GSD sync at start
- **D-12:** GSD is baked with `npm install -g @opengsd/gsd-core@${GSD_CORE_VERSION}`, and a start hook in `/etc/sbx/start.d` runs its installer against `CLAUDE_CONFIG_DIR` at every start (pattern in `.planning/research/ARCHITECTURE.md`, "bake the installer, sync at start"). No `.initialized` marker, no `npx`, no network.
- **D-13:** A failed GSD sync stops the container start, like any failing start hook (fail closed). A silently stale GSD is the bug this project exists to fix.
- **D-14:** The GSD hook runs before `10-best-practices`, so a bundle skill still wins a name clash (Phase 1.2 rule). Hand edits to GSD files are overwritten by the image's GSD (the installer backs them up to `gsd-local-patches/`); that is the intended "image wins" behaviour.

### Tool caches across recreate (new requirement IMG-07)
- **D-15:** Add requirement **IMG-07**: the Maven, npm and uv caches survive a container recreate (and so a rebuild/upgrade). Add it to `REQUIREMENTS.md` and the Phase 2 row of `ROADMAP.md`.
- **D-16:** The caches live on the existing bind mount under `<sandbox>/state/`: `NPM_CONFIG_CACHE` and `UV_CACHE_DIR` as image ENV pointing into `state/cache/...`, and `~/.m2` as a symlink into `state/` (the same pattern as the `~/.claude` link; Maven has no clean env var for its local repo). The new folders go into `SBX_STATE_DIRS` so the entrypoint creates them. No Docker named volume: `compose.yml` keeps "no volumes, all data in `$SBX_DIR`". The cost (slower file sharing for many small files, caches can reach GBs per sandbox and may be deleted freely) is accepted and stated in the docs.
- **D-17:** One host check proves a cached file survives a recreate.

### Base tools and ccusage
- **D-18:** The base apt list adds jq, ripgrep, unzip, zip, openssh-client, make, build-essential and tzdata to today's set (ca-certificates, curl, git, less, procps, xz-utils). Python comes from apt (`python3`, `python3-venv`, `python3-pip`, 3.12 on noble); uv handles projects and other Python versions.
- **D-19:** GSD and ccusage go in the Claude image, not the base (they are agent tools). The base holds only toolchains and Linux tools.
- **D-20:** ccusage keeps its default online price lookup at run time. TOOL-03 covers container start only. It reads `CLAUDE_CONFIG_DIR`, which is the sandbox's own `state/claude`, so it reports this project's usage with no extra wiring.

### Claude's Discretion
- Exact names in `versions.env` (for example `UBUNTU_IMAGE`, `TEMURIN_IMAGE`, `UV_IMAGE`, `MAVEN_VERSION`, `GSD_CORE_VERSION`, `CCUSAGE_VERSION`), the hook file name and number, and the cache folder names under `state/`.
- Which image gets the `/etc/sbx/versions.env` copy (base, claude, or both) as long as a sandbox shell can read it.
- How the host checks prove start with networking disabled (for example `--network none`), the GSD pin bump, the native arm64 binaries and ccusage on real data.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and requirements
- `.planning/ROADMAP.md` §Phase 2: goal and the five success criteria
- `.planning/REQUIREMENTS.md`: IMG-01, IMG-03, IMG-04, TOOL-01, TOOL-02, TOOL-03, USE-01 (and IMG-07 once added, D-15)
- `.planning/PROJECT.md`: core value, constraints (coexistence, security, simplicity, Mac verification)

### Research
- `.planning/research/STACK.md`: chosen sources and versions for Ubuntu, Node, Temurin, Maven, uv, Python, gh; rejected alternatives
- `.planning/research/ARCHITECTURE.md`: GSD "bake the installer, sync at start" pattern, ccusage install notes, `versions.env` role
- `.planning/research/PITFALLS.md`: layer cache staleness and other build pitfalls

### Prior phase decisions
- `.planning/phases/01.5-host-test-fixes/01.5-CONTEXT.md` D-03: Phase 1 WR-03 and IN-03 moved to this phase
- `.planning/phases/01-two-mount-claude-sandbox/01-REVIEW-DISPOSITION.md`: where WR-03 and IN-03 are recorded

### Current code
- `base/Dockerfile`, `claude/Dockerfile`: today's pins (`NODE_VERSION`, `GH_VERSION`, `CLAUDE_CODE_VERSION`) and the checksum pattern
- `claude/start.d/10-best-practices`: the existing start hook the GSD hook sits beside
- `base/sbx-entrypoint`, `base/sbx-start-lib.sh`: start hook runner, `SBX_STATE_DIRS`
- `compose.yml`: no volumes, the one bind mount
- `SANDBOX.md`: build and rebuild instructions to switch to `./build.sh`
- `tests/host/run-all.sh`, `tests/host-checklist.md`: where new host checks go

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Node and gh install blocks in `base/Dockerfile`: the tarball plus checksum pattern to copy for Maven.
- `/etc/sbx/start.d` hook runner: runs hooks in name order as `sandbox`, fails the start on a failing or broken hook.
- `SBX_STATE_DIRS`: lets an image ask the entrypoint to create extra folders under `state/`.
- `~/.claude` symlink in `claude/Dockerfile`: the pattern for the `~/.m2` link.
- The build-time smoke test (`claude --version` equals the pin): extend to GSD and ccusage.

### Established Patterns
- Every per-shell setting is image ENV, because `docker exec` shells never run the entrypoint.
- Root-owned tools in `/usr/local`, outside the mount; nothing is installed at runtime.
- Shell scripts use 80-column section banners, functions and a Main / Entry Point block, and must run on macOS (BSD tools); `build.sh` runs on the Mac.
- `.dockerignore` is an allowlist (`base/`, `claude/`, `best-practices/`); `versions.env` must be added if it is copied into the image.

### Integration Points
- `build.sh` is what the host tests and `SANDBOX.md` call to build.
- The GSD hook and the bundle hook both write into `state/claude`.
- The guard rule against the compromised GSD package must keep passing.

</code_context>

<specifics>
## Specific Ideas

- The user wants the build mechanism as simple as possible: no hand-written parser of `versions.env`; bash reads the values, Docker takes them from the environment.
- The user liked having the pins visible inside the container (`cat /etc/sbx/versions.env`).

</specifics>

<deferred>
## Deferred Ideas

None. The cache idea first proposed as deferred was folded in (D-15 to D-17).

</deferred>

---

*Phase: 02-pinned-toolchain-gsd-and-ccusage*
*Context gathered: 2026-10-08*
