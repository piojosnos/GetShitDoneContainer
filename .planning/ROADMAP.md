# Roadmap: GSD Agent Sandbox Containers

## Milestones

- ✅ **v1.0 Two-mount sandboxes**: Phases 1 to 5.2 (shipped 2026-11-12, tag `v1.0`)
- 🚧 **v2.0 Simple tooling**: Phases 6 to 11 (in progress; decisions in `.planning/research/v2-simple-tooling-decisions.md`)

## Phases

<details>
<summary>✅ v1.0 Two-mount sandboxes (Phases 1 to 5.2): SHIPPED 2026-11-12</summary>

- [x] Phase 1: Two-Mount Claude Sandbox (4/4 plans), completed 2026-10-04
- [x] Phase 1.1: Automated host tests (4/4 plans), completed 2026-10-04
- [x] Phase 1.2: Best-practices bundle baked into the image (stopgap) (6/6 plans), completed 2026-10-05
- [x] Phase 1.3: Shell script layout (6/6 plans), completed 2026-10-05
- [x] Phase 1.4: Test suite refactor (8/8 plans), completed 2026-10-06
- [x] Phase 1.5: Host test fixes (16/16 plans), completed 2026-10-08
- [x] Phase 2: Pinned Toolchain, GSD, and ccusage (9/9 plans), completed 2026-10-13
- [x] Phase 2.1: Shell diet (11/11 plans), completed 2026-10-16
- [x] Phase 2.2: Best-practices from git, editable from any sandbox (8/8 plans), completed 2026-10-26
- [x] Phase 3: Remembered Sandboxes and One-Command Upgrade (4/4 plans), completed 2026-11-07
- [x] Phase 4: Jump-In and Sandbox Housekeeping (5/5 plans), completed 2026-11-08
- [x] Phase 5: Migration, Docs, and Old-Layout Retirement (5/5 plans), completed 2026-11-08
- [x] Phase 5.2: Trust a company root certificate (3/3 plans), completed 2026-11-11

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

### 🚧 v2.0 Simple tooling (in progress)

**Milestone Goal:** Make the tests, and the tooling they test, simple: tests check our setup with real Docker and simple proxies, not other people's software.

Each phase depends on the one before. Docker does not run in the dev sandbox, so every criterion that needs Docker is proven by `./host-test.sh` on the Mac.

- [ ] **Phase 6: Test diet**: the tests check only our setup, nothing waits for a person, and the guard self-test and every stand-in docker are gone
- [ ] **Phase 7: Separate test images**: a test run builds and checks its own image tags and never replaces the images the sandboxes run
- [ ] **Phase 8: In-image self-check**: `sbx-selfcheck` in the image checks the sandbox, replaces most host probes and doubles as the doctor
- [ ] **Phase 9: sbx-init replaces the start hooks**: the user runs `sbx-init` to sync GSD and link the bundle; a container start runs no hooks
- [ ] **Phase 10: Host side to Python**: the Mac commands and host tests are Python run through `uv`, with one JSON registry file per sandbox
- [ ] **Phase 11: CI widened**: GitHub runs the guard, builds the test images and runs the Linux-runnable checks on every PR push

## Phase Details

### Phase 6: Test diet

**Goal**: The test suite checks only our own setup and runs with nobody at the keyboard. The manual helpers, the checks of Claude, GSD, Docker and Maven Central behaviour, the guard self-test and every stand-in docker are deleted, and simple proxies cover what the helpers used to prove. Deletions only, no rewrite.
**Depends on**: Nothing in v2.0 (builds on v1.0 at tag `v1.0`)
**Requirements**: DIET-01, DIET-02, DIET-03, DIET-04, DIET-05
**Success Criteria** (what must be TRUE):
  1. `tests/host/manual/`, `tests/host/support/fake-claude-api.js`, `tests/selftest/guard/`, `tests/selftest/entrypoint/start-library.sh` and both stand-in `docker` scripts (the scripted fake and the fence) are gone; the sbx self-test refusal cases run with `DOCKER_HOST` pointing nowhere.
  2. No host check drives Claude or checks Claude, GSD, Docker or Maven Central behaviour: H-02, H-18, H-21 and H-24 are gone, H-00 is one preflight line in `host-test.sh`, H-11 is part of H-28, and H-13, H-15, H-16 and H-23 keep only the parts that check our setup.
  3. A host check plants a fake credentials file and a fake session file, and both are still there after a recreate and after `sbx-upgrade`; the same run shows `DISABLE_UPDATES` set, the managed settings present and the bundle links resolving.
  4. The guard asserts the managed deny entries and the one-FROM rule, and no longer carries the `sbx-rm` source-line rule or the three start rules H-20 covers.
  5. On the Mac, `./host-test.sh` runs from start to end without asking anything and passes; in the dev sandbox, the guard and the remaining self-tests pass.

**Plans**: 6 plans

Plans:
**Wave 1**
- [ ] 06-01-PLAN.md: sbx self-test with no stand-in docker; refusal cases run with `DOCKER_HOST` pointing nowhere (wave 1)
- [ ] 06-03-PLAN.md: `tests/host/lib-login.sh`; H-09 and H-29 plant and check fake credentials and session files (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*
- [ ] 06-02-PLAN.md: guard gains the deny-entry and one-FROM rules, drops three start rules and the `sbx-rm` pin; guard self-test, `start-library.sh` and the entrypoint name cases go (wave 2)

**Wave 3** *(blocked on Wave 2 completion)*
- [ ] 06-04-PLAN.md: H-00 becomes a preflight; H-02, H-18, H-21, H-24 go; H-11 folds into H-28; H-13, H-15, H-16, H-23 trimmed (wave 3)

**Wave 4** *(blocked on Wave 3 completion)*
- [ ] 06-05-PLAN.md: `tests/host/manual/` and every pointer to it go (wave 4)

**Wave 5** *(blocked on Wave 4 completion)*
- [ ] 06-06-PLAN.md: dev-sandbox phase gate, then the Mac run of `./host-test.sh` (wave 5, checkpoint)

### Phase 7: Separate test images

**Goal**: A test run builds and checks its own images, so it never replaces the `sbx-base:local` and `sbx-claude:local` images the user's sandboxes run.
**Depends on**: Phase 6
**Requirements**: IMG-01, IMG-02
**Success Criteria** (what must be TRUE):
  1. `./host-test.sh` builds its own test image tags and runs every host check against them; the log names the test tags, and no host check names a `:local` tag.
  2. On the Mac, the image IDs of `sbx-base:local` and `sbx-claude:local` are the same before and after a full `./host-test.sh` run.
  3. `build.sh`, `sbx-upgrade` and the user's sandboxes still build and run the `:local` tags; only a test run uses the test tags.

**Plans**: TBD

### Phase 8: In-image self-check

**Goal**: One command inside the image tells whether a sandbox is set up right, and the host run asks it instead of probing piece by piece. It doubles as the sandbox doctor: each failure comes with its fix.
**Depends on**: Phase 7
**Requirements**: CHECK-01, CHECK-02, CHECK-03, CHECK-04
**Success Criteria** (what must be TRUE):
  1. `sbx-selfcheck` prints one PASS, FAIL or SKIP line per named check; in a plain container of the image with no sandbox mounts, the checks that need a live sandbox print SKIP, not FAIL.
  2. In `./host-test.sh` on the Mac, one host check runs `sbx-selfcheck` with `docker exec` and fails on any FAIL line or on a check count other than the expected one; the probes it absorbs (H-01, H-04, H-05 owners, H-06, H-12 pin part, H-13 env, H-14, H-15 links, H-22, H-25 record, H-30) are deleted.
  3. `./host-test.sh` makes a throwaway root certificate with `openssl`, builds it into the test base image, and the self-check finds it in the system bundle and in Java `cacerts`; no certificate is committed.
  4. Each FAIL line carries a fix hint, with the Mac command when the fix is on the Mac, and a skill shipped in the image runs the self-check and explains the results in plain words.

**Plans**: TBD

### Phase 9: sbx-init replaces the start hooks

**Goal**: A container start only keeps the container alive. The user runs `sbx-init` to sync GSD and link the bundle and sees each step's result, so no hook, poll or wait sits between `up` and a usable shell.
**Depends on**: Phase 8
**Requirements**: INIT-01, INIT-02, INIT-03, INIT-04, INIT-05, INIT-06
**Success Criteria** (what must be TRUE):
  1. In a fresh sandbox, `sbx-init` syncs GSD and links the bundle and prints each step with OK or FAIL; a second run when all is done is a quick no-op, and a run started while another holds the lock stops without touching anything.
  2. A container start runs no hooks: the entrypoint only keeps the container alive, and the start-hook runner, `start.d/`, the readiness poll, their guard rules and most of the entrypoint self-test are gone.
  3. `sbx-claude` in a sandbox where init has not run prints a warning and starts Claude at once; it neither waits nor runs init itself.
  4. A user skill with the same name as a bundle skill is still there after `sbx-init`, and the bundle links are swapped in atomically, so an interrupted run leaves the old links or the new ones, never a mix.
  5. After `sbx-init` on the Mac, every file in `state/claude` is owned by `sandbox`, not root, and `./host-test.sh` passes.

**Plans**: TBD

### Phase 10: Host side to Python

**Goal**: Every Mac command and its tests are short Python run through `uv`, with one JSON registry file per sandbox. The command names stay, and the bash host scripts, the bash host tests and the last of the fake docker are gone.
**Depends on**: Phase 9
**Requirements**: HOST-01, HOST-02, HOST-03, HOST-04, HOST-05
**Success Criteria** (what must be TRUE):
  1. On a Mac with only `brew install uv` added, every `bin/sbx-*` command, `build.sh` and `./host-test.sh` run under the same names as before, as Python run through `uv`.
  2. `sbx-add` writes `~/.config/sbx/sandboxes/NAME.json` with `path` and `agent`, and every other command reads the sandbox from that file.
  3. `sbx-add` refuses a folder that is, holds or sits inside another sandbox's folder, also when it is given through a symlink or a `..` path, because both paths are resolved before they are compared.
  4. On the Mac, the pytest suite runs one persistence group (planted files survive one `sbx-upgrade`), one refusal group and smoke tests for add, start, stop, shell, list and rm; a failing group stops at its first failure and names the step.
  5. No bash host script, bash host test or fake docker is left in the repo, and `./host-test.sh` passes on the Mac.

**Plans**: TBD

### Phase 11: CI widened

**Goal**: GitHub runs every check that does not need the Mac on each PR push and shows the result on the PR. The Mac is left for what only Docker Desktop shows.
**Depends on**: Phase 10
**Requirements**: CI-01, CI-02
**Success Criteria** (what must be TRUE):
  1. Every push to a PR runs the guard on GitHub, and the PR shows it as a check; breaking a guard rule on a PR branch turns the check red, and fixing it turns it green.
  2. On GitHub, the same PR push builds the test images and runs the self-check and the Linux-runnable host checks against them, and the PR shows the result.
  3. Nothing CI runs touches the Mac or a sandbox: there is no git hook, and nothing the agent can edit is executed by the Mac.
  4. Each check CI runs still works the same way by hand, and `./host-test.sh` on the Mac still passes.

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 6 → 7 → 8 → 9 → 10 → 11

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 6. Test diet | v2.0 | 0/TBD | Not started | - |
| 7. Separate test images | v2.0 | 0/TBD | Not started | - |
| 8. In-image self-check | v2.0 | 0/TBD | Not started | - |
| 9. sbx-init replaces the start hooks | v2.0 | 0/TBD | Not started | - |
| 10. Host side to Python | v2.0 | 0/TBD | Not started | - |
| 11. CI widened | v2.0 | 0/TBD | Not started | - |

## Backlog

### Phase 999.3: More tools in the image (BACKLOG)

**Goal:** The image grows the tools real projects ask for, each pinned in `versions.env` like the rest, so an agent can build in the sandbox what today only builds on the Mac.
**Source phase:** 05 (the RadioPractice migration)
**Deferred at:** 2026-11-08
**First request:** audio for RadioPractice. Its MP3s need `ffmpeg` and Piper (`pip install piper-tts`). The project's `.venv` is the Mac's and does not run in the container, so Piper needs its own Python environment there.
**Options:**
- [ ] Bake `ffmpeg` and `piper-tts` into the image, pinned; Piper in its own venv under the image home so it never clashes with a project's `.venv`.
- [ ] Keep `sbx-claude` small and add an opt-in tool layer (a second image or a build option) for heavy or project-specific tools.
- [ ] Gather other missing tools before planning, so one phase covers them together.
