---
created: 2026-11-18
title: Remove the duplication in the tests that the PR 52 review found
area: tests
source: Review of the sbx-init code PR against the best practices (2026-11-18)
---

A test-only cleanup, as its own PR after the sbx-init code PR merges. About 550 lines out.

(a) Merge the 16 twin Claude and Cursor test files in `tests/unit/selfcheck/` (`test_{claude,cursor}_{env,gsd_synced,best_practices_links,credentials,home_links,shared,image_paths_protected,versions_line}.py`) into one test parametrized over both agents. Drop the asserts that only compare a constant with the constant it was imported from; keep the ones with meaning (shared paths, home link list, login hint, image roots, versions line).

(b) Merge the five identical "missing pin" tests in `tests/unit/selfcheck/test_tool_{gh,uv,java,maven,gsd}.py` into one parametrized test.

(c) Drop the load-failure tests in `tests/unit/selfcheck/test_runner.py` and `tests/unit/init/test_init_runner.py` that `tests/unit/selfcheck/test_step_files.py` now covers; keep one end-to-end load-failure test per runner.

(d) Host tests: move the repeated blocks into `tests/host/lib-sbx.sh` (`check_found_on_path` from h28, h31, h32, h33; taking the test sandbox down and the add-and-start step from h28, h29, h31, h32, h33; `expect_exit_zero` and the inline exit checks; `require_run_dir`; `check_one_bind_mount` from h09 and h29). Split the process and timeout helpers (`tree_pids`, `kill_tree`, `any_alive`, `run_timeout`) out of `tests/host/lib-sandbox.sh` into their own library. Phase 10 rewrites the host tests in Python; if it starts before this cleanup, fold (d) into it instead.
