---
phase: "08"
slug: "in-image-self-check"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: true
wave_0_complete: false
created: "2026-11-14"
---

# Phase 08 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 9.2.0 through uv (Python 3.12) for the self-check; the bash guard and self-test suites; real Docker on the Mac for H-34 |
| **Config file** | `pyproject.toml` (none today; plan 08-01 task 2 creates it with `.python-version` and `uv.lock`) |
| **Quick run command** | `uv run pytest tests/selftest/selfcheck -q` |
| **Full suite command** | `uv run pytest tests/selftest/selfcheck -q && bash tests/guard/run-all.sh && bash tests/selftest/sbx/run-all.sh && bash tests/selftest/entrypoint/run-all.sh`, then `./host-test.sh` on the Mac |
| **Estimated runtime** | about 30 seconds in the dev sandbox (pytest about 5 s); the Mac run 10 to 20 minutes |

---

## Sampling Rate

- **After every task commit:** Run `uv run pytest tests/selftest/selfcheck -q` (from plan 08-01 task 2 on; the tracer task runs the launcher with python3) plus `bash tests/guard/run-all.sh`
- **After every plan wave:** Run the full dev-sandbox suite command above
- **Before `/gsd-verify-work`:** Full suite must be green, and the Mac gate of plan 08-07 approved
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | CHECK-01, CHECK-04 | T-08-02, T-08-03 | the launcher runs the image's own Python isolated from PYTHONPATH; one bad check never hides the others | smoke | `python3 base/selfcheck/sbx-selfcheck` and the composition probe in the plan | no, the task creates them | pending |
| 08-01-02 | 01 | 1 | CHECK-01, CHECK-04 | T-08-SC | pytest pinned to 9.2.0 and locked with hashes; dev only | unit | `uv run pytest tests/selftest/selfcheck -q` | no, Wave 0 | pending |
| 08-01-03 | 01 | 1 | CHECK-01 | T-08-01 | runner and checks root-owned in the image | static | `bash tests/guard/run-all.sh` (hadolint) and the Dockerfile order probes | edit | pending |
| 08-02-01 | 02 | 1 | CHECK-02, CHECK-03 | T-08-04, T-08-05 | root key deleted at once; the caller's root kept next to the test root | probe | the certificate probe and the fixture parser probe in the plan | no, the task creates them | pending |
| 08-02-02 | 02 | 1 | CHECK-02 | T-08-06 | the Cursor test sandbox is always removed | static | `bash tests/guard/run-all.sh` and the Main order probes | edit | pending |
| 08-03-01 | 03 | 2 | CHECK-01, CHECK-04 | T-08-08, T-08-09 | the state walk follows no link and opens no file; the probe file is removed | unit | `uv run pytest tests/selftest/selfcheck -q` | no, the task creates test_sandbox_checks.py | pending |
| 08-03-02 | 03 | 2 | CHECK-01, CHECK-04 | T-08-10, T-08-11 | argument lists only; the git identity values are never printed | unit | `uv run pytest tests/selftest/selfcheck -q` | yes after 08-03-01 | pending |
| 08-04-01 | 04 | 2 | CHECK-02 | T-08-12 | the compromised-package rule reads the new sources | guard | `bash tests/guard/run-all.sh` and the planted scratch probe | edit | pending |
| 08-04-02 | 04 | 2 | CHECK-02 | T-08-13 | every kept probe tests only what needs the Mac | static | the list, rename and comment probes in the plan | edit | pending |
| 08-04-03 | 04 | 2 | CHECK-02, CHECK-04 | T-08-14 | docs name no deleted check and no planning ID | static | the doc and sweep probes in the plan | edit | pending |
| 08-05-01 | 05 | 3 | CHECK-01, CHECK-04 | T-08-15 | a shadowing copy under /home or a longer version never passes | unit | `uv run pytest tests/selftest/selfcheck -q` | no, the task creates test_tool_checks.py | pending |
| 08-05-02 | 05 | 3 | CHECK-01, CHECK-03 | T-08-16, T-08-17, T-08-18 | certificates found by fingerprint; bash -i never touches the history file | unit | `uv run pytest tests/selftest/selfcheck -q` | no, the task creates test_certs.py | pending |
| 08-06-01 | 06 | 4 | CHECK-01, CHECK-04 | T-08-19, T-08-21 | login files never opened; links must carry the exact text | unit | `uv run pytest tests/selftest/selfcheck -q` | no, the task creates test_agent_checks.py | pending |
| 08-06-02 | 06 | 4 | CHECK-01, CHECK-02 | T-08-20, T-08-22 | cursor-agent never writes the sandbox's config; counts tied to H-34 | unit | `uv run pytest tests/selftest/selfcheck -q` | no, the task creates test_inventory.py | pending |
| 08-07-01 | 07 | 5 | CHECK-01 to CHECK-04 | T-08-23 | change set, modes and sweeps clean | gate | the six commands of the plan | n/a | pending |
| 08-07-02 | 07 | 5 | CHECK-01 to CHECK-04 | T-08-24, T-08-25 | the throwaway root never reaches the :local images | manual (Mac) | `./host-test.sh`, then read `host-test.log` and `../selfcheck-gate.log` | n/a | pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `pyproject.toml`, `.python-version` (3.12), `uv.lock` and the `.gitignore` entries `.venv/`, `__pycache__/`, `.pytest_cache/`: plan 08-01 task 2
- [ ] `tests/selftest/selfcheck/conftest.py` (`REPO_DIR`, `repo_dir`; later `make_certificate`, `agent_module`): plans 08-01, 08-05, 08-06
- [ ] `tests/selftest/selfcheck/test_runner.py` (08-01), `test_sandbox_checks.py` (08-03), `test_tool_checks.py` and `test_certs.py` (08-05), `test_agent_checks.py` and `test_inventory.py` (08-06)
- [ ] Framework install: `uv lock`, then `uv run pytest` (the exact pin pytest 9.2.0 was approved by the user)
- [ ] Guard: the support-folder glob leaves `tests/guard/supply-chain.sh` in the same commit as the toolchain probe (08-04 task 1)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The three images build with the self-check blocks (the py_compile steps) | CHECK-01 | Docker does not run in the dev sandbox | `./host-test.sh` on the Mac; the build step passes |
| H-34 passes: 51 checks in the Claude test sandbox, 49 in the Cursor test sandbox, no FAIL | CHECK-01, CHECK-02, CHECK-04 | needs real images and `docker exec` | plan 08-07 task 2; read the `INFO: H-34` lines in `host-test.log` |
| The throwaway root is found in the system bundle and Java cacerts, and its key is gone | CHECK-03 | needs the Mac's openssl (LibreSSL) and the real build | plan 08-07 task 2, steps 4 and 5 |
| The Cursor test sandbox is gone after H-34; H-32 and H-33 still pass | CHECK-02 | needs Docker | plan 08-07 task 2 |
| The :local images are untouched by the run | CHECK-03 | needs Docker | plan 08-07 task 2, steps 2 and 4 |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** {pending / approved YYYY-MM-DD}
