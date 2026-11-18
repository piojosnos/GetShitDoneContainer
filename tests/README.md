# Tests

These suites protect the images and the sandbox. Each runs in one place and catches one kind of mistake.

A new check needs a real failure it would have caught, not a hypothetical one.

| Suite | Command | Where it runs |
|---|---|---|
| `tests/guard/` | `bash tests/guard/run-all.sh` | any sandbox or Mac shell |
| `tests/selftest/sbx/` | `bash tests/selftest/sbx/run-all.sh` | any Linux sandbox or Mac shell, no Docker |
| `tests/selftest/init/` | `uv run pytest tests/selftest/init` | the dev sandbox (Linux, with uv); `./host-test.sh` does not run it |
| `tests/selftest/selfcheck/` | `uv run pytest tests/selftest/selfcheck` | the dev sandbox (Linux, with uv); `./host-test.sh` does not run it |
| `tests/host/` | `bash tests/host/run-all.sh` | the Mac, with Docker |
| `tests/host-checklist.md` | read it | the Mac, by hand |

On the Mac, `./host-test.sh` first checks that Docker Compose v2 is there and stops when it is not. It sets `SBX_IMAGE_TAG=test` for the whole run, so it builds and checks `sbx-base:test`, `sbx-claude:test` and `sbx-cursor:test` and never touches the `:local` images your sandboxes run; the log names the test images. The host checks build a throwaway root certificate into the test images; it is made once, kept in `$TMPDIR/sbx-hosttest-root-ca/` with its key deleted, and reused. Then it runs everything that needs Docker in one go: the host checks, the pin digests against the registry, the guard inside `sbx-hosttest`, the guard and the sbx self-test in the Mac shell (the guard with shellcheck and hadolint run from `sbx-base:test`, the self-test under `/bin/bash`). It writes all output to `host-test.log` in the repo root and ends with one OK or FAIL line per step. Pass `--keep` to leave the test sandbox up to look around after a failure.

There is no CI yet. Docs and shell portability have no automated check; PR review covers them.

## tests/guard/

| | |
|---|---|
| Runs | 20 rules that read the files only: pins and supply chain, the one-FROM agent images (Claude and Cursor), no entrypoint in the images or compose, the agents off the PATH, the compose image line and the `SBX_AGENT` and `SBX_IMAGE_TAG` hand-offs, agent builds on the base of their own tag, the managed deny entries, isolation greps, the self-check's Mac owner fix naming the container that `compose.yml` makes, host scripts other than `sbx-rm` that never delete data, host test files that never name a `:local` image, shellcheck and hadolint |
| Where | A sandbox on the current images: every rule passes, because sbx-base holds both linters. A dev sandbox without the linters, or a Mac shell by hand: the two linter rules FAIL as "not installed" and every other rule must PASS. `./host-test.sh` gives the Mac shell stand-ins that run both linters from `sbx-base:test`, so there every rule passes |
| Catches | An unpinned or floating version, a pipe-to-shell install, the compromised GSD package, a mounted Docker socket or privileged mode, a second FROM in an agent image, a lost skill deny entry in the managed settings, a self-check fix that names another container than `compose.yml`, a host script other than `sbx-rm` that deletes a file or takes a sandbox down, an entrypoint in an image or in compose, an agent linked into `/usr/local/bin` or without its smoke test by full path, a compose image line or `SBX_AGENT` hand-off that no longer follows the agent, a lost `SBX_IMAGE_TAG` hand-off or an agent build on another tag's base, a host test file that names a `:local` image, a shell or Dockerfile lint error |
| Does not catch | Whether an image builds or behaves (`tests/host/` does), or what `sbx-rm` removes (H-33 covers it) |

## tests/selftest/init/

| | |
|---|---|
| Runs | pytest on the `sbx-init` runner, its steps and libraries (`base/init/`, `claude/init/`, `cursor/init/`), the two wrappers `sbx-claude` and `sbx-cursor` with the `sbx-run-agent` script they share, `sbx-best-practices-clone` and `sbx-gh-login`, against real files, git and a real second process holding the lock, in a temp folder |
| Where | A Linux sandbox with uv (the dev sandbox). `./host-test.sh` does not run it |
| Catches | A step out of order, a lock or marker mistake, a user skill touched, an installer hang, a wrapper that starts an agent without init |
| Does not catch | Whether the steps work in a real image, which H-27, H-34 and H-35 cover |

## tests/selftest/sbx/

| | |
|---|---|
| Runs | The real `bin/` scripts as plain bash in a temp folder, with `DOCKER_HOST` pointing at a socket that does not exist and a registry in the work folder; `build.sh` with no `docker` on the PATH |
| Where | Linux and the Mac shell. `./host-test.sh` runs it under `/bin/bash` |
| Catches | A name, path or registry entry the scripts should refuse, a registry value that would run, a refusal that comes too late, Docker not answering reported as such, an image tag other than `local` or `test`, the image names each tag picks, and a `test` tag used without a line on stderr naming it |
| Does not catch | Anything that needs Docker to answer: starting, entering, listing and removing a sandbox. H-28 to H-33 cover it |

## tests/selftest/selfcheck/

| | |
|---|---|
| Runs | pytest on the runner, its libraries and the check files of `sbx-selfcheck` (`base/selfcheck/`, `base/selfcheck/checks/`, `claude/selfcheck/`, `cursor/selfcheck/` and the agent libraries in their `lib/` folders), one test file per library and per check file, against real files, git, openssl and keytool in a temp folder |
| Where | A Linux sandbox with uv (the dev sandbox). `./host-test.sh` does not run it |
| Catches | A check line too many or too few, a FAIL without a fix, a broken or missing checks file, the parsers (`versions.env`, `keytool`, the certificate bundle, mountinfo), the bundle links, the folder walk (one walker for the image ownership, the protected paths and the root-owned state scan), version and fingerprint matching, the certificate checks against the recorded fingerprints, and check counts that drift from H-34's constants |
| Does not catch | Whether the checks pass in a real image (H-34 does) |

## tests/host/

| | |
|---|---|
| Runs | H-03 to H-35 against real Docker (the IDs keep their gaps): builds, mounts, isolation (H-26), persistence, the first run and the clone links (H-27 and H-16: the wrappers, `sbx-init`, a push, relinking), the agents folder in a login shell inside an agent session (H-27 for Claude, H-34 for Cursor), the GSD sync, the `sbx-*` scripts (H-28, H-29 and H-31 to H-33), `sbx-init` and `sbx-selfcheck` in a Claude and a Cursor test sandbox (H-34, which also fails when a certificate check says no root was requested) and the ownership fix and the run lock of `sbx-init` (H-35) |
| Where | The Mac. `run-all.sh` and `./host-test.sh` are unattended |
| Catches | Anything that only shows on the real images and mounts |
| Does not catch | Claude's or Cursor's own behaviour and a real login: no check runs an agent, and H-09 and H-29 prove that planted login files survive. The checks run a Claude sandbox, H-34 also starts a Cursor one for the self-check, and a Cursor login and prompt are checked by hand |

## tests/host-checklist.md

| | |
|---|---|
| Runs | Nothing; it is the reading guide |
| Where | The Mac |
| Catches | Says what each host check proves and how to read a failure |
| Does not catch | Anything by itself; the checks it lists do |
