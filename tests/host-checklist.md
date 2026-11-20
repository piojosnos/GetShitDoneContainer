# Host checklist

What cannot live in code: one check by hand, and how to read the log of the host run.

- **When:** once after building a new version of the images or `compose.yml`.
- **Setup and daily use:** see [`README.md`](../README.md).
- **The suites and the scenario rule:** see [`tests/README.md`](README.md).
- Commands run from the repo root.

## Check a Cursor login by hand

No scenario runs an agent, so a real Cursor login is checked by hand.

1. `sbx-add NAME HOST_PATH cursor`, then `sbx-upgrade NAME` and `sbx-shell NAME`.
2. In the sandbox shell: `sbx-init`, then `sbx-cursor login`, and open the printed link in the host browser.
3. Run `sbx-cursor`, send one prompt, and exit.
4. On the host, run `sbx-upgrade NAME`, open `sbx-shell NAME`, run `sbx-init`, then `sbx-cursor`.
5. It must start with no login prompt. The login (`auth.json`) lives in `$SBX_DIR/state/cursor`, so the upgrade keeps it.

## Read host-test.log

`./host-test.sh` writes `host-test.log` in the repo root as the run goes. It starts with the date, the branch and commit, the test images, `git status`, and the Docker and Compose versions.

- **`-v` lines:** one line per scenario and agent, such as `tests/integration/test_persistence.py::test_planted_files_survive_one_upgrade[claude] PASSED`. A pin digests line has no agent.
- **`STEP FAILED:` note:** under a failing assertion it names the step that ended the scenario. Fix that step first; the steps before it passed.
- **The last line:** `host-test.sh: every test passed; log: ...`, or `host-test.sh: pytest exited N; the failures are listed above; log: ...`. Exit status 0 means every test passed.
- **Build failure:** the output names the log path, `logs/build-images.log` in the run directory (`sbx-hosttest-...` under `$TMPDIR`).
- **"Mounts denied":** Docker Desktop does not share `$TMPDIR`. Add it in Settings, Resources, File sharing.
- **Rebuilding retags the images:** your running sandboxes keep their old image until their next `sbx-start`. That is safe: all their data is in their directory.
- **`--keep`:** `./host-test.sh --keep` leaves the test sandboxes and the run directory after a failure, to look around. Remove them later with `./clean.sh --yes`.
