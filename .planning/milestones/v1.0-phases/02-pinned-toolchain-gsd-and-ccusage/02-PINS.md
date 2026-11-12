# Phase 2 pin table

Every version and digest the Phase 2 images will install, resolved from its authority on 2026-10-08. Later plans (03, 05, 07, 09) copy values from this table into `versions.env`, and only a row whose Status reads `approved YYYY-MM-DD` may be copied. A pin is one `versions.env` line, so a change is easy to undo. Nothing was installed to build this table; every lookup was read only (`npm view`, registry and release endpoints).

| NAME | Value | Kind | Published | Provenance or checksum | Checked with | Status |
|---|---|---|---|---|---|---|
| UBUNTU_IMAGE | ubuntu:24.04@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55 | image | 2026-09-18 (arm64 image created) | Index digest read from Docker Hub; the OCI index lists linux/arm64 and linux/amd64 (12 entries). Same digest as the research value, nothing changed. | Docker Hub token, then HEAD `registry-1.docker.io/v2/library/ubuntu/manifests/24.04` with OCI index and manifest list Accept headers (`docker-content-digest`), then GET of the index | approved 2026-10-09 |
| TEMURIN_IMAGE | eclipse-temurin:21.0.12_8-jdk-noble@sha256:4d271cd5e0624598cf563342f47281b09cb364bc13acbbd7251f49f83470018d | image | 2026-09-16 (arm64 image created) | Index digest read from Docker Hub; the OCI index lists linux/arm64 and linux/amd64 (10 entries). 21.0.12_8 is the newest 21.0.x jdk-noble tag in the tag list. Same digest as the research value. | Docker Hub token, HEAD and GET of `registry-1.docker.io/v2/library/eclipse-temurin/manifests/21.0.12_8-jdk-noble`, tag list check | approved 2026-10-09 |
| UV_IMAGE | ghcr.io/astral-sh/uv:0.12.21@sha256:a7aed3216253ee804de3e2d8afa5073baa1a177335345d43845cd4165e43b711 | image | 2026-09-29 (arm64 image created) | Index digest read from ghcr.io; the OCI index lists linux/arm64 and linux/amd64 (4 entries). Alternative for the reviewer: 0.12.23 is newer (arm64 image created 2026-10-03) at ghcr.io/astral-sh/uv:0.12.23@sha256:61d393e44e249f2e4b526b6c7ddcecce245946826e608e11c93ad4f5bba55b21, also an index listing arm64 and amd64. Both digests equal the research values. | ghcr.io token, HEAD and GET of `ghcr.io/v2/astral-sh/uv/manifests/0.12.21` and `/0.12.23` | approved 2026-10-09 |
| NODE_VERSION | 24.21.0 | tarball | 2026-09-07 (nodejs.org dist index, LTS Krypton) | Upstream SHASUMS256.txt for v24.21.0 lists node-v24.21.0-linux-arm64.tar.xz (sha256 6ad1325edbdb5649c379b75a237147a666c95d4f9ae8d340fef2d1575d289ad2) and node-v24.21.0-linux-x64.tar.xz (sha256 fd8e59d5a511510f6a298afb548f18c7d2b1be404d8b4a27d94fbe49f56cb2d6). 24.21.0 is the newest v24 release. Carried pin, unchanged. The checksum file shares an origin with the tarball (kept as decided). | GET `nodejs.org/dist/v24.21.0/SHASUMS256.txt`; `nodejs.org/dist/index.json` | approved 2026-10-09 |
| GH_VERSION | 2.102.0 | tarball | 2026-09-30 (GitHub release v2.102.0, latest release, not a prerelease) | Upstream gh_2.102.0_checksums.txt lists gh_2.102.0_linux_arm64.tar.gz (sha256 7862c86c72f43df3a2d93ddde6f473285b4e2af61b494849846827e513ef6484) and gh_2.102.0_linux_amd64.tar.gz (sha256 bb766f710eef8ede859c18578c72c327597cd4c8a85b06001b1f3843c6019386). Carried pin, unchanged. The checksum file shares an origin with the tarball (kept as decided). | GET `github.com/cli/cli/releases/download/v2.102.0/gh_2.102.0_checksums.txt`; GitHub releases API | approved 2026-10-09 |
| MAVEN_VERSION | 3.9.11 | tarball | 2025-07-12 (Maven Central file last-modified) | Maven Central serves apache-maven-3.9.11-bin.tar.gz.sha512 as a 128-hex hash (bcfe4fe305c962ace56ac7b5fc7a08b87d5abd8b7e89027ab251069faebee516b0ded8961445d6d91ec1985dfe30f8153268843c89aa392733d1a3ec956c9978). Maven is platform independent, one tarball for both architectures. The checksum shares an origin with the tarball (kept as decided). Replaces 3.9.16 (approved 2026-10-09): on the Mac run, 3.9.16 (Maven Resolver 1.9.27) failed with an Input/output error deleting .lastUpdated files in state/m2 on the virtiofs mount; 3.9.11 (Resolver 1.9.24) downloaded into the same folder. Held until a release passes the Maven download in H-23. | GET `repo.maven.apache.org/maven2/org/apache/maven/apache-maven/3.9.11/apache-maven-3.9.11-bin.tar.gz.sha512`; HEAD of the tarball; resolverVersion in the 3.9.x poms; Mac diagnostic run | approved 2026-10-09 |
| CLAUDE_CODE_VERSION | 2.1.285 | npm | 2026-09-29 | No provenance attestation. No repository in the registry metadata. Maintainers are 13 anthropic.com accounts. Install scripts: postinstall `node install.cjs` (links the native binary from the optional dependency @anthropic-ai/claude-code-linux-arm64@2.1.285); the `prepare` script only blocks direct publishing. Approved in Phase 1, carried. Note: dist-tags now show stable 2.1.286 and latest 2.1.294, so this pin is not the newest; kept because it was already approved. Integrity sha512-frr0DLmVHSDNjw+hC6ZmXMVQ8yH4nNmVcI4lVFzWt0bdPNZP7clOKsuLcqSdwQabIpe6A3NEc3TJfiBVD8B2Bg== | `npm view @anthropic-ai/claude-code@2.1.285 --json`; `npm view @anthropic-ai/claude-code time`; package legitimacy check (see below) | approved 2026-10-09 |
| GSD_CORE_VERSION | 1.15.0 | npm | 2026-09-26 | Provenance attestation present (SLSA provenance v1). Repository git+https://github.com/open-gsd/gsd-core.git. Maintainers trek-e, solvely-colin, jeremymcs. No install, preinstall or postinstall script (the `prepare`, `prepack` and `prepublishOnly` scripts run when publishing or installing from git, not when installing from the registry). Dependencies ws ^8.21.0 and @anthropic-ai/claude-agent-sdk ^0.2.84; optional dependency fallow ^2.70.0. 1.15.0 is proposed for its age (12 days); 1.16.0 is the attended bump target. Integrity sha512-GwdlJeupozyM22g2INdxiNfkpDm5hFS7G42leRqQwHb/0BclBG3TpgyGtWIkf47shjkfGRtrK5iK+pPZ61DvMA== | `npm view @opengsd/gsd-core@1.15.0 --json`; `npm view @opengsd/gsd-core time`; package legitimacy check (see below) | approved 2026-10-09 |
| CCUSAGE_VERSION | 20.0.26 | npm | 2026-09-27 (ccusage); 2026-09-27 (@ccusage/ccusage-linux-arm64) | ccusage: provenance attestation present (SLSA provenance v1), repository git+https://github.com/ccusage/ccusage.git (apps/ccusage), maintainer ryoppippi, no dependencies, no install script (only a `build` script). It ships its native binary as optional dependencies @ccusage/ccusage-linux-x64, -linux-arm64, -darwin-x64, -darwin-arm64, -win32-x64, -win32-arm64, all at 20.0.26. @ccusage/ccusage-linux-arm64@20.0.26: provenance attestation present, same repository (packages/ccusage-linux-arm64), os linux and cpu arm64, no scripts, no dependencies; installed as an optional dependency that must not be skipped (`--omit=optional` breaks ccusage). ccusage 20.0.26 is the latest tag. Integrity ccusage sha512-46TTmFKcuNyWbtqj8HZqWTmVQIsApvGO4xP+E2VL5NC/oMjdtHOv9svVTsHX1WQgetbNOV4GdvQGHLG22vXZgg==; arm64 package sha512-R8/gdX+XNYVxH6ZPq3RtBJt8TU23BFMLaHXwgF+ZYZyi8qbHwofrQemgZflB2cKWYgz3ejXuS2U2ggqzqNW8rw== | `npm view ccusage@20.0.26 --json`; `npm view @ccusage/ccusage-linux-arm64@20.0.26 --json`; `npm view ... time`; package legitimacy check (see below) | approved 2026-10-09 |
| GSD_BUMP_TARGET | 1.16.0 | npm, attended test only | 2026-10-05 | @opengsd/gsd-core@1.16.0: provenance attestation present (SLSA provenance v1), repository git+https://github.com/open-gsd/gsd-core.git, same maintainers, same dependencies as 1.15.0 (ws ^8.21.0, @anthropic-ai/claude-agent-sdk ^0.2.84, optional fallow ^2.70.0), no install script. Current `latest` tag. Used only by the attended bump test in plan 06 and never written into versions.env. Integrity sha512-A3OgmNH8/M0eALNpKZp0bjP0L5puu6rne1keqdFaM+NvqybuYZ2kJOcUH+fCKu6FQBGV0fAUEUE1bs6xqRfF7Q== | `npm view @opengsd/gsd-core@1.16.0 --json`; package legitimacy check (see below) | approved 2026-10-09 |

## Package legitimacy check

Command: `node ~/.claude/gsd-core/bin/gsd-tools.cjs query package-legitimacy check --ecosystem npm <names>`.

First attempt with the five `name@version` specs: the check treats the whole string as a package name and answers SLOP (`does-not-exist`) for all five. That is a limitation of the check's input form, not a finding about the packages (the `npm view` rows above show each exact version exists). Second run, by package name (it then judges the newest published version, which for Claude Code is 2.1.294, not the pinned 2.1.285):

| Package | Verdict | Reasons | Latest published | Weekly downloads | Repository | Install script |
|---|---|---|---|---|---|---|
| @anthropic-ai/claude-code | SUS | too-new, no-repository | 2026-10-08 | 14786283 | none | postinstall `node install.cjs` |
| @opengsd/gsd-core | SUS | too-new | 2026-10-05 | 11257 | git+https://github.com/open-gsd/gsd-core.git | none |
| ccusage | SUS | too-new | 2026-09-27 | 197130 | git+https://github.com/ccusage/ccusage.git | none |
| @ccusage/ccusage-linux-arm64 | SUS | too-new | 2026-09-27 | 10104 | git+https://github.com/ccusage/ccusage.git | none |

No package got a SLOP verdict by name. Every SUS reason is recency (`too-new`), plus `no-repository` for Claude Code (its registry metadata lists no repository; Phase 1 already approved it).

## Notes for the reviewer

- The npm flags are recency only. None is a name, maintainer or deprecation anomaly. Three of the four packages carry a SLSA provenance attestation; Claude Code has none (carried from Phase 1).
- @opengsd/gsd-core depends on @anthropic-ai/claude-agent-sdk, which brings a second Claude binary of about 232 MB under `/usr/local/lib` that is not on PATH (size from the research, not re-measured here). The caret ranges on its dependencies (ws, claude-agent-sdk, fallow) mean transitive versions are resolved at build time and are not pinned by `versions.env`.
- Node, gh and Maven are checked against upstream checksum files that share an origin with the tarballs. That is kept as decided; stronger per-architecture hashes in `versions.env` would be an additive change later.
- Images are pinned as tag plus index digest, so the same image is pulled on every machine and architecture. On the Mac you can compare: `docker buildx imagetools inspect ubuntu:24.04` (and the Temurin and uv tags); the index digest must equal the Value cell.
- Plain apt packages stay unpinned and follow the pinned Ubuntu release.
- GSD comes only from @opengsd/gsd-core. The old package names appear nowhere in this table.

## Choices for the reviewer

| Choice | Proposed | Alternative |
|---|---|---|
| GSD pin and bump target | GSD_CORE_VERSION 1.15.0, GSD_BUMP_TARGET 1.16.0 | swap them |
| uv | 0.12.21 | 0.12.23 (digest in the UV_IMAGE row) |

## Approval record

| Field | Value |
|---|---|
| Date | 2026-10-09 |
| Reviewer's answer (verbatim) | "approved" |
| Rows approved | all ten, no swaps |
| GSD pin | GSD_CORE_VERSION 1.15.0 (unchanged) |
| GSD bump target | GSD_BUMP_TARGET 1.16.0 (unchanged; attended test only, never written into `versions.env`) |
| uv | UV_IMAGE 0.12.21 with its digest (unchanged) |

Later plans may copy the Value of any row above into `versions.env`.

## Change after approval

- 2026-10-09: MAVEN_VERSION 3.9.16 replaced by 3.9.11 after the Mac run showed 3.9.16 cannot use a local repository on the mount. The user approved the change: "Yes, go with 1".
