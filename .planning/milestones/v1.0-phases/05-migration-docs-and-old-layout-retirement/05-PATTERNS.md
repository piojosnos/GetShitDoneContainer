# Phase 5: Migration, Docs, and Old-Layout Retirement - Pattern Map

**Mapped:** 2026-11-08
**Files analyzed:** 22 (3 new or rewritten docs, 9 reference or guard edits, 10 deletions or removals)
**Analogs found:** 22 / 22 (docs have in-repo voice analogs; edits are self-analogs with exact current text)

All analog paths below are git-tracked (checked with `git ls-files`).

No new shell, no new test (CONTEXT D-01). The only code-ish changes are edits to existing lists, strings and functions, and deletions.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `README.md` (git mv from `SANDBOX.md`, then rewrite) | doc (main) | reference, schematic | `SANDBOX.md` (itself), `tests/README.md` | exact |
| `MIGRATION.md` (new) | doc (one-time recipe) | copy/paste procedure | `SANDBOX.md` "Register a sandbox" + `05-RESEARCH.md` "The recipe" | role-match |
| `compose.yml` line 5 | config comment | none | itself | exact |
| `versions.env` line 5 | config comment | none | itself | exact |
| `base/sbx-start-lib.sh` line 34 | utility (message text) | request-response | itself | exact |
| `prompts/consolidate-memories.md` line 10 | prompt doc | none | itself | exact |
| `tests/host-checklist.md` lines 7, 72, 116, 118, 127 | doc (test plan) | reference | itself | exact |
| `tests/host/h23-caches-survive-recreate.sh` line 92 | test (message) | none | itself | exact |
| `tests/guard/supply-chain.sh` line 14 | test (guard rule file list) | batch grep | itself | exact |
| `tests/guard/isolation.sh` | test (guard) | batch | itself | exact |
| `tests/host/run-all.sh` | test runner | batch | itself | exact |
| `tests/host/lib-docker.sh` | test lib | transform | itself | exact |
| `tests/README.md` lines 40, 60 | doc | reference | itself | exact |
| `host-test.sh` line 52 | comment | none | itself | exact |
| `ClaudeCode/` (7 files), `OpenCode/` (3 files), `tests/host/coexistence.sh` | deletions (PR B) | none | n/a | n/a |

## Pattern Assignments

### `README.md` (doc, schematic reference; rewrite of `SANDBOX.md`)

**Analog:** `SANDBOX.md` (476 lines, 20 headings). Do `git mv SANDBOX.md README.md` first (the old `README.md` is replaced; PR A must also drop `README.md` from the `old_layout_untouched` pathspec or the guard fails).

**Voice and structure to copy** (SANDBOX.md lines 1-12): H1, one sentence, then a table of "On the Mac | Holds", then 2-3 short bullets.

```markdown
# sbx sandbox (new layout)

One Docker container per project. It sees exactly one folder on your Mac, `$SBX_DIR`:

| On the Mac | Holds |
|---|---|
| `$SBX_DIR/<name>/` | your code |
| `$SBX_DIR/best-practices/` | this sandbox's clone of the best-practices repo (standing rules and skills) |
| `$SBX_DIR/state/` | Claude login, settings and sessions; ... |

- Nothing is mounted over the container's home directory, so everything the image provides stays visible.
```

Edit that second bullet (line 12): "It runs side by side with the old `ClaudeCode/` layout ... stays documented in `README.md`" must go. Drop "(new layout)" from the H1. Link `MIGRATION.md` here instead.

**Style rules seen in the file (match them):**
- Command blocks are fenced ```` ```bash ````, one command per idea; file examples use ```` ```text ````.
- Facts as 2-column tables: scripts (`| Command | What it does |`, lines 48-67), layout (lines 105-116, with a third `Env var` column), images (lines 14-22), troubleshooting (`| Symptom | Fix |`, lines 441-476).
- Bullets are one sentence, nested bullets only for lists of refusals.
- No dashes as punctuation, punctuation outside closing quotes, ASCII only.

**Sections to keep (section-by-section map)**

| SANDBOX.md heading | Line | Plan |
|---|---|---|
| intro + layout table | 1-12 | keep, drop old-layout bullet |
| What the images hold | 14 | keep, trim |
| Requirements | 24 | keep, one line each |
| Build the images | 30 | compress 9 bullets to the 3 that matter |
| Scripts | 48 | keep table; PATH snippet (`export PATH="/path/to/GetShitDoneContainer/bin:$PATH"`) |
| Register a sandbox | 69 | keep registry 2-line `text` example, "what lives where" table |
| gh and git identity | 120 | keep |
| Start, enter, stop / List / Remove | 128/204/232 | compress, move "What the scripts run" (183) down |
| Upgrade | 254 | keep, headline |
| Bump a version | 272 | keep short |
| Best-practices bundle, GSD, ccusage | 279/355/371 | compress |
| Safety checks, Image-only smoke tests | 379/402 | move rare detail down |
| Verify a new build | 416 | replace with the 4-row DOC-04 table (RESEARCH "DOC-04 map") pointing at `./host-test.sh` and `tests/host-checklist.md` |
| Free disk space | 422 | keep short |
| Troubleshooting and known limits | 441 | keep heading text exactly (anchor `#troubleshooting-and-known-limits` is linked from `tests/host-checklist.md` line 116) |
| Threat model (new) | n/a | short table plus four-line rule list; facts in RESEARCH "Threat model facts" |

Troubleshooting rows to drop or rewrite because they refer to the old layout: the "A sandbox migrated from the old layout loads the same rules twice" row (line ~471) moves to `MIGRATION.md`; keep the row format:

```markdown
| A sandbox migrated from the old layout loads the same rules twice | Remove the `@AGENTS.md` and `@code-conventions.md` imports from `state/claude/CLAUDE.md`. |
```

The README must contain no `cc-*` command and no `cc-upgrade.sh`; run the one-off accuracy check from RESEARCH "Validation Architecture".

---

### `MIGRATION.md` (doc, copy/paste procedure)

**Analog:** `SANDBOX.md` "Register a sandbox" (lines 69-80) for the pattern "short command block, then bullets that explain what it does and what it refuses". Content comes from `05-RESEARCH.md` "Code Examples / The recipe" (lines 360-392), which is the tested block.

**Shape to copy** (SANDBOX.md lines 71-80):

```markdown
Once per sandbox:

```bash
sbx-add demo /Users/you/sbx-demo
```

- It creates `/Users/you/sbx-demo`, ...
- It refuses:
  - a name outside the name rule, ...
```

**Concrete requirements:**
- Variables once at the top: `OLD`, `NEW`, `NAME`, `CODE`, derived `ENC=$(printf '%s' "$CODE" | LC_ALL=C sed 's/[^a-zA-Z0-9]/-/g')`.
- Example values: `OLD=.../GSD_StaticSiteGenerator`, `CODE=MyCode`, `NAME=mycode` (legal name rule is `^[a-z][a-z0-9-]{0,30}$`, so `MyCode` must be shown being renamed).
- Stop old container with `docker stop cc_gsd_PROJECT`, never `cc-down` (it runs `down -v`, and the script is deleted in PR B).
- BSD-safe: `cp -Rp "$OLD/x/." "$NEW/y/"`; temp file plus `mv` instead of `sed -i`; quote every expansion (paths with spaces).
- Rename: `mv ".../projects/-home-sandbox-$ENC" ".../projects/-home-sandbox-workspace-$NAME"` (D-08's table writes `$CODE` raw; use `$ENC`).
- Rewrite git credential helper while copying: `sed 's|!/usr/bin/gh |!/usr/local/bin/gh |' "$OLD/.gitconfig" > "$NEW/state/git/config"`.
- Three checks (D-10) then undo line: `sbx-rm NAME --unregister`, then `docker start cc_gsd_PROJECT`.
- Extra short section for this dev sandbox (D-12/D-13): plain clone at `~/sbx-tools/GetShitDoneContainer`, `bin/` on PATH; take the remote URL from `git remote -v` on the Mac.
- Add `MIGRATION.md` to the `no_compromised_gsd_package` file list (see below); do not write the old package names in it.

---

### `base/sbx-start-lib.sh` (message text)

**Current, line 34:**

```bash
  echo "[sbx]        Start the sandbox with 'docker compose up' (see SANDBOX.md)." >&2
```

Change `SANDBOX.md` to `README.md`. No test asserts this text. Note: changes the image, so a rebuild marks other sandboxes "older image".

---

### Reference retargets (SANDBOX.md to README.md)

| File:line | Current text | Change |
|---|---|---|
| `compose.yml:5` | `# SANDBOX.md explains the variables and the sandbox name rule.` | `README.md` |
| `versions.env:5` | `# To bump or add a pin, see SANDBOX.md.` | `README.md` |
| `prompts/consolidate-memories.md:10` | `(see [`SANDBOX.md`](../SANDBOX.md), "Best-practices bundle")` | `[`README.md`](../README.md)`; keep the section name "Best-practices bundle" in the README |
| `tests/host/h23-caches-survive-recreate.sh:92` | `(see SANDBOX.md troubleshooting)` inside an `add_problem "..."` string | `README.md troubleshooting` |
| `tests/host-checklist.md:7` | `- **Setup and daily use:** see [`SANDBOX.md`](../SANDBOX.md).` | `README.md` |
| `tests/host-checklist.md:116` | `[`SANDBOX.md`, Troubleshooting](../SANDBOX.md#troubleshooting-and-known-limits)` | `README.md` both places; anchor kept |
| `tests/host-checklist.md:118` | `...and SANDBOX.md must not promise it until then.` | `README.md` |

---

### `tests/guard/supply-chain.sh` (guard file list)

**Current, line 14:**

```bash
  nowhere_matches 'get-shit-done-cc|gsd-build' $SANDBOX_FILES claude/start.d/* claude/bin/* claude/managed-settings.json SANDBOX.md tests/host-checklist.md tests/host/*.sh ...
```

Replace the token `SANDBOX.md` with `README.md MIGRATION.md` (the rest of the line unchanged). Do not weaken the pattern. `tests/guard/lib.sh:21` (`SANDBOX_FILES=...`) does not mention docs and needs no change.

---

### `tests/guard/isolation.sh` (guard)

PR A edit, line 69 (drop `README.md` from the pathspec; the line-70 untracked check stays):

```bash
old_layout_untouched() {
  git diff --quiet "$OLD_LAYOUT_COMMIT" -- ClaudeCode OpenCode README.md \
    && [ -z "$(git ls-files --others --exclude-standard -- ClaudeCode OpenCode)" ]
}
```

PR B removal (all in `tests/guard/isolation.sh`):
- line 3 banner `# Guard rules on isolation: no socket, no privileges, data kept, old layout kept` -> drop ", old layout kept"
- lines 11-17 (constants banner, `OLD_LAYOUT_COMMIT=304f80d...`; the comment already says "Remove both when the old layout is retired")
- lines 65-71 (the `old_layout_untouched` banner and function)
- line 81 `  old_layout_untouched || exit 1` and the trailing `\` on line 80 (so `host_scripts_keep_sandbox_data || exit 1` ends the call):

```bash
run_rules \
  no_docker_socket_or_privileges \
  host_scripts_keep_sandbox_data \
  old_layout_untouched || exit 1
```

Rule count then falls from 19 to 18 (see `tests/README.md`). No selftest case names this rule (grep over `tests/selftest/guard` found nothing). Run `bash tests/guard/run-all.sh` and `bash tests/selftest/guard/run-all.sh` after.

---

### `tests/host/run-all.sh` (PR B)

**Current snippets that go:**

Line 25 and 27:
```bash
finalCheckList="coexistence.sh"

remainingList="$fatalCheck $noSandboxCheckList $sandboxCheckList $chainCheckList $finalCheckList"
```
-> delete `finalCheckList=...`; drop `$finalCheckList` from `remainingList`.

Lines 217-236, whole function with its banner (`record_old_layout`, which calls `snapshot_old_containers` and `snapshot_old_folders` and writes `$RUN/logs/old-containers.before` and `old-folders.before`).

Main block lines 305 and 311:
```bash
record_old_layout
...
run_list "$finalCheckList"
finish "not reached"
```
-> delete `record_old_layout` and `run_list "$finalCheckList"`. Also grep the file for other `coexistence` / `finalCheckList` mentions (header comments) before finishing.

---

### `tests/host/lib-docker.sh` (PR B)

- Line 3 banner: `# Docker beyond the test sandbox: images, facts about them, old-layout snapshots` -> drop ", old-layout snapshots" (adjust "images, facts about them").
- Delete `snapshot_old_containers` (lines ~62-75, greps `^[0-9a-f]+ cc_`) and `snapshot_old_folders` (lines ~77-100, `git rev-parse HEAD:ClaudeCode HEAD:OpenCode`) with their banners. Keep `claude_pin` (lines 8-11) and everything above line 55.

---

### `tests/host-checklist.md`, `tests/README.md`, `host-test.sh` (PR B)

| File:line | Current | Change |
|---|---|---|
| `tests/host-checklist.md:72` | `| Coexistence | Old-layout containers and files are untouched | `coexistence.sh` | automatic |` | delete row |
| `tests/host-checklist.md:127` | `- **Coexistence fails:** if you started or stopped a `cc_` container during the run, run it again.` | delete bullet |
| `tests/README.md:40` | `...19 rules that read the files only...` | `18 rules` |
| `tests/README.md:60` | `H-00 to H-33 and Coexistence against real Docker` | `H-00 to H-33 against real Docker` |
| `host-test.sh:52` | `# host_checks: H-00 to H-33 and Coexistence; builds both images first` | drop "and Coexistence" |

Keep `tests/host/h32-sbx-list.sh` (~line 100, asserts no `cc_` row in `sbx-list`); optional reword of the `bin/sbx-list` comment about "old-layout containers".

---

### Deletions (PR B, after the user confirms all 4 sandboxes are migrated)

`git rm -r ClaudeCode OpenCode tests/host/coexistence.sh`. Evidence: `git ls-files` lists `ClaudeCode/` (Dockerfile, README.md, cc-bash.sh, cc-down.sh, cc-up.sh, docker-compose.yml, docker-entrypoint.sh) and `OpenCode/` (Dockerfile, docker-compose.yml, docker-entrypoint.sh). `.claude/CLAUDE.md` still describes them; per project memory it needs its own `.claude/`-only PR, flag it, do not fold it in.

## Shared Patterns

### Docs style (README.md, MIGRATION.md, all doc edits)
**Source:** `SANDBOX.md` structure, `~/.claude/AGENTS.md` (prose and documentation style)
**Apply to:** `README.md`, `MIGRATION.md`, `tests/host-checklist.md` edits
- Tables for facts, labelled lists for steps, one idea per line, copy/paste fenced blocks.
- No `--` or em/en dash as punctuation (literal flags like `--unregister`, `--yes` are fine), punctuation outside closing quotes, ASCII only.
- No phase or decision IDs (D-xx, SCR-08, DOC-xx) in committed docs or comments.
- Match neighbouring voice; docs follow code (code is ground truth).

### Portable Mac shell (recipe commands)
**Source:** memory "shell-scripts-must-be-bsd-macos-portable"; `tests/guard/isolation.sh` style for loops
**Apply to:** every command in `MIGRATION.md`
- `cp -Rp SRC/. DST/`, temp file plus `mv` (never `sed -i`), quoted variables, no GNU-only flags.

### Guard file-list edit
**Source:** `tests/guard/supply-chain.sh:14`
**Apply to:** the one `SANDBOX.md` token swap; keep the pattern `'get-shit-done-cc|gsd-build'` untouched.

### Verification commands per task
- `bash tests/guard/run-all.sh` after every task; `bash tests/selftest/guard/run-all.sh` after editing `tests/guard/*.sh`.
- `./host-test.sh` on the Mac for PR A and again for PR B (Docker is not in the dev sandbox).
- README accuracy one-off check: RESEARCH lines 497-504 (run, do not commit). Final grep: `git grep -n 'SANDBOX.md' -- . ':!.planning'` must print nothing after PR A.

### Branch and PR split
**Source:** `~/.claude/AGENTS.md`, memory "separate-prs-for-planning-and-claude"
- PR A: README/MIGRATION/retargets/`isolation.sh` pathspec/`supply-chain.sh` list. PR B: deletions and guard/test edits (after the user's migration). `.planning/` and `.claude/` changes in their own PRs. Branch from updated target; human merges; push needs explicit go.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `MIGRATION.md` | one-time procedure doc | copy/paste | No migration doc exists; use `SANDBOX.md` "Register a sandbox" for shape and RESEARCH "The recipe" for content |
| Threat model section in `README.md` | doc section | reference | No threat-model text exists; use RESEARCH "Threat model facts" table and `SANDBOX.md` bundle "The trade" wording as voice |

## Metadata

**Analog search scope:** repo root docs, `tests/guard/`, `tests/host/`, `tests/README.md`, `tests/host-checklist.md`, `base/`, `compose.yml`, `versions.env`, `prompts/`, `host-test.sh`
**Files scanned:** about 25 (full or targeted reads); reference list from `git grep -n 'SANDBOX.md'`
**Pattern extraction date:** 2026-11-08
