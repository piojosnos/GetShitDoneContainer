---
phase: "6"
slug: "test-diet"
# status lifecycle: draft (seeded by plan-phase) -> validated (set by validate-phase)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-13"
---

# Phase 6: Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | plain bash: guard rules (`run_rules`), self-tests (`expect`), host checks (`report_check`) |
| **Config file** | none (`.shellcheckrc`, `.hadolint.yaml` only) |
| **Quick run command** | `bash tests/selftest/sbx/run-all.sh && bash tests/selftest/entrypoint/run-all.sh` |
| **Full suite command** | `bash tests/guard/run-all.sh && bash tests/selftest/sbx/run-all.sh && bash tests/selftest/entrypoint/run-all.sh` (dev sandbox); `./host-test.sh` then read `host-test.log` (Mac) |
| **Estimated runtime** | about 17 seconds (dev sandbox) |

---

## Sampling Rate

- **After every task commit:** the suite the task touched (one self-test group or one guard file) plus `bash -n` on edited host files.
- **After every plan wave:** the full dev-sandbox suite, the `run-all.sh` list-consistency loop and the reference-sweep greps from `06-RESEARCH.md`.
- **Before `/gsd-verify-work`:** full suite green in the dev sandbox, then `./host-test.sh` green on the Mac.
- **Max feedback latency:** 20 seconds (dev sandbox).

---

## Per-Task Verification Map

Filled by the planner per task; the requirement-level map lives in `06-RESEARCH.md` under "Phase Requirements to Test Map".

| Requirement | Test Type | Automated Command | Status |
|-------------|-----------|-------------------|--------|
| DIET-01 | static | `test ! -e tests/host/manual` plus the reference sweep grep | pending |
| DIET-02 | static | list-consistency loop, `bash -n` on host files, no-Claude grep | pending |
| DIET-03 | static + host | `grep -c plant_login_files` in H-09 and H-29; Mac `./host-test.sh` | pending |
| DIET-04 | guard | `bash tests/guard/run-all.sh` ends "All rules hold." | pending |
| DIET-05 | self-test | `bash tests/selftest/sbx/run-all.sh`, `bash tests/selftest/entrypoint/run-all.sh` | pending |

*Status: pending, green, red, flaky*

Per task (from the plans):

| Task | Requirement | Automated command (dev sandbox) | Status |
|------|-------------|---------------------------------|--------|
| 06-01-1 | DIET-05 | `bash tests/selftest/sbx/run-all.sh`; start 3 and upgrade 5 PASS; `DOCKER_HOST` and `unset DOCKER_CONTEXT` in `start_group` | pending |
| 06-01-2 | DIET-05 | `bash tests/selftest/sbx/run-all.sh`; shell 9, list 2, add 48, entry 19 PASS | pending |
| 06-01-3 | DIET-05 | sbx suite 121 PASS; no stand-in helper under `tests/selftest` | pending |
| 06-02-1 | DIET-04 | `bash tests/guard/run-all.sh` (20 rules); scratch-copy negative control for both new rules | pending |
| 06-02-2 | DIET-04 | guard 17 PASS, three start rules absent; planted rm in `bin/sbx-list` still fails | pending |
| 06-02-3 | DIET-05 | `bash tests/selftest/entrypoint/run-all.sh` 43 PASS; sbx-add name cases pass | pending |
| 06-03-1 | DIET-03 | `bash -n`, guard, `lib-login.sh` probe (plant, missing, changed, empty dir) | pending |
| 06-03-2 | DIET-03 | `bash -n`, guard, awk region greps for H-29 plant and check | pending |
| 06-04-1 | DIET-02 | `bash -n`, guard, preflight probe on a scratch copy of `host-test.sh`, list-consistency loop | pending |
| 06-04-2 | DIET-02 | list-consistency loop (26 checks), H-28 stop timing grep | pending |
| 06-04-3 | DIET-02 | no-Claude and no-Maven grep over `tests/host/*.sh`, kept-parts grep | pending |
| 06-05-1 | DIET-01 | guard with `PASS: no_compromised_gsd_package`, `test ! -e tests/host/manual`, no prompt constructs | pending |
| 06-05-2 | DIET-01 | `git grep` sweep for every helper name outside `.planning` | pending |
| 06-06-1 | all | full dev-sandbox gate and sweeps | pending |
| 06-06-2 | all | Mac: `./host-test.sh`, then read `host-test.log` (checkpoint) | pending |

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fake login files survive recreate and `sbx-upgrade`; host run asks nothing | DIET-03, criterion 5 | Docker is not available in the dev sandbox | On the Mac: `./host-test.sh`, then read `host-test.log` |
| The two new guard rules can fail | DIET-04 | the guard self-test is deleted by this phase | One-time scratch-copy negative control, recorded in the summary |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
