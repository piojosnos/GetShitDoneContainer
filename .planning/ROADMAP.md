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

- [x] **Phase 6: Test diet**: the tests check only our setup, nothing waits for a person, and the guard self-test and every stand-in docker are gone (completed 2026-11-13)
- [x] **Phase 06.1: Cursor agent image** (INSERTED): a separate Cursor image; a sandbox picks Claude or Cursor when it is added (completed 2026-11-14)
- [x] **Phase 7: Separate test images**: a test run builds and checks its own image tags and never replaces the images the sandboxes run (completed 2026-11-14)
- [x] **Phase 8: In-image self-check**: `sbx-selfcheck` in the image checks the sandbox, replaces most host probes and doubles as the doctor (completed 2026-11-15)
- [ ] **Phase 9: sbx-init replaces the start hooks**: the user runs `sbx-init` to sync GSD and link the bundle; a container start runs no hooks
- [ ] **Phase 09.1: Align vocabulary** (INSERTED): code, tests and docs use one set of terms; best-practices, never bundle
- [ ] **Phase 10: Host side to Python**: the Mac commands and host tests are Python run through `uv`, with one JSON registry file per sandbox
- [ ] **Phase 10.1: Full skills and best-practices support in Cursor** (INSERTED): the bundle's rules and skills work in Cursor as they do in Claude
- [ ] **Phase 10.2: OpenCode agent image** (INSERTED): a third agent image with full skills and best-practices support; may split into more phases
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

**Plans**: 6/6 plans complete

Plans:
**Wave 1**
- [x] 06-01-PLAN.md: sbx self-test with no stand-in docker; refusal cases run with `DOCKER_HOST` pointing nowhere (wave 1)
- [x] 06-03-PLAN.md: `tests/host/lib-login.sh`; H-09 and H-29 plant and check fake credentials and session files (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 06-02-PLAN.md: guard gains the deny-entry and one-FROM rules, drops three start rules and the `sbx-rm` pin; guard self-test, `start-library.sh` and the entrypoint name cases go (wave 2)

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 06-04-PLAN.md: H-00 becomes a preflight; H-02, H-18, H-21, H-24 go; H-11 folds into H-28; H-13, H-15, H-16, H-23 trimmed (wave 3)

**Wave 4** *(blocked on Wave 3 completion)*
- [x] 06-05-PLAN.md: `tests/host/manual/` and every pointer to it go (wave 4)

**Wave 5** *(blocked on Wave 4 completion)*
- [x] 06-06-PLAN.md: dev-sandbox phase gate, then the Mac run of `./host-test.sh` (wave 5, checkpoint)

### Phase 06.1: Cursor agent image (INSERTED)

**Goal**: A sandbox can run Cursor instead of Claude, from its own image, so work can be spread over both subscriptions. Scrappy: few new tests; a login and a short run on the Mac are the gate.
**Depends on**: Phase 6
**Requirements**: TBD
**Success Criteria** (what must be TRUE):
  1. `build.sh` builds `sbx-cursor:local` from `cursor/Dockerfile` (FROM the base image) next to `sbx-claude:local`; the Cursor CLI is pinned in `versions.env` and installed by download, never piped to a shell. GSD, `sbx-gh-login` and `sbx-bundle-clone` move to the base image, so both agent images share them.
  2. `sbx-add NAME HOST_PATH [claude|cursor]` records the sandbox's agent (`claude` by default), Compose starts the matching image, and `sbx-shell` opens bash in both, where the user starts `claude` or `cursor-agent`.
  3. The Cursor login and settings live under `state/`, so they survive a recreate and `sbx-upgrade`.
  4. GSD is installed for Cursor in a Cursor sandbox, and existing Claude sandboxes work as before.
  5. On the Mac, a Cursor sandbox logs in, answers a prompt in its workspace, and `./host-test.sh` still passes.

**Plans**: 5/5 plans complete

Plans:
**Wave 1**
- [x] 06.1-01-PLAN.md: tracer; `SBX_AGENT=cursor` starts `sbx-cursor:local` built from the pinned, checksummed Cursor package; `sbx-add` takes `[claude|cursor]`; login under `state/cursor` (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 06.1-02-PLAN.md: GSD, `sbx-gh-login`, `sbx-bundle-clone` and the shared bundle linker move to `sbx-base`; Claude works as before (wave 2)

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 06.1-03-PLAN.md: Cursor start hooks (self-update off, GSD sync, bundle skills); guard and self-tests cover them (wave 3)

**Wave 4** *(blocked on Wave 3 completion)*
- [x] 06.1-04-PLAN.md: list of bundle items that do not work in Cursor; README and test docs (wave 4)

**Wave 5** *(blocked on Wave 4 completion)*
- [x] 06.1-05-PLAN.md: dev-sandbox suites, then the Mac gate with a Cursor login and one prompt (wave 5)

### Phase 7: Separate test images

**Goal**: A test run builds and checks its own images, so it never replaces the `sbx-base:local` and `sbx-claude:local` images the user's sandboxes run.
**Depends on**: Phase 6
**Requirements**: IMG-01, IMG-02
**Success Criteria** (what must be TRUE):
  1. `./host-test.sh` builds its own test image tags and runs every host check against them; the log names the test tags, and no host check names a `:local` tag.
  2. On the Mac, the image IDs of `sbx-base:local` and `sbx-claude:local` are the same before and after a full `./host-test.sh` run.
  3. `build.sh`, `sbx-upgrade` and the user's sandboxes still build and run the `:local` tags; only a test run uses the test tags.

**Plans**: 3/3 plans complete

Plans:
**Wave 1**
- [x] 07-01-PLAN.md: tracer; `SBX_IMAGE_TAG` (`local` or `test`, anything else refused) picks the tag in `bin/sbx-lib.sh`, `compose.yml` and `build.sh`; guard rule `compose_image_follows_agent_and_tag`; dockerless self-test group `image-tag.sh` (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 07-02-PLAN.md: tracer; `./host-test.sh` and `host_init` set `SBX_IMAGE_TAG=test`; every host check, the linter stand-ins and H-03 use the test images; guard rule `host_tests_never_name_the_local_tag` (wave 2)

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 07-03-PLAN.md: docs and comments, the dev-sandbox gate, then the Mac gate with the before and after `:local` image IDs (wave 3, checkpoint)

### Phase 8: In-image self-check

**Goal**: One command inside the image tells whether a sandbox is set up right, and the host run asks it instead of probing piece by piece. It doubles as the sandbox doctor: each failure comes with its fix.
**Depends on**: Phase 7
**Requirements**: CHECK-01, CHECK-02, CHECK-03, CHECK-04
**Success Criteria** (what must be TRUE):
  1. `sbx-selfcheck` prints one PASS or FAIL line per named check: the base image ships the runner and the shared checks, and each agent image adds its own checks file to a fixed folder the runner reads; there is no SKIP.
  2. In `./host-test.sh` on the Mac, one host check runs `sbx-selfcheck` with `docker exec` in a Claude and in a Cursor test sandbox and fails on any FAIL line or on a check count other than that agent's expected one; H-01, H-04, H-05, H-13, H-14, H-15, H-22 and H-30 are deleted, and H-06, H-12 and H-25 keep only the parts that need the Mac.
  3. `./host-test.sh` makes a throwaway root certificate with `openssl`, builds it into the test base image, and the self-check finds it in the system bundle and in Java `cacerts`; no certificate is committed.
  4. Each FAIL line carries a fix hint, with the Mac command when the fix is on the Mac; no skill wraps the self-check.

**Plans**: 13/13 plans complete

Plans:
**Wave 1**
- [x] 08-01-PLAN.md: the runner (tracer): `sbx-selfcheck`, its pytest harness pinned to 9.2.0, and the image wiring (wave 1)
- [x] 08-02-PLAN.md: host check H-34 in a Claude and a Cursor test sandbox, with the reused throwaway root certificate (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 08-03-PLAN.md: shared checks for the sandbox, user, git, environment, state and image paths (wave 2)
- [x] 08-04-PLAN.md: H-01, H-04, H-05, H-13, H-14, H-15, H-22 and H-30 deleted; H-06, H-12 and H-25 slimmed; docs (wave 2)

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 08-05-PLAN.md: shared checks for the toolchain (one line per tool), the versions records and the extra root certificates (wave 3)

**Wave 4** *(blocked on Wave 3 completion)*
- [x] 08-06-PLAN.md: the Claude and Cursor checks files; check counts tied to H-34 (wave 4)

**Wave 5** *(blocked on Wave 4 completion)*
- [x] 08-07-PLAN.md: dev-sandbox phase gate, then the Mac run of `./host-test.sh` (wave 5, checkpoint)

Gap closure, from the phase verification (the `no-root-owned-state` fix line cannot work in the sandbox) and the code review:

**Wave 6** *(blocked on Wave 5 completion)*
- [x] 08-08-PLAN.md: the owner fix hint becomes a Mac command (tracer), unreadable folders are named instead of crashing, and the runner fails when no agent check ran

**Wave 7** *(blocked on Wave 6 completion)*
- [x] 08-09-PLAN.md: `tool-bash` and `tool-keytool` (counts 41, 53, 51), and H-34 runs the owner fix round trip on real Docker

**Wave 8** *(blocked on Wave 7 completion)*
- [x] 08-10-PLAN.md: the review's info findings: settings message, shape suffixes, type hints, loops instead of comprehensions

**Wave 9** *(blocked on Wave 8 completion)*
- [x] 08-11-PLAN.md: dispositions recorded, the dev-sandbox gate, the Mac run (checkpoint), then CHECK-01 to CHECK-04 marked complete

**Wave 10** *(blocked on Wave 9 completion)*
- [x] 08-12-PLAN.md: the two review warnings fixed (an unsearchable state folder and a malformed CHECK_LIST), the info findings deferred to Phase 10

**Wave 11** *(blocked on Wave 10 completion)*
- [x] 08-13-PLAN.md: the last two review findings fixed (a check that returns no CheckResult, and one failing state entry no longer marks its whole folder)

### Phase 9: sbx-init replaces the start hooks

**Goal**: A container start only keeps the container alive. The user runs `sbx-init` to sync GSD and link the bundle and sees each step's result, so no entrypoint, hook, poll or wait sits between `up` and a usable shell.
**Depends on**: Phase 8
**Requirements**: INIT-01, INIT-02, INIT-03, INIT-04, INIT-05, INIT-06
**Success Criteria** (what must be TRUE):
  1. In a fresh sandbox, `sbx-init` syncs GSD and links the bundle and prints each step with OK or FAIL; a second run gives the same result, and a run started while another holds the lock stops without touching anything.
  2. A container start runs no hooks and no entrypoint: the container only sleeps, and the entrypoint, the start-hook runner, `start.d/`, the readiness poll, their guard rules and the entrypoint self-test are gone.
  3. `sbx-claude` and `sbx-cursor` in a container where init has not run fail at once with a message to run `sbx-init`; they neither wait nor run init. `claude` and `cursor-agent` are not on a plain shell's PATH.
  4. A user skill with the same name as a bundle skill is still there after `sbx-init`, which reports the clash as a FAIL; init removes only its own links into the bundle.
  5. After `sbx-init` on the Mac, every file in `state/claude` is owned by `sandbox`, not root, and `./host-test.sh` passes.

**Plans**: 4/13 plans executed

Plans:
**Wave 1**
- [x] 09-01-PLAN.md: `sbx-init` launcher and runner (tracer), run lock, init marker and the state folders step (wave 1)
- [x] 09-08-PLAN.md: the host lib owns the sandbox name rule; the readiness poll goes (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 09-02-PLAN.md: the GSD sync step for both agents and Cursor's static channel step (wave 2)
- [x] 09-03-PLAN.md: the state-owner step and one shared root-owned scan; the self-check stops tolerating root-owned GSD files (wave 2)
- [ ] 09-04-PLAN.md: the best-practices links step that never touches a user skill, and the check without the list file (wave 2)
- [ ] 09-05-PLAN.md: self-check `init-marker`, `claude-off-path` and `cursor-off-path`; counts 55 and 53 (wave 2)
- [ ] 09-06-PLAN.md: `sbx-claude` and `sbx-cursor` refuse until init passed; `sbx-bundle-clone` runs `sbx-init`; `sbx-gh-login` precondition (wave 2)

**Wave 3** *(blocked on Wave 2 completion)*
- [ ] 09-07-PLAN.md: images without an entrypoint, `sbx-init` installed, agents in `/opt/sbx/agents/bin`, image roots, step inventory (wave 3)

**Wave 4** *(blocked on Wave 3 completion)*
- [ ] 09-09-PLAN.md: the entrypoint, start library, start hooks, bash linker and entrypoint self-test deleted; two new guard rules (wave 4)
- [ ] 09-10-PLAN.md: `compose_up` and H-34 run `sbx-init`; H-12, H-17 and H-20 go; hook waits removed from H-28, H-29 and H-31 (wave 4)

**Wave 5** *(blocked on Wave 4 completion)*
- [ ] 09-11-PLAN.md: H-27 and H-16 rewritten for the first run and the clash rule; new H-35 for ownership and the lock (wave 5)

**Wave 6** *(blocked on Wave 5 completion)*
- [ ] 09-12-PLAN.md: README, MIGRATION, ZSCALER, the memory prompt and the test docs follow the new start (wave 6)

**Wave 7** *(blocked on Wave 6 completion)*
- [ ] 09-13-PLAN.md: dev-sandbox phase gate, then the Mac run of `./host-test.sh` (wave 7, checkpoint)

### Phase 09.1: Align vocabulary across code and docs (INSERTED)

**Goal**: Code, tests and docs use one set of terms. The user's rules and skills repo is called best-practices everywhere, never bundle, and any other inconsistent names the sweep finds are fixed.
**Requirements**: TBD
**Depends on**: Phase 9

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
  6. The host tests are one shared harness run for each agent: the checks common to both agents are written once, and only a few small checks differ between Claude and Cursor.

**Plans**: TBD

### Phase 10.1: Full skills and best-practices support in Cursor (INSERTED)

**Goal:** Cursor sandboxes get the same skills and best-practices support as Claude sandboxes: the bundle's rules and skills reach Cursor in the form it reads, and the self-check proves they are there. Scope and split into one or more phases are decided at discuss time.
**Requirements**: TBD
**Depends on:** Phase 10
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-discuss-phase 10.1 to scope it)

### Phase 10.2: OpenCode agent image with full skills and best-practices support (INSERTED)

**Goal:** An OpenCode agent image next to Claude and Cursor, with the same skills and best-practices support from the start, and its own self-check files. This may become more than one phase; that is decided at discuss time.
**Requirements**: TBD
**Depends on:** Phase 10.1
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-discuss-phase 10.2 to scope it)

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
| 6. Test diet | v2.0 | 6/6 | Complete    | 2026-11-13 |
| 7. Separate test images | v2.0 | 3/3 | Complete    | 2026-11-14 |
| 8. In-image self-check | v2.0 | 13/13 | Complete    | 2026-11-15 |
| 9. sbx-init replaces the start hooks | v2.0 | 4/13 | In Progress|  |
| 10. Host side to Python | v2.0 | 0/TBD | Not started | - |
| 10.1. Cursor skills and best practices | v2.0 | 0/TBD | Not started | - |
| 10.2. OpenCode agent image | v2.0 | 0/TBD | Not started | - |
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
