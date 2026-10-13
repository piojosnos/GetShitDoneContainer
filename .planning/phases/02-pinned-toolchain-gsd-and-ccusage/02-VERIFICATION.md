---
phase: 02-pinned-toolchain-gsd-and-ccusage
verified: 2026-10-13T00:00:00Z
status: passed
score: 5/5 must-haves verified
covered_files:
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-01-PLAN.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-01-SUMMARY.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-02-PLAN.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-02-SUMMARY.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-03-PLAN.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-03-SUMMARY.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-04-PLAN.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-04-SUMMARY.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-05-PLAN.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-05-SUMMARY.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-06-PLAN.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-06-SUMMARY.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-07-PLAN.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-07-SUMMARY.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-08-PLAN.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-08-SUMMARY.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-09-PLAN.md"
  - ".planning/phases/02-pinned-toolchain-gsd-and-ccusage/02-09-SUMMARY.md"
  - "base/Dockerfile"
  - "build.sh"
  - "claude/Dockerfile"
  - "claude/start.d/05-gsd"
  - "compose.yml"
  - "tests/host/h13-env-and-no-self-update.sh"
  - "tests/host/h16-sync-refreshes-and-spares.sh"
  - "tests/host/h17-start-offline-and-failing-hook.sh"
  - "tests/host/h22-toolchain-in-base.sh"
  - "tests/host/h23-caches-survive-recreate.sh"
  - "tests/host/h24-ccusage-reports-usage.sh"
  - "tests/host/h25-images-match-versions.sh"
  - "versions.env"
covered_digest: "v2:sha256:34214788d9a8ef010610778030635664863d62cb9f8d03e35691c60ef1427da5"
behavior_unverified: 0
overrides_applied: 0
---

# Phase 2: Pinned Toolchain, GSD, and ccusage Verification Report

**Phase Goal:** The sandbox has the full development toolchain plus Claude Code, GSD, and ccusage baked into the image at versions pinned in one `versions.env`. Rebuilding with changed pins delivers the new versions into the sandbox while login and history persist.
**Verified:** 2026-10-13
**Status:** passed
**Re-verification:** No, initial verification

## How this was verified

Docker does not run in the dev sandbox, so the verification has two kinds of evidence:

- Code and wiring, read directly from the repo on HEAD (`f8ec3c2`), plus the Linux suites run here.
- Runtime behavior, taken from the recorded human Mac runs in `02-09-SUMMARY.md`: the first full run (25 passed, 0 failed, 0 not run), the attended GSD bump from 1.15.0 to 1.16.0 with `claude --continue` resuming the earlier session (user confirmed), and the post-review re-run on 2026-10-12 (`Summary: 25 passed, 0 failed, 0 not run`) that covers the code review fixes.

I did not take the SUMMARY's word for the code. Each recorded Mac result below was matched to a host check that exists in the repo, is wired into `tests/host/run-all.sh`, and asserts the thing the criterion names.

## Goal Achievement

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `git`, `gh`, `node -v` (24.x), `python3`, `uv`, `java -version` (Temurin 21), `mvn -v` run as native arm64 binaries, from the shared base image, not the Claude image | VERIFIED | `base/Dockerfile` installs Node (tarball + SHASUMS256 check), gh (tarball + checksums), Temurin (`COPY --from=jdk`, pinned by digest), Maven (tarball + sha512), uv (`COPY --from=uv`, pinned by digest), Python and Linux tools via apt. `claude/Dockerfile` installs none of these (only Claude Code, GSD, ccusage). Build-time smoke test in the base checks `node -v`, `gh`, `mvn`, `java` Temurin, `uv`, `python3`. H-22 (`tests/host/h22-toolchain-in-base.sh` with `support/toolchain-probe.sh`) reads the ELF e_machine bytes (b700 = AArch64) in a throwaway `sbx-base:local` container and in the sandbox. Mac: H-22 passed ("Node 24.21.0, uv 0.12.21, Temurin 21.0.12 and Maven 3.9.11 are native and at their pins"). |
| 2 | Every version is set in `versions.env`; no Dockerfile uses a floating `latest`; bumping a pin or adding a tool with a one-line change, then rebuilding and recreating, puts that version in use | VERIFIED | `versions.env` holds 9 pins (3 image pins with `@sha256` digests, 6 exact versions). `build.sh` sources it and passes every NAME as a bare `--build-arg`. Dockerfile ARGs have no defaults (only `BASE_IMAGE`, a local tag) and every install step starts with `: "${X:?X is not set; build with ./build.sh}"`. Guard rules `versions_are_pinned`, `no_floating_latest_versions` and `installs_use_declared_pins` pass on HEAD ("All rules hold."). A grep for `latest` and `npx` in the Dockerfiles, start hook and `sbx-*` scripts finds no non-comment use. All 9 values equal the approved rows of `02-PINS.md` (Maven at 3.9.11, the recorded change after approval). Mac: H-25 (image's `/etc/sbx/versions.env` equals the repo file; GSD and ccusage equal their pins; a build without `build.sh` stops naming the missing pin) and the attended bump (one changed line plus rebuild delivered GSD 1.16.0). |
| 3 | After a rebuild, `claude --version` matches the pin, Claude reports self-updating is disabled, and `~/.local` has no self-installed Claude copy | VERIFIED | `claude/Dockerfile` installs `@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}` globally from npm as root into `/usr/local`, sets `DISABLE_UPDATES=1`, and the smoke test requires `claude --version` equal to `"<pin> (Claude Code)"`. H-13 asserts `claude update` says "Updates are disabled by your administrator", and that neither `~/.local/share/claude` nor `~/.local/bin/claude` exists. H-25 compares the installed set to the pins. Mac: H-13 and H-25 passed. |
| 4 | After the GSD pin is bumped and the image rebuilt, starting the container syncs the image's `@opengsd/gsd-core` into the persisted `~/.claude`; GSD matches the new pin; login and session history are unchanged; start works with networking disabled with no `npx` or `@latest` in the start logs | VERIFIED | `claude/start.d/05-gsd` runs the baked `gsd-core --claude --global --config-dir "$CLAUDE_CONFIG_DIR"` at every start (no network, 300 s limit, output printed only on failure), then fails the start unless `gsd-core/VERSION` equals the image's `gsd-tools runtime-identity` version. It runs before `10-best-practices`. The Dockerfile installs `@opengsd/gsd-core` (never the old package) at the pin and checks its identity at build time. H-17 (`--network none`; asserts `state/claude/gsd-core/VERSION` equals the pin, the `[sbx] GSD <v> synced` line, and no `npx` or `@latest`). H-16 (stale GSD is restored, user files spared). Mac: H-16 and H-17 passed in both runs; the attended `tests/host/manual/h16-gsd-bump.sh` run with the bump target 1.16.0 passed: GSD 1.16.0 in `state/claude` and the start log, no `npx` or `@latest`, `loggedIn` still true, `claude --continue` resumed the earlier session (user confirmed). |
| 5 | `ccusage daily`, `monthly` and `session` run in the container shell and report this project's real Claude usage from `<sandbox>/state/claude` | VERIFIED | `claude/Dockerfile` installs `ccusage@${CCUSAGE_VERSION}` as root into `/usr/local` with optional dependencies kept, and `chmod 755` on the native binary (glob fails the build if missing); the smoke test requires `ccusage --version` equal `ccusage <pin>`. `CLAUDE_CONFIG_DIR` is image ENV, so docker exec shells read `state/claude`. H-24 plants a transcript in `state/claude/projects/...` and asserts daily, monthly and session JSON report 100/200/300 tokens as whole numbers plus a table with a Total row, as the sandbox user. Mac: H-24 passed in both runs. |

**Score:** 5/5 truths verified (0 present but behavior-unverified)

The behavior-dependent truths (criterion 4: the image wins over persisted state, login and history unchanged) are backed by named host checks that exercise the transition (H-16, H-17, and the attended bump) with recorded passing Mac results, not by symbol presence alone. The Linux self-tests of the same checks (fake docker and fake GSD) also pass here.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `versions.env` | the only place versions live | VERIFIED | 9 pins, each equal to its approved row in `02-PINS.md` |
| `build.sh` | builds base then Claude image from `versions.env` | VERIFIED | Sources the file, bare `--build-arg` per NAME, stops on a missing file or empty pin list; stock bash 3.2 style |
| `base/Dockerfile` | multi-stage base with all toolchains, caches env, empty mount point | VERIFIED | Substantive and wired through `build.sh`; last RUN fails if files sit under the mount point |
| `claude/Dockerfile` | pinned Claude Code, GSD, ccusage, hook copy, pin record | VERIFIED | Substantive; each npm step uses a throwaway `/tmp/npm-cache`; `/etc/sbx/versions.env` copied last |
| `claude/start.d/05-gsd` | GSD sync start hook | VERIFIED | Fail closed, offline, version-checked; copied to `/etc/sbx/start.d` and made executable |
| `tests/host/h22` to `h25`, `h13`, `h16`, `h17`, `manual/h16-gsd-bump.sh` | host checks | VERIFIED | All exist, are non-stub, and h22 to h25, h16, h17 are listed in `tests/host/run-all.sh` lists |
| `02-PINS.md` | approved pin table | VERIFIED | Ten rows approved 2026-10-09; Maven change recorded with the user's approval |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `versions.env` | both Dockerfiles | `build.sh` exports and `--build-arg NAME` | WIRED | Dockerfiles carry no defaults; H-25 builds without `build.sh` and expects a stop naming the pin |
| `claude/Dockerfile` | `05-gsd` hook | `COPY claude/start.d/ /etc/sbx/start.d/` plus `chmod 755` | WIRED | Hook runs at every start from the base entrypoint, before the bundle hook |
| `05-gsd` | `state/claude` | `gsd-core --config-dir "$CLAUDE_CONFIG_DIR"` | WIRED | `CLAUDE_CONFIG_DIR` is image ENV; hook refuses to run without it |
| `ccusage` | `state/claude` | `CLAUDE_CONFIG_DIR` env | WIRED | H-24 proves it with a planted transcript |
| `base/Dockerfile` caches | `state/` | `NPM_CONFIG_CACHE`, `UV_CACHE_DIR`, `~/.m2` link to `state/m2`, `SBX_STATE_DIRS` | WIRED | H-23 (including a real `mvn dependency:get` of junit 4.13.2) passed on the Mac |
| `tests/host/run-all.sh` | h22 to h25 | check lists | WIRED | Present in the no-sandbox, sandbox and chain lists |

### Data-Flow Trace (Level 4)

| Artifact | Data | Source | Produces Real Data | Status |
|----------|------|--------|--------------------|--------|
| `ccusage` reports | token counts | JSONL under `state/claude/projects` via `CLAUDE_CONFIG_DIR` | Yes (planted transcript read back in H-24) | FLOWING |
| `05-gsd` version check | synced version | `gsd-core/VERSION` written by the installer vs `gsd-tools runtime-identity` | Yes (two independent sources compared) | FLOWING |

### Behavioral Spot-Checks (Linux, run here on HEAD)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Every script parses | `bash -n` over all tracked scripts | `BASHN_OK` | PASS |
| Guard rules (pins, isolation, supply chain, start, host tests) | `bash tests/guard/run-all.sh` | `All rules hold.` | PASS |
| Guard self-tests | `bash tests/selftest/guard/run-all.sh` | `All cases pass.` | PASS |
| Entrypoint and GSD hook self-tests | `bash tests/selftest/entrypoint/run-all.sh` | `All cases pass.` | PASS |
| Host check self-tests (fake docker) | `bash tests/selftest/host/run-all.sh` | `All cases pass.` | PASS |
| Bundle self-tests | `bash tests/selftest/bundle/run-all.sh` | `All cases pass.` | PASS |

### Probe Execution

SKIPPED: the phase declares no `probe-*.sh` scripts. Its probe-like file, `tests/host/support/toolchain-probe.sh`, runs only inside a container and is exercised by H-22 on the Mac.

### Mac Runtime Evidence (recorded, not re-run here)

| Evidence | Source | Result |
|----------|--------|--------|
| Full host run before review (`bash tests/host/run-all.sh`) | `02-09-SUMMARY.md` Mac run | 25 passed, 0 failed, 0 not run |
| Guard under macOS bash | `02-09-SUMMARY.md` | `All rules hold.` |
| Attended GSD bump 1.15.0 to 1.16.0, login kept, `claude --continue` resumed | `02-09-SUMMARY.md` (user confirmed) | PASS |
| Post-review re-run, 2026-10-12 | `02-09-SUMMARY.md` "Post-review Mac run" | `Summary: 25 passed, 0 failed, 0 not run` |

The post-review run covers the stricter H-16, H-23, H-24 and H-25 and the renamed download steps in `base/Dockerfile`. Commits after it are `clean.sh` (outside the phase requirements) and documentation only.

### Requirements Coverage

Requirement IDs declared across the plan frontmatter: IMG-01, IMG-03, IMG-04 (plans 01, 03, 08, 09), IMG-07 (04, 09), TOOL-01 (02, 08, 09), TOOL-02 and TOOL-03 (02, 05, 06, 09), USE-01 (02, 07, 09). That is the same set as the roadmap's Phase 2 line, and `REQUIREMENTS.md` maps exactly these eight IDs to Phase 2. No ID is missing from the plans and none is orphaned.

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|--------------|-------------|--------|----------|
| IMG-01 | 03, 09 | Shared base with Linux tools, git, gh, Node 24, Python 3 + uv, Temurin 21, Maven | SATISFIED | `base/Dockerfile`; H-22 on the Mac |
| IMG-03 | 01, 02, 03, 08, 09 | Every version pinned in one `versions.env`; no floating `latest`; no runtime installs | SATISFIED | `versions.env`, `build.sh`, guard rules, H-25; no `npx` or `latest` in the Dockerfiles or hooks |
| IMG-04 | 01, 08, 09 | Adding a tool is one line plus a rebuild | SATISFIED | Header of `versions.env` documents the one-line procedure; `build.sh` passes every NAME; the attended bump proved a one-line change |
| IMG-07 | 04, 09 | Maven, npm and uv caches live in `state/` and survive recreate | SATISFIED | ENV and `~/.m2` link in `base/Dockerfile`; H-23 on the Mac (junit jar survives) |
| TOOL-01 | 02, 08, 09 | Claude Code at the pin, self-update off, no stray copy in `~/.local` | SATISFIED | `claude/Dockerfile`; H-13 and H-25 on the Mac |
| TOOL-02 | 02, 05, 06, 09 | GSD only from `@opengsd/gsd-core`, synced at every start, image wins, login and history untouched | SATISFIED | `05-gsd`; H-16; the attended bump |
| TOOL-03 | 02, 05, 06, 09 | Start needs no network, no `npx` or `@latest` | SATISFIED | `05-gsd` and H-17 (`--network none`) |
| USE-01 | 02, 07, 09 | `ccusage` shows this project's real usage | SATISFIED | `claude/Dockerfile`; H-24 on the Mac |

### Code Review Disposition

`02-REVIEW-DISPOSITION.md` has one row per finding in `02-REVIEW.md`. CR-01, WR-01, WR-02, WR-03, WR-07 and IN-01 to IN-07 are fixed (commits recorded). WR-05 and WR-06 are accepted and recorded in `02-PINS.md`. WR-04 is deferred to Phase 7 ("Start readiness", which exists in the roadmap with this exact TODO), and the user-facing sentence in `SANDBOX.md` was corrected so it now says `up` returns before the start hooks finish. The phase criteria do not depend on `up --wait` meaning ready: the host harness waits for the hooks itself, and the deferral matches a scheduled phase, so it is not a gap here.

### Anti-Patterns Found

None. A scan for `TBD`, `FIXME` and `XXX` across every non-planning file changed since the merge base with `origin/main` found no marker. No stubs, placeholder returns, or hardcoded empty data in the phase's code.

### Human Verification Required

None. Every runtime-dependent criterion is covered by a recorded Mac result (full runs, the attended bump, and the user's confirmation that `claude --continue` resumed the earlier session).

### Advisory Notes (not gaps)

- `ROADMAP.md` still shows `- [ ] **Phase 2: ...**` in the phase list although the section header reads 9/9 plans executed. The orchestrator should tick it when it commits this verification.
- Accepted residual risk, recorded in `02-PINS.md` and the review disposition: toolchain checksums share an origin with their tarballs (WR-05), and npm transitive dependencies float at build time (WR-06). Neither contradicts a Phase 2 success criterion.
- `clean.sh` (commit `26fd13e`) was added after the first Mac run and only changed in the review round; it is outside the Phase 2 requirements and was exercised only by the Linux suites.

## Gaps Summary

No gaps. All five roadmap success criteria hold in the code on HEAD, each is backed by a named host check that is wired into the runner, and the recorded Mac results (25 of 25 twice, plus the attended GSD bump) cover the behavior that cannot run in this sandbox. All eight requirement IDs are accounted for and satisfied.

---

_Verified: 2026-10-13_
_Verifier: Claude (gsd-verifier)_
