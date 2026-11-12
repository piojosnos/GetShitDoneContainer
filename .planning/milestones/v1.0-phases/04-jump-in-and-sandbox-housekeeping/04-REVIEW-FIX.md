---
phase: 04-jump-in-and-sandbox-housekeeping
fixed_at: 2026-11-08T00:00:00Z
review_path: .planning/phases/04-jump-in-and-sandbox-housekeeping/04-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 04: Code Review Fix Report

**Fixed at:** 2026-11-08
**Source review:** .planning/phases/04-jump-in-and-sandbox-housekeeping/04-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6 (WR-01 to WR-05, plus IN-04 on request)
- Fixed: 6
- Skipped: 0
- Branch: `chore/planning-phase-04-context` (no worktree: `workflow.use_worktrees` is false)
- Verification ran in the main checkout, Linux dev sandbox, no Docker

## Fixed Issues

### WR-01: H-31 greps for "TTY" but SANDBOX.md documents a newer wording

**Files modified:** `tests/host/h31-sbx-shell.sh`
**Commit:** 73474f5
**Applied fix:** the no-terminal check accepts `TTY|not a terminal` (case-insensitive), so both "the input device is not a TTY" and "stdin is not a terminal" count. The problem text names both wordings.
**Verification:** bash -n, shellcheck; the old `grep -qi TTY` does not match "stdin is not a terminal" (mutant confirmed).

### WR-03: sbx-shell and sbx-start blame a missing image when Docker is down

**Files modified:** `bin/sbx-lib.sh`, `tests/selftest/sbx/lib.sh`, `tests/selftest/sbx/shell.sh`, `tests/selftest/sbx/start.sh`, `SANDBOX.md`
**Commit:** 2e0e14c
**Applied fix:** `require_images` asks `docker info` first and prints "cannot reach Docker; is Docker running?" (same tail as sbx-list); only a genuinely missing image keeps the sbx-upgrade advice. Scripted docker gained `info` and a `docker-down` knob. New cases for sbx-shell and sbx-start: Docker down (message, no compose, no sbx-upgrade advice) and image missing (sbx-upgrade advice, no Docker blame). Troubleshooting row extended. (The check later moved into `require_docker`, commit 41437c8.)
**Verification:** mutant (fix reverted) fails 4 new cases.

### WR-05: H-33 volume and container snapshots pass vacuously on Docker errors

**Files modified:** `tests/host/h33-sbx-rm.sh`
**Commit:** 63de7d2
**Applied fix:** no `2>&1` merge; Docker's stderr goes to `logs/h33-listings.err`. Each listing keeps docker's exit status (`list_other_containers` filters only after capturing docker's status). A failed listing before or after is its own problem naming the log and is never compared.
**Verification:** harness with a fake docker: Docker failing gives 4 problems with clear reasons; the original file gave 0 problems (vacuous pass, mutant confirmed).

### WR-04: sbx-rm removes a running sandbox with no confirmation

**Files modified:** `bin/sbx-rm`, `tests/selftest/sbx/lib.sh`, `tests/selftest/sbx/rm.sh`, `tests/host/h33-sbx-rm.sh`, `SANDBOX.md`, `tests/README.md`, `tests/host-checklist.md`
**Commit:** 2ee102f
**Applied fix:** after the existing warning a running sandbox asks `Remove the running sbx-NAME? [y/N]` (read -p from stdin, only when stdin is a terminal); only y/Y proceeds, anything else exits 1 with nothing changed. `--yes` skips it and combines with `--unregister` in any order (each once; usage is `NAME [--unregister] [--yes]`). No terminal and no `--yes` on a running sandbox: exit 1, message names `--yes`. Stopped or no container: unchanged. H-33 now asserts the no-terminal refusal (exit 1, names --yes, still running, entry and sentinels intact) and then removes with `--yes`. Docs: Scripts table, Remove section (question, --yes, no terminal, 10 s grace caveat), troubleshooting row, H-33 checklist row, tests/README.
**Self-test helper:** `run_sbx_in_terminal` gives the script a pty through script(1) (util-linux `-c` string form or BSD word form) and keeps input open until the exit status file exists.
**Verification:** mutants (original sbx-rm, any answer accepted, no terminal check, --yes ignored) each fail new cases.

### WR-02: sbx-rm cannot clean up entries sbx-list reports as broken

**Files modified:** `bin/sbx-rm`, `bin/sbx-lib.sh`, `tests/guard/isolation.sh`, `tests/selftest/guard/sandbox-rules.sh`, `tests/selftest/sbx/lib.sh`, `tests/selftest/sbx/rm.sh`, `SANDBOX.md`
**Commit:** 41437c8
**Applied fix:** `read_entry` marks an existing but unusable entry as broken (the name still passes check_name; a missing file is still "not registered"). Without `--unregister` a broken entry is refused with the reason and a hint naming `--unregister`. With it: `require_docker` (new lib helper, also used by `require_images`), then if `sbx-NAME` exists, the same running confirmation, `docker stop "sbx-$1"` and `docker rm "sbx-$1"` (no -v, no -f), then the one `rm -- "$entryFile"` in `unregister_sandbox`, shared by both paths. Messages use "the sandbox folder" when the entry has no usable folder. The guard allows exactly the line `  if ! docker rm "sbx-$1" >/dev/null </dev/null; then`; new planted cases (`docker rm -v`, `docker rm -f`, another container, `docker volume rm`) all fail the rule. Docs: list section, raw commands, Remove section (network `sbx-NAME_default` stays), troubleshooting row.
**Verification:** mutants (strict read, no Docker check, no confirmation on the broken path) fail new sbx cases; a broad guard allow (`docker rm ` anywhere) fails the -f and other-container planted cases.

### IN-04: the failed-entry-delete branch of sbx-rm had no test

**Files modified:** `tests/selftest/sbx/rm.sh`
**Commit:** bd38b74
**Applied fix:** `case_rm_delete_fails` makes the registry folder read-only (skipped as root with an INFO line), runs `sbx-rm locked --unregister` on a stopped sandbox and expects exit 1, the "could not delete ...; the container is gone and nothing in DIR was changed" message, no deleted or closing line, the entry kept and the folder listing unchanged.
**Verification:** mutant (`rm` failure swallowed) fails 4 of the new expectations.

## Final suite results (main checkout, Linux, bash 5.3)

| Suite | Result |
|---|---|
| `tests/selftest/sbx/run-all.sh` | 212 PASS, 0 FAIL, `All cases pass.` |
| `tests/selftest/guard/run-all.sh` | 158 PASS, 0 FAIL, `All cases pass.` |
| `tests/selftest/entrypoint/run-all.sh` | 60 PASS, 0 FAIL, `All cases pass.` |
| `tests/guard/run-all.sh` (rehearsal linters on PATH) | 19 PASS, `All rules hold.` |

## Still to prove on the Mac (`./host-test.sh`)

- The sbx self-test under `/bin/bash` 3.2 with BSD `script`: the terminal cases in `rm.sh` (question, y/n, --yes, stopped) run through the BSD form of `run_sbx_in_terminal`, never exercised here.
- H-31 passes with the Mac's Docker wording.
- H-33: the running sandbox is refused without a terminal or --yes and stays running with its entry; `sbx-rm --yes` then removes it; listings fail loudly if Docker errors.
- Not covered by any host check: the broken-entry path against real Docker (`docker stop` + `docker rm` by name, network left behind), and the "cannot reach Docker" message with Docker Desktop stopped.

---

_Fixed: 2026-11-08_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
