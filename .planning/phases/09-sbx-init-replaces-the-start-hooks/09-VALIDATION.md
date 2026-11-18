---
phase: "9"
slug: "sbx-init-replaces-the-start-hooks"
# status lifecycle: draft (seeded by plan-phase) -> validated (set by validate-phase)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-16"
---

# Phase 9: Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 9.2.0 through `uv run pytest`; bash guard rules; bash sbx self-test; bash host checks (Mac) |
| **Config file** | `pyproject.toml` (add `base/init` to `pythonpath`, `tests/selftest/init` to `testpaths`) |
| **Quick run command** | `uv run pytest tests/selftest/init tests/selftest/selfcheck -q` |
| **Full suite command** | `uv run pytest -q && bash tests/guard/run-all.sh && bash tests/selftest/sbx/run-all.sh` |
| **Mac suite** | `./host-test.sh`, then read `host-test.log` |
| **Estimated runtime** | ~15 seconds (dev sandbox) |

---

## Sampling Rate

- **After every task commit:** quick run command, plus `bash tests/guard/run-all.sh` when a Dockerfile, shell file, glob or managed setting changed
- **After every plan wave:** full suite command
- **Before `/gsd-verify-work`:** full suite green, then `./host-test.sh` green on the Mac
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

Filled in by the planner and the executor; the requirement map below is the source.

| Req ID | Behavior | Test Type | Automated Command | File Exists | Plan, task |
|--------|----------|-----------|-------------------|-------------|------------|
| INIT-01 | Runner prints one OK or FAIL line per step, stops at the first FAIL, exits 0, 1 or 2 | unit | `uv run pytest tests/selftest/init/test_init_launcher.py tests/selftest/init/test_init_runner.py -q` | W0 | 09-01 T1, T2 |
| INIT-01 | State folders, GSD sync, Cursor channel steps | unit | `uv run pytest tests/selftest/init/test_init_state_folders.py tests/selftest/init/test_init_gsd_sync.py tests/selftest/init/test_init_self_update.py -q` | W0 | 09-01 T3, 09-02 T1, T2 |
| INIT-01 | Step inventory per image and launcher argument refusal | unit | `uv run pytest tests/selftest/init/test_init_inventory.py tests/selftest/init/test_init_launcher.py -q` | W0 | 09-07 T1, T2, 09-01 T1 |
| INIT-02 | Rerun gives the same result; lock held makes a second run stop untouched; marker lifecycle | unit | `uv run pytest tests/selftest/init/test_init_runner.py -q` | W0 | 09-01 T2 |
| INIT-03 | Entrypoint, start library, hook runner, `start.d/`, readiness poll and entrypoint self-test are gone and unnamed | guard | `bash tests/guard/run-all.sh` | partly W0 | 09-09 T1, T2 |
| INIT-03 | Host scripts work without the start library | sbx self-test | `bash tests/selftest/sbx/run-all.sh` | exists | 09-08 T1, T2 |
| INIT-04 | Wrappers refuse without the marker, exec the agent with it | unit | `uv run pytest tests/selftest/init/test_init_wrappers.py -q` | W0 | 09-06 T1, T2 |
| INIT-04 | Self-check marker, off-PATH and tool checks with the agents folder; counts 55 and 53 | unit | `uv run pytest tests/selftest/selfcheck -q` | exists (edit) | 09-05 T1 to T3 |
| INIT-05 | A user skill with a clone skill's name survives and is reported as FAIL; only own links are removed | unit | `uv run pytest tests/selftest/init/test_init_best_practices_link.py -q` | W0 | 09-04 T1, T2 |
| INIT-06 | Root-owned entries under `state/` are given back to `sandbox` | unit | `uv run pytest tests/selftest/init/test_init_state_owner.py -q` | W0 | 09-03 T1 |
| INIT-01 to INIT-06 | The real images on the Mac (H-16, H-27, H-34, H-35) | host | `./host-test.sh`, then read `host-test.log` | W0 (edit, new H-35) | 09-10, 09-11, gate 09-13 T2 |

---

## Wave 0 Requirements

- [ ] `tests/selftest/init/` with `conftest.py` and helpers (stub `gsd-core`, stub agent, tree builders)
- [ ] One test file per init library and step file
- [ ] `pyproject.toml`: `pythonpath` gains `base/init`; `testpaths` gains `tests/selftest/init`
- [ ] New guard rules: no `ENTRYPOINT` in the Dockerfiles, no `entrypoint:` in compose
- [ ] New host check H-35 and edits to H-16, H-27, H-28, H-34, `compose_up`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real images: container only sleeps, init runs, ownership fixed | INIT-03, INIT-06 | Docker is not available in the dev sandbox | `./host-test.sh`, read `host-test.log`; every step OK |
| Wrappers in a real sandbox | INIT-04 | needs the built image | after `sbx-upgrade NAME`: `claude` not found; `sbx-claude` asks for `sbx-init`; after init it starts |
| Concurrent init | INIT-02 | needs two real shells | run `sbx-init` in two shells at once; one prints the lock FAIL |
| Ownership on Docker Desktop | INIT-06 | macOS bind mount behavior | `docker exec sbx-NAME find /home/sandbox/workspace/state -user root` prints nothing |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
