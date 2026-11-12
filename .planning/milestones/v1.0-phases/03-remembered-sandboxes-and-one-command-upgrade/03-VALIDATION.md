---
phase: "03"
slug: "remembered-sandboxes-and-one-command-upgrade"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-11-06"
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Plain bash suites: guard (`tests/guard/`), self-tests (`tests/selftest/entrypoint/`, `tests/selftest/guard/`, new `tests/selftest/sbx/`), host checks (`tests/host/`, Mac + Docker) |
| **Config file** | none (`.shellcheckrc`, `.hadolint.yaml` for lint) |
| **Quick run command** | `bash tests/selftest/sbx/run-all.sh && bash tests/selftest/entrypoint/run-all.sh && bash tests/selftest/guard/run-all.sh && PATH="${TMPDIR:-/tmp}/sbx-linters/bin:$PATH" bash tests/guard/run-all.sh` |
| **Full suite command** | On the Mac: `./host-test.sh` (then read `host-test.log`); attended: `bash tests/host/manual/h29-upgrade-resume.sh` |
| **Estimated runtime** | ~60 seconds quick; host suite several minutes |

In this dev sandbox the guard without the rehearsal linters ends with exactly two FAILs (`shellcheck_passes`, `hadolint_passes`: not installed); with `PATH="${TMPDIR:-/tmp}/sbx-linters/bin:$PATH"` it ends `All rules hold.` (18 rules, 19 after plan 02). Docker is not available here: every Docker behaviour (H-28, H-29, H-30) is proven only by the Mac run in plan 04. The plan tracers use a throwaway docker stand-in that records calls; it is never committed.

---

## Sampling Rate

- **After every task commit:** Run the quick run command
- **After every plan wave:** Run the quick run command; the full suite runs once, on the Mac, in plan 04
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds (quick suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-T1 | 01 | 1 | SCR-01, SCR-02 | T-03-01, T-03-03, T-03-04 | registry outside mounts; name checked first; compose ignores the caller's environment | tracer (stand-in docker), lint, entrypoint self-test | sbx-add, sbx-start, sbx-stop through PATH on a spaced path; exact recorded compose lines; shellcheck; guard rehearsal; modes | ✅ | ✅ green |
| 03-01-T2 | 01 | 1 | SCR-01, SCR-02 | T-03-01, T-03-02, T-03-06, T-03-08 | every refusal before a write; a registry value never runs; overlaps refused; no Docker, no real registry | self-test + two mutants | `bash tests/selftest/sbx/run-all.sh`; mutant without the registry refusal; mutant that sources the entry | ✅ | ✅ green |
| 03-01-T3 | 01 | 1 | SCR-01, SCR-02 | T-03-05, T-03-08 | test registry only under the run folder; sandbox restored | static + unit of lib-sbx + host (Mac) | bash -n, shellcheck, sbx_test_setup unit; Mac H-28 PASS and the Mac-shell self-test OK | ✅ | ✅ green |
| 03-02-T1 | 02 | 2 | SCR-03 | T-03-09, T-03-11, T-03-12 | failed build changes nothing; warning before recreate; one project only | tracer (stand-in docker) | failing build: no compose call; good build: "container build build compose exec", force-recreate, last line | ✅ | ✅ green |
| 03-02-T2 | 02 | 2 | SCR-03 | T-03-10 | refusals before the build; no delete words in bin/ | self-test, guard self-test | `bash tests/selftest/sbx/run-all.sh`; `bash tests/selftest/guard/sandbox-rules.sh` plants; 19 guard rules | ✅ | ✅ green |
| 03-02-T3 | 02 | 2 | SCR-03 | T-03-09, T-03-10, T-03-12 | files, mount and other sandboxes kept | static + host (Mac) + helper | bash -n, shellcheck, helper refuses without a terminal; Mac H-29 PASS; h29-upgrade-resume.sh PASS | ✅ | ✅ green |
| 03-03-T1 | 03 | 3 | SCR-07 | T-03-14 | versions written at build time from proven pins | tracer (stand-in docker), hadolint | sbx-upgrade's last line is the container's file; Dockerfile placement; guard rehearsal with hadolint | ✅ | ✅ green |
| 03-03-T2 | 03 | 3 | SCR-07 | T-03-14, T-03-15 | only interactive shells print | static + host (Mac) | bash -n, shellcheck; Mac H-30 PASS and H-29 last-line check | ✅ | ✅ green |
| 03-03-T3 | 03 | 3 | SCR-01, SCR-02, SCR-03, SCR-07 | T-03-16 | docs name the PATH trust | doc content checks | SANDBOX.md sections and strings; tests/README.md and checklist counts; README.md untouched | ✅ | ✅ green |
| 03-04-T1 | 04 | 4 | all | T-03-17, T-03-18 | no planning IDs or attribution on the code branch | gate + git | full Linux suite, planning-ID scan, feat/sbx-scripts tree equals HEAD | ✅ | ✅ green |
| 03-04-T2 | 04 | 4 | all | T-03-19 | test logins removed by the cleanup | checkpoint (Mac) | `./host-test.sh --keep`: Summary 30 passed; Mac-shell self-test on /bin/bash 3.2; helper PASS | ✅ | ✅ green |
| 03-04-T3 | 04 | 4 | all | n/a | n/a | records | rows, criteria map, Mac summary line recorded | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `tests/selftest/sbx/` (`run-all.sh`, `lib.sh`, `add.sh`, `entry.sh`; `upgrade.sh` in plan 02): SCR-01, SCR-02, SCR-03 refusals, roadmap criterion 5 on the Mac shell
- [x] `tests/host/lib-sbx.sh`, `h28-sbx-add-start-stop.sh`, `h29-sbx-upgrade.sh`, `h30-version-line.sh`, `manual/h29-upgrade-resume.sh`: SCR-02, SCR-03, SCR-07 on real Docker
- [x] `host-test.sh` step `mac_sbx_selftest`; `tests/host/run-all.sh` list entries
- [x] Guard: `bin/*` in SHELL_FILES, SANDBOX_FILES and the pipe rule; rule `host_scripts_keep_sandbox_data` with planted cases
- [x] No framework install needed

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Claude stays logged in and `claude --continue` resumes the session after `sbx-upgrade` | SCR-03 | needs a real claude.ai login and a human judgment that the session resumed | `bash tests/host/manual/h29-upgrade-resume.sh` on the Mac (plan 04, step 3) |
| Every Docker behaviour of the scripts and the versions line | SCR-01, SCR-02, SCR-03, SCR-07 | Docker does not run in the dev sandbox; automated on the Mac only | `./host-test.sh --keep` on the Mac (plan 04, step 2): H-28, H-29, H-30 |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-11-06

Notes at sign-off:
- The Mac run passed 30 of 30 host checks, the Mac-shell self-test on `/bin/bash` 3.2.57 and the attended helper. The separate host-test step `pin digests` failed on UBUNTU_IMAGE (upstream drift, not caused by this phase); a follow-up PR bumps the pin.
- The test cleanup (T-03-19) is the user's to run on the Mac (`/home/sandbox/mac-cleanup-03.txt`).
