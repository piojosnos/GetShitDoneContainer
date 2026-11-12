---
phase: "2"
slug: "pinned-toolchain-gsd-and-ccusage"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-10-08"
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Plain bash suites in three layers: guard (static rules), self-tests (Linux, fake docker), host checks (Mac, real Docker) |
| **Config file** | none; `tests/guard/lib.sh`, `tests/selftest/lib-expect.sh`, `tests/host/lib.sh` |
| **Quick run command** | `bash tests/guard/run-all.sh` |
| **Full suite command** | Linux: `bash tests/guard/run-all.sh && bash tests/selftest/guard/run-all.sh && bash tests/selftest/entrypoint/run-all.sh && bash tests/selftest/host/run-all.sh && bash tests/selftest/bundle/run-all.sh`; Mac: `bash tests/host/run-all.sh` |
| **Estimated runtime** | Linux ~60 seconds; Mac host run several minutes (image builds) |

---

## Sampling Rate

- **After every task commit:** Run `bash tests/guard/run-all.sh` plus the self-test group(s) for the files touched
- **After every plan wave:** Run all four self-test runners and the guard
- **Before `/gsd-verify-work`:** `bash tests/host/run-all.sh` green on the Mac (human checkpoint)
- **Max feedback latency:** 60 seconds (Linux layers)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-T1 | 01 | 1 | IMG-03, IMG-04 | T-02-02 | Every pin reaches both builds from versions.env; no ARG defaults | guard, self-test | Full Linux suite (full suite command above) | yes | ✅ green |
| 02-01-T2 | 01 | 1 | IMG-03, IMG-04 | T-02-03, T-02-04 | build.sh and the pin guard rules proven by planted violations | self-test, guard | `bash tests/selftest/host/build-wiring.sh && bash tests/selftest/guard/sandbox-rules.sh && bash tests/selftest/guard/host-rules.sh` | yes | ✅ green |
| 02-01-T3 | 01 | 1 | IMG-03, IMG-04 | T-02-01 | Docs say build with ./build.sh and how to bump a pin | guard | `bash tests/guard/docs.sh && bash tests/guard/planning-ids.sh` | yes | ✅ green |
| 02-02-T1 | 02 | 2 | IMG-03, TOOL-01, TOOL-02, USE-01 | T-02-05, T-02-06 | Every pin resolved from its authority into 02-PINS.md | manual | Pin-row loop of the plan: every NAME has a row and each image pin holds a 64-hex digest | yes | ✅ green |
| 02-02-T2 | 02 | 2 | IMG-03, TOOL-01, TOOL-02, USE-01 | T-02-07 | The user approves every pin before any plan installs it | manual | Approval loop of the plan: every row reads approved with a date | yes | ✅ green |
| 02-03-T1 | 03 | 3 | IMG-01, IMG-03 | T-02-09, T-02-10, T-02-12 | Base image from digest-pinned images; Maven checked against its sha512 | guard, host | Full Linux suite (full suite command above) | yes | ✅ green |
| 02-03-T2 | 03 | 3 | IMG-01, IMG-03 | T-02-09 | H-22: toolchain native, pinned, visible to a login shell | self-test, host | `bash tests/selftest/host/h22-toolchain-in-base.sh && bash tests/selftest/host/runner-healthy.sh && bash tests/selftest/host/runner-failures.sh && bash tests/guard/host-tests.sh` | yes | ✅ green |
| 02-04-T1 | 04 | 4 | IMG-07 | T-02-13, T-02-14, T-02-15 | Caches point into state/ from image ENV and one link | guard, host | Full Linux suite (full suite command above) | yes | ✅ green |
| 02-04-T2 | 04 | 4 | IMG-07 | T-02-15 | H-23: a file in each cache survives a recreate | self-test, host | `bash tests/selftest/host/h23-caches-survive-recreate.sh && bash tests/selftest/host/runner-healthy.sh && bash tests/guard/host-tests.sh` | yes | ✅ green |
| 02-05-T1 | 05 | 5 | TOOL-02, TOOL-03 | T-02-17, T-02-18, T-02-21 | Baked GSD synced at every start, fail closed, offline | self-test, guard | `bash tests/selftest/entrypoint/gsd-hook.sh && bash tests/guard/start.sh && bash tests/guard/planning-ids.sh` | yes | ✅ green |
| 02-05-T2 | 05 | 5 | TOOL-02, TOOL-03 | T-02-17, T-02-19 | H-17 needs an offline GSD sync and a prompt stop; H-14 covers the hook | self-test, host | `bash tests/selftest/host/h17-start-offline-and-failing-hook.sh && bash tests/selftest/host/h14-bundle-in-image.sh && bash tests/selftest/host/h16-sync-refreshes-and-spares.sh` | yes | ✅ green |
| 02-06-T1 | 06 | 6 | TOOL-02, TOOL-03 | T-02-22 | A restart restores a stale GSD and spares user files; compose_up waits for the hooks | self-test, host | `bash tests/selftest/host/units.sh && bash tests/selftest/host/h16-sync-refreshes-and-spares.sh && bash tests/selftest/host/runner-healthy.sh && bash tests/guard/host-tests.sh` | yes | ✅ green |
| 02-06-T2 | 06 | 6 | TOOL-02, TOOL-03 | T-02-23, T-02-24, T-02-25 | Attended bump helper keeps the login; GSD upgrades only by pin and rebuild | manual, guard | `bash -n tests/host/manual/h16-gsd-bump.sh && bash tests/guard/host-tests.sh && bash tests/guard/docs.sh && bash tests/guard/supply-chain.sh` | yes | ✅ green |
| 02-07-T1 | 07 | 7 | USE-01 | T-02-26 | ccusage baked at the pinned version, executable for the sandbox user | guard, host | Full Linux suite (full suite command above) | yes | ✅ green |
| 02-07-T2 | 07 | 7 | USE-01 | T-02-28 | H-24: ccusage reports a planted transcript from state/claude | self-test, host | `bash tests/selftest/host/h24-ccusage-reports-usage.sh && bash tests/selftest/host/runner-healthy.sh && bash tests/guard/host-tests.sh` | yes | ✅ green |
| 02-08-T1 | 08 | 8 | IMG-03, IMG-04, TOOL-01 | T-02-29, T-02-30, T-02-32 | H-25: images match versions.env; a build without build.sh stops naming the pin | self-test, host | `bash tests/selftest/host/h25-images-match-versions.sh && bash tests/selftest/host/runner-healthy.sh && bash tests/guard/host-tests.sh` | yes | ✅ green |
| 02-08-T2 | 08 | 8 | IMG-03, IMG-04, TOOL-01 | T-02-31 | H-13 refuses a self-installed Claude in ~/.local/bin | self-test, host | `bash tests/selftest/host/h13-env-and-no-self-update.sh && bash tests/guard/host-tests.sh && bash tests/guard/docs.sh` | yes | ✅ green |
| 02-09-T1 | 09 | 9 | all | T-02-34 | Final gate: every Linux suite, branch contents, approved pins | guard, self-test | Full Linux suite (full suite command above) plus the branch and pin checks of the plan | yes | ✅ green |
| 02-09-T2 | 09 | 9 | all | T-02-33, T-02-35 | Mac run 25 passed, guard on bash 3.2, attended GSD bump | host, manual | `bash tests/host/run-all.sh`, `bash tests/guard/run-all.sh`, `bash tests/host/manual/h16-gsd-bump.sh` on the Mac | yes | ✅ green |
| 02-09-T3 | 09 | 9 | all | T-02-34 | Phase 1 dispositions and this map reflect the Mac proof | guard | Row checks of the plan on 01-REVIEW-DISPOSITION.md and this file | yes | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `versions.env`, `build.sh` and the Dockerfile edits come first
- [x] Guard rewrite: `versions_are_pinned`, file lists, COPY-flag parsing, `.dockerignore` rule
- [x] Host library: `build_images` via `build.sh`, `claude_pin` from `versions.env`, `pin_of NAME`, a poll-until-synced helper, an `elf_machine` helper
- [x] Fake docker knobs for the new host checks and the `versions.env` pin source
- [x] New host checks (toolchain, pins and GSD record, ccusage, caches), each with checklist row, `run-all.sh` placement and self-test group

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full host suite passes on real Docker | all | Docker is not available in the dev sandbox | `bash tests/host/run-all.sh` on the Mac |
| Real GSD bump keeps login and history | TOOL-02 | Needs a real logged-in sandbox | Attended helper in `tests/host/manual/` |
| A pin bump rebuilds only its own and later layers | IMG-03 | One-time cache observation | Attended observation on the Mac |
| Each new pin approved | IMG-03 | Supply-chain review is a human decision | Checkpoint per pin during execution |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [ ] Feedback latency < 60s (the Linux suite was not timed)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** Mac run of 2026-10-09 passed (25 passed, 0 failed, 0 not run; guard: All rules hold.)
