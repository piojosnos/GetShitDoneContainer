# Tests

These suites protect the images and the sandbox. Each runs in one place and catches one kind of mistake.

A new check needs a real failure it would have caught, not a hypothetical one.

| Suite | Command | Where it runs |
|---|---|---|
| `tests/guard/` | `uv run pytest tests/guard` | the dev sandbox, and `./host-test.sh` on the host |
| `tests/unit/sbx/` | `uv run pytest tests/unit/sbx` | the dev sandbox, and `./host-test.sh` on the host; no Docker |
| `tests/unit/init/` | `uv run pytest tests/unit/init` | the dev sandbox only (Linux, with uv); `./host-test.sh` does not run it |
| `tests/unit/selfcheck/` | `uv run pytest tests/unit/selfcheck` | the dev sandbox only (Linux, with uv); `./host-test.sh` does not run it |
| `tests/integration/` | `./host-test.sh` | the host only, with Docker |
| `tests/host-checklist.md` | read it | the host, by hand |

Every suite is pytest. The host never runs a bare `uv run`: the `.venv` it makes in the repo belongs to the dev sandbox. On the host, `./host-test.sh` is the one entry point.

## The host run

`./host-test.sh` (the host run) is a launcher into `sbx/host_test.py`.

- It first checks that Docker Compose v2 is there and stops when it is not.
- It sets `SBX_IMAGE_TAG=test` for the whole run, so it builds and checks `sbx-base:test`, `sbx-claude:test` and `sbx-cursor:test` and never touches the `:local` images your sandboxes run. The log names the test images.
- It runs one pytest process over `tests/unit/sbx`, `tests/integration` and `tests/guard`, in that order. The sbx unit tests need no Docker and fail fastest. The integration session builds `sbx-base:test`, and the guard's linter rules run shellcheck and hadolint from it, so the guard comes last.
- It writes all output to `host-test.log` in the repo root as it comes, so the log is readable while the run is still going. It ends with the pytest summary and one last line. How to read them is in [`host-checklist.md`](host-checklist.md).
- The integration scenarios build a throwaway root certificate into the test images. It is made once, kept in `$TMPDIR/sbx-test-root-ca/` with its key deleted, and reused.
- Pass `--keep` to leave the test sandboxes and the run directory up to look around after a failure.

There is no CI yet. Docs and shell portability have no automated check; PR review covers them.

## Scenarios

The integration suite is written as scenarios. A test function is one scenario, and the rule is stated here once.

- One scenario tells one story: its steps are `with step("..."):` blocks, run in code order.
- The first failed step ends the scenario, and the pytest report names it as `STEP FAILED: ...` under the failing assertion.
- A check outside the story gets its own scenario.
- Scenarios never depend on each other, and they have no order.
- The `sandbox` fixture (in `tests/integration/conftest.py`) brings the shared test sandbox to "running, init done" before each scenario. It starts the container when it is not running and runs `sbx-init` when the init marker is gone, so a scenario that stopped, recreated or upgraded the sandbox leaves nothing for the next one to repair. At the end of the run every test sandbox goes through `sbx-rm`, unless `--keep`.
- Each scenario and each fixture carries a banner of one to three schematic lines.
- Each scenario runs once for Claude and once for Cursor. The `agent` fixture gives it an `AgentSpec` (`tests/integration/agent_specs.py`), the one place that holds what differs between the agents. Adding an agent means adding a row there.
- Shared helpers (`step`, `run_sbx`, `docker_exec`, `inspect_container`) are in `tests/integration/scenario_helpers.py`.
- The one test that is not per agent is the pin digests test: it reads `versions.env` and starts no sandbox.

## tests/guard/

| | |
|---|---|
| Runs | Rules that read the files only: pins and supply chain, the one-FROM agent images (Claude and Cursor), no entrypoint in the images or compose, the agents off the PATH, the compose image line and the `SBX_AGENT` and `SBX_IMAGE_TAG` hand-offs, the managed deny entries, isolation greps, the selfcheck's host owner fix naming the container that `compose.yml` makes, every host launcher being two lines into an existing module with git mode 755, no host logic in shell, host modules other than `sbx/rm.py` and `sbx/clean.py` that never delete data, integration test files that never name a `:local` image, shellcheck and hadolint |
| Where | The dev sandbox on the current images: every rule passes, because `sbx-base` holds both linters. A shell without them runs the linters from `sbx-base:test` when it exists, else the two linter rules FAIL as "not installed"; every other rule must pass. `./host-test.sh` runs it after the integration suite built that image |
| Catches | An unpinned or floating version, a pipe-to-shell install, the compromised GSD package, a mounted Docker socket or privileged mode, a second FROM in an agent image, a lost skill deny entry in the managed settings, a selfcheck fix that names another container than `compose.yml`, a launcher with logic in it or a lost exec bit, a bash host script, bash test or stand-in tool tracked under `tests/`, a host module other than `sbx/rm.py` and `sbx/clean.py` that deletes a file or takes a sandbox down, an entrypoint in an image or in compose, an agent linked into `/usr/local/bin` or without its smoke test by full path, a compose image line or `SBX_AGENT` hand-off that no longer follows the agent, an integration test file that names a `:local` image, a shell or Dockerfile lint error |
| Does not catch | Whether an image builds or behaves (`tests/integration/` does), or what `sbx-rm` removes (the rm scenario covers it) |

## tests/unit/init/

| | |
|---|---|
| Runs | pytest on the `sbx-init` runner, its steps and libraries (`base/init/`, `claude/init/`, `cursor/init/`), the two agent wrappers `sbx-claude` and `sbx-cursor` with the `sbx-run-agent` script they share, `sbx-best-practices-clone` and `sbx-gh-login`, against real files, git and a real second process holding the lock, in a temp directory |
| Where | The dev sandbox (Linux, with uv). `./host-test.sh` does not run it |
| Catches | A step out of order, a lock or marker mistake, a user skill touched, an installer hang, an agent wrapper that starts an agent without init, an agent step file that does not load with the `sbx-init` import path |
| Does not catch | Whether the steps work in a real image, which the first run, init and selfcheck and owner fix scenarios cover |

## tests/unit/sbx/

`tests/unit/sbx/` calls the modules of `sbx/` in process, so it covers refusals and what a command does when Docker answers in a way the test chooses.

| | |
|---|---|
| Runs | Each module of `sbx/` with a registry in a temp directory and a recorder in place of Docker (`DockerRecorder` in `sbx_helpers.py`) that notes every call and answers from a table; `build.sh`, `clean.sh`, `host-test.sh` and every `bin/` launcher as processes from a directory outside the repo, as a user runs them from PATH; `sbx-migrate-registry` against old and new entries |
| Where | The dev sandbox, and `./host-test.sh` on the host. No Docker |
| Catches | A name, path or registry entry the commands should refuse, a registry value that would run, a refusal that comes too late, Docker not answering reported as such, an image tag other than `local` or `test`, the image names each tag picks, a `test` tag used without a line on stderr naming it, what `clean.sh` keeps and removes, the host run's Compose check and pytest arguments, an old registry file converted wrongly, a launcher that takes a wrong argument |
| Does not catch | Anything that needs Docker to answer for real: starting, entering, listing and removing a sandbox. The integration scenarios cover it |

## tests/unit/selfcheck/

| | |
|---|---|
| Runs | pytest on the runner, its libraries and the check files of `sbx-selfcheck` (`base/selfcheck/`, `base/selfcheck/checks/`, `claude/selfcheck/`, `cursor/selfcheck/` and the agent libraries in their `lib/` directories), one test file per library and per check file, against real files, git, openssl and keytool in a temp directory |
| Where | The dev sandbox (Linux, with uv). `./host-test.sh` does not run it |
| Catches | A check line too many or too few, a FAIL without a fix, a broken or missing checks file, the parsers (`versions.env`, `keytool`, the certificate bundle, mountinfo), the best-practices links, the directory walk (one walker for the image ownership, the protected paths and the root-owned state scan), version and fingerprint matching, the certificate checks against the recorded fingerprints, and check counts that drift from `selfcheck_count` in `agent_specs.py`, an agent check file that does not load with the `sbx-selfcheck` import path |
| Does not catch | Whether the checks pass in a real image (the init and selfcheck scenario does) |

## tests/integration/

| | |
|---|---|
| Runs | Scenarios against real Docker, each for Claude and for Cursor, in `tests/integration/test_*.py`: persistence across one `sbx-upgrade`, a failed upgrade that changes nothing, `sbx-upgrade` of a running sandbox, refusal (plain `docker compose` with a missing directory or an uppercase name), smoke (add, start and stop; shell; list; rm; git on a repository made on the host), isolation of the running container, the first run and the relink after a pull, `sbx-init` and `sbx-selfcheck` passing, `sbx-init` giving root-owned state back, and the image's `versions.env` equal to the repo's; plus the pin digests test, which is not per agent |
| Where | The host only, through `./host-test.sh`. The dev sandbox has no Docker |
| Catches | Anything that only shows on the real images and mounts: a lost login, setting, history, cache or file after a rebuild, a build failure that touches the running sandbox, a missing refusal, a widened mount or privilege, a broken first run or relink, a check that fails in the real image, an image built from other pins than the repo's, a digest pin the registry no longer resolves |
| Does not catch | Claude's or Cursor's own behavior and a real login: no scenario runs an agent, and the persistence scenario proves that planted login files survive. A Cursor login and prompt are checked by hand |

## tests/host-checklist.md

| | |
|---|---|
| Runs | Nothing; it is the reading guide |
| Where | The host |
| Catches | Says how to check a Cursor login by hand and how to read `host-test.log` |
| Does not catch | Anything by itself; the scenarios do |
