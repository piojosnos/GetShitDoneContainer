# Phase 2: Pinned Toolchain, GSD, and ccusage - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the alternatives considered.

**Date:** 2026-10-08
**Phase:** 02-pinned-toolchain-gsd-and-ccusage
**Areas discussed:** Build wiring for `versions.env`, Tool caches across recreate (areas 2 to 4 accepted as recommended)

---

## Build wiring for `versions.env`

### What turns `versions.env` into build args

| Option | Description | Selected |
|--------|-------------|----------|
| `build.sh` | Short script at the repo root, builds base then claude | ✓ |
| `docker compose build` | No script, but Compose needs `SBX_NAME`/`SBX_DIR` for every command | |
| Dockerfile defaults checked by the guard | Two copies of every version | |

### Default versions in the Dockerfiles

| Option | Description | Selected |
|--------|-------------|----------|
| No defaults, fail loudly | A bare `docker build` stops and points to `./build.sh` | ✓ |
| Keep defaults, `build.sh` overrides | Bare build works, defaults can drift | |

**Notes:** user asked for a comment in both Dockerfiles and in `build.sh`.

### How pins are passed

| Option | Description | Selected |
|--------|-------------|----------|
| Every pin to both builds | New pin never edits `build.sh` | ✓ |
| Explicit per-image list | Third edit per tool | |

### How `build.sh` reads the file

| Option | Description | Selected |
|--------|-------------|----------|
| Strict line reader | Validates each line, reports the line number | |
| Ship the file into the build, source it in `RUN` | Proposed by the user; rejected because `FROM` pins need build args and every bump rebuilds all layers | |
| A: `set -a; source`, then pass names with `--build-arg NAME` | About ten lines, no validation | ✓ |
| B: Compose `build.yml` with `--env-file` | No script logic, but a line per pin in `build.yml` | |

**User's choice:** A.
**Notes:** the user did not want to maintain a script that parses another file. The user liked keeping the env file in the container for reference, so a copy goes to `/etc/sbx/versions.env`.

---

## Tool caches across recreate

| Option | Description | Selected |
|--------|-------------|----------|
| Include in Phase 2, bind mount under `state/` | About 10 lines plus one host check | ✓ |
| Defer | Originally proposed only because it is not a listed requirement | |
| Docker named volume | Faster, but breaks the no-volumes rule | |

**User's choice:** include it; new requirement IMG-07.

---

## Accepted recommendations (not discussed)

- Pin strictness: tag plus digest for Ubuntu, Temurin, uv; exact npm versions; checksums for tarballs; apt follows the pinned Ubuntu release; human approval per new pin.
- GSD sync failure stops the start.
- Base tools: add jq, ripgrep, unzip, zip, openssh-client, make, build-essential, tzdata. ccusage keeps online price lookup.

## Claude's Discretion

- `versions.env` names, hook file name and number, cache folder names, which image holds the `versions.env` copy, how host checks prove offline start and the GSD bump.

## Deferred Ideas

None.
