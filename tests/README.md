# Tests

These suites protect the images and the sandbox. Each runs in one place and catches one kind of mistake.

A new check needs a real failure it would have caught, not a hypothetical one.

| Suite | Command | Where it runs |
|---|---|---|
| `tests/guard/` | `bash tests/guard/run-all.sh` | any sandbox or Mac shell |
| `tests/selftest/entrypoint/` | `bash tests/selftest/entrypoint/run-all.sh` | Linux sandbox, no Docker |
| `tests/selftest/guard/` | `bash tests/selftest/guard/run-all.sh` | Linux sandbox, no Docker |
| `tests/host/` and `tests/host/manual/` | `bash tests/host/run-all.sh` | the Mac, with Docker |
| `tests/host-checklist.md` | read it | the Mac, by hand |

On the Mac, `./host-test.sh` runs everything that needs Docker in one go: the host checks, the pin digests against the registry, the guard and both self-tests inside `sbx-hosttest`, and the guard in the Mac shell. It writes all output to `host-test.log` in the repo root and ends with one OK or FAIL line per step. Pass `--keep` to leave the test sandbox up for `tests/host/manual/`.

There is no CI yet. Docs and shell portability have no automated check; PR review covers them.

## tests/guard/

| | |
|---|---|
| Runs | 18 rules that read the files only: pins and supply chain, start hooks, isolation greps, shellcheck and hadolint |
| Where | New-layout sandbox: every rule passes, because sbx-base holds both linters. Old dev sandbox or Mac shell without the linters: the two linter rules FAIL as "not installed" and every other rule must PASS |
| Catches | An unpinned or floating version, a pipe-to-shell install, the compromised GSD package, a mounted Docker socket or privileged mode, a badly named start hook, a shell or Dockerfile lint error |
| Does not catch | Whether an image builds or behaves (`tests/host/` does) |

## tests/selftest/entrypoint/

| | |
|---|---|
| Runs | The real `base/sbx-start-lib.sh`, `base/sbx-entrypoint`, `claude/start.d/05-gsd` and `claude/start.d/10-best-practices` as plain bash in a temp folder, with a fake GSD |
| Where | Linux only (needs `/proc`) |
| Catches | A broken start hook step, the sandbox name rule, the project and state folders, the first GSD sync and its fail-closed stops, the bundle links (no clone, rerun, upgrade from copies) |
| Does not catch | Anything about the real image: mounts, users, file modes, links and special files in the hook folder. Host checks H-12, H-16, H-17, H-20 and H-21 cover those |

## tests/selftest/guard/

| | |
|---|---|
| Runs | The guard against a scratch copy of the repo with one planted problem each |
| Where | Linux only |
| Catches | A guard rule that can no longer fail |
| Does not catch | A missing rule; that is judged in PR review |

## tests/host/ and tests/host/manual/

| | |
|---|---|
| Runs | H-00 to H-26 and Coexistence against real Docker: builds, mounts, isolation (H-26), persistence, the bundle and the GSD sync |
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
