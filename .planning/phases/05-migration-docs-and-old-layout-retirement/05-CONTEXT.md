# Phase 5: Migration, Docs, and Old-Layout Retirement - Context

**Gathered:** 2026-11-08
**Status:** Ready for planning

<domain>
## Phase Boundary

The user's 4 existing old-layout sandboxes (whole-home mount, `cc-*` scripts), including the one this repo is developed in, move to the new layout by hand, keeping the Claude login, resumable sessions, ccusage history, gh login, git identity and bash history. The repo then holds only the new layout, and its main doc (`README.md`) describes exactly what exists, including a short threat model.

This phase is documentation plus deletion. It adds no new script, no migration tool and no new host check.

</domain>

<decisions>
## Implementation Decisions

### Ground rule
- **D-01:** No migration script, no new shell, no new self-test or host check. The user migrates each sandbox by hand from a copy/paste recipe. Why: the user explicitly does not want more shell to write, run and test; 4 sandboxes do not justify a tool.

### Docs layout
- **D-02:** `SANDBOX.md` becomes `README.md` (git mv, then edit). The old `README.md` (old layout only) is replaced. There is one main doc.
- **D-03:** The new `README.md` must be very simple, streamlined, easy to read and schematic: tables, short labelled lists, copy/paste command blocks, one idea per line. It is a rewrite pass over today's 476-line `SANDBOX.md`, not a rename only: cut repetition, move rare detail down or out, keep every fact a user needs. The user stressed this as the bar for the phase.
- **D-04:** The one-time migration recipe lives in its own `MIGRATION.md`, linked from `README.md`. Why: once the 4 sandboxes are moved, the main doc never makes the user scroll past it. DOC-02 is met by README linking to MIGRATION.md.
- **D-05:** Every reference to `SANDBOX.md` in the repo points at `README.md` afterwards (comments in `compose.yml`, `versions.env`, the message in `base/sbx-start-lib.sh`, the guard file list in `tests/guard/supply-chain.sh`, `tests/host-checklist.md`, `tests/host/h23-caches-survive-recreate.sh`, `prompts/consolidate-memories.md`).

### Migration recipe (MIGRATION.md)
- **D-06:** Copy into a new sandbox folder; never move or change the old folder. The old sandbox stays runnable as the rollback until the user deletes it (suggest after a week).
- **D-07:** Variables are set once at the top of the recipe (`OLD` old host folder, `NEW` new sandbox folder, `NAME` sandbox name, `CODE` the code folder's name inside OLD); every command after that pastes unchanged.
- **D-08:** What is carried over, old home folder to new sandbox folder:

  | Old (`$OLD`) | New (`$NEW`) |
  |---|---|
  | `$CODE/` | `$NAME/` |
  | `.claude/` | `state/claude/` |
  | `.claude.json` | `state/claude/.claude.json` |
  | `.bash_history` | `state/shell/bash_history` |
  | `.config/gh/` | `state/gh/` |
  | `.gitconfig` | `state/git/config` |
  | `state/claude/projects/-home-sandbox-$CODE` | renamed to `-home-sandbox-workspace-$NAME` (old sessions show in `/resume`, ccusage keeps the usage) |

  Not carried: `.npm`, `.cache`, `.local`, `.initialized` and other caches; the tools fetch them again. The researcher confirms the exact project-dir name encoding and anything else in `.claude.json` keyed by the old path.
- **D-09:** Order of commands: stop the old container (`cc-down`), copy, rename, then `sbx-add NAME NEW` and `sbx-shell NAME` (sbx-add accepts an existing folder, Phase 4 D-12).
- **D-10:** The recipe ends with three checks the user looks at: `sbx-claude` starts logged in, `/resume` lists the old sessions, `ccusage` shows pre-migration usage. Plus a short "if something is wrong" line: remove with `sbx-rm NAME --unregister`, the old sandbox still works.
- **D-11:** Example values use the real case from the roadmap: `GSD_StaticSiteGenerator` with code at `MyCode`.

### This dev sandbox
- **D-12:** `sbx-add` refuses a sandbox folder that holds the repo the Mac runs `bin/` from. So the Mac gets one plain clone of the repo used only to run the `sbx-*` scripts (suggested `~/sbx-tools/GetShitDoneContainer`, its `bin/` on `PATH`), and this sandbox's copy stays the agent's working copy. MIGRATION.md has a short extra section for this case.
- **D-13:** This sandbox is migrated last.

### Old layout removal
- **D-14:** Delete `ClaudeCode/` and `OpenCode/` entirely. Git history keeps them; OpenCode comes back later on the new base image. This closes the STATE.md question of whether SCR-08 covers `OpenCode/`.
- **D-15:** The deletion is the last step of the phase, done only after the user confirms all 4 sandboxes are migrated. The checks that only protect the old layout during coexistence go with it: guard rule `old_layout_untouched` (`tests/guard/isolation.sh`), the old-layout record in `tests/host/run-all.sh` and `tests/host/lib-docker.sh`, `tests/host/coexistence.sh`. Removing those is deletion, not new shell.

### Threat model (README section)
- **D-16:** A short schematic section: what is isolated (one mounted folder, no Mac home, unprivileged user), the credential-exfiltration risk under skip-permissions (the agent can read `state/` tokens and reach the network), and files the agent can plant that the Mac later runs.
- **D-17:** Host git is documented as a rule, with no new code: the agent can plant `.git/hooks/*` and git config (`core.fsmonitor`, `core.pager`, `diff.external`, `credential.helper`, `core.sshCommand`) in the project folder; run git inside the sandbox, or treat Mac-side git and IDE git on that folder as running agent code. Same for IDE run configs. Folds the pending todo on host git.

### Verification
- **D-18:** The acceptance test for the migration is the user migrating the smallest sandbox with MIGRATION.md and seeing the three checks pass. No new automated test.
- **D-19:** DOC-04 (host-side checklist) is met by the existing `./host-test.sh` and `tests/host-checklist.md`; README points at them. Nothing new is built.

### Claude's Discretion
- Exact structure and wording of the new README and MIGRATION.md, within D-03.
- Whether to copy with `cp -R` or `rsync -a`, as long as it works with macOS (BSD) tools and paths with spaces.
- How the Mac tools clone is set on `PATH` (shell profile line).

### Folded Todos
- **Host git on agent-writable project folders needs its own design** (`.planning/todos/pending/2026-10-24-host-git-on-agent-writable-folders.md`): resolved by documentation only (D-17). The wrapper, Edit deny and separate git dir options are not taken.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope
- `.planning/ROADMAP.md` (Phase 5) — goal and the 5 success criteria
- `.planning/REQUIREMENTS.md` — SCR-08, DOC-01, DOC-02, DOC-03, DOC-04
- `.planning/PROJECT.md` — Constraints (Coexistence until Phase 5; security)

### Docs being rewritten or replaced
- `SANDBOX.md` — becomes `README.md`; source of every current fact (layout table, scripts, upgrade flow, bundle, GSD, ccusage, troubleshooting)
- `README.md` — old-layout doc being replaced
- `ClaudeCode/README.md` — old-layout doc, deleted with `ClaudeCode/`

### Old layout (what migration reads from, what gets deleted)
- `ClaudeCode/docker-compose.yml`, `ClaudeCode/cc-up.sh`, `cc-bash.sh`, `cc-down.sh`, `docker-entrypoint.sh`, `Dockerfile` — whole home mounted at `/home/sandbox`
- `OpenCode/` — deleted

### New layout facts the recipe depends on
- `claude/Dockerfile` — `CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude`, `~/.claude` link
- `bin/sbx-add` — accepts an existing folder; refuses a folder that overlaps the repo, the registry or another sandbox
- `.planning/phases/04-jump-in-and-sandbox-housekeeping/04-CONTEXT.md` — D-12 re-register round trip

### Checks tied to the old layout
- `tests/guard/isolation.sh` (`old_layout_untouched`), `tests/guard/supply-chain.sh` (SANDBOX.md in its file list), `tests/host/coexistence.sh`, `tests/host/run-all.sh` (`record_old_layout`), `tests/host/lib-docker.sh`

### Todo folded
- `.planning/todos/pending/2026-10-24-host-git-on-agent-writable-folders.md`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SANDBOX.md` already has the layout table (`$SBX_DIR/state/*` to container path to env var), the script table, upgrade flow, gh/git identity notes and a troubleshooting row for migrated sandboxes loading rules twice.
- `sbx-add`, `sbx-shell`, `sbx-rm --unregister` cover register, enter and undo; the recipe only needs `cp`/`mv` plus these.
- `./host-test.sh` plus `tests/host-checklist.md` already verify login across rebuild, pins, ccusage and the visible home (DOC-04).

### Established Patterns
- Docs style: schematic tables, labelled lists, no dashes as punctuation, punctuation outside quotes, ASCII in source files.
- Mac commands must be BSD/macOS-portable and handle paths with spaces.
- Code and `.planning/` go in separate branches and PRs.

### Integration Points
- References to `SANDBOX.md` in `compose.yml`, `versions.env`, `base/sbx-start-lib.sh`, `tests/guard/supply-chain.sh`, `tests/host-checklist.md`, `tests/host/h23-caches-survive-recreate.sh`, `prompts/consolidate-memories.md`.
- Old-layout guards listed under canonical refs; they go in the same change that deletes `ClaudeCode/` and `OpenCode/`.

</code_context>

<specifics>
## Specific Ideas

- Real example for the recipe: `GSD_StaticSiteGenerator` with code at `/home/sandbox/MyCode`.
- This dev sandbox: code at `GetShitDoneContainer`, Claude project dir `-home-sandbox-GetShitDoneContainer`.
- The user does not want to run anything beyond the recipe itself.

</specifics>

<deferred>
## Deferred Ideas

### Reviewed Todos (not folded)
The other 10 pending todos matched on generic keywords only. They are script or test fixes (bundle clone hint, bundle hook atomicity, user skills, sbx-claude wait, sbx-gh-login re-login, shell diet second PR, skill list locale order, guard glob, H-18 readiness, H-19 wording) and add shell work this phase rules out (D-01). They stay pending.

</deferred>

---

*Phase: 05-migration-docs-and-old-layout-retirement*
*Context gathered: 2026-11-08*
