# Roadmap: GSD Agent Sandbox Containers

## Milestones

- ✅ **v1.0 Two-mount sandboxes**: Phases 1 to 5.2 (shipped 2026-11-12, tag `v1.0`)
- 🚧 **v2.0 Simple tooling**: Phases 6 and up (planning; see `.planning/research/v2-simple-tooling-decisions.md`)

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

### 🚧 v2.0 Simple tooling (planning)

Phases are added by `/gsd-new-milestone`.

## Backlog

### Phase 999.2: Retire the fake docker (BACKLOG)

**Goal:** Run the host checks against real Docker from the agent side, so `tests/selftest/host/support/fake-docker` and its self-test can be deleted. The fake is too complex to own long term.
**Source phase:** 01.4
**Deferred at:** 2026-10-06
**Promoted:** 2026-10-13 into Phase 2.1 (shell diet), success criterion 2
**Options:**
- [ ] Docker-in-Docker in the dev sandbox, accepting the isolation trade-off and changing only that container.
- [ ] GitHub Actions on each PR, which ties in with Phase 6.

### Phase 999.3: More tools in the image (BACKLOG)

**Goal:** The image grows the tools real projects ask for, each pinned in `versions.env` like the rest, so an agent can build in the sandbox what today only builds on the Mac.
**Source phase:** 05 (the RadioPractice migration)
**Deferred at:** 2026-11-08
**First request:** audio for RadioPractice. Its MP3s need `ffmpeg` and Piper (`pip install piper-tts`). The project's `.venv` is the Mac's and does not run in the container, so Piper needs its own Python environment there.
**Options:**
- [ ] Bake `ffmpeg` and `piper-tts` into the image, pinned; Piper in its own venv under the image home so it never clashes with a project's `.venv`.
- [ ] Keep `sbx-claude` small and add an opt-in tool layer (a second image or a build option) for heavy or project-specific tools.
- [ ] Gather other missing tools before planning, so one phase covers them together.
