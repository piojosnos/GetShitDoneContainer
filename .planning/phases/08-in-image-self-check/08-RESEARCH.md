# Phase 8: In-image self-check - Research

**Researched:** 2026-11-14
**Domain:** a Python self-check runner baked into a Docker image (stdlib only), its Mac-side host check, and a throwaway root certificate in the test base image
**Confidence:** HIGH for everything read from this repo or run in the dev sandbox; MEDIUM for macOS (LibreSSL) behaviour and the Cursor GSD sync layout (flagged in the Assumptions Log)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Where the checks live
- **D-01:** The base image ships the runner (`sbx-selfcheck`) and the shared checks only (toolchain, user, git, env and so on). It knows nothing about Claude or Cursor.
- **D-02:** Each agent image adds its own checks file to a fixed folder (for example `/etc/sbx/selfcheck.d/claude.py` and `cursor.py`). The runner runs its shared checks plus every file in that folder. Nothing records which agent an image is for.

### Output
- **D-03:** One line per check, PASS or FAIL, easy to grep. There is no SKIP: outside a sandbox the checks that need the mounts simply FAIL, with a hint to run the command in a sandbox started with `sbx-start`. No code path exists that only a plain container would exercise.
- **D-04:** Each FAIL line has an indented `fix:` line under it. When the fix is on the Mac, the hint says so and gives the Mac command.
- **D-05:** No skill wraps the self-check; the fix hints carry the explanation. CHECK-04 and success criterion 4 were amended to say so.

### The host check
- **D-06:** One new host check runs `sbx-selfcheck` with `docker exec` in a Claude test sandbox and in a Cursor test sandbox. It fails on any FAIL line or when the number of checks differs from that agent's expected count. The two expected counts are constants in the host check, so a check that silently disappears fails the run.
- **D-07:** The run starts a Cursor test sandbox, which no host check does today. The user accepts the extra minute or so; revisit if the run gets long.

### What moves and what stays on the Mac
- **D-08:** Everything the old probes check from inside the container moves into the self-check: architecture, user and home owners, git and identity, pinned versions, env variables, wrappers and managed settings, bundle links, the toolchain, the versions record and the interactive-shell versions line.
- **D-09:** The toolchain check confirms each tool resolves to a path in the image, not under `/home`. This keeps H-22's point (the tools come from the image, not the mount) without a throwaway container.
- **D-10:** Probe files after this phase:

  | Probe | Result |
  |---|---|
  | H-01, H-04, H-05, H-13, H-14, H-15, H-22, H-30 | deleted: everything moves inside |
  | H-06 | slimmed: keeps "git works on a repo made on the Mac" |
  | H-12 | slimmed: keeps "a plain `docker run` is refused" |
  | H-25 | slimmed: keeps "the image's `versions.env` equals the repo's" and "a bare build is refused" |

- **D-11:** H-05's "a file made in the container shows up in the Mac folder" is dropped, not kept: H-06 (git on a Mac-made repo) and H-08/H-09 (files survive a recreate) already prove the mount.

### Extra checks
- **D-12:** Add every check that needs no login and no interaction and can be seen from inside: credentials file present (the planted fake passes it), git identity set, `state/` writable, no root-owned files except the known GSD sync leftovers (Phase 9 fixes those). "gh logged in" is out, because it needs a real token.

### Root certificate
- **D-13:** `./host-test.sh` makes a throwaway root certificate with `openssl`, builds it into the test base image through `SBX_CA_CERT`, and deletes the private key at once. Nothing is committed. No HTTPS server, no per-tool checks.
- **D-14:** The self-check confirms every extra certificate the build installed is in the system bundle and in Java `cacerts`. With no extra certificate there is nothing to confirm and the check passes.

### Claude's Discretion
- The exact name of the agent checks folder and how a checks file declares its checks.
- How each check is expressed in Python (small functions returning a result with a name and a hint).
- How the self-check knows which extra certificates the build installed (for example the `sbx-extra-ca-*.crt` files `build.sh` produces).
- How the interactive-shell versions line is checked from inside.
- Updating `tests/README.md`, `tests/host-checklist.md` and `README.md` for the new command and the removed probes.

### Folded Todos
- **Two wording nits from the phase 5 review** (`.planning/todos/pending/2026-11-08-retirement-review-nits.md`): the comment at `tests/guard/isolation.sh:28` and the guard row at `tests/README.md:25`. They were meant for the old sandbox doctor phase, which this phase replaces.

### Deferred Ideas (OUT OF SCOPE)
- If the Cursor test sandbox makes the run noticeably longer, revisit how the host run covers Cursor.
- Not folded: `2026-11-08-gsd-sync-leaves-root-owned-files.md` (Phase 9, INIT-06); the bundle hook todos and `2026-10-24-sbx-claude-no-wait-when-non-interactive.md` (Phase 9); `2026-10-24-bundle-clone-error-hint-and-option-guard.md` and `2026-10-26-sbx-gh-login-skip-when-logged-in.md` (future requirements).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CHECK-01 | `sbx-selfcheck` (Python, in the image) prints one PASS or FAIL line per named check; the base image holds the runner and the shared checks, each agent image adds its own checks | Runner and plugin design (Architecture Patterns), proposed 32 shared, 11 Claude and 9 Cursor checks, Dockerfile wiring, pytest plan |
| CHECK-02 | One host check runs `sbx-selfcheck` with `docker exec` in a Claude and a Cursor test sandbox and asserts no FAIL and each agent's expected count; the in-container parts of H-01, H-04, H-05, H-06, H-12, H-13, H-14, H-15, H-22, H-25 and H-30 are deleted | Probe-to-check mapping table, host check H-34 design, Cursor sandbox start via `sbx-add` and `sbx-start`, run-all and docs edits, the guard glob pitfall |
| CHECK-03 | The root certificate is checked automatically: a throwaway `openssl` certificate is built into the test base image and the self-check finds it in the system bundle and Java `cacerts` | Certificate section: file names, keytool and fingerprint comparison (run here), where the certificate is made, layer-cache and Zscaler pitfalls |
| CHECK-04 | The self-check doubles as the doctor: each FAIL prints a fix hint (with the Mac command where one is needed); no skill wraps it | `CheckResult` shape that cannot fail without a hint, hint conventions, `SBX_NAME` in hints |
</phase_requirements>

## Project Constraints (from CLAUDE.md and the user's standing rules)

- **Isolation:** agents never run on the host; each container sees only its project mount. The self-check must not widen anything and must never print credential contents. [CITED: .claude/CLAUDE.md "Constraints"]
- **GSD source:** only `@opengsd/gsd-core`; never `get-shit-done-cc` or `gsd-build`. The guard rule `no_compromised_gsd_package` scans files by glob (see Pitfall 1). [CITED: .claude/CLAUDE.md]
- **Docker is not available in the dev sandbox:** plans need host-side manual verification on the Mac, always through `./host-test.sh` and then reading `host-test.log`. [CITED: .claude/CLAUDE.md "Verification"; MEMORY.md mac-test-entry-point]
- **Shell portability:** scripts run on the Mac (stock bash 3.2, BSD tools); executor agents author on Linux (GNU). No `sed -i`, `stat -c`, `grep -P`, `timeout` in host code. In-container code may use GNU tools. [CITED: MEMORY.md shell-scripts-must-be-bsd-macos-portable]
- **Fake docker is quasi deprecated:** never extend `tests/selftest/sbx`; use a host check instead. [CITED: tests/README.md, 08-CONTEXT.md canonical refs]
- **Python rules:** logic goes in Python, not shell; pytest for tests; pin the Python version and dependencies with `uv`; imperative control flow (`if`/`for`, no comprehension chains); full descriptive variable names; collection suffix (`_list`, `_set`, `_by_name_map`); blank line before and after control-flow blocks; early return; no docstrings unless asked; ASCII only in source; no planning or decision IDs in committed code; no "was X" comments; prose and comments use no dashes as punctuation. [CITED: ~/workspace/best-practices/rules/coding-general.md, prose-style.md]
- **Real infrastructure over mocks; test data abstract:** pytest fixtures use numbered names (`certs1`), run against real files in `tmp_path`, mock only external boundaries. [CITED: coding-general.md "Testing"]
- **Write automated tests for new behavior** (the "no new tests for chores" rule was reverted 2026-11-10). [CITED: MEMORY.md write-tests-for-new-behavior]
- **Sandbox edits drop the exec bit on the Mac:** use `COPY --chmod` in Dockerfiles for anything executed; do not rely on git file modes. [CITED: MEMORY.md sandbox-edits-drop-exec-bit-on-mac]

## Summary

The phase is mostly translation work: eleven bash probes (about 1,300 lines) become one Python runner plus about 50 small check functions that run inside a real sandbox, and one new host check starts a Claude and a Cursor sandbox and asks the runner. Everything the old probes assert from inside the container is enumerated in the mapping table below, so nothing is silently lost. Three assertions cannot move inside and are called out: H-01's comparison with the Docker daemon's architecture, H-01's scan of build logs for platform warnings, and H-25's "nothing under the mount point in the image" (already enforced by a build-time smoke test in every Dockerfile).

The design is stdlib only. A small library module (`CheckResult`, `Check`, runner, helpers) and the shared checks live in the base image; each agent image drops one file into `/etc/sbx/selfcheck.d/`; the runner imports every `*.py` there and reads a module-level `CHECK_LIST`. The count of PASS/FAIL lines is therefore the count of declared checks, which is exactly what the host check pins with two constants. Python lives under `base/selfcheck/`, `claude/selfcheck/` and `cursor/selfcheck/`, not in the `bin/` folders, because the guard runs shellcheck on every `*/bin/*` file and shellcheck refuses a Python shebang (verified, SC1071).

Five pitfalls drive the plan more than anything else: (1) deleting `tests/host/support/toolchain-probe.sh` makes the guard rule `no_compromised_gsd_package` fail, because its glob `tests/host/support/*.*` then matches nothing (reproduced); (2) a fresh throwaway certificate per run busts the Docker layer cache for every layer after the apt step, so reuse one certificate outside the run folder; (3) the user works behind Zscaler and already exports `SBX_CA_CERT`, so the test must trust the user's certificate and the throwaway one together, which means the host check must match the throwaway certificate's SHA-256 fingerprint, not count certificates; (4) `versions.env` exists only in the agent images, so the shared pin checks read `/etc/sbx/versions.env` as a contract every `build.sh` image meets; (5) `cursor-agent --version` writes `cli-config.json`, so it must run with a throwaway `HOME` and no `CURSOR_CONFIG_DIR`, exactly as the Dockerfile smoke test does.

**Primary recommendation:** write `sbx-selfcheck` as a stdlib Python package under `base/selfcheck/` (library module, shared checks, thin launcher), agent files under `claude/selfcheck/` and `cursor/selfcheck/` copied to `/etc/sbx/selfcheck.d/`, one new host check `h34-selfcheck.sh` that starts the Cursor sandbox through `sbx-add` and `sbx-start`, and a pytest suite under `tests/selftest/selfcheck/` run with `uv`; fix the guard glob in the same commit that deletes the toolchain probe.

## Architectural Responsibility Map

The tiers here are the layers of this repo, not web tiers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Runner, result type, output format, exit code | Base image (`base/selfcheck/`) | none | D-01: the base owns the runner and knows no agent |
| Shared checks (toolchain, user, git, env, state, certificates, versions line base fields) | Base image | none | Everything the base Dockerfile installs or configures |
| Claude checks (CLI pin, managed settings, `.credentials.json`, rules link) | Claude image (`claude/selfcheck/claude.py`) | none | D-02: each agent image adds its own file; base never names an agent |
| Cursor checks (CLI pin, static channel, `auth.json`, home links) | Cursor image (`cursor/selfcheck/cursor.py`) | none | Same |
| Shared logic agents reuse (bundle links, versions-line prefix, owner and mode check) | Base image library module | Agent files call it | "A shared module for shared behavior": agent files declare, the library does the work |
| Expected check counts, planting identity and fake login, reading the output | Mac host check (`tests/host/h34-selfcheck.sh`) | `lib-sbx.sh` for the Cursor sandbox | D-06: counts are constants in the host check |
| Image record equals repo `versions.env`; plain `docker run` refused; bare build refused | Mac host checks H-25 and H-12 (slimmed) | none | Needs the repo or a container with no mount |
| Throwaway certificate creation and `SBX_CA_CERT` export | Mac host run (`tests/host/run-all.sh`, helper in `lib-docker.sh`) | `build.sh` splits it, base Dockerfile installs it | `openssl` and the key live on the Mac only |
| Unit tests of runner and helpers | `tests/selftest/selfcheck/` (pytest, dev sandbox and CI) | optionally inside `sbx-hosttest` | Pure logic, no Docker |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Python stdlib (`dataclasses`, `subprocess`, `importlib.util`, `os`, `pathlib`, `json`, `hashlib`, `ssl`, `re`, `platform`, `pwd`) | Python 3.12.3 from Ubuntu 24.04 apt | The whole runner and every check | Already in the base image; no install, no new supply-chain surface. [VERIFIED: base/Dockerfile:31 `python3 python3-venv python3-pip \`; `python3 --version` in this sandbox printed `Python 3.12.3`; /etc/sbx/tool-versions here ends `python 3.12.3`] |
| `keytool` (Temurin 21) | 21.0.12 | Read Java `cacerts` fingerprints | Linked into `/usr/local/bin` by the base Dockerfile; the same tool the build uses to import. [VERIFIED: base/Dockerfile:113 `keytool -importcert -noprompt -cacerts -storepass changeit -alias "$(basename "$certFile" .crt)" -file "$certFile" \|\| exit 1; \`; ran `keytool -list -cacerts -storepass changeit` here] |
| `openssl` (Mac, host run only) | OpenSSL 3.0.13 here; LibreSSL on macOS | Make the throwaway certificate | `build.sh` already requires it when `SBX_CA_CERT` is set. [VERIFIED: build.sh:`command -v openssl` check in prepare_extra_cert] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| pytest | 9.1.1 or 9.2.0 (exact pin, needs approval, see audit) | Unit tests of the runner and helpers | Dev sandbox, CI, optionally inside `sbx-hosttest`; never in an image |
| uv | 0.12.21 (already in the image and in this sandbox) | Run pytest with a pinned Python and dependency set | `uv run pytest tests/selftest/selfcheck` [VERIFIED: ran `uv run --no-project --with pytest python -c 'import pytest'` here, printed 9.2.0] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| stdlib `dataclasses` result type | `pydantic`, `attrs` | Would need an install into the image; nothing here needs validation beyond one `ValueError` |
| Parse `keytool -list` text | A Java keystore library (`pyjks`) | New dependency in the image for one comparison; keytool output is stable and was verified |
| Parse certificates with `openssl` in the image | Python `ssl.PEM_cert_to_DER_cert` and `hashlib` | `openssl` exists in the image (ca-certificates depends on it) but Python needs no subprocess; fingerprints matched in the test below |

**Installation:** no image installs. Dev only: add a `pyproject.toml` with a pytest dependency group and run `uv lock`, then `uv run pytest`.

**Version verification:** `pip index versions pytest` lists 9.2.0 as newest; PyPI upload times: 9.1.1 on 2026-06-19, 9.2.0 on 2026-10-27, `requires_python >=3.10`. [VERIFIED: pypi.org/pypi/pytest/json fetched in this session]

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| pytest | PyPI | about 20 yrs (2.0.0 up to 9.2.0; 100+ releases) | seam returned null | github.com/pytest-dev/pytest | SUS (seam reasons: `too-new`, `unknown-downloads`) | Flagged, planner adds `checkpoint:human-verify` before pinning |

`gsd-tools query package-legitimacy check --ecosystem pypi pytest` returned `"verdict": "SUS"` with `"reasons": ["too-new", "unknown-downloads"]`; `publishedAt` was 2026-10-27, the newest release. The verdict reflects the age of the latest release and missing download data, not the project. Pinning 9.1.1 (released 2026-06-19) sidesteps the "too-new" heuristic, but the planner should still put a human approval checkpoint before the pin, as this repo did for every other pin.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** `pytest` (dev only; never installed in an image). `pytest` was named by the user's own rules, not discovered by search, but it is tagged per the seam anyway.

No package is installed into an image by this phase.

## Architecture Patterns

### System Architecture Diagram

```
 MAC                                     IMAGE (any sandbox: user's own or a test sandbox)
 ---                                     -------------------------------------------------
 host-test.sh
   |
   +-> tests/host/run-all.sh
         |  make test root cert (openssl, key deleted at once, reused across runs)
         |  SBX_CA_CERT = user's cert (if any) + test cert
         |  build.sh -> sbx-base:test, sbx-claude:test, sbx-cursor:test
         |
         +-> compose_up  (Claude test sandbox "hosttest")
         +-> h34-selfcheck.sh
               |  1. plant git identity + fake credentials (docker exec, as sandbox)
               |  2. docker exec sbx-hosttest sbx-selfcheck > log
               |  3. assert: 0 FAIL lines, N_claude PASS lines, cert fingerprint in both cert lines
               |  4. sbx-add + clone fixture + sbx-start  (Cursor test sandbox "hosttest-cursor")
               |  5. plant, docker exec sbx-hosttest-cursor sbx-selfcheck, assert N_cursor
               |  6. sbx-rm hosttest-cursor --yes
               v
                                            /usr/local/bin/sbx-selfcheck (launcher)
                                                 |
                                                 v
                                       sbx_selfcheck.py (runner)
                                          |             |
                          shared_checks.CHECK_LIST   /etc/sbx/selfcheck.d/*.py (sorted)
                          (base image)               each exposes CHECK_LIST
                                          \             /
                                           run each Check (exception -> FAIL line)
                                                 |
                              stdout: "PASS: name: detail" | "FAIL: name: detail" + "      fix: hint"
                              last line: "sbx-selfcheck: N checks, M failed"   exit 0 or 1
```

### Recommended Project Structure

```
base/selfcheck/
  sbx-selfcheck          # launcher, mode 755 -> /usr/local/bin/sbx-selfcheck
  sbx_selfcheck.py       # CheckResult, Check, runner, shared helpers -> /usr/local/lib/sbx-selfcheck/
  shared_checks.py       # CHECK_LIST of the shared checks            -> /usr/local/lib/sbx-selfcheck/
claude/selfcheck/claude.py   -> /etc/sbx/selfcheck.d/claude.py   (CHECK_LIST)
cursor/selfcheck/cursor.py   -> /etc/sbx/selfcheck.d/cursor.py   (CHECK_LIST)
tests/selftest/selfcheck/    # pytest: test_runner.py, test_helpers.py, conftest.py
tests/host/h34-selfcheck.sh  # the one new host check
pyproject.toml, uv.lock, .python-version   # minimal pytest pin (see Open Questions)
```

Why not `base/bin/`: `SHELL_FILES` contains `base/bin/* claude/bin/* cursor/bin/*`, and shellcheck on a Python shebang prints `error: ShellCheck only supports sh/bash/dash/ksh/'busybox sh' scripts. Sorry! [SC1071]` (ran it here). [VERIFIED: tests/guard/lib.sh:`SHELL_FILES="build.sh clean.sh host-test.sh bin/* base/sbx-entrypoint base/sbx-start-lib.sh base/bin/* claude/start.d/* cursor/start.d/* claude/bin/* cursor/bin/* tests/*/*.sh tests/*/*/*.sh tests/selftest/*/support/fake-gsd"`] `.dockerignore` already allows `base`, `claude` and `cursor` into the build context, so the new folders need no change. [VERIFIED: .dockerignore `!base` `!claude` `!cursor` `!versions.env`]

### Pattern 1: result type that cannot fail without a hint (CHECK-04)

**What:** a frozen dataclass plus two constructors. `failed()` raises `ValueError` on an empty hint, so a FAIL without a fix is a programming error caught by pytest, not a convention.
**When to use:** every check.
**Example (sketch; style follows the user's rules):**
```python
# base/selfcheck/sbx_selfcheck.py
from dataclasses import dataclass
from typing import Callable


@dataclass(frozen=True)
class CheckResult:
    passed: bool
    detail: str
    hint: str


def passed(detail):
    return CheckResult(True, detail, "")


def failed(detail, hint):
    if not hint:
        raise ValueError("a failed check needs a fix hint")

    return CheckResult(False, detail, hint)


@dataclass(frozen=True)
class Check:
    name: str
    function: Callable[[], CheckResult]
```

### Pattern 2: declare checks as a list, run each in isolation

**What:** each module (shared or agent) defines `CHECK_LIST = [Check("user-sandbox", check_user), ...]`. The runner calls each function inside `try/except Exception`; an exception becomes a FAIL line carrying the exception text and a generic hint, so one broken check never hides the others. A file in the agent folder that fails to import becomes one FAIL line named `load-<stem>`.
**Why a list, not a decorator or a naming convention:** the name is known even when the function raises, the count is `len(list)`, and a reader sees every check of a file in one place (symmetry between shared, Claude and Cursor).
**Example:**
```python
def run_checks(check_list):
    outcome_list = []

    for check in check_list:
        try:
            result = check.function()
        except Exception as error:
            result = failed(f"raised {type(error).__name__}: {error}",
                            "this is a bug in the self-check; report it with this line")

        outcome_list.append((check.name, result))

    return outcome_list
```

### Pattern 3: output format (symmetric with the guard and host checks)

The guard prints `PASS: rule`, the host checks print `PASS: H-NN text` and print details indented six spaces. [VERIFIED: tests/guard/lib.sh `echo "PASS: $rule"`; tests/host/lib-report.sh `printf 'FAIL: %s %s\n'` and `printf '      %s\n' "$1"`] Use the same shape:

```
PASS: user-sandbox: uid 1000, gid 1000, name sandbox
FAIL: git-identity: git user.email is not set
      fix: run sbx-gh-login in this sandbox; it asks for the name and email
sbx-selfcheck: 43 checks, 1 failed
```

- The host check counts `^(PASS|FAIL): ` lines. The closing summary line must not start with PASS or FAIL.
- Exit status: 0 when no check failed, 1 otherwise, 2 for a usage error (any argument).
- Hints name the sandbox through `os.environ["SBX_NAME"]` when it is set (compose passes it into the container). [VERIFIED: compose.yml `environment:` `SBX_NAME: "${SBX_NAME}"`]. Mac fixes read like `on the Mac run: sbx-upgrade NAME`.
- Every subprocess call: argument list, never `shell=True`, `stdin=subprocess.DEVNULL`, `timeout=60`; a `TimeoutExpired` becomes a FAIL via Pattern 2.
- Do not follow symlinks when walking `state/` (use `os.scandir` and `lstat`), and never read credential files (presence and size only).

### Pattern 4: parameterised helpers, constants as defaults

Per the "overloads" rule, helpers take their paths as parameters and a thin check passes the image constants. This is what makes the pure logic testable in `tmp_path` without Docker:

```python
def bundle_links_result(config_dir, bundle_dir, links_rules):
    ...

def check_claude_bundle_links():
    return bundle_links_result(Path(os.environ["CLAUDE_CONFIG_DIR"]),
                               Path(os.environ["SBX_BUNDLE_DIR"]), True)
```

### Anti-Patterns to Avoid

- **A SKIP outcome or an "outside a sandbox" branch:** D-03 forbids it; no run would exercise it.
- **Base code that names an agent:** shared checks must not mention `claude` or `cursor`; the agent file calls a shared helper with its own config folder and mode.
- **`source`-ing or `eval`-ing `/etc/sbx/versions.env`:** parse `NAME=value` lines as text. The project reads registry files "as text and never sourced" for the same reason. [CITED: bin/sbx-lib.sh read_registry_entry banner]
- **Running `cursor-agent --version` in the real sandbox environment:** see Pitfall 6.
- **Copying the expected check count into the Python:** the count lives only in the host check (D-06); the runner must not know it.

## Probe-to-check mapping (D-08: nothing silently lost)

Legend: S = shared (base), C = Claude file, U = Cursor file, HOST = stays on the Mac, DROP = removed on purpose.

### H-01 (native arch), H-04 (user), H-05 (home)

| Probe assertion (today) | Becomes | Where |
|---|---|---|
| H-01: both images' `Architecture` equals the daemon's | no in-container equivalent; see Open Question 3 | HOST (or DROP) |
| H-01: `uname -m` in the container equals the daemon's | `architecture`: `platform.machine()` is `aarch64` or `x86_64` and the ELF machine bytes of node, gh, uv, java and python3 match it | S |
| H-01: no build log holds `does not match the detected host platform` or `InvalidBaseImagePlatform` | fold the same grep into the existing `build_warnings` step of `host-test.sh` (3 lines) | HOST |
| H-04: `id` starts `uid=1000(sandbox) gid=1000(sandbox)` | `user-sandbox` | S |
| H-05: a file created in the container reaches the Mac folder | dropped by D-11 | DROP |
| H-05: `ls -a /home/sandbox` lists `.bashrc` and `.local` | `home-layout` | S |
| H-05: owner of `~/.local` and `~/.local/state` is `sandbox` | `home-owners` | S |

### H-06 (git, slimmed), H-12 (plain run, slimmed), H-13 (env)

| Probe assertion | Becomes | Where |
|---|---|---|
| H-06: `git status` on a Mac-made repo has no `dubious ownership` | stays | HOST (slimmed H-06) |
| H-06: `git config --system --get-all safe.directory` is `*` | `git-safe-directory` | S |
| H-06: identity set in the container reaches `state/git/config` on the Mac | replaced by `git-identity` (set and non-empty), `state-writable`, `env-state-paths` (`GIT_CONFIG_GLOBAL` under `state/`) and the persistence checks H-08 and H-09; the Mac-sees-the-file assertion goes | S |
| H-12: plain `docker run` exits 1 with `[sbx] ERROR` and `not a mount point` | stays | HOST (slimmed H-12) |
| H-12: `claude --version` equals `<pin> (Claude Code)` | `claude-version` | C |
| H-13: `CLAUDE_CONFIG_DIR`, `DISABLE_UPDATES=1`, `HISTFILE`, `GH_CONFIG_DIR`, `GIT_CONFIG_GLOBAL` set in `docker exec` | `claude-env` (CLAUDE_CONFIG_DIR under `state/claude`, DISABLE_UPDATES is `1`) and `env-state-paths` (the other three, plus `NPM_CONFIG_CACHE`, `UV_CACHE_DIR`) | C and S |
| H-13: `~/.local/share/claude` and `~/.local/bin/claude` do not exist | `claude-no-home-copy` | C |

Running through `docker exec` is itself the proof that image `ENV` reaches non-entrypoint shells: the self-check reads `os.environ` in the process `docker exec` starts. [VERIFIED: base/Dockerfile:155 comment `docker exec shells never run the entrypoint, so they get these from ENV.`]

### H-14 (wrappers, hooks, managed settings)

| Probe assertion | Becomes | Where |
|---|---|---|
| `/etc/sbx/start.d`, `05-gsd`, `10-best-practices`, `sbx-gh-login`, `sbx-bundle-clone`, `sbx-claude` are `root:root` 755; `managed-settings.json` is `root:root` 644 | `wrappers-root-owned` (base wrappers plus `sbx-link-bundle`, `sbx-entrypoint`, `sbx-selfcheck` 755, `sbx-start-lib.sh` 644), `claude-wrappers` (`sbx-claude`, the two Claude hooks, managed settings) | S and C |
| Nothing under `/etc/sbx/start.d`, `/etc/claude-code`, the three wrappers is writable by `sandbox` | `image-paths-protected` (adds `/etc/sbx` and `/etc/sbx/selfcheck.d`) and `claude-image-paths-protected` | S and C |
| No mount under `/etc/sbx`, `/etc/claude-code`, `/usr/local/bin` | same two checks (field 5 of `/proc/self/mountinfo`) | S and C |
| `/opt/sbx/best-practices` does not exist | `no-bundle-copy` | S |
| `BUNDLE_REPO_URL` equals the pin; `SBX_BUNDLE_DIR` is the clone path | `env-bundle` | S |
| Managed settings parse; `additionalDirectories` is exactly the clone; `deny` is exactly the two Edit entries | `claude-managed-settings` (derive the paths from `SBX_BUNDLE_DIR` and `CLAUDE_CONFIG_DIR` instead of repeating literals) | C |

### H-15 (bundle links), H-22 (toolchain), H-25 (record, tool pins), H-30 (versions line)

| Probe assertion | Becomes | Where |
|---|---|---|
| H-15 `check_bundle_links`: `rules` is a link to `../../best-practices/rules` and its content equals the clone's | `claude-bundle-links` via the shared helper `bundle_links_result` | C |
| H-15: each clone skill has a link `../../../best-practices/skills/NAME` | same | C and U |
| H-15: `.best-practices-skills` lists the clone's skills | same (compare as sets, because the hook writes glob order and a todo already notes the locale-order issue) | C and U |
| H-15: container reads the clone's rule equal to the Mac's | dropped; H-16 `check_edit_is_live` already reads the rule through `state/claude/rules` after a Mac edit | DROP |
| Cursor: skills linked, no rules link (new, symmetric) | `cursor-bundle-links` | U |
| H-22: git, gh, node, python3, uv, java, mvn found; jq, rg, unzip, zip, ssh, make, gcc exist; tzdata UTC | `tools-in-image` (all resolved with the default login `PATH`, resolved path not under `/home`, D-09) and `tzdata` | S |
| H-22: node, gh, uv equal their pins | `tool-node`, `tool-gh`, `tool-uv` | S |
| H-22: Temurin vendor, `java -version` equals the `TEMURIN_IMAGE` tag version | `tool-java` | S |
| H-22: `mvn -v` equals `MAVEN_VERSION` and runs on the pinned JDK | `tool-maven` | S |
| H-22: Python is 3 | `tool-python` | S |
| H-22: every native binary has the daemon's ELF machine | folded into `architecture` (against `uname -m`) | S |
| H-22: `JAVA_HOME` is `/opt/java/openjdk` | `java-home` | S |
| H-22: probe also runs in a throwaway base container and in `bash -lc` | replaced by the default-login-`PATH` lookup in `tools-in-image` | S |
| H-25: GSD `runtime-identity` is `{"packageName":"@opengsd/gsd-core","version":PIN}` | `tool-gsd` | S |
| H-25: `ccusage --version` is `ccusage PIN` | `ccusage-version` | C |
| H-25: image `/etc/sbx/versions.env` equals the repo's | stays | HOST (slimmed H-25) |
| H-25: nothing under `/home/sandbox/workspace` in the image | build-time smoke test already fails the build | DROP |
| H-25: bare builds refused | stays | HOST (slimmed H-25) |
| H-30: `/etc/sbx/tool-versions` equals the line from pins, jdk from the tag, python from the container | `versions-line-file` (base fields, S), `claude-versions-line`, `cursor-versions-line` (prefix fields) | S, C, U |
| H-30: `bash -i` prints the line once | `versions-line-interactive` | S |
| H-30: `bash -c true` and `bash -lc true` print nothing | `versions-line-quiet` | S |

The nothing-under-the-mount smoke test: [VERIFIED: base/Dockerfile `{ test -z "$(ls -A /home/sandbox/workspace)" || { echo "Files under the mount point:"; find /home/sandbox/workspace; exit 1; }; }`; the same line is in claude/Dockerfile and cursor/Dockerfile.]

### New checks (D-12 and sandbox shape)

| Check | Meaning | Where |
|---|---|---|
| `workspace-mount` | `/home/sandbox/workspace` is a mount point (field 5 of `/proc/self/mountinfo`) and writable | S |
| `project-folder` | `workspace/$SBX_NAME` exists | S |
| `state-folders` | `shell`, `gh`, `git` and every `SBX_STATE_DIRS` entry exist under `state/` | S |
| `state-writable` | a temporary file can be created and removed in `state/` | S |
| `no-root-owned-state` | no root-owned file under `state/` (skip `cache/npm`, `cache/uv`, `m2`; do not follow links) except the GSD sync leftovers | S |
| `git-identity` | `git config --global user.name` and `user.email` non-empty | S |
| `versions-record` | `/etc/sbx/versions.env` exists and parses as `NAME=value` lines | S |
| `claude-credentials`, `cursor-credentials` | `state/claude/.credentials.json`, `state/cursor/auth.json` exist and are non-empty; content never read or printed | C, U |
| `claude-gsd-synced`, `cursor-gsd-synced` | `<config>/gsd-core/VERSION` equals the image's GSD version | C, U |
| `cursor-version`, `cursor-env`, `cursor-self-update-off`, `cursor-home-links`, `cursor-wrappers` | see the inventory | U |
| `extra-ca-system-bundle`, `extra-ca-java-cacerts` | CHECK-03 and D-14 | S |

### Proposed inventory and counts (planner may merge or split; the host constants must equal the final sum)

Shared (32): `workspace-mount`, `project-folder`, `state-folders`, `state-writable`, `no-root-owned-state`, `user-sandbox`, `home-layout`, `home-owners`, `architecture`, `git-safe-directory`, `git-identity`, `env-state-paths`, `env-bundle`, `java-home`, `tools-in-image`, `tzdata`, `tool-node`, `tool-gh`, `tool-uv`, `tool-java`, `tool-maven`, `tool-python`, `tool-gsd`, `versions-record`, `versions-line-file`, `versions-line-interactive`, `versions-line-quiet`, `wrappers-root-owned`, `image-paths-protected`, `no-bundle-copy`, `extra-ca-system-bundle`, `extra-ca-java-cacerts`.

Claude (11): `claude-version`, `ccusage-version`, `claude-env`, `claude-no-home-copy`, `claude-credentials`, `claude-gsd-synced`, `claude-bundle-links`, `claude-wrappers`, `claude-managed-settings`, `claude-image-paths-protected`, `claude-versions-line`. Total 43.

Cursor (9): `cursor-version`, `cursor-env`, `cursor-self-update-off`, `cursor-home-links`, `cursor-credentials`, `cursor-gsd-synced`, `cursor-bundle-links`, `cursor-wrappers`, `cursor-versions-line`. Total 41.

Phase 9 coupling: the start hooks, `.best-practices-skills` and `cli-config.json` are written by hooks that Phase 9 replaces with `sbx-init`. Keep every hook-dependent check (`*-gsd-synced`, `*-bundle-links`, `cursor-self-update-off`, `*-wrappers` hook entries, the `start.d` part of `image-paths-protected`) in clearly named functions so Phase 9 edits only those, and note this in the plan.

## Root certificate (CHECK-03, D-13, D-14)

### What the build installs

| Fact | Source |
|---|---|
| `build.sh` splits `SBX_CA_CERT` into one file per PEM block named `sbx-extra-ca-N.crt`, N from 1 | [VERIFIED: build.sh:111 `out = sprintf("%s/sbx-extra-ca-%d.crt", dir, count)`] |
| The base Dockerfile copies them to `/usr/local/share/ca-certificates/`, runs `update-ca-certificates`, and writes the concatenation to `/etc/sbx/extra-ca.pem` | [VERIFIED: base/Dockerfile:44-47 `update-ca-certificates \`, `cat /mnt/*.crt > /etc/sbx/extra-ca.pem \`] |
| It then imports each into Java `cacerts` with alias equal to the file name without `.crt`, store password `changeit` | [VERIFIED: base/Dockerfile:113, quoted above] |
| The system bundle is `/etc/ssl/certs/ca-certificates.crt` | [VERIFIED: ls in this sandbox showed `/etc/ssl/certs/ca-certificates.crt`; base/Dockerfile:116 `cafile=/etc/ssl/certs/ca-certificates.crt`] |

### How to check from inside (all run in this sandbox)

1. Extra certificates = `sorted(glob("/usr/local/share/ca-certificates/sbx-extra-ca-*.crt"))`. Zero files means nothing to confirm; both checks pass with `no extra root certificate installed` (D-14).
2. Fingerprint of a file: `hashlib.sha256(ssl.PEM_cert_to_DER_cert(pem_text)).hexdigest().upper()`. For a test certificate this printed `5FEE950F4C0F30F36A5BC76208A65BF215E93D534DB74880FEE27A32F8E1DDEB`, equal to `openssl x509 -noout -fingerprint -sha256` with the colons removed.
3. System bundle: split `/etc/ssl/certs/ca-certificates.crt` with `re.findall(r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", text, re.S)` (found 120 blocks here), fingerprint each, test membership of the extra certificate's fingerprint.
4. Java: one `keytool -list -cacerts -storepass changeit` call (about 0.15 s here) prints entries as `ALIAS, DATE, trustedCertEntry,` then `Certificate fingerprint (SHA-256): AA:BB:...`. Parse every `Certificate fingerprint (SHA-256): ` line to a set (remove colons) and test membership. Also require the alias `sbx-extra-ca-N` to be present. I imported a test certificate into a copy of the real `cacerts` and `keytool -list -keystore ... -alias sbx-extra-ca-1` printed the same fingerprint as `openssl`.
5. Make the PASS detail carry the fingerprints (`2 extra root certificates found: 5FEE...DDEB, 1A2B...`), so the host check can match the throwaway one (below).

Dockerfile ordering note: the `cacerts` import happens in a separate `RUN` guarded by `/etc/sbx/extra-ca.pem`. A build where the apt-side step ran but the Java step silently did not would make `extra-ca-java-cacerts` FAIL, which is the regression the check exists to catch.

### Where the certificate is made

- **Make it in `tests/host/run-all.sh`, before `build_all_images`**, with a helper in `tests/host/lib-docker.sh`. `host-test.sh` runs `run-all.sh`, so "`./host-test.sh` makes it" holds, and a direct `bash tests/host/run-all.sh` keeps working (otherwise the host check's fingerprint assertion would fail standalone). Export `SBX_CA_CERT` for the rest of the run. Later builds (H-09 `build_images`, H-29 `sbx-upgrade`) inherit it. [VERIFIED: tests/host/lib-docker.sh `build_images` runs `bash "$REPO_DIR/build.sh"` with the caller's environment; tests/selftest/sbx/lib.sh:29 already unsets `SBX_CA_CERT` in `start_group`]
- Export a second variable (for example `SBXTEST_ROOT_CA`) with the path of the throwaway certificate alone, so `h34` can compute its fingerprint. This mirrors how `make_run_dir` exports `SBXTEST_DIR` to child checks. [VERIFIED: tests/host/lib.sh `SBXTEST_DIR=$RUN; export SBXTEST_DIR`]
- Command (portable form, key deleted at once):
```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -subj "/CN=sbx-hosttest-throwaway-root" \
  -keyout "$keyFile" -out "$certFile" >/dev/null 2>&1 && rm -f "$keyFile"
```
  `-keyout /dev/null` also worked with OpenSSL 3.0.13 here (the key never touches disk), but LibreSSL on macOS is unverified, so prefer the write-then-`rm` form that D-13 describes.

### Two traps that change the design

1. **Layer cache.** A new certificate every run changes the content of the `cacert` build context, and the README states the consequence: "The first build with a root, or after it changes or goes away, rebuilds every layer after the apt step once." [VERIFIED: README.md:71 quoted verbatim] Node, gh, JDK copy, Maven, GSD, Claude, ccusage and the Cursor CLI would all rebuild on every `./host-test.sh`. Recommendation: generate the throwaway certificate once into a stable folder outside the run folder (for example `${TMPDIR:-/tmp}/sbx-hosttest-root-ca/`), reuse it while it exists, never store the key. The certificate is public; with its key deleted it can sign nothing. See Open Question 1.
2. **The user's own `SBX_CA_CERT` (Zscaler).** The project exists partly because Zscaler blocks the build on the work Mac. If `run-all.sh` simply overwrites `SBX_CA_CERT`, a build behind the proxy fails with `curl: (60)`. Build a combined file for the run: the user's file (when set) followed by the throwaway certificate; `build.sh` already splits multi-certificate PEMs. [VERIFIED: build.sh prepare_extra_cert loops over every `-----BEGIN CERTIFICATE-----` block] Consequence: the self-check may see N+1 certificates, so the host check must not assert a count of 1. It asserts that the throwaway certificate's fingerprint appears in the `extra-ca-system-bundle` and `extra-ca-java-cacerts` PASS lines.

Host fingerprint (portable, no `shasum` needed): `openssl x509 -noout -fingerprint -sha256 -in "$SBXTEST_ROOT_CA" | sed 's/.*=//' | tr -d ':' | tr 'a-f' 'A-F'`. Both OpenSSL and LibreSSL print `...Fingerprint=AA:BB:...` after an equals sign; `build.sh` warns the prefix text differs, so only the text after `=` is used. [CITED: build.sh print_cert_banner comment "openssl output is only shown, never parsed, because LibreSSL and OpenSSL 3 format it differently"]

## The host check (CHECK-02, D-06, D-07)

New file `tests/host/h34-selfcheck.sh` (H-34 is the next free ID; IDs keep their gaps). Add it to `sandboxCheckList` in `run-all.sh` (it needs the running Claude test sandbox), and remove the deleted probes from that list. The Cursor sandbox must be torn down inside the check, before the restart chain, because H-32 and H-33 list and compare every `sbx-` container and a second live sandbox would disturb them. [VERIFIED: tests/host/h33-sbx-rm.sh `grep -v '^sbx-hosttest '` filter lets `sbx-hosttest-cursor` through; tests/host/run-all.sh `sandboxCheckList` runs before `chainCheckList`]

### Flow

1. `require_test_sandbox H-34 || exit 1`.
2. Plant, as the sandbox user via `docker exec` (not from the Mac), so ownership is deterministic: git identity (`git config --global user.name`/`user.email` with run-unique values) and the fake login file (`$CLAUDE_CONFIG_DIR/.credentials.json`). The checks `git-identity` and `claude-credentials` FAIL on an untouched fresh sandbox; that is correct doctor behaviour, so the host check must plant first. Do not print the planted text into logs beyond a run-unique token.
3. `run_timeout 120 docker exec sbx-hosttest sbx-selfcheck > $RUN/logs/h34-claude.out`; keep the exit status out of the decision, parse the output. Expect about 10 s (java, mvn, node, claude and ccusage start-ups).
4. Assert: `grep -Ec '^(PASS|FAIL): '` equals `expectedClaudeCount`; `grep -c '^FAIL: '` is 0; both `extra-ca-` PASS lines contain the throwaway fingerprint. On failure print the FAIL lines and their `fix:` lines as the detail (`first_lines` is too short; print them all).
5. Cursor: `sbx_test_setup H-34 h34` (own registry inside the run folder, `/bin/bash` first on `PATH`), `run_sbx ... sbx-add hosttest-cursor "$sbxDir" cursor`, make the clone (`make_bundle_clone "$RUN/bundle-origin.git" "$sbxDir/best-practices"`) before the start so the 10-best-practices hook links it, `run_sbx ... sbx-start hosttest-cursor`, plant identity and `state/cursor/auth.json`, `docker exec sbx-hosttest-cursor sbx-selfcheck`, assert `expectedCursorCount`.
6. Always finish with `run_sbx ... sbx-rm hosttest-cursor --yes` (also on failure paths), so no `sbx-hosttest-cursor` container or network is left. [VERIFIED: bin/sbx-rm usage `sbx-rm NAME [--unregister] [--yes]`; bin/sbx-add usage `sbx-add NAME HOST_PATH [claude|cursor]`; tests/host/lib-sbx.sh `sbx_test_setup` and `run_sbx`] This is first-party tooling (rule "First-party tooling") and exercises the real `sbx-start`, as D-01 of the CONTEXT intends ("a sandbox started by sbx-start").
7. Constants at the top of the file, with a comment saying where to count them (`grep -c` over the three check lists):
```bash
expectedClaudeCount=43
expectedCursorCount=41
```

Mac-only facts the plan must carry: `grep -E` and `grep -c` (BSD) are fine; no `timeout` (use `run_timeout`); `printf` not `echo -e`; bash 3.2 means no associative arrays, no `${var,,}`.

The sandbox name `hosttest-cursor` follows the name rule `^[a-z][a-z0-9-]{0,30}$`. [VERIFIED: base/sbx-start-lib.sh `sandboxNamePattern='^[a-z][a-z0-9-]{0,30}$'`]

### Edits that follow from the deletions

| File | Edit |
|---|---|
| `tests/host/run-all.sh` | `sandboxCheckList` loses h01, h04, h05, h13, h14, h15, h22, h30 and gains h34; `noSandboxCheckList` entry `h12-plain-run-refused-pin-installed.sh` renamed if H-12's file is renamed; add `create_test_root_cert` before `build_all_images` |
| `tests/host/h06-git-and-identity.sh` | remove `check_safe_directory`, `check_identity_stored`, the identity lines of `read_git_state`; keep `init_host_repo` and `check_git_status` |
| `tests/host/h12-...sh` | keep `check_plain_run_refused`; drop `check_pin_installed`, the `pin` use, and the second `docker run`; rename the file to say what it now proves |
| `tests/host/h25-images-match-versions.sh` | keep `check_record` and `check_bare_builds`; drop `check_tool_versions` and `check_workspace_empty`; update the PASS text |
| `tests/host/lib-docker.sh` | `expected_arch` has no caller after h01 and h22 go: delete it. Keep `pin_of` (used by h17), `claude_pin` (used by h27) |
| `tests/host/lib-bundle.sh` | keep `check_bundle_links`: h16 and h17 still call it [VERIFIED: grep showed one use each in h16 and h17] |
| `tests/host/support/toolchain-probe.sh` | delete with H-22 |
| `tests/guard/supply-chain.sh:14` | remove the term `tests/host/support/*.*` (Pitfall 1) |
| `host-test.sh` | comment `H-01 to H-33` in `host_checks`; add the platform-warning grep to `build_warnings`; optionally run the pytest suite in `sandbox_suites` |
| `tests/README.md`, `tests/host-checklist.md`, `README.md` | see Documentation edits |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Certificate fingerprint | A DER parser or `openssl` subprocess in the image | `ssl.PEM_cert_to_DER_cert` + `hashlib.sha256` | Verified equal to `openssl x509 -fingerprint` here |
| Java keystore reading | A keystore parser | `keytool -list -cacerts -storepass changeit` text | Same tool the build used; stable output |
| ELF architecture | `file`, `readelf` calls | `struct.unpack("<H", data[18:20])` of `/bin`-style files; `0xB7` is AArch64, `0x3E` is x86-64 | The old probe read the same two bytes with `od` [VERIFIED: tests/host/support/toolchain-probe.sh `od -An -tx1 -j18 -N2`]; here node, gh, uv, java and python3 all read `b7 00` on aarch64 |
| Mount detection | `mountpoint` or `findmnt` | Parse field 5 of `/proc/self/mountinfo` | util-linux is not guaranteed; the start library does the same [VERIFIED: base/sbx-start-lib.sh `is_mount() { awk -v p="$1" '$5==p { f=1 } END { exit !f }' /proc/self/mountinfo; }`] |
| Version comparison | Semver parsing | String equality or prefix against the pin | Pins are exact; the old probes used equality |
| Test runner for the checks | A shell harness | pytest through `uv` | The user's rule; Phase 10 extends it |
| Shell `timeout` on the Mac | `timeout` | the existing `run_timeout` in `tests/host/lib-sandbox.sh` | macOS has none |

**Key insight:** every check is a comparison of an observed value with an expected one; the only real logic is parsing three text formats (`versions.env`, `keytool -list`, the PEM bundle) and walking two folders. Keep those parsers small, pure and unit-tested; keep each check a five-line function over them.

## Common Pitfalls

### Pitfall 1: deleting the toolchain probe breaks a guard rule
**What goes wrong:** `no_compromised_gsd_package` passes the glob `tests/host/support/*.*` to grep. `tests/host/support/` holds `bundle/` (no dot) and `toolchain-probe.sh`. With the probe gone the glob matches nothing, bash passes the literal text, grep exits 2, and `nowhere_matches` reports `grep could not read every file it was given`. I reproduced it: `grep: support/*.*: No such file or directory`, `rc=2`.
**How to avoid:** remove that term in the same commit that deletes the probe. Optionally add the new scan paths (`base/selfcheck/*`, `claude/selfcheck/*`, `cursor/selfcheck/*`) to the same rule. [VERIFIED: tests/guard/supply-chain.sh:14, the whole line quoted in the file; tests/guard/lib.sh `nowhere_matches` returns 1 when `grepStatus -gt 1`]
**Warning signs:** guard prints `FAIL: no_compromised_gsd_package` after the deletion. A pending todo (`2026-10-24-guard-support-glob-and-h19-rule-names`) already describes this class of bug.

### Pitfall 2: Python under `*/bin/` fails the shellcheck rule
**What goes wrong:** shellcheck refuses a Python file (SC1071) and the rule `shellcheck_passes` fails.
**How to avoid:** put the sources in `base/selfcheck/`, `claude/selfcheck/`, `cursor/selfcheck/` and `COPY` them to the final names in the Dockerfile. No guard glob matches those folders.

### Pitfall 3: `COPY --chmod=644 dir/` also modifies directories
**What goes wrong:** a `--chmod=644` on a directory source gives the directory mode 644, which is not traversable by non-root. [ASSUMED: BuildKit behaviour from memory, not re-verified here]
**How to avoid:** copy single files with explicit destinations (`COPY --chmod=644 base/selfcheck/sbx_selfcheck.py /usr/local/lib/sbx-selfcheck/sbx_selfcheck.py`) and make the target folder with `mkdir -p` in a `RUN`. Existing single-file precedent: `COPY --chmod=644 versions.env /etc/sbx/versions.env`. [VERIFIED: claude/Dockerfile:86]

### Pitfall 4: a fresh certificate every run rebuilds everything
See "Two traps" above. Cache the certificate outside the run folder.

### Pitfall 5: Zscaler and a count of 1
See above. Match the fingerprint; build the combined file.

### Pitfall 6: `cursor-agent --version` writes state
**What goes wrong:** it writes `cli-config.json`; with `CURSOR_CONFIG_DIR` set in a live sandbox it would rewrite the file the `02-no-self-update` hook maintains.
**How to avoid:** run it as the Dockerfile smoke test does: a throwaway `HOME` from `tempfile.mkdtemp()` and the variable removed from the environment. [VERIFIED: cursor/Dockerfile:83 `test "$(env -u CURSOR_CONFIG_DIR HOME="$smokeHome" cursor-agent --version)" = "${CURSOR_AGENT_VERSION}"`, and the comment at line 78 `cursor-agent --version writes cli-config.json, so it runs with a throwaway HOME`]

### Pitfall 7: `versions.env` is only in the agent images
**What goes wrong:** the base image has no copy, so a shared check cannot read it in a plain base container, and the agent Dockerfiles say "Nothing reads it at runtime".
**Why this is fine:** D-03 says the self-check always runs in a sandbox, and every sandbox is an agent image built by `build.sh`. [VERIFIED: claude/Dockerfile:86 and cursor/Dockerfile:92 `COPY --chmod=644 versions.env /etc/sbx/versions.env`; base/Dockerfile has no such line] Do not copy it into the base: that would rebuild every agent image whenever any pin changes (a Cursor bump would reinstall Claude).
**How to avoid:** the shared checks read `/etc/sbx/versions.env`; the `versions-record` check says so when it is missing ("rebuild with `sbx-upgrade NAME` on the Mac"); update the two agent Dockerfile comments (and the README sentence) that claim nothing reads it.

### Pitfall 8: `bash -i` prints job-control noise on stderr
`docker exec ... bash -i` without a terminal writes `bash: cannot set terminal process group ... Inappropriate ioctl for device` to stderr. Capture stdout only and compare it to the file. Verified here with `subprocess.run(["bash","-i"], stdin=DEVNULL, capture_output=True)`: stdout was exactly the versions line plus a newline, stderr held the noise, `bash -c true` and `bash -lc true` printed nothing.

### Pitfall 9: GSD sync leftovers are root-owned, and the Cursor layout is unmeasured
**What goes wrong:** `no-root-owned-state` would FAIL on every sandbox.
**Evidence:** in this sandbox `find` under `state/` (skipping `cache` and `m2`) found 313 root-owned files: 279 in `claude/gsd-core`, 11 in `claude/hooks`, 23 in `claude/scripts`, matching the todo's count. [VERIFIED: ran the find in this session; todo 2026-11-08-gsd-sync-leaves-root-owned-files.md states "313 of the 820 files ... `gsd-core/`, `hooks/`, `scripts/`"] The scan took 0.13 s over 2,878 entries.
**Unknown:** the Cursor sync's root-owned set. [ASSUMED: same three folder names] Tolerate root-owned files only under `<state subfolder>/gsd-core/`, `hooks/` and `scripts/`, and print up to ten offending paths in the FAIL detail so the first Mac run shows any other location. Plan a task to read that output after the first Mac run and adjust.
**Not a problem:** files made on the Mac show as `sandbox`-owned in the container. [VERIFIED: `ls -la /home/sandbox/workspace` here lists the Mac-created `.DS_Store` as `sandbox sandbox`]

### Pitfall 10: a second live sandbox disturbs H-32 and H-33
Tear the Cursor sandbox down inside H-34 (see the flow).

### Pitfall 11: expected counts drift silently
If a check is added to a file but the host constant is not updated, the host check fails with a clear count message; that is the intended tripwire (D-06). Print both numbers in the failure text and name the three places to update.

### Pitfall 12: nits that already moved
The folded nit IN-01 (`tests/guard/isolation.sh:28`, "because removing them is how the old layout lost data") no longer exists: `grep -n "lost data\|old layout" tests/guard/*.sh` finds nothing and the rule's comment now reads "so no other script deletes data or takes a sandbox down". Confirm and close it with no edit. IN-02 is now line 24 of `tests/README.md` (the guard `Where` row), not 25: reword "Old dev sandbox or a Mac shell by hand without the linters" to "A dev sandbox without the linters, or a Mac shell by hand: ...", and the neighbouring "New-layout sandbox" to "A sandbox on the current images". [VERIFIED: grep and `sed -n 24p tests/README.md`]

### Pitfall 13: hint text will age with Phase 9
Hints mention `sbx-bundle-clone`, `sbx-stop` and `sbx-start` and the start-time relinking. Phase 9 replaces start-time hooks with `sbx-init`. Keep the hint strings in one place per check and tell the plan to re-read them in Phase 9.

## Code Examples

Sketches, not final code. Every discrete value below appears in a quote above.

### Parse `versions.env` as data

```python
def parse_versions_text(text):
    pin_by_name_map = {}

    for line in text.splitlines():
        stripped = line.strip()

        if not stripped or stripped.startswith("#"):
            continue

        name, separator, value = stripped.partition("=")

        if separator:
            pin_by_name_map[name] = value

    return pin_by_name_map
```

### Java fingerprints from `keytool -list`

```python
def java_fingerprint_set(keytool_text):
    fingerprint_set = set()
    marker = "Certificate fingerprint (SHA-256): "

    for line in keytool_text.splitlines():
        if line.startswith(marker):
            fingerprint_set.add(line[len(marker):].strip().replace(":", ""))

    return fingerprint_set
```

### ELF machine of the container's architecture

```python
ELF_MACHINE_BY_UNAME_MAP = {"aarch64": 0xB7, "x86_64": 0x3E}


def elf_machine(path):
    with open(path, "rb") as handle:
        header = handle.read(20)

    return int.from_bytes(header[18:20], "little")
```

### Shared bundle-link check (used by Claude with rules, by Cursor without)

The link targets and the list file come from the hook the images run today. [VERIFIED: base/bin/sbx-link-bundle `ln -s ../../best-practices/rules "$configDir/rules"`, `ln -s "../../../best-practices/skills/$skillName" "$configDir/skills/$skillName"`, `skillList=$configDir/.best-practices-skills`]

```python
def bundle_links_result(config_dir, bundle_dir, links_rules):
    problem_list = []
    expected_set = set()

    for skill_dir in sorted((bundle_dir / "skills").glob("*/")):
        expected_set.add(skill_dir.name)
        link_path = config_dir / "skills" / skill_dir.name

        if os.readlink(link_path) != f"../../../best-practices/skills/{skill_dir.name}":
            problem_list.append(f"skills/{skill_dir.name} is not linked into the clone")
    ...
```
(An `OSError` from `readlink` is a missing link; map it to a problem, do not let it escape.)

### Dockerfile wiring (base, agent)

```dockerfile
# base, after the helpers, as late as the smoke test allows
RUN mkdir -p /usr/local/lib/sbx-selfcheck /etc/sbx/selfcheck.d
COPY --chmod=755 base/selfcheck/sbx-selfcheck /usr/local/bin/sbx-selfcheck
COPY --chmod=644 base/selfcheck/sbx_selfcheck.py /usr/local/lib/sbx-selfcheck/sbx_selfcheck.py
COPY --chmod=644 base/selfcheck/shared_checks.py /usr/local/lib/sbx-selfcheck/shared_checks.py

# claude/Dockerfile, near the versions.env copy
COPY --chmod=644 claude/selfcheck/claude.py /etc/sbx/selfcheck.d/claude.py
```
Add `python3 -m py_compile` of each file in the same `RUN` so a syntax error fails the build (the managed-settings JSON check at claude/Dockerfile does the same for JSON). Put the base copies after the base smoke test: any base change rebuilds both agent images, so keep the self-check layers last. Hadolint threshold is `warning`, so `RUN`/`COPY` grouping needs no special care. [VERIFIED: .hadolint.yaml `failure-threshold: warning`]

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Eleven bash probes, each a `docker exec` or `docker run` from the Mac | One in-image command, one host check | Fewer Docker round trips; the same command is the user's doctor and Phase 11's CI check |
| Counting checks by reading the host summary | Expected count constants per agent | A check that disappears fails the run |
| Throwaway container to prove tools are in the image (H-22) | Resolve each tool and require a path outside `/home` | No extra container; keeps the point |

**Deprecated/outdated:** `.planning/codebase/TESTING.md` still describes the pre-v1 layout (`cc-up.sh`); do not use it as a source.

## Runtime State Inventory

Not a rename or migration phase. Skipped. (Deleted probes leave no runtime state; the Cursor test sandbox is removed by `sbx-rm --yes` inside the check.)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | macOS LibreSSL accepts `openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj ... -keyout F -out F2` and its config has a CA-capable default extension set | Root certificate | The cert step fails on the user's Mac; fallback: write a minimal config file or use `ecparam`; update-ca-certificates and keytool do not validate `CA:TRUE`, so the extension is not needed |
| A2 | An unchanged certificate file keeps the `cacert` build context identical, so layers after the apt step stay cached | Root certificate | If BuildKit keys on something unstable, every run rebuilds anyway; cost is time, not correctness |
| A3 | The Cursor GSD sync leaves root-owned files only under `gsd-core/`, `hooks/`, `scripts/` | Pitfall 9 | `no-root-owned-state` FAILs in the Cursor sandbox on the first Mac run; fix by widening the tolerance after reading the printed paths |
| A4 | `COPY --chmod=644` on a directory makes it non-traversable | Pitfall 3 | None if files are copied one by one, as recommended |
| A5 | Starting the Cursor sandbox (GSD sync via the 05-gsd hook) takes about a minute | Host check | User already accepted "a minute or so" (D-07); `sbx-start` waits up to 120 s, so a slower start would fail the check |
| A6 | OpenSSL and LibreSSL both print the SHA-256 fingerprint as `...Fingerprint=AA:BB:...` | Root certificate | Host fingerprint extraction returns garbage; the check would fail loudly, and the portable fallback is `openssl x509 -outform der | shasum -a 256` |
| A7 | The first Mac run after this phase rebuilds all layers after the apt step once (the test images gain a certificate for the first time) | Root certificate | Longer first run; nothing to fix |
| A8 | `uv` can download pytest inside `sbx-hosttest` (network available, extra certificate trusted by `uv` through `system-certs`) if the pytest suite is added to `sandbox_suites` | Validation | The optional step fails behind a proxy; keep it optional or run pytest only in the dev sandbox and CI |

## Open Questions

1. **Reuse one throwaway certificate across runs, or make a new one per run?**
   - What we know: a new certificate per run busts the layer cache after the apt step (README line 71), adding minutes to every `./host-test.sh`. A certificate whose key is deleted is public and inert.
   - What's unclear: whether the user reads "throwaway" as "new each run".
   - Recommendation: reuse one stored under `${TMPDIR:-/tmp}/sbx-hosttest-root-ca/`, create it when missing. Say so plainly in the plan and the checklist.
2. **Where does pytest configuration live?**
   - What we know: the rules ask for a pinned Python and dependencies through the project's tooling; Phase 10 later makes the host side Python and brings a larger pytest suite; the repo has no `pyproject.toml` today (searched: none).
   - Recommendation: a minimal root `pyproject.toml` (`requires-python = ">=3.12"`, a `dev` dependency group with the exact pytest pin, `[tool.pytest.ini_options] pythonpath` for the three selfcheck folders), plus `.python-version` (3.12) and `uv.lock`, plus `.venv/`, `__pycache__/`, `.pytest_cache/` in `.gitignore`. Phase 10 extends the same file.
3. **H-01's two Mac-only parts (image architecture versus the daemon, platform-warning scan).** D-10 deletes H-01 whole, but a mixed or emulated image would pass every in-container check (the container reports its own, emulated, `uname -m`).
   - Recommendation: keep the build-log warning scan by folding one grep into `build_warnings` in `host-test.sh`, and let H-34 compare the architecture the self-check reports (in the `architecture` PASS detail) with `docker info` in two lines. The user decides whether that stays within D-10.
4. **Run the pytest suite inside `sbx-hosttest` as a third entry of `sandbox_suites`?** It makes the unit tests part of the Mac gate without installing `uv` on the Mac (HOST-01 brings that in Phase 10). Cost: needs network inside the test sandbox (A8).
   - Recommendation: add it, but make the plan's gate for it the dev sandbox, so a network hiccup on the Mac does not block the phase.
5. **Granularity.** 43 and 41 lines is a lot of output for a doctor. If the user wants fewer, merge `tool-*` into one line per tool group; the constants change, nothing else does.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3 | runner, pytest | yes (dev sandbox) | 3.12.3 | none needed |
| uv | pytest run | yes (dev sandbox) | 0.12.21 | `python3 -m venv` plus pip (slower) |
| network for uv | fetching pytest | yes here | pytest 9.2.0 resolved | none; vendor nothing |
| openssl | throwaway certificate | yes (dev sandbox 3.0.13); Mac LibreSSL assumed | | write the cert with Python? not recommended |
| keytool | Java cacerts check | yes (dev sandbox) | JDK 21.0.12 | none needed |
| shellcheck, hadolint | guard | yes (dev sandbox) | v0.11.0, v2.15.1 pins | none needed |
| Docker and Compose | image build, host check | no in the dev sandbox; yes on the Mac | Compose v2 required by `host-test.sh` | host-side manual verification via `./host-test.sh` |

**Missing dependencies with no fallback:** Docker in the dev sandbox; the Dockerfile edits and the host check can only be proven by a Mac run (project constraint). The dev sandbox gate is: pytest, guard, both self-test suites, `bash -n` on edited scripts, and a direct run of the runner from the repo for a smoke look.

**Dev-sandbox smoke:** `python3 base/selfcheck/sbx-selfcheck` run from the repo (outside an image) exercises most shared checks for real because this sandbox is itself an `sbx-claude` container, but its image is older, so counts and some results differ; treat it as a look, not a gate.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest (exact pin after approval) via `uv` for the Python; the existing bash suites for the guard and self-tests; real Docker on the Mac for `h34` |
| Config file | none today; Wave 0 adds `pyproject.toml` (see Open Question 2) |
| Quick run command | `uv run pytest tests/selftest/selfcheck -q` |
| Full suite command | `uv run pytest tests/selftest/selfcheck -q && bash tests/guard/run-all.sh && bash tests/selftest/sbx/run-all.sh && bash tests/selftest/entrypoint/run-all.sh`, then `./host-test.sh` on the Mac |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CHECK-01 | Runner loads the shared list plus every `*.py` in a folder, prints exactly one `PASS: ` or `FAIL: ` line per check, no SKIP, summary line not counted, exit 0/1/2, a broken agent file becomes `FAIL: load-NAME`, a raising check becomes FAIL | unit | `uv run pytest tests/selftest/selfcheck/test_runner.py -q` | no, Wave 0 |
| CHECK-01 | Helpers: versions parser, keytool parser, ELF machine, mount parser, bundle links, root-owned scan with tolerance, versions-line builder, each on real `tmp_path` trees | unit | `uv run pytest tests/selftest/selfcheck/test_helpers.py -q` | no, Wave 0 |
| CHECK-01 | Dockerfiles copy runner, library, shared checks and each agent file; `py_compile` step | static plus Mac build | `bash tests/guard/run-all.sh` (hadolint) and `./host-test.sh` | edit |
| CHECK-02 | Claude sandbox: 0 FAIL, count equals constant; Cursor sandbox: same | host | `./host-test.sh` (step "host checks", H-34) | no, new `tests/host/h34-selfcheck.sh` |
| CHECK-02 | Deleted probes are gone and nothing references them | static | `! ls tests/host/h01-* tests/host/h04-* tests/host/h05-* tests/host/h13-* tests/host/h14-* tests/host/h15-* tests/host/h22-* tests/host/h30-* 2>/dev/null` and `! grep -rnE 'h(01|04|05|13|14|15|22|30)-' tests host-test.sh` | n/a |
| CHECK-02 | Guard still passes after the glob edit (19 rules, or more if added) | guard | `bash tests/guard/run-all.sh` | edit |
| CHECK-03 | Throwaway certificate fingerprint appears in both `extra-ca-` PASS lines in both sandboxes | host | `./host-test.sh` (H-34) | new |
| CHECK-03 | Cert helper logic: finds a generated certificate in a bundle text, in keytool-format text, and fails when absent | unit | `uv run pytest tests/selftest/selfcheck/test_certs.py -q` (makes a certificate with `openssl` in `tmp_path`; nothing committed; the keytool sample is plain text with no key) | no, Wave 0 |
| CHECK-04 | `failed()` rejects an empty hint; every FAIL line is followed by a `fix:` line; a check that raises gets a hint | unit | `uv run pytest tests/selftest/selfcheck/test_runner.py -q` | no, Wave 0 |
| CHECK-04 | Hints for Mac-side fixes contain the Mac command (`sbx-upgrade`, `sbx-start`) | unit | one parametrised test over the hint strings of the mount, versions-record and tool-pin checks | no, Wave 0 |

### Sampling Rate
- **Per task commit:** `uv run pytest tests/selftest/selfcheck -q` (about 5 s) plus `bash tests/guard/run-all.sh`
- **Per wave merge:** the full dev-sandbox command above
- **Phase gate:** `./host-test.sh` green on the Mac, with `host-test.log` read; the Cursor `no-root-owned-state` output inspected once (A3)

### Wave 0 Gaps
- [ ] `pyproject.toml`, `.python-version`, `uv.lock`, `.gitignore` entries for `.venv/`, `__pycache__/`, `.pytest_cache/`
- [ ] `tests/selftest/selfcheck/conftest.py` (put the three selfcheck folders on `sys.path`)
- [ ] `tests/selftest/selfcheck/test_runner.py`, `test_helpers.py`, `test_certs.py`
- [ ] Framework install: `uv lock` then `uv run pytest` (after the pytest pin is approved)
- [ ] Guard: `tests/guard/supply-chain.sh` glob edit lands with the probe deletion

## Security Domain

`security_enforcement` is enabled in `.planning/config.json` (ASVS level 1, block on high). The self-check is not a security boundary; it reads and reports.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | The check only tests that a login file exists; it never reads or sends a credential |
| V3 Session Management | no | none |
| V4 Access Control | yes (light) | The runner and every agent file are root-owned and not writable by `sandbox`; `image-paths-protected` asserts it for `/etc/sbx`, `/etc/sbx/selfcheck.d` and `/usr/local/bin` |
| V5 Input Validation | yes | Treat `/etc/sbx/versions.env`, `keytool` output, the PEM bundle and JSON as data: split and compare, never `source`, `eval`, `exec` or `shell=True`; fixed `timeout` on every subprocess |
| V6 Cryptography | yes (narrow) | Use `hashlib` and `ssl`; never hand-roll a parser beyond PEM block splitting; the throwaway private key is deleted right after creation and never committed |
| V12 Files | yes | Walk `state/` without following symlinks (`lstat`); never print file contents from `state/` |
| V14 Configuration | yes | No secrets, hosts or machine paths hardcoded beyond the image's own fixed paths; names come from env or the image |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Planted `*.py` in the checks folder runs as `sandbox` | Tampering, Elevation (none gained) | Folder is root-owned 755 and asserted not writable; code runs as the same user that could already run it |
| Credential content leaks into a log or FAIL detail | Information disclosure | Checks stat the file only; fake test credentials are run-unique tokens |
| Symlink in `state/` points outside the mount during the root-owned scan | Tampering, Information disclosure | `os.scandir` with `follow_symlinks=False`; skip links |
| Hung subprocess blocks the doctor or the Mac run | Denial of service | `timeout=60` per call, `run_timeout 120` in the host check |
| Throwaway root certificate trusted by a user's images | Spoofing | Key never written to a persistent location; certificate only in test images (`:test` tag); user's `:local` images are untouched (IMG-02, guard rule `host_tests_never_name_the_local_tag`) |
| Pytest dependency compromise | Supply chain | Exact pin, human approval checkpoint, dev only, never in an image |

## Documentation edits (Claude's discretion list)

- `tests/README.md`: add a `tests/selftest/selfcheck/` row (pytest, runs in any Linux sandbox or CI); change the `tests/host/` row (range now has gaps, H-34 covers the in-image self-check, "the checks run a Claude sandbox" is no longer true: H-34 also starts a Cursor sandbox); reword the guard `Where` row (IN-02); the guard rule count stays 19 unless the plan adds rules.
- `tests/host-checklist.md`: delete the H-01, H-04, H-05, H-13, H-14, H-15, H-22 and H-30 rows; slim the H-06, H-12 and H-25 rows; add H-34; update the title range and the "keeps its gaps" sentence stays true.
- `README.md`: the "Verify a new build" table rows citing H-05, H-25 and H-30 (lines 372 to 374) now point at `sbx-selfcheck` and H-34; add `sbx-selfcheck` to the in-sandbox command sentence under "Scripts"; add a short "Doctor" or "Check a sandbox" paragraph (what it prints, `fix:` lines, run it in `sbx-shell NAME`; it FAILs in a plain `docker run`); the sentence "The host checks run a Claude sandbox" becomes "run a Claude and a Cursor sandbox"; the proxy section can point at the `extra-ca-*` lines instead of listing hand checks where they overlap.
- `MIGRATION.md` "Check": add `sbx-selfcheck` as a last step (the retired doctor phase planned it).
- Agent Dockerfile comments "Nothing reads it at runtime" (claude/Dockerfile:84, cursor/Dockerfile:90) become false once the self-check reads `versions.env`.
- No planning or decision IDs in any committed source or doc comment.

## Sources

### Primary (HIGH confidence, read or run this session)
- `.planning/phases/08-in-image-self-check/08-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/ROADMAP.md` (Phase 8 and 9 sections), `.planning/research/v2-simple-tooling-decisions.md`
- Repo files read in full: `base/Dockerfile`, `claude/Dockerfile`, `cursor/Dockerfile`, `build.sh`, `host-test.sh`, `compose.yml`, `versions.env`, `bin/sbx-lib.sh`, `base/sbx-start-lib.sh`, `base/sbx-entrypoint`, `base/bin/sbx-link-bundle`, `base/bin/sbx-gh-login`, `claude/start.d/*`, `cursor/start.d/*`, `claude/bin/sbx-claude`, `cursor/bin/sbx-cursor`, `claude/managed-settings.json`, `tests/host/{h01,h04,h05,h06,h12,h13,h14,h15,h22,h25,h30}*.sh`, `tests/host/support/toolchain-probe.sh`, `tests/host/lib*.sh`, `tests/host/run-all.sh`, `tests/guard/*.sh`, `tests/README.md`, `tests/host-checklist.md`, `README.md` (sections cited), pending todos for the nits and the root-owned files
- Commands run in this sandbox: `bash tests/guard/run-all.sh` (19 PASS), shellcheck on a Python file (SC1071), glob reproduction (grep rc 2), `openssl req` with `-keyout /dev/null`, `keytool -importcert` and `-list` on a copy of `cacerts`, Python fingerprint and bundle parsing, `bash -i`/`-c`/`-lc` from `subprocess`, `find ... -user root` over `state/`, `uv run --no-project --with pytest`, `gsd-tools query package-legitimacy check`, PyPI JSON for pytest

### Secondary (MEDIUM confidence)
- None used beyond the above.

### Tertiary (LOW confidence, flagged in the Assumptions Log)
- macOS LibreSSL behaviour (A1, A6), BuildKit `--chmod` on directories (A4), the Cursor GSD sync layout (A3), BuildKit cache keying on the named context (A2).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH, stdlib plus tools already in the image, versions read from the running image.
- Architecture and probe mapping: HIGH, every old assertion was read from its probe source.
- Host check and Cursor sandbox flow: MEDIUM, built from the existing `lib-sbx.sh` and `sbx-add`/`sbx-start`/`sbx-rm` but not runnable here (no Docker).
- Certificate section: HIGH inside the container, MEDIUM for the Mac-side `openssl` and cache behaviour.
- Pitfalls: HIGH for the guard glob, shellcheck and cursor `--version` (reproduced or quoted), MEDIUM for the rest.

**Research date:** 2026-11-14
**Valid until:** 2026-12-14 (the pins, the Phase 9 hook removal and the Phase 10 Python rewrite are the things that would change it)
