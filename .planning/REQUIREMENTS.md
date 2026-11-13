# Requirements: GSD Agent Sandbox Containers

**Defined:** 2026-11-12
**Core Value:** Rebuilding the image must reliably deliver new or updated tools into a project sandbox without losing the agent's login, settings, or history, and without the host mount hiding anything the image provides.

## v2.0 Requirements

Milestone v2.0 Simple tooling. Decisions behind them: `.planning/research/v2-simple-tooling-decisions.md`.

### Test diet

- [x] **DIET-01**: No test needs a person at the keyboard: `tests/host/manual/` and every interactive helper are gone.
- [x] **DIET-02**: No test drives Claude or checks Claude, GSD, Docker or Maven Central behaviour: H-18, `fake-claude-api.js`, H-21, H-24, H-02 and those parts of H-13, H-15, H-16 and H-23 are gone; H-00 becomes one preflight line in `host-test.sh`; H-11 merges into H-28.
- [ ] **DIET-03**: Proxies replace the manual helpers: a planted fake credentials file and a fake session file survive recreate and `sbx-upgrade`; `DISABLE_UPDATES` is set; managed settings are present; bundle links resolve.
- [ ] **DIET-04**: Guard rules assert the managed deny entries and the one-FROM rule; the guard self-test, the `sbx-rm` source-line rule and the three start rules H-20 covers are gone.
- [ ] **DIET-05**: No stand-in `docker` is left: the scripted fake docker, the 7-line fence and the self-test cases that need Docker to answer are gone, and the refusal cases run with `DOCKER_HOST` pointing nowhere; `start-library.sh` and the name-rule cases of the entrypoint self-test are gone.

### Test images

- [ ] **IMG-01**: `./host-test.sh` builds its own test image tags and runs every host check against them.
- [ ] **IMG-02**: A test run never replaces `sbx-base:local` or `sbx-claude:local`.

### Self-check

- [ ] **CHECK-01**: `sbx-selfcheck` (Python, in the image) prints one PASS, FAIL or SKIP line per named check; a check that needs a live sandbox prints SKIP outside one.
- [ ] **CHECK-02**: One host check runs `sbx-selfcheck` with `docker exec` and asserts no FAIL and the expected check count; the host probes it absorbs (H-01, H-04, H-05 owners, H-06, H-12 pin part, H-13 env, H-14, H-15 links, H-22, H-25 record, H-30) are deleted.
- [ ] **CHECK-03**: The root certificate is checked automatically: a throwaway `openssl` certificate is built into the test base image and the self-check finds it in the system bundle and Java `cacerts`.
- [ ] **CHECK-04**: The self-check doubles as the doctor: each FAIL prints a fix hint (with the Mac command where one is needed), and a thin skill shipped in the image runs it and explains the results.

### sbx-init

- [ ] **INIT-01**: User runs `sbx-init` (Python, in the image); it syncs GSD and links the bundle, printing each step with OK or FAIL.
- [ ] **INIT-02**: A rerun when done is a quick no-op; a lock file stops an overlapping second run.
- [ ] **INIT-03**: A container start runs no hooks: the entrypoint only keeps the container alive; the start-hook runner, `start.d/`, the readiness poll, their guard rules and most of the entrypoint self-test are gone.
- [ ] **INIT-04**: `sbx-claude` warns, without waiting or running anything, when init has not run.
- [ ] **INIT-05**: Init never deletes a user skill that shares a bundle skill's name, and swaps the bundle links in atomically.
- [ ] **INIT-06**: After init, the files in `state/claude` are owned by `sandbox`, not root.

### Host side in Python

- [ ] **HOST-01**: `bin/sbx-*`, `build.sh` and `host-test.sh` are Python run through `uv` (`brew install uv` is the only Mac prerequisite); command names stay.
- [ ] **HOST-02**: The registry is one JSON file per sandbox, `~/.config/sbx/sandboxes/NAME.json`, with `path` and `agent`.
- [ ] **HOST-03**: The folder-overlap check resolves both paths and compares them.
- [ ] **HOST-04**: A pytest suite runs one persistence group (planted files survive one `sbx-upgrade`), one refusal group, and smoke tests for add, start, stop, shell, list and rm; a group stops at its first failure and names the step.
- [ ] **HOST-05**: The bash host scripts, the bash host tests and the last of the fake docker are gone.

### CI

- [ ] **CI-01**: Every push to a PR runs the guard on GitHub and shows it as a check on the PR.
- [ ] **CI-02**: GitHub builds the test images and runs the self-check and the Linux-runnable host checks; nothing runs on the Mac or in a sandbox.

## Future Requirements

Tracked, not in this roadmap.

- OpenCode image on the shared base, with `@opengsd/gsd-core`.
- More tools in the image (backlog 999.3, for example `ffmpeg` and Piper).
- `sbx-bundle-clone` error hint and option guard; `sbx-gh-login` skips when already logged in (pending todos).
- Limit what a leaked token costs in bypass mode (pending todo).

## Out of Scope

| Feature | Reason |
|---------|--------|
| The eight open Phase 5.2 review findings (WR-01 to IN-05) | Left as they are for v2.0 |
| Spike on a fixed skills path outside the Claude config folder | Revisit only if `sbx-init` proves painful |
| Baking the Claude config folder into the image | A new Claude version could write state we do not keep |
| Docker labels as the registry | A new Mac or another engine starts with no containers; the file registry copies over |
| Tests that run `claude -p` | Needs a stored credential, costs tokens, and checks Claude, not us |
| Migrating v1 registries and configs | Configs can be recreated |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DIET-01 | Phase 6 | Complete |
| DIET-02 | Phase 6 | Complete |
| DIET-03 | Phase 6 | Pending |
| DIET-04 | Phase 6 | Pending |
| DIET-05 | Phase 6 | Pending |
| IMG-01 | Phase 7 | Pending |
| IMG-02 | Phase 7 | Pending |
| CHECK-01 | Phase 8 | Pending |
| CHECK-02 | Phase 8 | Pending |
| CHECK-03 | Phase 8 | Pending |
| CHECK-04 | Phase 8 | Pending |
| INIT-01 | Phase 9 | Pending |
| INIT-02 | Phase 9 | Pending |
| INIT-03 | Phase 9 | Pending |
| INIT-04 | Phase 9 | Pending |
| INIT-05 | Phase 9 | Pending |
| INIT-06 | Phase 9 | Pending |
| HOST-01 | Phase 10 | Pending |
| HOST-02 | Phase 10 | Pending |
| HOST-03 | Phase 10 | Pending |
| HOST-04 | Phase 10 | Pending |
| HOST-05 | Phase 10 | Pending |
| CI-01 | Phase 11 | Pending |
| CI-02 | Phase 11 | Pending |

**Coverage:**
- v2.0 requirements: 24 total
- Mapped to phases: 24
- Unmapped: 0

---
*Requirements defined: 2026-11-12*
*Last updated: 2026-11-12 after the v2.0 roadmap (phases 6 to 11)*
