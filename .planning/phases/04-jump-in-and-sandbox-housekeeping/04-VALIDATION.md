---
phase: "04"
slug: "jump-in-and-sandbox-housekeeping"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-07"
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Plain bash suites: guard (`tests/guard/`), self-tests (`tests/selftest/sbx/`, `tests/selftest/guard/`, `tests/selftest/entrypoint/`), host checks (`tests/host/`, Mac + Docker) |
| **Config file** | none (`.shellcheckrc`, `.hadolint.yaml` for lint) |
| **Quick run command** | `bash tests/selftest/sbx/run-all.sh && bash tests/selftest/guard/run-all.sh && bash tests/selftest/entrypoint/run-all.sh && PATH="${TMPDIR:-/tmp}/sbx-linters/bin:$PATH" bash tests/guard/run-all.sh` |
| **Full suite command** | On the Mac: `./host-test.sh` (then read `host-test.log`); attended: `bash tests/host/manual/h31-jump-in.sh` |
| **Estimated runtime** | ~30 seconds quick; host suite several minutes |

In this dev sandbox the guard without linters ends with exactly two FAILs (`shellcheck_passes`, `hadolint_passes`: not installed); with `PATH="${TMPDIR:-/tmp}/sbx-linters/bin:$PATH"` it ends `All rules hold.`. Docker is not available here: every Docker behaviour (H-31, H-32, H-33 and the helper) is proven only by the Mac run in plan 05. The plan tracers use a throwaway docker stand-in that records calls; it is never committed.

---

## Sampling Rate

- **After every task commit:** Run the quick run command
- **After every plan wave:** Run the quick run command plus shellcheck on the new `bin/` files when available
- **Before `/gsd-verify-work`:** Full suite must be green on the Mac
- **Max feedback latency:** 30 seconds (quick suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-T1 | 01 | 1 | SCR-04 | T-04-01, T-04-02, T-04-03 | name checked first; registry read even when running; a running sandbox gets the exec only | tracer (stand-in docker), lint, guard | sbx-shell and sbx-start through PATH on a spaced path: exact compose line, the wait, the exec into the project folder, status 7 passed through; running: one inspect plus the exec; shellcheck; 19 guard rules; modes | ❌ W0 | ⬜ pending |
| 04-01-T2 | 01 | 1 | SCR-04 | T-04-01, T-04-03, T-04-06 | refusals before compose and the shell; no recreate on entry; no Docker, no real registry | self-test + two mutants | `bash tests/selftest/sbx/run-all.sh`; mutant that always starts the sandbox; mutant that opens the shell in the mount point | ❌ W0 `shell.sh` | ⬜ pending |
| 04-01-T3 | 01 | 1 | SCR-04 | T-04-06 | test registry under the run folder; test sandbox restored | static + host (Mac) + helper | bash -n, shellcheck, the helper refuses without a terminal; Mac H-31 PASS; `h31-jump-in.sh` PASS | ❌ W0 | ⬜ pending |
| 04-02-T1 | 02 | 2 | SCR-05 | T-04-07, T-04-08 | a failed docker ps is an error; sbx-list only reads | tracer (stand-in docker), lint, guard | sbx-list through PATH: header, rows in order, older-image mark, leftovers, one ps call, no compose; ps failure exit 1 with empty stdout; usage exit 2 | ❌ W0 | ⬜ pending |
| 04-02-T2 | 02 | 2 | SCR-05 | T-04-07, T-04-09, T-04-12 | exact name match; a Docker failure never reads as an empty list | self-test + two mutants | `bash tests/selftest/sbx/run-all.sh`; prefix-match mutant; ignored-failure mutant | ❌ W0 `list.sh` | ⬜ pending |
| 04-02-T3 | 02 | 2 | SCR-05 | T-04-11, T-04-12 | no cc_ container; status equals docker ps -a | static + host (Mac) | bash -n, shellcheck; Mac H-32 PASS | ❌ W0 | ⬜ pending |
| 04-03-T1 | 03 | 3 | SCR-06 | T-04-13, T-04-14, T-04-15, T-04-16 | plain down only; the entry deleted only after a good down; one allowed delete line | tracer (stand-in docker), lint, guard, guard self-test | sbx-rm through PATH: a failing down keeps the entry; exact down line; entry deleted; folder files kept; sbx-add writes the same entry; 19 rules; nine planted cases | ❌ W0 | ⬜ pending |
| 04-03-T2 | 03 | 3 | SCR-06 | T-04-13, T-04-14, T-04-15 | folder untouched; the order of the delete | self-test + two mutants | `bash tests/selftest/sbx/run-all.sh`; ignored-failure mutant; `-v` mutant | ❌ W0 `rm.sh` | ⬜ pending |
| 04-03-T3 | 03 | 3 | SCR-06 | T-04-13, T-04-18 | sentinels, volumes, images and other sandboxes kept; the re-register round trip | static + host (Mac) | bash -n, shellcheck; Mac H-33 PASS | ❌ W0 | ⬜ pending |
| 04-04-T1 | 04 | 4 | SCR-04, SCR-05, SCR-06 | T-04-19, T-04-21 | docs promise only what the scripts do; README.md untouched | doc content checks | SANDBOX.md strings and the sbx-list header; ASCII; no dash punctuation; README.md and the old layout unchanged; guard | ✅ | ⬜ pending |
| 04-04-T2 | 04 | 4 | SCR-04, SCR-05, SCR-06 | T-04-20 | the counts follow the runner | doc content checks | checklist title, range, chain and helper count; tests/README.md ranges and 19 rules; host-test.sh comment; guard; sbx self-test | ✅ | ⬜ pending |
| 04-05-T1 | 05 | 5 | all | T-04-22, T-04-23 | no planning IDs or attribution on the code branch | gate + git | full Linux suite, planning-ID scan, feat/sbx-shell-list-rm tree equals HEAD, not on origin | n/a | ⬜ pending |
| 04-05-T2 | 05 | 5 | all | T-04-24 | test logins removed by the cleanup | checkpoint (Mac) | `./host-test.sh --keep`: Summary 33 passed; Mac-shell self-test on /bin/bash 3.2; `h31-jump-in.sh` PASS | n/a | ⬜ pending |
| 04-05-T3 | 05 | 5 | all | n/a | n/a | records | rows, criteria map, Mac summary line and M1 to M8 recorded | n/a | ⬜ pending |

Requirement level map (from 04-RESEARCH.md; host checks split as one per command: H-31 `sbx-shell`, H-32 `sbx-list`, H-33 `sbx-rm`):

| Requirement | Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|----------|-----------|-------------------|-------------|--------|
| SCR-04 | usage, refusals before any exec; start-if-needed then `docker exec -it -w /home/sandbox/workspace/NAME`; running gets exec only; exit status passes through; `sbx-start` hint names `sbx-shell` | selftest | `bash tests/selftest/sbx/run-all.sh` | ❌ W0 `shell.sh` | ⬜ pending |
| SCR-04 | real start and shell in the project folder; running one entered without recreate | host | `./host-test.sh` (H-31) | ❌ W0 | ⬜ pending |
| SCR-05 | three statuses, path with spaces, older-image marker, error row, leftover section, `docker ps` failure exits 1 | selftest | `bash tests/selftest/sbx/run-all.sh` | ❌ W0 `list.sh` | ⬜ pending |
| SCR-05 | status equals `docker ps -a` in all three states | host | `./host-test.sh` (H-32) | ❌ W0 | ⬜ pending |
| SCR-06 | `down` with exact scope, no `-v`/`--volumes`/`--rmi`; `--unregister` only after a good `down`; folder untouched; closing line | selftest | `bash tests/selftest/sbx/run-all.sh` | ❌ W0 `rm.sh` | ⬜ pending |
| SCR-06 | rewritten data rule passes clean tree, fails each planted violation | guard + guard selftest | `bash tests/guard/run-all.sh && bash tests/selftest/guard/run-all.sh` | modify | ⬜ pending |
| SCR-06 | container gone, sentinels intact, re-register brings back login and history | host | `./host-test.sh` (H-33) | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/selftest/sbx/shell.sh` (plan 01), `list.sh` (plan 02), `rm.sh` (plan 03): new groups for SCR-04, SCR-05, SCR-06
- [ ] `tests/selftest/sbx/lib.sh`: stand-in docker gains the `shell-status`, `compose-fail`, `image-missing` (plan 01) and `ps-lines`, `ps-fail` (plan 02) knobs; `appears_before` moves here
- [ ] `tests/guard/isolation.sh` and `tests/selftest/guard/sandbox-rules.sh`: data rule rewrite and planted cases, in the same commit as `bin/sbx-rm` (plan 03)
- [ ] `tests/host/h31-sbx-shell.sh`, `tests/host/manual/h31-jump-in.sh` (plan 01), `tests/host/h32-sbx-list.sh` (plan 02), `tests/host/h33-sbx-rm.sh` (plan 03)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Interactive terminal shell, then `sbx-claude` starts logged in | SCR-04 | needs a real terminal and a real login | `bash tests/host/manual/h31-jump-in.sh` on the Mac |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
