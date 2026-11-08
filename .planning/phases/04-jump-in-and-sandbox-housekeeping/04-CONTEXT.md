# Phase 4: Jump-In and Sandbox Housekeeping - Context

**Gathered:** 2026-11-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Three new host commands next to the Phase 3 ones in `bin/`:

| Command | Does |
|---|---|
| `sbx-shell NAME` | Starts the sandbox when needed, then opens a bash shell in `/home/sandbox/workspace/NAME` |
| `sbx-list` | Lists the registered sandboxes with host path and status |
| `sbx-rm NAME [--unregister]` | Removes the container (and with the flag the registry entry); never touches the sandbox folder |

Requirements: SCR-04, SCR-05, SCR-06. Claude is started from the shell with the in-image `sbx-claude`; there is no host command that launches Claude (SCR-04 and success criterion 2 were amended in this discussion).

</domain>

<decisions>
## Implementation Decisions

### Jump-in
- **D-01:** The command is `sbx-shell NAME`. It only opens a shell. A sandbox that is stopped or has no container goes through the same steps as `sbx-start` (name check, registry entry, folder check, image check, `compose up -d --wait`, wait for the start hooks), then `docker exec -it -w /home/sandbox/workspace/NAME sbx-NAME bash`. A running sandbox gets the `docker exec` only.
- **D-02:** No host command launches Claude. The flow is `sbx-shell demo`, then `sbx-claude` in that shell. SCR-04 in `.planning/REQUIREMENTS.md` and Phase 4 success criterion 2 in `.planning/ROADMAP.md` now say this.
- **D-03:** A running sandbox on an older build of `sbx-claude:local` (for example after `sbx-upgrade` of another sandbox) is entered as it is: no recreate, no message. Why: entering must never close the other shells and Claude sessions in that sandbox, and a message adds code for little value. The older image is shown by `sbx-list` instead (D-06).
- **D-04:** The start steps are shared with `sbx-start`, not copied (a function in `bin/sbx-lib.sh`, or `sbx-shell` calling `sbx-start`; the planner picks). `sbx-start`'s closing hint ("open a shell with: docker exec ...") becomes `sbx-shell NAME`.

### List
- **D-05:** `sbx-list` takes no arguments. It prints one row per registry entry: name, host path, status. Status is one of `running`, `stopped`, `no container`, read from Docker for the container `sbx-NAME`, so it matches `docker ps -a`.
- **D-06:** A running sandbox whose container image differs from the current `sbx-claude:local` is marked as on an older image (wording is the planner's). The comparison is the one `warn_if_older_image` in `bin/sbx-start` already does; it moves to `bin/sbx-lib.sh` so both use one copy.
- **D-07:** After the table, a second section lists containers that carry the `sbx.name` label but have no registry entry (for example a registry file deleted by hand, or the host test sandbox `sbx-hosttest`). It is printed only when there is at least one. Containers are found by the label, so the old `cc_*` containers never show up.

### Remove
- **D-08:** `sbx-rm NAME` runs `docker compose down` for that sandbox: container and network go. Never `-v` and never `--rmi`; the images stay for the other sandboxes.
- **D-09:** A running sandbox is removed without a prompt, after the `warn_sessions_close` line. Why: nothing on disk can be lost, and `sbx-upgrade` already recreates without asking.
- **D-10:** `--unregister` also deletes the registry file `~/.config/sbx/sandboxes/NAME`, and only after `compose down` succeeded. When `down` fails, the entry stays.
- **D-11:** `sbx-rm` never reads, writes or deletes anything under `SBX_DIR`. It always ends with one line saying nothing in `SBX_DIR` was changed (same style as `sbx-stop`).
- **D-12:** Re-registering the same path with `sbx-add NAME HOST_PATH` after `--unregister` brings back the login and history. `sbx-add` already accepts an existing folder; a host check proves the full round trip on the Mac.

### Claude's Discretion
- Exact output layout of `sbx-list` (columns, alignment, the older-image marker text) and the error wording of all three scripts.
- How `sbx-list` shows a registry entry it cannot read (an error in its row is preferred over failing the whole list).
- What `sbx-rm` does on a registered sandbox that has no container (succeed quietly is fine), and whether `sbx-list` prints a `docker rm` hint for unregistered leftovers.
- How the host checks prove the scripts (test registry via `SBX_CONFIG_DIR`, paths with spaces, bash 3.2), following the Phase 3 host checks.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and requirements
- `.planning/ROADMAP.md` (Phase 4 section): goal and the four success criteria (criterion 2 amended)
- `.planning/REQUIREMENTS.md`: SCR-04 (amended), SCR-05, SCR-06
- `.planning/PROJECT.md`: constraints (security, simplicity, coexistence with the old `cc_*` layout, Mac verification)
- `.planning/phases/03-remembered-sandboxes-and-one-command-upgrade/03-CONTEXT.md`: registry format and location, `bin/` layout, stop and upgrade semantics this phase builds on

### Existing code the new scripts build on
- `bin/sbx-lib.sh`: `sbx_init`, `check_name`, `read_registry_entry`, `check_sandbox_folders`, `run_compose`, `require_images`, `sandbox_is_running`, `warn_sessions_close`, `wait_until_ready`
- `bin/sbx-start`: start steps and `warn_if_older_image` (to be shared, D-04 and D-06)
- `bin/sbx-stop`: shape of a small script and its closing line
- `bin/sbx-add`: accepts an existing folder (D-12)
- `compose.yml`: `container_name: sbx-${SBX_NAME}`, label `sbx.name`, the mount, `working_dir`
- `SANDBOX.md`: "Start, enter, stop" and the command table; they get `sbx-shell`, `sbx-list`, `sbx-rm`

### Conventions and tests
- `~/.claude/code-conventions.md` and `~/.claude/AGENTS.md`: shell layout, naming, no dashes as punctuation, ASCII only in source
- `tests/README.md`, `tests/host/run-all.sh`, `tests/host-checklist.md`: where the host checks for the new scripts go

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bin/sbx-lib.sh` already has every building block: registry read, name check, folder check, scoped `run_compose`, running check, the sessions warning, the start wait.
- `warn_if_older_image` in `bin/sbx-start`: the image comparison `sbx-list` needs.

### Established Patterns
- Script banner (80-column rules, title, at most two "why" lines, Main / Entry Point), `set -eu`, functions, camelCase locals, collection suffixes.
- `sbx_usage` for a wrong argument count (exit 2); `sbx_error` for errors on stderr.
- Every `docker` call reads `</dev/null`; stock bash 3.2 and BSD tools only.

### Integration Points
- New files `bin/sbx-shell`, `bin/sbx-list`, `bin/sbx-rm` next to the Phase 3 scripts (`bin/` is already on the user's `PATH`).
- `sbx-start`'s closing hint line, `SANDBOX.md`, the host test list.

</code_context>

<specifics>
## Specific Ideas

- The user wants small, separate commands, each doing one thing, over one command with modes.
- The user starts Claude by hand in the shell with `sbx-claude`; a host launcher is not wanted.
- Image age belongs in the list, not in the jump-in.

</specifics>

<deferred>
## Deferred Ideas

None. Discussion stayed within phase scope.

### Reviewed Todos (not folded)
Six pending todos matched on generic keywords only ("sandbox", "claude"). They cover the bundle hook, `sbx-bundle-clone`, `sbx-claude`'s wait, `sbx-gh-login` and the shell diet, not jump-in, list or remove, so none were folded.

</deferred>

---

*Phase: 04-jump-in-and-sandbox-housekeeping*
*Context gathered: 2026-11-07*
