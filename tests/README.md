# Tests

These suites protect the images and the sandbox. Each runs in one place and catches one kind of mistake.

A new check needs a real failure it would have caught, not a hypothetical one.

| Suite | Command | Where it runs |
|---|---|---|
| `tests/guard/` | `bash tests/guard/run-all.sh` | any sandbox or Mac shell |
| `tests/selftest/entrypoint/` | `bash tests/selftest/entrypoint/run-all.sh` | Linux sandbox, no Docker |
| `tests/selftest/sbx/` | `bash tests/selftest/sbx/run-all.sh` | any Linux sandbox or Mac shell, no Docker |
| `tests/host/` and `tests/host/manual/` | `bash tests/host/run-all.sh` | the Mac, with Docker |
| `tests/host-checklist.md` | read it | the Mac, by hand |

On the Mac, `./host-test.sh` runs everything that needs Docker in one go: the host checks, the pin digests against the registry, the guard and the entrypoint self-test inside `sbx-hosttest`, the guard and the sbx self-test in the Mac shell (the guard with shellcheck and hadolint run from `sbx-base`, the self-test under `/bin/bash`). It writes all output to `host-test.log` in the repo root and ends with one OK or FAIL line per step. Pass `--keep` to leave the test sandbox up for `tests/host/manual/`.

There is no CI yet. Docs and shell portability have no automated check; PR review covers them.

## tests/guard/

| | |
|---|---|
| Runs | 17 rules that read the files only: pins and supply chain, the one-FROM Claude image, start hooks, the managed deny entries, isolation greps, host scripts other than `sbx-rm` that never delete data, shellcheck and hadolint |
| Where | New-layout sandbox: every rule passes, because sbx-base holds both linters. Old dev sandbox or a Mac shell by hand without the linters: the two linter rules FAIL as "not installed" and every other rule must PASS. `./host-test.sh` gives the Mac shell stand-ins that run both linters from `sbx-base`, so there every rule passes |
| Catches | An unpinned or floating version, a pipe-to-shell install, the compromised GSD package, a mounted Docker socket or privileged mode, a second FROM in the Claude image, a lost skill deny entry in the managed settings, a host script other than `sbx-rm` that deletes a file or takes a sandbox down, a badly named start hook, a shell or Dockerfile lint error |
| Does not catch | Whether an image builds or behaves (`tests/host/` does), or what `sbx-rm` removes (H-33 covers it) |

## tests/selftest/entrypoint/

| | |
|---|---|
| Runs | The real `base/sbx-start-lib.sh`, `base/sbx-entrypoint`, `claude/start.d/05-gsd` and `claude/start.d/10-best-practices` as plain bash in a temp folder, with a fake GSD |
| Where | Linux only (needs `/proc`) |
| Catches | A broken start hook step, the sandbox name rule, the project and state folders, the first GSD sync and its fail-closed stops, the bundle links (no clone, rerun, upgrade from copies) |
| Does not catch | Anything about the real image: mounts, users, file modes, links and special files in the hook folder. Host checks H-12, H-16, H-17, H-20 and H-21 cover those |

## tests/selftest/sbx/

| | |
|---|---|
| Runs | The real `bin/` scripts as plain bash in a temp folder, with `DOCKER_HOST` pointing at a socket that does not exist (no stand-in `docker`) and a registry in the work folder |
| Where | Linux and the Mac shell. `./host-test.sh` runs it under `/bin/bash` |
| Catches | A name, path or registry entry the scripts should refuse, a registry value that would run, a refusal that comes too late, Docker not answering reported as such |
| Does not catch | Anything that needs Docker to answer: starting, entering, listing and removing a sandbox. H-28 to H-33 cover it |

## tests/host/ and tests/host/manual/

| | |
|---|---|
| Runs | H-00 to H-33 against real Docker: builds, mounts, isolation (H-26), persistence, the bundle clone and its links (H-27 covers the wrappers and a push), the GSD sync, the `sbx-*` scripts (H-28, H-29 and H-31 to H-33) and the tool versions line (H-30) |
| Where | The Mac. `run-all.sh` is unattended; the helpers in `manual/` need a real terminal |
| Catches | Anything that only shows on the real images and mounts |
| Does not catch | Claude's login and behaviour; only the helpers in `manual/` cover them |

## tests/host-checklist.md

| | |
|---|---|
| Runs | Nothing; it is the reading guide |
| Where | The Mac |
| Catches | Says what each host check proves and how to read a failure |
| Does not catch | Anything by itself; the checks it lists do |
