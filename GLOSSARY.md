# Glossary

Code, tests and docs use one term per concept, listed here. Review keeps it that way; no automatic check does.

## How a term is picked

1. An industry-standard term always wins.
2. Otherwise the name users type or see (a command, a check or a step name) wins, and the prose follows it.

## The best-practices repo and the host

| Concept | Term | Retired (where it was used) | Kept on purpose (why) |
|---|---|---|---|
| The user's repo of standing rules and skills, and this sandbox's clone of it | best-practices repo (the GitHub repo that `BEST_PRACTICES_REPO_URL` names); best-practices clone (`/home/sandbox/workspace/best-practices`, `$SBX_DIR/best-practices`) | "bundle", "the bundle", "bundle repo", "bundle skill" (the README best-practices section, `prompts/consolidate-memories.md`, `MIGRATION.md`, the clone command, its environment variable and pin, the selfcheck module and check names, test and host check file names) | "CA bundle" and "system bundle" for `/etc/ssl/certs/ca-certificates.crt` and the check `extra-ca-system-bundle` (industry term); "bundled with Node.js" (plain English) |
| The machine that runs Docker and the `sbx-*` commands | the host | "the Mac", "Mac" as a stand-in for the host, "your Mac user", "Mac modes" (README, `bin/` messages and comments, selfcheck hints, `host-test.sh` step names, host checks) | "macOS" (or "Docker Desktop") only where a fact holds only there, phrased "on a macOS host": BSD tools and bash 3.2, the Keychain, the case-insensitive default disk, the `user.containers.override_stat` attribute; the `### Mac OS ###` header in `.gitignore` (third-party template text) |

## Directories

| Concept | Term | Retired (where it was used) | Kept on purpose (why) |
|---|---|---|---|
| The word for a place in the file system | directory in prose and messages; `dir` in identifiers, file names, check and step names | "folder" (README, `MIGRATION.md`, test docs, `bin/`, `base/`, `claude/`, `cursor/`, the tests) | Third-party names that already say DIR or directory: `CLAUDE_CONFIG_DIR`, `CURSOR_CONFIG_DIR`, `GH_CONFIG_DIR`, `UV_CACHE_DIR`, git `safe.directory`, the Claude settings key `additionalDirectories`. `mkdir` and git use "directory" (industry term) |
| The one host directory mounted at `/home/sandbox/workspace` (`$SBX_DIR`) | sandbox directory | "host folder", "sandbox folder"; the `bin/` names `entryDir` and `hostPath` | The sandbox directory (host side, per sandbox) is bind-mounted as the workspace (container side, the same in every sandbox): same files, two views. Host-side code says "sandbox directory", container-side code says "workspace" |
| The user's code, `$SBX_DIR/<name>` | project directory | "project folder", "code folder", "your code folder", `codeDir` (`bin/sbx-fix-modes`, `MIGRATION.md`) | |
| `$SBX_DIR/state`: login, settings, history, caches | state directory | "state folder", "state dir" | |
| The agent's own config, `state/claude` or `state/cursor` (`CLAUDE_CONFIG_DIR`, `CURSOR_CONFIG_DIR`) | agent config directory; Python name `AGENT_CONFIG_DIR`, like `AGENT_BIN_DIR` and `AGENT_STEPS_DIR` | "config folder", "the agent's config folder", the Python name `CONFIG_DIR` | |
| The host's `~/.config/sbx` (`SBX_CONFIG_DIR`), which holds the registry | sbx config directory | "config folder" and "config dir" in this meaning (`bin/sbx-lib.sh` `configDir` stays: the host side has only this one) | |
| The host clone of this repo, whose `bin/` the host runs (`repoDir`) | tools clone | "repo folder"; "the repo" and "the clone" where they mean it | "best-practices clone" is a different clone (first group) |
| `/home/sandbox/workspace`, the mount point inside the container | the workspace | | Kept as is. It is the container-side view of the sandbox directory (same files) |
| The sandbox this repo is developed in (no Docker inside) | dev sandbox | | Kept; named here so nobody reads it as a product sandbox |

## Commands, checks and tests

| Concept | Term | Retired (where it was used) | Kept on purpose (why) |
|---|---|---|---|
| What a user types, and the file that holds it | command (`sbx-add`); script (the file) | "script" where the README means the command a user types | |
| `sbx-claude` and `sbx-cursor`, which exec `sbx-run-agent` | agent wrapper (always both words) | bare "wrapper" | A different thing from the launcher: the code shows an agent wrapper is one `exec sbx-run-agent` line, a launcher is a Python entry file |
| The Python entry file of `sbx-init` and `sbx-selfcheck` (`/usr/local/lib/<tool>/<tool>`, linked into `/usr/local/bin`) | launcher | | Kept (`LAUNCHER_FILE_LIST` in `image_roots.py`) |
| The four kinds of check | `sbx-init` step (prints OK or FAIL); `sbx-selfcheck` check (PASS or FAIL); guard rule (`tests/guard/`); host check | | The OK and PASS pair is a deliberate symmetry (`STEP_LIST` with OK, `CHECK_LIST` with PASS) |
| The container self-inspection command and its checks | selfcheck (one word, after `sbx-selfcheck`) | "self-check" (README, code comments, the printed hint "this is a bug in the self-check") | |
| The suite of fast tests that run without Docker | unit tests (suite directory `tests/unit/`) | "self-test", "selftest" (`host-test.sh`, suite headers, `tests/selftest/`) | "Unit tests" is the industry term, and dropping "selftest" stops it being confused with selfcheck |
| Host-side verification, by role | host check (one `tests/host/hNN-*.sh` file, with an H-nn ID); host tests (the suite `tests/host/`); host run (`./host-test.sh`) | Mixed use of "host check" and "host test" in the `tests/host/lib-*.sh` headers | The names (host versus integration) are revisited with the Python rewrite of the test suites |
| The store of sandboxes, one record per sandbox, and the actions on it | registry (the store under the sbx config directory); registry entry (one record); register and unregister (the actions) | The noun "registration" | Three roles, not synonyms: `registryDir`, `read_registry_entry`, `sbx-add` and `sbx-rm --unregister` |

## Names you type or see

| Concept | Term | Retired (where it was used) | Kept on purpose (why) |
|---|---|---|---|
| The command that clones the best-practices repo | `sbx-best-practices-clone` | `sbx-bundle-clone` (`base/bin/`, README, `MIGRATION.md`, test docs, the FAIL hint in the links check, host checks) | Keeps the `sbx-` prefix the image ownership check relies on |
| The clone path variable | `SBX_BEST_PRACTICES_DIR` | `SBX_BUNDLE_DIR` (`base/Dockerfile`, the clone command, an env check, README, host checks) | |
| The repo URL pin in `versions.env` | `BEST_PRACTICES_REPO_URL` | `BUNDLE_REPO_URL` (`versions.env`, `base/Dockerfile`, the clone command, an env check, README, test helpers) | |
| The selfcheck checks about the clone | `env-best-practices`, `no-best-practices-copy`, `claude-best-practices-links`, `cursor-best-practices-links` | `env-bundle`, `no-bundle-copy`, `claude-bundle-links`, `cursor-bundle-links` (the four check files and the inventory test) | The links checks now share their names with the init steps, like `state-dirs` |
| The state directory step and check | `state-dirs` | `state-folders` (`010_state_folders.py`, `030_state_folders.py`, inventory tests, README rows) | |
| The project directory check | `project-dir` | `project-folder` (`020_project_folder.py`, inventory tests) | |
| The image ownership checks | `image-root-owned`, `claude-image-root-owned`, `cursor-image-root-owned` | `wrappers-root-owned`, `claude-wrappers`, `cursor-wrappers` (they walk the image roots for root ownership and check no wrapper) | |
| Host check files and fixtures | `h27-best-practices-clone-and-publish.sh`, `h06-git-on-host-repo.sh`, `h10-missing-dir-refused.sh`, `lib-best-practices.sh`, `tests/host/support/best-practices/` | `h27-bundle-clone-and-publish.sh`, `h06-git-on-mac-repo.sh`, `h10-missing-folder-refused.sh`, `lib-bundle.sh`, `tests/host/support/bundle/` | |
| `host-test.sh` step names | "sbx unit tests in the host shell", "guard in the host shell", "run directory" | "sbx self-test in the Mac shell", "guard in the Mac shell", "run folder" | |
| The path argument of `sbx-add NAME HOST_PATH` | `HOST_PATH` | | Kept: it names where the path lives, and users type it |

## Spelling

| Concept | Term | Retired (where it was used) | Kept on purpose (why) |
|---|---|---|---|
| English spelling | American: initialized, behavior | "initialised", "uninitialised" (`tests/guard/start.sh`, `tests/host/h34-selfcheck.sh`), "behaviour" (`tests/README.md`) | |
