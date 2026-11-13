# v2.0 Simple tooling: decisions from discussion (2026-11-11 and 2026-11-12)

Input for `/gsd-new-milestone`. The v1.0 tooling is tagged `v1.0` (origin/main at 8bc464e) and stays in daily use on the Mac while v2 is built on `main`. Little migration: configs can be recreated.

## Goal

Make the tests, and the tooling they test, simple. Today about 10.9k lines of test shell guard about 2.1k lines of product shell. Simplicity wins over some safety; nothing interactive; tests check our setup, not Claude, GSD or Docker behaviour.

## Principles

- Anything with logic is Python, on the host and in the image. Shell stays only for thin `exec` wrappers and Dockerfile `RUN` lines. On the host, Python runs through `uv` (`#!/usr/bin/env -S uv run --script`); the only Mac prerequisite is `brew install uv`. In the image, the image's own `python3`.
- Config and state files are JSON.
- No fake docker. The fake docker in `tests/selftest/sbx/` is quasi deprecated: never extend it; it goes.
- Tests do not drive Claude (no `claude -p`: it needs a stored credential, costs tokens and checks Claude, not us). Proxies instead: a file, link, owner or env var is in place.
- Host checks are grouped to cut restarts and rebuilds. A group stops at its first failure and names the step.

## Phases, in order

1. **Test diet.** Deletions only, no rewrite. Drop: `tests/host/manual/` (all helpers), H-00 (one preflight line in `host-test.sh` instead), H-02 layer check (the one-FROM rule goes to the guard), H-11 (into H-28), H-18 and `fake-claude-api.js`, H-21, H-24, the Claude, GSD and Maven Central parts of H-13, H-15, H-16 and H-23, `tests/selftest/guard/`, the guard rule pinning `sbx-rm` source lines and the three start rules H-20 covers, the scripted fake docker with the self-test groups that need it (the 7-line fence goes too, decided in the Phase 6 discussion on 2026-11-13: refusal cases run with `DOCKER_HOST` pointing nowhere), `start-library.sh` and the name-rule cases of the entrypoint self-test. Proxies for the manual helpers: a planted fake credentials file and a fake session file survive recreate and `sbx-upgrade`; `DISABLE_UPDATES` set; managed settings present; deny entries asserted by a guard rule; bundle links resolve.
2. **Separate test images from prod images** (was v1 Phase 5.3). `./host-test.sh` builds and tests its own image tags and never replaces `sbx-base:local` and `sbx-claude:local`.
3. **In-image self-check** (absorbs v1 Phases 5.1 sandbox doctor and 5.4 extra root certificate test). `sbx-selfcheck` in the image, Python: each check a small function returning PASS, FAIL or SKIP with a name and metadata, one line each, easy to grep. A check that needs a live sandbox prints SKIP outside one. One host check runs it with `docker exec` and asserts no FAIL and the expected count. Absorbs H-01, H-04, H-05 owners, H-06, H-12 pin part, H-13 env, H-14, H-15 links, H-22, H-25 record, H-30, and the root certificate check (throwaway cert from `openssl`, test image, cert in the system bundle and Java `cacerts`). The doctor is this runner plus a fix hint per FAIL and a thin skill.
4. **`sbx-init` replaces the start hooks and the poller.** User-triggered only: `sbx-init` (Python, in the image) syncs GSD and links the bundle, printing each step with OK or FAIL; quick no-op when done; a lock file blocks a second run (no polling). The entrypoint only keeps the container alive. `sbx-claude` warns (runs nothing) when init has not run, as it already warns when no bundle is linked. Deletes the start-hook runner, `start.d/`, the readiness poll, the hook guard rules, most of the entrypoint self-test, and v1 Phase 7 (start readiness). Rejected: baking the Claude config folder into the image (a new Claude version could write state we do not keep).
5. **Host side to Python.** `bin/sbx-*`, `build.sh`, `host-test.sh` and the host tests. Registry: one JSON file per sandbox, `~/.config/sbx/sandboxes/NAME.json` with `path` and `agent` (room for opencode or cursor). Simpler folder-overlap check (resolve and compare). Command names stay. pytest suite with grouped checks: one persistence group (planted files survive one `sbx-upgrade`), one refusal group, smoke tests for add, start, stop, shell, list, rm. Rejected: Docker labels as the registry (a new Mac or another engine starts with no containers; the file registry copies over).
6. **CI widened** (was v1 Phase 6). GitHub builds the test images, runs the guard, the self-check and the Linux-runnable host checks. The Mac is left for Docker Desktop specifics.

## Out of scope for v2

- The eight open v1 Phase 5.2 review findings (WR-01 to IN-05).
- A spike on a fixed path where Claude reads skills outside its config folder; revisit only if `sbx-init` proves painful.

## Appendix: unfinished v1.0 phases, moved here verbatim (2026-11-12)

Removed from the v1.0 roadmap before archiving. Mapping into v2: 5.3 is v2 phase 2; 5.4 and 5.1 fold into v2 phase 3 (self-check); 7 is dropped by v2 phase 4 (`sbx-init`); 6 is v2 phase 6.

#### Phase 05.3: Separate test images from prod images (INSERTED)

**Goal:** `./host-test.sh` builds and tests its own images, so a test run never replaces the `sbx-base:local` and `sbx-claude:local` images that the user's sandboxes run. Today `tests/host/lib-docker.sh` runs plain `build.sh`, and the host checks, `compose.yml` and `bin/sbx-lib.sh` all name the `:local` tags. Runs before 5.4.
**Requirements**: TBD
**Depends on:** Phase 5.2
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 05.3 to break down)

#### Phase 05.4: Tests for the extra root certificate (INSERTED)

**Goal:** The extra root certificate feature from Phase 5.2 (`SBX_CA_CERT`) gets one simple, fully automatic sanity check, so a later change that breaks it fails `./host-test.sh` instead of a build on the work Mac. Runs before 5.1.
**Requirements**: TBD
**Depends on:** Phase 5.3
**Plans:** 0 plans

**Settled in discussion (2026-11-11):**
- One host check (H-34), run by `./host-test.sh`, nothing interactive.
- A throwaway root certificate made with `openssl` during the run; nothing committed.
- It builds the test base image (from Phase 5.3) with that certificate and checks the build passes and the certificate is in the system bundle and in Java's `cacerts`. No HTTPS test server, no per-tool checks.
- No test of `build.sh` itself and no fake `docker`. The fake `docker` in `tests/selftest/sbx/` is quasi deprecated and must not be extended; `tests/README.md` says so.
- The eight open 5.2 review findings stay out of scope.

Plans:
- [ ] TBD (run /gsd-plan-phase 05.4 to break down)

#### Phase 05.1: Sandbox doctor (INSERTED)

**Goal:** One command inside a sandbox tells you whether it is healthy after a migration or an upgrade: a `sbx-doctor` script prints one OK/WARN/FAIL line per check with the fix, and a thin `sbx-doctor` skill runs it and explains the results in plain words, including any command to run on the Mac.
**Requirements**: TBD
**Depends on:** Phase 5
**Plans:** 0 plans

**TODO** (from the Phase 5 migrations, 2026-11-08):
- [ ] Script `claude/bin/sbx-doctor`, shipped in the image next to `sbx-claude`, with a self-test. Deterministic checks; the skill only runs and explains it.
- [ ] Skill shipped with the image, not the best-practices bundle: the checks follow the sandbox layout, so they version and test with this repo.
- [ ] Checks to start with: files owned by uid 1001 or root (the root `state/claude/sessions` seen once), private files `sandbox` cannot read, `git status` mode changes (fix: `sbx-fix-modes NAME` on the Mac), Claude login present, gh logged in, git identity, the gh credential helper path, bundle linked, GSD installed, tool versions, `state/` writable, stale `@AGENTS.md` / `@code-conventions.md` lines in `state/claude/CLAUDE.md`.
- [ ] Limit: inside the container it cannot see Mac-side modes; it reports the symptom and prints the Mac command.
- [ ] The GSD sync leaves 313 files owned by root in `state/claude` at every start (Docker Desktop lets `copyFileSync` keep the root owner). Harmless; decide here whether the doctor reports them as expected or `05-gsd` gives them back to `sandbox`. See `.planning/todos/pending/2026-11-08-gsd-sync-leaves-root-owned-files.md`.
- [ ] Once it exists, add it as the last step of `MIGRATION.md` "Check" and to the README.
- [ ] Fold in the two wording nits from the phase 5 code review (`tests/guard/isolation.sh:28` comment, `tests/README.md:25` guard row). See `.planning/todos/pending/2026-11-08-retirement-review-nits.md`.

Plans:
- [ ] TBD (run /gsd-plan-phase 05.1 to break down)

#### Phase 6: Automated checks (CI)

**Goal**: The repo's automated checks run on their own. GitHub runs `bash tests/guard/run-all.sh` on every push to a PR and shows the result as a check on the PR, without running anything on the Mac or in a sandbox container.
**Mode:** mvp
**Depends on**: Phase 5
**Requirements**: CI-01
**Success Criteria** (what must be TRUE):
  1. Every push to a PR runs `bash tests/guard/run-all.sh` on GitHub's machines, and the PR shows it as a passing or failing check.
  2. Breaking a guard rule on a PR branch turns the check red; fixing it turns it green.
  3. Nothing runs on the Mac or in a sandbox container: no git hook, nothing the agent could edit that the Mac executes.
  4. Running `bash tests/guard/run-all.sh` by hand still works the same way.
  5. Candidates to add when planned: shellcheck for the scripts, hadolint for the Dockerfiles.

**Plans**: TBD

#### Phase 7: Start readiness

**Goal:** `docker compose up -d --wait` returns only when the sandbox is ready: every start hook has finished, and a failing hook fails `up`.
**Requirements**: TBD
**Depends on:** Phase 6
**Plans:** 0 plans

**TODO** (from the Phase 2 code review, finding WR-04):
- [ ] `up --wait` returns before the start hooks finish, so a shell opened during the GSD sync can see a half-synced `state/claude`, and a failing hook does not fail `up`. Candidate fix: a compose healthcheck that turns healthy only once the start hooks are done (the host tests already poll `pgrep -x sleep` for this), so `--wait` means ready. Then drop the host tests' own wait in `compose_up`.

Plans:
- [ ] TBD (run /gsd-plan-phase 7 to break down)
