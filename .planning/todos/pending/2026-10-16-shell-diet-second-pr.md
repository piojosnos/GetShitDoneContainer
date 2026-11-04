---
created: 2026-10-16
title: Shell diet second PR (approved re-scan cuts)
area: tests
source: .planning/phases/02.1-shell-diet/02.1-RESCAN.md
---

Plan and ship the second code PR from Phase 2.1's re-scan, on a branch cut from main after PR #20 merges.

Scope: the 18 rows marked `approved 2026-10-15` in `02.1-RESCAN.md` (R-01, R-02, R-04 to R-13, R-15 to R-20). R-03 and R-14 are rejected. About 1020 lines, 50 of them shipped; brings shipped shell to about 700 (the restated Phase 2.1 goal).

Also fold in the deferred review findings from `02.1-REVIEW-DISPOSITION.md`: WR-03 (planted failures for three guard rules) and WR-04 (Mac-shell step ignores both linter rules by name). WR-01, WR-02, WR-05 are R-17, R-20, R-19.

After editing executables in the sandbox, run the exec-bit fix on the Mac before testing (`git diff --summary` mode changes), then `./host-test.sh`.

## Coordination with the best-practices clone change

Phase 2.2 (best-practices from a git clone, branch `feat/best-practices-from-git`) changes files this PR also touches. Cut the diet branch from main only after the 2.2 code PR is merged, then re-read each row below against the merged files.

| Row | Effect of the clone change |
|---|---|
| R-19 | Superseded. The hook line `bundleDir=${SBX_BUNDLE_DIR:-/opt/sbx/best-practices}` is gone; the hook reads `bundleDir=${SBX_BUNDLE_DIR:-}` and the image sets `SBX_BUNDLE_DIR` as ENV. Drop the row. |
| R-12 | The 05-gsd half is unchanged. The 10-best-practices half now applies to the new hook: it still has a one-test `check_inputs` (config folder and clone folder), plus `remove_old_links` and `link_bundle`. |
| R-07 | `tests/host/run-all.sh` now lists 27 checks (H-27 added) and builds the fixture clone; `tests/README.md` and the checklist name H-00 to H-27. |
| R-08 | `tests/host-checklist.md` was rewritten for the clone model (H-14 to H-19 rows, new H-27 row). Re-read before cutting. |
| R-11 | `base/sbx-start-lib.sh` gained the `state` and `best-practices` name refusal; H-17 now runs five containers (offline with and without a clone, broken config, not-executable hook, dangling hook). |
| R-15 | H-09 plants and checks a file in the clone across the rebuild. |
| R-20 | `SHELL_FILES` in `tests/guard/lib.sh` gained `claude/bin/*`; add `host-test.sh` next to it. |
| R-10 | `tests/selftest/guard/sandbox-rules.sh` gained two planted failures for the bundle URL pin. |
| R-01, R-06 | They edit H-22 and H-25, which this phase did not change. Their "still covered by" text names the Dockerfile smoke tests and the pin rules; the claude Dockerfile lost the bundle copy and gained the `BUNDLE_REPO_URL` ARG, so re-read that coverage. |
