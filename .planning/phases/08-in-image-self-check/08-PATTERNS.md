# Phase 8: In-image self-check - Pattern Map

**Mapped:** 2026-11-14
**Files analyzed:** 29 (new and modified)
**Analogs found:** 25 / 29 (the Python files have no Python analog in the repo; they copy the structure of the bash probes they replace)

CONTEXT.md D-15 to D-19 win over RESEARCH.md where they differ: H-01 is deleted whole (no `docker info` comparison, no platform-warning grep, ignore Open Question 3); pytest is NOT added to `sandbox_suites` (ignore Open Question 4); one self-check line per tool (no merged groups, ignore Open Question 5); the throwaway certificate is reused from `${TMPDIR:-/tmp}/sbx-hosttest-root-ca/` (RESEARCH recommendation, now locked); pytest pinned to exactly 9.2.0.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `base/selfcheck/sbx-selfcheck` (launcher) | utility (CLI entry) | request-response | `base/bin/sbx-link-bundle` (installed by Dockerfile `COPY --chmod=755`) | role-match (shell, not Python) |
| `base/selfcheck/sbx_selfcheck.py` (CheckResult, Check, runner, helpers) | utility | transform | `tests/host/lib-report.sh` (PASS/FAIL/indent format) + `tests/host/support/toolchain-probe.sh` (helper per fact) | role-match |
| `base/selfcheck/shared_checks.py` | service (check list) | request-response | `tests/host/support/toolchain-probe.sh`, `tests/host/h06`, `h14`, `h22`, `h30` assertions | role-match |
| `claude/selfcheck/claude.py` | service (check list) | request-response | old `h12`, `h13`, `h14`, `h15`, `h25` assertions; `claude/start.d/*` | role-match |
| `cursor/selfcheck/cursor.py` | service (check list) | request-response | `cursor/Dockerfile` smoke test; `cursor/start.d/*` | role-match |
| `base/Dockerfile` (modify) | config | file-I/O | its own `COPY --chmod` and cert `RUN` blocks | exact |
| `claude/Dockerfile` (modify) | config | file-I/O | `claude/Dockerfile:86` `COPY --chmod=644 versions.env` | exact |
| `cursor/Dockerfile` (modify) | config | file-I/O | `cursor/Dockerfile:92` `COPY --chmod=644 versions.env` | exact |
| `tests/host/h34-selfcheck.sh` (new) | test (host check) | request-response | `tests/host/h28-sbx-add-start-stop.sh` + `h12` | exact |
| `tests/host/run-all.sh` (modify) | config (orchestrator) | batch | itself (lines 21-25, 238-274) | exact |
| `tests/host/lib-docker.sh` (modify: add cert helper, delete `expected_arch`) | utility | file-I/O | `build_images` in the same file | exact |
| `tests/host/h06-git-and-identity.sh` (slim) | test | request-response | itself | exact |
| `tests/host/h12-plain-run-refused-pin-installed.sh` (slim, rename) | test | request-response | itself | exact |
| `tests/host/h25-images-match-versions.sh` (slim) | test | request-response | itself | exact |
| `tests/host/h01,h04,h05,h13,h14,h15,h22,h30` + `support/toolchain-probe.sh` (delete) | test | n/a | n/a | n/a |
| `tests/guard/supply-chain.sh:14` (modify) | test (guard) | transform | itself | exact |
| `tests/selftest/selfcheck/conftest.py`, `test_runner.py`, `test_helpers.py`, `test_certs.py` (new) | test | transform | no pytest in repo; style from `tests/selftest/entrypoint/*.sh` (real files in a temp dir) | partial |
| `pyproject.toml`, `.python-version`, `uv.lock` (new), `.gitignore` (modify) | config | n/a | none (no Python project file exists) | none |
| `host-test.sh` (modify comment only) | config | batch | itself | exact |
| `tests/README.md`, `tests/host-checklist.md`, `README.md`, `MIGRATION.md` (modify) | doc | n/a | neighbouring rows in the same files | exact |

## Pattern Assignments

### `base/selfcheck/sbx_selfcheck.py` and the check files (utility, transform)

**Analog:** none in Python. Use RESEARCH.md "Pattern 1" (`CheckResult`, `passed()`, `failed()` raising on empty hint), "Pattern 2" (`CHECK_LIST` of `Check(name, function)`, each run inside `try/except Exception`), and the Code Examples (`parse_versions_text`, `java_fingerprint_set`, `elf_machine`, `bundle_links_result`). Follow `/home/sandbox/workspace/best-practices/rules/coding-general.md`: braces-style imperative loops, blank line around control flow, full names, `_list`/`_set`/`_by_x_map` suffixes, no docstrings, ASCII, no phase or decision IDs in comments, no dashes as punctuation.

**Output format to copy** from `tests/host/lib-report.sh` (PASS line, details indented six spaces):
```
PASS: user-sandbox: uid 1000, gid 1000, name sandbox
FAIL: git-identity: git user.email is not set
      fix: run sbx-gh-login in this sandbox; it asks for the name and email
sbx-selfcheck: 43 checks, 1 failed
```
The summary line must not start with PASS or FAIL (the host check counts `^(PASS|FAIL): `). Exit 0 / 1 / 2 (usage), matching `.claude/rules/shell.md` exit-code convention.

**Helper-per-fact pattern** (analog `tests/host/support/toolchain-probe.sh` lines 20-35, the bytes to port):
```bash
elf_machine() {
  od -An -tx1 -j18 -N2 "$1" | tr -d ' \n'
}
# b700 is AArch64, 3e00 is x86-64.
```
Port to `int.from_bytes(header[18:20], "little")` with `{"aarch64": 0xB7, "x86_64": 0x3E}`.

**Mount detection** (analog `base/sbx-start-lib.sh`, same logic): `awk -v p="$1" '$5==p { f=1 } END { exit !f }' /proc/self/mountinfo` becomes "field 5 of `/proc/self/mountinfo`" in Python.

**Cursor version trap** (analog `cursor/Dockerfile:83`): run `cursor-agent --version` with `env -u CURSOR_CONFIG_DIR HOME=<tempfile.mkdtemp()>`; never in the live sandbox env.

**Where to put source:** `base/selfcheck/`, `claude/selfcheck/`, `cursor/selfcheck/`, NOT `*/bin/` (guard `SHELL_FILES` globs `base/bin/* claude/bin/* cursor/bin/*` and shellcheck rejects a Python shebang, SC1071).

**Check inventory:** use RESEARCH.md "Proposed inventory" (32 shared + 11 Claude = 43; 32 + 9 Cursor = 41), but D-19 applies: keep `tool-node`, `tool-gh`, `tool-uv`, `tool-java`, `tool-maven`, `tool-python`, `tool-gsd` as separate lines (already so). `tools-in-image` is the existing exception in the list; if the planner keeps it as one line, split it into one line per tool (git, gh, node, python3, uv, java, mvn, jq, rg, unzip, zip, ssh, make, gcc) and update both counts. The two counts live only in `h34`.

---

### `base/Dockerfile`, `claude/Dockerfile`, `cursor/Dockerfile` (config, file-I/O)

**Analog:** `claude/Dockerfile:86` and `cursor/Dockerfile:92`:
```dockerfile
COPY --chmod=644 versions.env /etc/sbx/versions.env
```
Copy single files with explicit destinations (not a directory with `--chmod`). From RESEARCH.md Dockerfile wiring:
```dockerfile
RUN mkdir -p /usr/local/lib/sbx-selfcheck /etc/sbx/selfcheck.d
COPY --chmod=755 base/selfcheck/sbx-selfcheck /usr/local/bin/sbx-selfcheck
COPY --chmod=644 base/selfcheck/sbx_selfcheck.py /usr/local/lib/sbx-selfcheck/sbx_selfcheck.py
COPY --chmod=644 base/selfcheck/shared_checks.py /usr/local/lib/sbx-selfcheck/shared_checks.py
# claude/Dockerfile
COPY --chmod=644 claude/selfcheck/claude.py /etc/sbx/selfcheck.d/claude.py
```
Place base copies after the base smoke test (a base change rebuilds both agent images). Add `python3 -m py_compile` in the same RUN. Update the comment above `versions.env` in both agent Dockerfiles ("Nothing reads it at runtime" becomes false). The extra-certificate step already exists (`base/Dockerfile` lines 35-48, files `sbx-extra-ca-N.crt` into `/usr/local/share/ca-certificates/`); do not change it. `.dockerignore` already allows `base`, `claude`, `cursor`.

---

### `tests/host/h34-selfcheck.sh` (host check, request-response)

**Analog:** `tests/host/h28-sbx-add-start-stop.sh` (Cursor sandbox via `sbx-add`/`sbx-start`/`sbx-rm`) and `tests/host/h12-plain-run-refused-pin-installed.sh` (one-shot docker call, `add_problem`, `report_check`).

**Header and init** (h28 lines 1-13):
```bash
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# H-28: sbx-add registers a sandbox once; sbx-start and sbx-stop work by name
# ------------------------------------------------------------------------------
# Needs: test sandbox running; takes it down and restores it
# ------------------------------------------------------------------------------
set -u
. "$(dirname "$0")/lib.sh"
host_init
. "$(dirname "$0")/lib-sbx.sh"
```

**Cursor sandbox setup** (`tests/host/lib-sbx.sh` 15-59): `sbx_test_setup H-34 h34`, then `run_sbx h34-add sbx-add hosttest-cursor "$sbxDir" cursor`, `run_sbx h34-start sbx-start hosttest-cursor`, always `run_sbx h34-rm sbx-rm hosttest-cursor --yes`. `run_sbx` logs to `$RUN/logs/NAME.out/.err`, sets `sbxStatus`, uses `run_timeout 900`.

**Run in the Claude sandbox** (`lib-sandbox.sh:12`): `in_container` is `docker exec "$CONTAINER" "$@" </dev/null 2>&1`; for the Cursor sandbox use `docker exec sbx-hosttest-cursor sbx-selfcheck` through `run_timeout 120` (no `timeout` on macOS).

**Problem accumulation and result** (h12 lines 24-28, 42-47):
```bash
  if [ "$plainStatus" -ne 1 ] || [[ "$plainOutput" != *"[sbx] ERROR"* ]]; then
    add_problem "a plain docker run must exit 1 ...: $(first_lines "$plainOutput")"
  fi
...
require_no_arguments "$@" || exit 2
report_check H-12 "the start check or the pinned version is wrong" \
  "a plain docker run is refused and Claude Code $pin is installed"
```
Constants at the top: `expectedClaudeCount=43`, `expectedCursorCount=41`, with a comment on where to count. Assertions: `grep -Ec '^(PASS|FAIL): '` equals the constant; `grep -c '^FAIL: '` is 0; both `extra-ca-` PASS lines contain the throwaway fingerprint (`$SBXTEST_ROOT_CA` via `openssl x509 -noout -fingerprint -sha256 | sed 's/.*=//' | tr -d ':' | tr 'a-f' 'A-F'`). On failure print every FAIL line and its `fix:` line. Plant identity and fake credentials with `docker exec` as `sandbox` first (the doctor FAILs on a fresh sandbox, correctly). Add `h34-selfcheck.sh` to `sandboxCheckList`; tear the Cursor sandbox down inside the check. Bash 3.2 and BSD tools only (shell.md portability).

---

### `tests/host/run-all.sh` and `tests/host/lib-docker.sh` (config / utility, file-I/O)

**Analog:** itself. `run-all.sh` lines 21-25 hold the lists:
```bash
noSandboxCheckList="h03-... h12-plain-run-refused-pin-installed.sh h17-... h25-images-match-versions.sh h27-..."
sandboxCheckList="h01-native-arch.sh h04-nonroot-user.sh h05-workspace-and-home.sh h06-git-and-identity.sh h13-... h14-... h15-... h22-... h26-isolation-by-inspect.sh h30-version-line.sh"
```
Edit: `sandboxCheckList` drops h01, h04, h05, h13, h14, h15, h22, h30 and gains h34 (keep h06, h26); rename entry for h12 if the file is renamed. Main block (lines 261-274) shows the order; add `create_test_root_cert` (new function with its own banner, per shell.md) before `build_all_images`:
```bash
create_bundle_clone
remove_leftover_test_container
build_all_images
```
`build_all_images` calls `build_images build` from `lib-docker.sh`, which runs `bash "$REPO_DIR/build.sh"` with the caller's environment, so exporting `SBX_CA_CERT` before it reaches every later build. Helper shape to copy for the new cert function (lib-docker.sh style: banner per function, `local`, `|| return 1`):
```bash
# ------------------------------------------------------------------------------
# build_images LOG_PREFIX [--no-cache]: runs build.sh, logging to the run folder
# ------------------------------------------------------------------------------
```
Cert command (RESEARCH, key deleted at once, reused when the cert exists under `${TMPDIR:-/tmp}/sbx-hosttest-root-ca/`):
```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -subj "/CN=sbx-hosttest-throwaway-root" \
  -keyout "$keyFile" -out "$certFile" >/dev/null 2>&1 && rm -f "$keyFile"
```
Combine with the user's `SBX_CA_CERT` (Zscaler) in a run-folder file, user cert first; export `SBXTEST_ROOT_CA` for h34 (mirrors `SBXTEST_DIR` exported by `make_run_dir` in `lib.sh`). In `lib-docker.sh` delete `expected_arch` (no caller after h01 and h22 go); keep `pin_of` and `claude_pin`.

---

### `tests/host/h06`, `h12`, `h25` (slimming)

**Analog:** the files themselves; delete functions and their calls, update the PASS text.

- `h06-git-and-identity.sh`: keep `init_host_repo` (line 20) and `check_git_status` (46-52); remove `check_safe_directory` (55), `check_identity_stored` (64) and the `safeOutput`/`identityOutput` lines of `read_git_state` (35-41).
- `h12-...sh`: keep `check_plain_run_refused` (24-28); remove `check_pin_installed`, `pin`, `pinOutput`, the second `docker run`; the entry in `run-all.sh` and the header comment change to match.
- `h25-images-match-versions.sh`: keep `require_run_folder`, `check_record` (27-40), `check_bare_builds` (88+); delete `check_tool_versions` (45) and `check_workspace_empty` (67).

---

### `tests/guard/supply-chain.sh` (guard, transform)

**Analog:** line 14. Remove the term `tests/host/support/*.*` in the same commit that deletes `tests/host/support/toolchain-probe.sh`; otherwise grep exits 2 on the unmatched glob and `no_compromised_gsd_package` FAILs. Optionally add `base/selfcheck/* claude/selfcheck/* cursor/selfcheck/*` to the same scan list.

---

### `tests/selftest/selfcheck/*` and `pyproject.toml` (test / config)

**Analog:** none for pytest. Style reference `tests/selftest/entrypoint/` (real files in a temp dir, no mocks; fake docker in `tests/selftest/sbx/` must not be extended). Rules: abstract numbered fixture names (`certs1`), `tmp_path` real trees, each test independent. `conftest.py` puts `base/selfcheck`, `claude/selfcheck`, `cursor/selfcheck` on `sys.path`. Minimal root `pyproject.toml` (`requires-python = ">=3.12"`, dev dependency group with `pytest==9.2.0`, `[tool.pytest.ini_options]`), `.python-version` 3.12, `uv.lock`; add `.venv/`, `__pycache__/`, `.pytest_cache/` to `.gitignore` (currently ends with `host-test.log`). pytest runs in the dev sandbox only (D-18); `host-test.sh` is not changed to run it. The pytest pin is flagged SUS by the legitimacy seam (new release); planner adds a human-verify checkpoint before pinning.

---

### Doc edits (doc)

**Analog:** neighbouring rows and sentences in each file. Follow `/home/sandbox/workspace/best-practices/rules/documentation.md` (match voice, schematic, no dashes as punctuation).
- `tests/README.md`: add a `tests/selftest/selfcheck/` row; update the `tests/host/` row; fix the guard `Where` row (now line 24, the folded nit).
- `tests/host-checklist.md`: delete rows for H-01, H-04, H-05, H-13, H-14, H-15, H-22, H-30; slim H-06, H-12, H-25; add H-34; document the reused throwaway certificate directory.
- `README.md` (lines ~372-374 "Verify a new build" rows citing H-05, H-25, H-30; the "Scripts" sentence; line ~71 cert-cache text), `MIGRATION.md` "Check".
- The folded `tests/guard/isolation.sh:28` nit no longer exists; close with no edit.

## Shared Patterns

### Shell banners and layout
**Source:** `/home/sandbox/workspace/best-practices/rules/shell.md`, visible in every file under `tests/host/`
**Apply to:** `h34-selfcheck.sh`, new functions in `run-all.sh` and `lib-docker.sh`
Rule line is `# ` plus 78 hyphens; every function has a banner; end with `Main / Entry Point`; functions return non-zero instead of exiting; args first (`require_no_arguments "$@" || exit 2`); exit 0/1/2.

### Host-check reporting
**Source:** `tests/host/lib-report.sh` (`add_problem`, `report_check`, `first_lines`, `join_lines`, `fail`, `info`)
**Apply to:** `h34`, slimmed `h06`, `h12`, `h25`
```bash
report_check H-12 "the start check or the pinned version is wrong" "a plain docker run is refused ..."
```

### Test sandbox and timeouts
**Source:** `tests/host/lib-sandbox.sh` (`in_container` line 12, `run_timeout` line 87), `tests/host/lib-sbx.sh` (`sbx_test_setup`, `run_sbx`)
**Apply to:** `h34`. Never use `timeout`, `sed -i`, `stat -c`, `grep -P`; macOS bash 3.2, no associative arrays.

### Tracked-source gate
All analog paths above were checked as tracked in git (`base/Dockerfile`, `base/bin/*`, `tests/host/*`); none is a gitignored `.gsd/capabilities` mirror. The untracked `.gsd/` folder in the working tree is not referenced.

### Python style for all new Python
**Source:** `/home/sandbox/workspace/best-practices/rules/coding-general.md`
No comprehensions with conditions, no stream chains, braces-equivalent blank lines around `if`/`for`, early return, full names with collection suffix, no docstrings, no decision or phase IDs in source, argument lists for every subprocess (never `shell=True`, `stdin=DEVNULL`, `timeout=60`), never read or print credential contents, walk `state/` with `os.scandir` without following links.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `base/selfcheck/*.py`, `claude/selfcheck/claude.py`, `cursor/selfcheck/cursor.py` | utility / service | transform | No Python source in the repo; planner uses RESEARCH.md Patterns 1 to 4 and Code Examples, and ports assertions from the deleted bash probes |
| `tests/selftest/selfcheck/*.py` | test | transform | No pytest suite exists yet |
| `pyproject.toml`, `.python-version`, `uv.lock` | config | n/a | No Python project file exists; Phase 10 extends this one |

## Metadata

**Analog search scope:** `base/`, `claude/`, `cursor/`, `bin/`, `tests/host/`, `tests/guard/`, `tests/selftest/`, `host-test.sh`, `.gitignore`
**Files scanned:** about 30 read or grepped (full read of h12, lib-sbx.sh, lib-docker.sh; targeted reads of run-all.sh, h25, h06, h28, lib-report.sh, lib-sandbox.sh, supply-chain.sh, Dockerfiles, toolchain-probe.sh)
**Pattern extraction date:** 2026-11-14
