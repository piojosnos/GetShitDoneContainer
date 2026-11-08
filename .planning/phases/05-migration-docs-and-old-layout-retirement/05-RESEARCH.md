# Phase 5: Migration, Docs, and Old-Layout Retirement - Research

**Researched:** 2026-11-08
**Domain:** Documentation rewrite, hand migration of Claude Code state between two mount layouts, deletion of a retired layout and its guards
**Confidence:** HIGH (path encoding, `.claude.json` location, repo inventory); MEDIUM (ccusage `session` labels, GSD settings merge on a migrated config)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Ground rule**
- **D-01:** No migration script, no new shell, no new self-test or host check. The user migrates each sandbox by hand from a copy/paste recipe. Why: the user explicitly does not want more shell to write, run and test; 4 sandboxes do not justify a tool.

**Docs layout**
- **D-02:** `SANDBOX.md` becomes `README.md` (git mv, then edit). The old `README.md` (old layout only) is replaced. There is one main doc.
- **D-03:** The new `README.md` must be very simple, streamlined, easy to read and schematic: tables, short labelled lists, copy/paste command blocks, one idea per line. It is a rewrite pass over today's 476-line `SANDBOX.md`, not a rename only: cut repetition, move rare detail down or out, keep every fact a user needs. The user stressed this as the bar for the phase.
- **D-04:** The one-time migration recipe lives in its own `MIGRATION.md`, linked from `README.md`. Why: once the 4 sandboxes are moved, the main doc never makes the user scroll past it. DOC-02 is met by README linking to MIGRATION.md.
- **D-05:** Every reference to `SANDBOX.md` in the repo points at `README.md` afterwards (comments in `compose.yml`, `versions.env`, the message in `base/sbx-start-lib.sh`, the guard file list in `tests/guard/supply-chain.sh`, `tests/host-checklist.md`, `tests/host/h23-caches-survive-recreate.sh`, `prompts/consolidate-memories.md`).

**Migration recipe (MIGRATION.md)**
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

**This dev sandbox**
- **D-12:** `sbx-add` refuses a sandbox folder that holds the repo the Mac runs `bin/` from. So the Mac gets one plain clone of the repo used only to run the `sbx-*` scripts (suggested `~/sbx-tools/GetShitDoneContainer`, its `bin/` on `PATH`), and this sandbox's copy stays the agent's working copy. MIGRATION.md has a short extra section for this case.
- **D-13:** This sandbox is migrated last.

**Old layout removal**
- **D-14:** Delete `ClaudeCode/` and `OpenCode/` entirely. Git history keeps them; OpenCode comes back later on the new base image. This closes the STATE.md question of whether SCR-08 covers `OpenCode/`.
- **D-15:** The deletion is the last step of the phase, done only after the user confirms all 4 sandboxes are migrated. The checks that only protect the old layout during coexistence go with it: guard rule `old_layout_untouched` (`tests/guard/isolation.sh`), the old-layout record in `tests/host/run-all.sh` and `tests/host/lib-docker.sh`, `tests/host/coexistence.sh`. Removing those is deletion, not new shell.

**Threat model (README section)**
- **D-16:** A short schematic section: what is isolated (one mounted folder, no Mac home, unprivileged user), the credential-exfiltration risk under skip-permissions (the agent can read `state/` tokens and reach the network), and files the agent can plant that the Mac later runs.
- **D-17:** Host git is documented as a rule, with no new code: the agent can plant `.git/hooks/*` and git config (`core.fsmonitor`, `core.pager`, `diff.external`, `credential.helper`, `core.sshCommand`) in the project folder; run git inside the sandbox, or treat Mac-side git and IDE git on that folder as running agent code. Same for IDE run configs. Folds the pending todo on host git.

**Verification**
- **D-18:** The acceptance test for the migration is the user migrating the smallest sandbox with MIGRATION.md and seeing the three checks pass. No new automated test.
- **D-19:** DOC-04 (host-side checklist) is met by the existing `./host-test.sh` and `tests/host-checklist.md`; README points at them. Nothing new is built.

### Claude's Discretion
- Exact structure and wording of the new README and MIGRATION.md, within D-03.
- Whether to copy with `cp -R` or `rsync -a`, as long as it works with macOS (BSD) tools and paths with spaces.
- How the Mac tools clone is set on `PATH` (shell profile line).

### Deferred Ideas (OUT OF SCOPE)
The other 10 pending todos matched on generic keywords only (bundle clone hint, bundle hook atomicity, user skills, sbx-claude wait, sbx-gh-login re-login, shell diet second PR, skill list locale order, guard glob, H-18 readiness, H-19 wording). They add shell work this phase rules out (D-01). They stay pending. The host-git todo is folded (D-17) and resolved by documentation only; the wrapper, Edit deny and separate git dir options are not taken.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCR-08 | The old `cc-*` scripts and the whole-home-mount layout are removed from the repo | Inventory of every file and guard/test hook to delete or edit (sections "Old-layout removal inventory" and "Guard and test edits"); deletion must be the last PR (D-15) |
| DOC-01 | README describes the new layout, scripts, upgrade flow; matches the repo (no phantom `cc-upgrade.sh`) | Facts inventory from `SANDBOX.md` verified against `bin/`, `compose.yml`, `build.sh`, Dockerfiles; `cc-upgrade.sh` appears only in the old `ClaudeCode/README.md` (script never existed in the tree); one-off existence check recipe |
| DOC-02 | README documents how to migrate (code to `<name>/`, state incl. `.claude.json` to `state/claude`, rename history project path) | Tested recipe (section "Code Examples"), exact encoding rule, `.claude.json` location, other path-keyed data |
| DOC-03 | README short threat-model section | Facts from `compose.yml`, `sbx-add` overlap checks, plaintext token locations; planted-file list (section "Threat model facts") |
| DOC-04 | Host-side verification checklist exists and runs end-to-end on the Mac | Existing `./host-test.sh` + `tests/host-checklist.md`; map from the four DOC-04 questions to existing check IDs (section "DOC-04 map") |
</phase_requirements>

## Summary

This phase is documentation plus deletion, with no new shell (D-01). The research job was to make the migration recipe exact. Three facts settle it, and all three were confirmed against the pinned Claude Code binary (2.1.285) and the official docs. First, Claude Code names a project folder by replacing every character that is not a letter or digit with `-` (so `_`, `.`, spaces and `-` all become `-`), capped at 200 characters plus a hash. The recipe must therefore encode `$CODE` before building the old folder name; using the raw `$CODE` (as D-08's table literally reads) breaks for `GSD_StaticSiteGenerator`-style names with underscores. Second, with `CLAUDE_CONFIG_DIR` set the global config is `$CLAUDE_CONFIG_DIR/.claude.json`, not `~/.claude.json`, so it must go to `state/claude/.claude.json`. Third, ccusage reads `$CLAUDE_CONFIG_DIR/projects/**`, so copying `projects/` is all it needs.

Two non-obvious findings change the recipe beyond D-08. (1) `.claude.json` holds a `projects["/home/sandbox/<CODE>"]` entry (trust, allowed tools, MCP servers) and `githubRepoPaths`, and `history.jsonl` stamps each prompt with the old project path. If left alone the only effect is a repeated trust prompt, lost per-project MCP/allowed-tool settings and no up-arrow history for that project; a one-line `sed` repoints them and was dry-run tested. (2) The old `.gitconfig` points git at `!/usr/bin/gh auth git-credential` (apt gh at `/usr/bin/gh`), but the new image installs gh only at `/usr/local/bin/gh`, so a verbatim copy leaves HTTPS git without a working credential helper. The recipe must rewrite that path while copying.

Repo-side, one sequencing trap: the guard rule `old_layout_untouched` diffs `README.md` against the old commit, so replacing README.md (D-02) fails the guard unless that pathspec is dropped in the same change. Therefore split into two code PRs: PR A (docs, references, drop `README.md` from the rule) and PR B (retirement, after the user confirms all four sandboxes migrated).

**Primary recommendation:** Write MIGRATION.md around a tested variable block (`OLD`, `NEW`, `NAME`, `CODE`, `ENC` derived by `sed 's/[^a-zA-Z0-9]/-/g'`), stop the old container with plain `docker stop` (not `cc-down`, which removes it and which is deleted in PR B), and ship the work as PR A (README/MIGRATION/refs) then PR B (deletion + guard/test edits), each validated on the Mac with `./host-test.sh`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Migration recipe (copy, rename, repoint) | Mac host shell (user pastes) | Container (first start syncs GSD, relinks bundle) | Files live on the Mac; container never touches OLD. D-01 forbids a tool |
| Project-dir rename for `/resume` and ccusage | Mac host (files under `state/claude/projects`) | Container (Claude and ccusage read it) | Claude derives the folder from the container cwd `/home/sandbox/workspace/<name>` |
| Stopping the old sandbox | Mac Docker (`docker stop cc_gsd_<proj>`) | none | Old container is outside the new registry and scripts |
| Register and enter the new sandbox | Repo `bin/` scripts on the Mac | Container | Existing `sbx-add`, `sbx-shell`, `sbx-rm --unregister` |
| README / MIGRATION.md | Repo docs | none | Docs follow code (AGENTS.md); code is ground truth |
| Old-layout retirement | Repo (git delete) | Guard and host tests | SCR-08; guards that protect the old layout go with it |
| Host verification | Mac (`./host-test.sh`, `tests/host/manual/`) | none | Docker is not available in the dev sandbox |
| Threat model statement | Repo docs | Compose/Dockerfile facts | Documents limits that compose already enforces |

## Standard Stack

No new library, tool or package is introduced. The phase uses what exists.

### Core
| Tool | Version | Purpose | Why |
|------|---------|---------|-----|
| `cp -Rp SRC/. DST/` | macOS BSD cp / GNU cp | Copy folders incl. dotfiles, keep modes | The `SRC/.` form behaves the same on BSD and GNU; trailing-slash `SRC/` does not [ASSUMED] |
| `sed 's/...//' IN > TMP && mv TMP IN` | BSD sed / GNU sed | Encode the folder name, repoint paths | `sed -i` differs between BSD (`-i ''`) and GNU (`-i`), so write to a temp file and `mv` |
| `docker stop` / `docker start` | Docker Desktop | Pause and roll back the old container | Old container name is `cc_gsd_${PROJECT_NAME}` [VERIFIED: ClaudeCode/docker-compose.yml `container_name: cc_gsd_${PROJECT_NAME}`] |
| `sbx-add`, `sbx-shell`, `sbx-rm --unregister`, `sbx-claude`, `ccusage` | repo `bin/` and image | Register, enter, undo, check | Already shipped in Phases 3 and 4 |
| `./host-test.sh`, `tests/host-checklist.md` | repo | DOC-04 verification | D-19: nothing new |

### Supporting
| Tool | Purpose | When |
|------|---------|------|
| `bash tests/guard/run-all.sh` | Prove the guard still passes after each PR | Every task commit (any sandbox or Mac shell) |
| `bash tests/selftest/guard/run-all.sh` | Prove a guard rule can still fail | After editing `tests/guard/*.sh` |
| `bash tests/selftest/sbx/run-all.sh` | `bin/` unchanged, sanity | Optional |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `cp -Rp` | `rsync -a` | macOS ships an old rsync (2.6.9 era / openrsync) [ASSUMED]; `cp` is on every Mac and is enough for a one-off copy |
| `docker stop cc_gsd_X` | `cc-down.sh` | `cc-down` runs `docker-compose -p cc_X down -v`, which deletes the container (no rollback by `docker start`) and is removed in PR B [VERIFIED: ClaudeCode/cc-down.sh] |
| Edit `.claude.json` with `sed` | Accept a one-time trust prompt | `sed` keeps trust, allowed tools and MCP servers; skipping it is the zero-risk default. Offer `sed` as an optional step |

**Installation:** none.

**Version verification:** no package is added. Pinned versions the docs quote come from `versions.env` [VERIFIED: versions.env lines 17-20]: `CLAUDE_CODE_VERSION=2.1.285`, `GSD_CORE_VERSION=1.15.0`, `CCUSAGE_VERSION=20.0.26`. The README must not hard-code them; it points at `versions.env`.

## Package Legitimacy Audit

No external package is installed or recommended in this phase. `gsd-tools query package-legitimacy check` was not needed.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

The only package names that appear are already pinned and audited in earlier phases (`@opengsd/gsd-core`, `ccusage`, `@anthropic-ai/claude-code`). The old OpenCode entrypoint installs `get-shit-done-cc` [VERIFIED: OpenCode/docker-entrypoint.sh line `npx -y get-shit-done-cc --opencode --global`]; deleting `OpenCode/` removes that compromised-package reference from the tree (the guard rule `no_compromised_gsd_package` never scanned it).

## Architecture Patterns

### System Architecture Diagram

```text
 OLD sandbox folder on the Mac ($OLD, mounted whole at /home/sandbox)
 +-- $CODE/                  ----cp -Rp---->  $NEW/$NAME/                     (code)
 +-- .claude/                ----cp -Rp---->  $NEW/state/claude/              (login, sessions, GSD, skills)
 |     projects/-home-sandbox-$ENC  --mv-->   projects/-home-sandbox-workspace-$NAME   (rename)
 |     history.jsonl         --sed (opt)-->   project path repointed
 +-- .claude.json            ----cp -p----->  $NEW/state/claude/.claude.json  (sed opt: repoint projects key)
 +-- .bash_history           ----cp -p----->  $NEW/state/shell/bash_history
 +-- .config/gh/             ----cp -Rp---->  $NEW/state/gh/
 +-- .gitconfig              --sed(gh path)-> $NEW/state/git/config
 (not carried: .npm .cache .local .initialized)

 Mac shell:  docker stop cc_gsd_<proj>   (old stays as rollback)
        |
        v
 sbx-add NAME $NEW   (existing folder accepted; creates only what is missing)
        |
        v
 sbx-shell NAME  -> container start: 05-gsd syncs image GSD into state/claude,
        |            10-best-practices relinks rules/skills (or says run sbx-bundle-clone)
        v
 cwd = /home/sandbox/workspace/$NAME   <-- must equal the renamed projects/ folder
        |
        +--> sbx-claude   : logged in  (state/claude/.credentials.json)
        +--> /resume      : lists sessions in projects/-home-sandbox-workspace-$NAME
        +--> ccusage      : reads $CLAUDE_CONFIG_DIR/projects/**  (pre-migration usage)
```

### Recommended Project Structure (end of phase)

```text
README.md            # was SANDBOX.md, rewritten; the one main doc
MIGRATION.md         # one-time recipe, linked from README
compose.yml  build.sh  clean.sh  host-test.sh  versions.env
base/  claude/  bin/  prompts/
tests/{guard,selftest,host,host-checklist.md,README.md}
# gone: ClaudeCode/  OpenCode/  old README.md  tests/host/coexistence.sh
```

### Pattern 1: Variables once, commands paste unchanged (D-07)
**What:** one block of four assignments plus one derived value, then plain commands that quote every expansion.
**When to use:** the whole of MIGRATION.md.
**Example:** see "Code Examples".

### Pattern 2: Docs follow code, schematic
**What:** tables for facts (layout, scripts), labelled lists for steps, one idea per line, no dashes as punctuation, punctuation outside closing quotes, ASCII only [VERIFIED: ~/.claude/AGENTS.md and code-conventions.md in this session's context].
**When to use:** README and MIGRATION.md. Match the existing `SANDBOX.md` voice (target-state, class/token oriented).

### Pattern 3: Two PRs, code never mixed with `.planning/` or `.claude/`
**What:** PR A docs and references; PR B deletion. Planning artifacts and `.claude/CLAUDE.md` go in their own PRs [CITED: project memory "separate-prs-for-planning-and-claude"]. Branch from the updated target, `feat/` or `chore/` names, human merges.
**Why two code PRs:** D-15 makes deletion last, after the user migrates, and MIGRATION.md must be merged and pullable before the user can follow it.

### Anti-Patterns to Avoid
- **Raw `$CODE` in the old project folder name.** Claude encodes it; `GSD_StaticSiteGenerator` is `-home-sandbox-GSD-StaticSiteGenerator`. Always derive `ENC`.
- **`cc-down` in the recipe.** It deletes the container (`down -v`) and the script vanishes in PR B.
- **`sed -i` in the recipe.** GNU and BSD disagree; use temp file plus `mv`.
- **Copying with a trailing slash only (`cp -R "$OLD/.claude/" ...`).** BSD and GNU differ on whether the folder or its contents land; use `SRC/.`.
- **Docs that name files or commands that do not exist** (SC2). Check before finishing.
- **Mentioning internal phase or decision IDs in committed docs/comments** (AGENTS.md rule).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Migrating 4 sandboxes | A `sbx-migrate` script | Copy/paste recipe in MIGRATION.md | D-01; out-of-scope table in REQUIREMENTS.md |
| Undo a failed migration | New cleanup logic | `sbx-rm NAME --unregister` plus the untouched old folder | Already shipped; deletes nothing in `$NEW` |
| Checking the migrated sandbox | A new host check | The three eyes-on checks (D-10) and existing H-checks | D-18, D-19 |
| Verifying README accuracy | A committed doc linter | A one-off grep during verification (see Validation Architecture) | D-01 forbids new committed checks |
| Name encoding by hand | A lookup table of cases | `sed 's/[^a-zA-Z0-9]/-/g'` | Same rule Claude uses |

**Key insight:** every piece of state is plain files on the Mac, and Claude/ccusage/gh/git read them by path. The migration is path hygiene only; nothing needs to run inside the old container.

## Facts the recipe depends on (all checked this session)

| Fact | Evidence |
|------|----------|
| Project folder name = cwd with every char outside `[a-zA-Z0-9]` replaced by `-`; names over 200 chars are cut to 200 plus `-` plus a hash | [VERIFIED: pinned Claude binary 2.1.285, function `k(e){return e.replace(/[^a-zA-Z0-9]/g,"-")}` and `function LA(e){let n=k(e);if(n.length<=Bre)return n;return`${n.slice(0,Bre)}-${Le(e)}``, `var Bre=200`]; [CITED: code.claude.com/docs/en/claude-directory: "`<project>` is your working directory path with every character other than letters and digits replaced by `-`, such as `-Users-you-my-project`"] |
| This dev sandbox: `/home/sandbox/GetShitDoneContainer` is stored as `-home-sandbox-GetShitDoneContainer` | [VERIFIED: `ls ~/.claude/projects` printed `-home-sandbox-GetShitDoneContainer`] |
| New-layout folder for a sandbox named `hosttest` is `projects/-home-sandbox-workspace-hosttest` | [VERIFIED: tests/host/h09-rebuild-keeps-files-no-volumes.sh `memorySentinel=$RUN/state/claude/projects/-home-sandbox-workspace-hosttest/memory/h09-memory.md`] |
| New-layout cwd is `/home/sandbox/workspace/<name>` | [VERIFIED: bin/sbx-shell `exec docker exec -it -w "/home/sandbox/workspace/$1" "sbx-$1" bash`; compose.yml `working_dir: "/home/sandbox/workspace"`] |
| New name rule `^[a-z][a-z0-9-]{0,30}$`; `state` and `best-practices` reserved | [VERIFIED: base/sbx-start-lib.sh `sandboxNamePattern='^[a-z][a-z0-9-]{0,30}$'` and `sandboxReservedNameList="state best-practices"`]. So `MyCode` is not a legal NAME; use `mycode` or `my-code`. A legal NAME encodes to itself, so the new side needs no encoding |
| `CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude`; `~/.claude` is a symlink to it | [VERIFIED: claude/Dockerfile `ENV CLAUDE_CONFIG_DIR=/home/sandbox/workspace/state/claude` and `ln -s /home/sandbox/workspace/state/claude /home/sandbox/.claude`] |
| Global config path = `$CLAUDE_CONFIG_DIR/.claude.json` when set, else `~/.claude.json` | [VERIFIED: pinned binary `globalConfig:nt(e||Bt(),".claude.json")` with `ySn("CLAUDE_CONFIG_DIR")`]; [CITED: claude-directory docs: "If you set CLAUDE_CONFIG_DIR, every ~/.claude path on this page lives under that directory instead. The same applies to .claude.json, which otherwise sits at ~/.claude.json"]; the repo's own helper asserts no `~/.claude.json` in the container home [VERIFIED: tests/host/manual/h07-login.sh lines 37-73] |
| Old layout left `CLAUDE_CONFIG_DIR` unset, so `.claude.json` sat at `$OLD/.claude.json` and credentials at `$OLD/.claude/.credentials.json` | [VERIFIED: ClaudeCode/docker-compose.yml sets no environment; ClaudeCode/docker-entrypoint.sh comment "Claude login (which lives in ~/.claude.json and ~/.claude/.credentials.json)"; this sandbox has both files] |
| `.claude.json` keys that hold the old path: `projects["/home/sandbox/<CODE>"]` (trust, allowed tools, MCP servers, last-session stats) and `githubRepoPaths` | [VERIFIED: `node` read of ~/.claude.json: `projects keys: [ '/home/sandbox/GetShitDoneContainer' ]`, `githubRepoPaths: {"piojosnos/getshitdonecontainer":["/home/sandbox/GetShitDoneContainer"]}`]; [CITED: docs "The project's entry in ~/.claude.json" (trust, history, MCP servers)] |
| `history.jsonl` lines carry `"project":"<old cwd>"`, used for up-arrow recall | [VERIFIED: head of ~/.claude/history.jsonl]; [CITED: docs "Prompts you've typed, with timestamp and project path. Used for up-arrow recall"] |
| Transcript lines carry `"cwd":"<old cwd>"` inside the `.jsonl` | [VERIFIED: `grep -o '"cwd":...'` over projects/*.jsonl]. Whether `/resume` cares is not documented; Claude lists by folder name. Do not rewrite transcripts [ASSUMED safe] |
| Auto memory lives in `projects/<project>/memory/`, so the rename carries it | [CITED: claude-directory docs table row `projects/<project>/memory/`] |
| ccusage reads `$CLAUDE_CONFIG_DIR/projects/` (comma-separated list allowed); without it `~/.config/claude/projects/` and `~/.claude/projects/` | [CITED: ccusage.com/guide/claude/ "Set CLAUDE_CONFIG_DIR when Claude Code logs live outside the default locations"]; the image sets `CLAUDE_CONFIG_DIR`, and H-24 proves a planted transcript in `state/claude` is reported [VERIFIED: tests/host/h24-ccusage-reports-usage.sh header "ccusage reports this sandbox's Claude usage from state/claude"] |
| `ccusage daily` and `monthly` do not depend on the folder name; `ccusage session` may label by project folder | `daily`/`monthly` independence and `session` labelling [ASSUMED]; the docs page does not say. Do not promise a particular session label in the docs |
| Old `.gitconfig` helper is `!/usr/bin/gh auth git-credential`; new gh lives only at `/usr/local/bin/gh` | [VERIFIED: ~/.gitconfig of this old sandbox shows `helper = !/usr/bin/gh auth git-credential`; base/Dockerfile extracts gh with `tar ... -C /usr/local/bin ... gh` and installs no apt gh] |
| gh and git state paths in the new layout | [VERIFIED: base/Dockerfile `GH_CONFIG_DIR=/home/sandbox/workspace/state/gh`, `GIT_CONFIG_GLOBAL=/home/sandbox/workspace/state/git/config`, `HISTFILE=/home/sandbox/workspace/state/shell/bash_history`] |
| Old container name | [VERIFIED: ClaudeCode/docker-compose.yml `container_name: cc_gsd_${PROJECT_NAME}`; ClaudeCode/cc-up.sh runs `docker-compose -p "cc_${PROJECT_NAME}" up -d`; cc-down runs `docker-compose -p "cc_${PROJECT_NAME}" down -v`] |
| `sbx-add` accepts an existing folder (`mkdir -p`), refuses overlap with the registry, the repo folder and other sandboxes, and a name outside the rule | [VERIFIED: bin/sbx-add `create_folders` = `mkdir -p "$hostPath/$1" "$hostPath/state"`; `refuse_repo_overlap`, `refuse_registry_overlap`, `refuse_sandbox_overlap`] |
| Start syncs GSD and relinks the bundle; a migrated `CLAUDE.md` importing `@AGENTS.md` and `@code-conventions.md` double-loads rules once the clone exists | [VERIFIED: claude/start.d/05-gsd, claude/start.d/10-best-practices (`rm -rf "$configDir/rules"` then link); SANDBOX.md troubleshooting row "A sandbox migrated from the old layout loads the same rules twice"; this sandbox's ~/.claude/CLAUDE.md is exactly `@AGENTS.md` and `@code-conventions.md`] |

## Inventory

### Old-layout removal inventory (PR B)

| Path | Action | Evidence |
|------|--------|----------|
| `ClaudeCode/` (Dockerfile, README.md, cc-bash.sh, cc-down.sh, cc-up.sh, docker-compose.yml, docker-entrypoint.sh) | `git rm -r` | [VERIFIED: `git ls-files`] |
| `OpenCode/` (Dockerfile, docker-compose.yml, docker-entrypoint.sh) | `git rm -r` (D-14) | [VERIFIED: `git ls-files`] |
| `tests/host/coexistence.sh` | `git rm` | [VERIFIED: file read; checks `cc_` containers and `ClaudeCode`/`OpenCode` git state] |
| `tests/guard/isolation.sh`: constant `OLD_LAYOUT_COMMIT=304f80d...` with its banner, function `old_layout_untouched`, and its line in `run_rules`; fix the file banner "data kept, old layout kept" | edit | [VERIFIED: tests/guard/isolation.sh lines 3, 12-17, 66-71, 81] |
| `tests/host/run-all.sh`: `finalCheckList="coexistence.sh"`, the `remainingList` reference, function `record_old_layout` and its call, `run_list "$finalCheckList"` in Main | edit | [VERIFIED: lines 25, 27, 217-236, 305, 311]. `run_list` loops over its argument, so an empty list is safe, but remove the variable and call cleanly |
| `tests/host/lib-docker.sh`: functions `snapshot_old_containers`, `snapshot_old_folders`, and the file banner "old-layout snapshots" | edit | [VERIFIED: lines 3, 62-100] |
| `tests/host-checklist.md`: the `Coexistence` row (line 72) and the bullet "Coexistence fails" (line 127) | edit | [VERIFIED] |
| `tests/README.md`: "19 rules" becomes 18; "H-00 to H-33 and Coexistence" loses "and Coexistence" | edit | [VERIFIED: tests/README.md lines 40, 60] |
| `host-test.sh` line 52 comment "H-00 to H-33 and Coexistence" | edit | [VERIFIED] |
| `tests/selftest/guard/*` | no rule `old_layout_untouched` case exists | [VERIFIED: grep for `old_layout|ClaudeCode|README` in tests/selftest/guard returned nothing] |
| `tests/host/h32-sbx-list.sh` line ~100 (`sbx-list printed a line with cc_`) | keep or reword; it asserts old containers never show in `sbx-list`, which stays true | [VERIFIED] |
| `bin/sbx-list` comment "The label keeps the old-layout containers out" | optional reword | [VERIFIED] |
| `.claude/CLAUDE.md` (generated project file) | Describes `ClaudeCode/`, `OpenCode/`, `cc-*` throughout and the "Coexistence" constraint; dangling after PR B. Needs a refresh, in its own `.claude/` PR | [VERIFIED: grep]. See Open Question 2 |
| `.planning/PROJECT.md` Constraints "Coexistence", Key Decisions row, and REQUIREMENTS/STATE | Updated by GSD transition, in the planning PR | [VERIFIED: PROJECT.md lines 63, 83, 95] |

### SANDBOX.md references to retarget (PR A)

All seven places from D-05 confirmed [VERIFIED: grep]:
`compose.yml:5`, `versions.env:5`, `base/sbx-start-lib.sh:34` (message text "see SANDBOX.md"), `tests/guard/supply-chain.sh:14` (file list), `tests/host-checklist.md:7,116,118` (line 116 is a link with an anchor `#troubleshooting-and-known-limits`; keep that heading text in the README or update the anchor), `tests/host/h23-caches-survive-recreate.sh:92`, `prompts/consolidate-memories.md:10` (relative link `../SANDBOX.md`, becomes `../README.md`).

Also: `SANDBOX.md` line 12 says the layout "runs side by side with the old `ClaudeCode/` layout ... stays documented in `README.md`" and line 475 mentions migration; both are rewritten. No test asserts the text "see SANDBOX.md" [VERIFIED: grep over tests/ shows no match], so editing `base/sbx-start-lib.sh` needs no test change; it does change the image (a rebuild marks other running sandboxes "older image", which is expected).

### Guard trap in PR A
`old_layout_untouched` runs `git diff --quiet 304f80d... -- ClaudeCode OpenCode README.md` [VERIFIED: tests/guard/isolation.sh:69]. Replacing `README.md` makes it fail. PR A must remove `README.md` from that pathspec (keep `ClaudeCode OpenCode`, which PR A does not touch). Then PR B removes the rule entirely. The guard is run by `./host-test.sh` ("guard in the Mac shell" and in `sbx-hosttest`), so a miss here fails the Mac run.

### Facts the README must keep (from SANDBOX.md, verified against code)

| Section in SANDBOX.md | Keep as | Check against |
|---|---|---|
| Two-mount layout table (`$SBX_DIR/<name>`, `best-practices`, `state`) | Keep, it is the core table | compose.yml volumes [VERIFIED] |
| "What lives where" mapping table (state/claude, shell, gh, git, cache/npm, cache/uv, m2) with env vars | Keep, trimmed | base/Dockerfile ENV [VERIFIED] |
| Images table; Requirements; name rule | Keep short | base/Dockerfile, sbx-start-lib.sh |
| Scripts table (7 in `bin/`; 3 in-container: `sbx-claude`, `sbx-gh-login`, `sbx-bundle-clone`) | Keep as one table each | `ls bin` shows sbx-add, sbx-list, sbx-rm, sbx-shell, sbx-start, sbx-stop, sbx-upgrade plus `sbx-lib.sh` [VERIFIED]; claude/bin has the three wrappers [VERIFIED: git ls-files] |
| Upgrade flow: edit `versions.env`, `sbx-upgrade NAME` | Keep, headline | bin/sbx-upgrade, build.sh [VERIFIED] |
| Registry file format `~/.config/sbx/sandboxes/NAME` | Keep 2-line example | bin/sbx-add `write_entry` [VERIFIED] |
| Bundle, GSD, ccusage, safety checks, disk space, troubleshooting | Keep, compress; move rare detail (raw compose commands, image-only smoke test, per-error hook text) down | |
| Verify a new build / host-test | Keep, shrink; point at `tests/host-checklist.md` | host-test.sh [VERIFIED] |
| Threat model | New section (below) | |

`cc-upgrade.sh` appears in `ClaudeCode/README.md` ("`cc-upgrade.sh` | One-command routine upgrade") but the file is not in the tree [VERIFIED: `git ls-files` shows only cc-bash, cc-down, cc-up]. Deleting that README in PR B removes the phantom. The new README must not mention any `cc-*` command except in MIGRATION.md's "old sandbox" context (container name `cc_gsd_<proj>`).

### DOC-04 map (existing checks answer the four questions)

| DOC-04 question | Existing check | How the user runs it |
|---|---|---|
| Login survives a rebuild | `tests/host/manual/h09-rebuild-resume.sh` (login and `claude --continue` after rebuild), `manual/h29-upgrade-resume.sh` (after `sbx-upgrade`); automatic H-09 covers files and memory | `bash tests/host/manual/h09-rebuild-resume.sh` (needs a login in the test sandbox; `h07-login.sh` makes one) [VERIFIED: tests/host-checklist.md helper table] |
| Versions match the pins | H-25 (images match `versions.env`), H-30 (versions line), host-test step "pin digests", build-time smoke tests in both Dockerfiles | `./host-test.sh` [VERIFIED: checklist rows H-25, H-30; host-test.sh steps] |
| ccusage works | H-24 | `./host-test.sh` [VERIFIED] |
| Home is not hidden | H-05 (`.bashrc` and `.local` listed in `/home/sandbox`), build-time `ls -A /home/sandbox/workspace` empty check | `./host-test.sh` [VERIFIED: tests/host/h05-workspace-and-home.sh `for wanted in .bashrc .local`] |

The README needs one short "Verify" table with these four rows and the commands; no new file.

## Threat model facts (for the README section, D-16, D-17)

| Topic | Statement to make | Evidence |
|---|---|---|
| Isolated | One bind mount (`$SBX_DIR` at `/home/sandbox/workspace`); no Mac home, no `~/.ssh`, no Docker socket; non-root `sandbox` uid 1000; all capabilities dropped; `no-new-privileges` | [VERIFIED: compose.yml `cap_drop: ALL`, `security_opt: no-new-privileges:true`, single `volumes` entry; base/Dockerfile `useradd -m -u 1000`; H-26 checks it by `docker inspect`] |
| Registry and scripts out of reach | The registry (`~/.config/sbx/sandboxes`) and the repo folder cannot sit inside a sandbox folder, so an agent cannot change which folder a start mounts or the scripts the Mac runs | [VERIFIED: bin/sbx-add `refuse_registry_overlap`, `refuse_repo_overlap`] |
| Not isolated: network | The container has normal outbound network; no egress allowlist (SEC-01 is deferred) | [VERIFIED: compose.yml sets no network restriction; REQUIREMENTS.md SEC-01 v2] |
| Credentials in reach | Under `--dangerously-skip-permissions` the agent can read `state/claude/.credentials.json` (Claude login), `state/gh/hosts.yml` (gh token in plain text, no keyring) and `state/git/config`, and can send them out over the network | [VERIFIED: SANDBOX.md "gh token as plain text in state/gh/hosts.yml"; ~/.claude/.credentials.json exists, mode 600 in this old sandbox; h07-login.sh asserts `.credentials.json` in `state/claude`]. Mitigations to state: use a fine-grained gh token (already recommended for the bundle repo), keep `state/` out of IDEs |
| Planted files the Mac later runs | Anything the agent writes in `$SBX_DIR/<name>` that a Mac tool executes: `.git/hooks/*` and git config keys `core.fsmonitor`, `core.pager`, `diff.external`, `credential.helper`, `core.sshCommand`; IDE run configurations and tasks (`.idea/`, `.vscode/tasks.json`, `launch.json`), build files and scripts the user then runs (`Makefile`, `package.json` scripts, `.mvn/`), `.envrc` | git list [VERIFIED: pending todo 2026-10-24 text]; IDE and build-file examples [ASSUMED: common knowledge, not verified in this session] |
| Rule | Run git inside the sandbox (`sbx-shell`), review the diff on GitHub, open the project in the IDE with git integration and run configs treated as untrusted; never run git on `best-practices/` from the Mac | [VERIFIED: SANDBOX.md "Never run git on the clone from the Mac"; D-17] |
| Bundle trade | Claude can change rules every later session loads; review changes by PR | [VERIFIED: SANDBOX.md "The trade"] |
| Edit deny is not a boundary | Managed settings deny the Edit tool on skill paths, but a script can still write | [VERIFIED: SANDBOX.md "It is not a security boundary"] |

Keep it a short table plus a four-line rule list.

## Common Pitfalls

### Pitfall 1: Raw `$CODE` as the history folder name
**What goes wrong:** `/resume` shows nothing; ccusage `session` still counts the usage but under the old folder.
**Why:** Claude encodes the cwd with `[^a-zA-Z0-9]` to `-`; `GSD_StaticSiteGenerator` becomes `GSD-StaticSiteGenerator`. D-08's table writes `-home-sandbox-$CODE` literally.
**How to avoid:** derive `ENC` with sed and `mv` from `-home-sandbox-$ENC`; check the folder exists first (`ls "$NEW/state/claude/projects"`).
**Warning signs:** `mv: ... No such file or directory`; `/resume` empty in the new sandbox.

### Pitfall 2: Illegal NAME
**What goes wrong:** `sbx-add` refuses `MyCode` (uppercase) or `my_code`.
**How to avoid:** NAME is lowercase letters, digits, hyphens, starting with a letter, 31 chars max; the code folder is renamed to NAME on the Mac. For `MyCode` pick `mycode`. The example in the recipe must show the code folder being renamed (`MyCode` to `mycode`). Mac tools (IDE projects) pointing at the old code path need re-opening.

### Pitfall 3: Dead git credential helper
**What goes wrong:** HTTPS `git push/pull` in the new sandbox prompts for a password or fails with "gh: not found".
**Why:** copied `.gitconfig` names `/usr/bin/gh`; new image has gh at `/usr/local/bin/gh` only.
**How to avoid:** rewrite while copying (`sed 's|!/usr/bin/gh |!/usr/local/bin/gh |'`), tested. Fallback: `gh auth setup-git` once in the sandbox [ASSUMED it appends a second helper line and is harmless]. Do not tell users to re-run `sbx-gh-login` (the todo notes it forces a full re-login).

### Pitfall 4: Double-loaded rules after the bundle clone
**What goes wrong:** the copied `state/claude/CLAUDE.md` imports `@AGENTS.md` and `@code-conventions.md`; the copied old copies still sit in `state/claude`, and the clone's `rules/` link now loads the same text again.
**How to avoid:** after `sbx-bundle-clone`, remove those two import lines from `state/claude/CLAUDE.md` (the existing troubleshooting row). Put this as a step after the three checks, not before; rules still load from the old copies until the clone exists.

### Pitfall 5: Copying while Claude or the old container is running
**What goes wrong:** half-written `.claude.json`, a stale `.claude.json.lock` or `sessions/` files copied; later "Claude hangs at start" (known row in the troubleshooting table).
**How to avoid:** `/exit` Claude, `docker stop` the old container first (D-09), copy, then delete `state/claude/.claude.json.lock` in the copy if present.

### Pitfall 6: Rollback token rotation
**What goes wrong:** after the new sandbox refreshes the login, the old sandbox's copy of the credentials may no longer refresh; the "old sandbox still works" claim (D-06, D-10) can need a `/login` there.
**Status:** [ASSUMED] (refresh-token rotation behaviour not verified). Word the README as "the old sandbox keeps your code and history; if it asks you to log in again, do so". Do not promise an unattended rollback.

### Pitfall 7: Guard fails in PR A
`old_layout_untouched` includes `README.md` (see "Guard trap"). Drop it from the pathspec in PR A.

### Pitfall 8: GSD settings merge on a copied config
**What goes wrong (possible):** the copied `settings.json` already holds GSD hook entries written by the old install (paths `/home/sandbox/.claude/hooks/...`, valid through the `~/.claude` link). The start-time sync (`gsd-core --claude --global --config-dir <state/claude>`) may add a second set under the new path, so hooks run twice.
**Status:** [ASSUMED]; the repo's H-16 proves GSD refresh and "settings keys kept" but not a pre-existing old-layout hook set. Verify during D-18 on the smallest sandbox: after the first start, count GSD entries in `state/claude/settings.json` (or run `/hooks` in Claude). If duplicated, document "delete the `hooks` block that mentions gsd from `state/claude/settings.json` before the first start" in MIGRATION.md. This is why the open question below must be answered on the Mac.

### Pitfall 9: Sessions started at the home folder
Old docs said to run `claude` at the project root, but a session started in `/home/sandbox` itself is stored as `-home-sandbox` and will not show in `/resume` from the new project folder. Usage still counts in ccusage (the file is copied). One sentence in MIGRATION.md.

### Pitfall 10: Dev-sandbox self-overlap
`sbx-add` refuses a `NEW` that holds the repo the Mac runs `bin/` from (D-12). The Mac's `bin/` must come from the separate tools clone before `sbx-add` on the dev sandbox. Also `NEW` must not live inside `OLD` (the copy would recurse).

## Code Examples

### The recipe (dry-run tested on a fake old home with a space in both paths, GNU tools; uses only POSIX options BSD supports)

```bash
# --- set once ---------------------------------------------------------------
OLD="/Users/you/GSD_StaticSiteGenerator"   # old host folder (the whole old home)
NEW="/Users/you/sbx/mycode"                # new sandbox folder; not inside OLD
NAME=mycode                                # new sandbox name: lowercase, digits, hyphens
CODE=MyCode                                # code folder name inside OLD
ENC=$(printf '%s' "$CODE" | LC_ALL=C sed 's/[^a-zA-Z0-9]/-/g')   # how Claude names its history folder

# --- stop the old sandbox (keeps the container as the rollback) ------------
docker ps --format '{{.Names}}' | grep '^cc_gsd_'    # find the old container name
docker stop cc_gsd_PROJECT                            # replace PROJECT; close Claude first

# --- copy (the old folder is only read) ------------------------------------
mkdir -p "$NEW/$NAME" "$NEW/state/claude" "$NEW/state/shell" "$NEW/state/gh" "$NEW/state/git"
cp -Rp "$OLD/$CODE/." "$NEW/$NAME/"
cp -Rp "$OLD/.claude/." "$NEW/state/claude/"
cp -p  "$OLD/.claude.json" "$NEW/state/claude/.claude.json"
cp -p  "$OLD/.bash_history" "$NEW/state/shell/bash_history"
cp -Rp "$OLD/.config/gh/." "$NEW/state/gh/"
sed 's|!/usr/bin/gh |!/usr/local/bin/gh |' "$OLD/.gitconfig" > "$NEW/state/git/config"
rm -f "$NEW/state/claude/.claude.json.lock"

# --- rename the history folder: old cwd -> new cwd -------------------------
mv "$NEW/state/claude/projects/-home-sandbox-$ENC" "$NEW/state/claude/projects/-home-sandbox-workspace-$NAME"

# --- optional: keep trust, MCP servers and up-arrow history ----------------
sed "s|\"/home/sandbox/$CODE\"|\"/home/sandbox/workspace/$NAME\"|g" "$NEW/state/claude/.claude.json" > "$NEW/state/claude/.claude.json.new" && mv "$NEW/state/claude/.claude.json.new" "$NEW/state/claude/.claude.json"
sed "s|\"project\":\"/home/sandbox/$CODE\"|\"project\":\"/home/sandbox/workspace/$NAME\"|g" "$NEW/state/claude/history.jsonl" > "$NEW/state/claude/history.jsonl.new" && mv "$NEW/state/claude/history.jsonl.new" "$NEW/state/claude/history.jsonl"

# --- register and enter ----------------------------------------------------
sbx-add "$NAME" "$NEW"
sbx-shell "$NAME"
```

Dry-run result (fake tree, `CODE='My_Code.v2'`): `ENC=My-Code-v2`; `.claude.json` keys `projects["/home/sandbox/workspace/mycode"]` and `githubRepoPaths` rewritten while `"/home/sandbox/My_Code.v2x"` was left alone; `history.jsonl` rewrote only the matching project; `.credentials.json` kept mode 600; the git helper line became `!/usr/local/bin/gh auth git-credential`. Not run on BSD/macOS: the planner must keep the Mac run (D-18) as the proof. Caveats to note in the doc: the optional `sed` lines assume `CODE` has no `|`, `*`, `[` or `&`; a code folder that is itself in a sub-folder is out of scope; each extra project folder in the old home needs its own sandbox.

Guard the missing-source case in prose, not code: "skip a line whose source does not exist (a fresh sandbox may have no `.config/gh`)".

Checks after `sbx-shell` (D-10):

```bash
sbx-claude        # no login prompt
# inside Claude: /resume   -> the old sessions are listed
ccusage daily     # pre-migration usage appears (add --offline if the price lookup is slow)
```

Undo: `sbx-rm NAME --unregister` (leaves `$NEW` and `$OLD` alone), then `docker start cc_gsd_PROJECT` and `docker exec -it cc_gsd_PROJECT /bin/bash` bring the old sandbox back without any script [VERIFIED: ClaudeCode/cc-bash.sh is exactly `docker exec -it cc_gsd_${PROJECT_NAME} /bin/bash`].

### Dev-sandbox extra section (D-12, D-13)

```bash
mkdir -p ~/sbx-tools && cd ~/sbx-tools
git clone https://github.com/piojosnos/GetShitDoneContainer.git      # plain clone; only runs bin/ and build.sh
echo 'export PATH="$HOME/sbx-tools/GetShitDoneContainer/bin:$PATH"' >> ~/.zshrc
```

The remote URL above is [ASSUMED]: the origin is not recorded in the files read; the planner should take it from `git remote -v` on the Mac. Then do the normal recipe with `CODE=GetShitDoneContainer` (the history folder encodes to itself, `-home-sandbox-GetShitDoneContainer`, because it has only letters), a legal `NAME` such as `gsd-container`, and `sbx-add` from the tools clone's `bin/`. The copy of the repo at `$NEW/$NAME` is the agent's working copy; it must never be the clone whose `bin/` is on `PATH`.

## State of the Art

| Old | Current | When | Impact |
|-----|---------|------|--------|
| Whole home bind mount at `/home/sandbox`, GSD installed by entrypoint on first run (`npx @latest`) | One mount at `/home/sandbox/workspace`, GSD and tools baked and pinned, synced at every start | Phases 1 and 2 | Login moves to `state/claude`; docs must stop describing `.initialized` and `npx` |
| `cc-up/cc-bash/cc-down` | `sbx-add/start/shell/stop/rm/list/upgrade` | Phases 3 and 4 | Old scripts are deleted in PR B |
| `docker-compose down -v` | `sbx-rm` runs plain `down`, never volumes | Phase 4 | Data-loss path removed |
| `~/.claude.json` in the home | `$CLAUDE_CONFIG_DIR/.claude.json` | Phase 1 | The core fact of the migration |

**Deprecated/outdated:** `get-shit-done-cc` (compromised; present only in `OpenCode/docker-entrypoint.sh`, deleted in PR B); `cc-upgrade.sh` (documented, never existed in the tree).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `cp -Rp SRC/. DST/` behaves identically on macOS BSD cp and GNU cp; trailing-slash `SRC/` differs | Standard Stack, Code Examples | Wrong files land; confirmed only by the Mac run in D-18 |
| A2 | macOS ships an old rsync, so `cp` is the better choice | Alternatives | Low; it is Claude's Discretion either way |
| A3 | Refresh-token rotation may log the old sandbox out after the new one refreshes | Pitfall 6 | The rollback promise in D-06/D-10 needs a re-login; wording hedge covers it |
| A4 | A GSD start-sync on a copied old-layout `settings.json` may leave duplicate hook entries | Pitfall 8 | Hooks run twice; needs a recipe line if observed |
| A5 | `gh auth setup-git` in the new image writes `/usr/local/bin/gh` and is harmless next to a stale line | Pitfall 3 | Only a fallback; main path is the `sed` |
| A6 | `ccusage daily/monthly` ignore the folder name; `session` may label by it | Facts table | A user sees a different session label; docs must not promise a label |
| A7 | IDE run configs and build files (`.idea/`, `.vscode/`, `Makefile`, `.mvn/`, `.envrc`) are valid planted-file examples | Threat model | Threat list slightly off; low risk, reviewer can trim |
| A8 | Rewriting `cwd` inside transcripts is unnecessary for `/resume` | Facts table | If resume filters on in-file `cwd`, old sessions would not list; the D-18 run tests this directly |
| A9 | The GitHub remote URL for the Mac tools clone | Dev-sandbox section | Wrong command in the doc; take it from `git remote -v` |
| A10 | The optional `.claude.json` and `history.jsonl` `sed` edits are safe on real, larger files (only tested on a small fake) | Code Examples | Corrupt JSON; mitigated by writing to a temp file and keeping `$OLD` untouched |

## Open Questions

1. **Does the first start sync duplicate GSD hooks in a copied `settings.json`? (Pitfall 8, A4)**
   - Known: the old `settings.json` has GSD hooks at `/home/sandbox/.claude/hooks/...`; the sync runs `gsd-core --claude --global --config-dir /home/sandbox/workspace/state/claude`.
   - Unclear: whether GSD's installer recognises the old entries as its own.
   - Recommendation: plan the D-18 smallest-sandbox run to include "count GSD hook entries in `state/claude/settings.json` after the first start" and, if doubled, add one recipe step. Do not pre-emptively delete settings.

2. **Who updates `.claude/CLAUDE.md`, and when?**
   - Known: it is tracked, generated, and describes the old layout and the Coexistence constraint throughout; after PR B it names files that do not exist. Project memory says `.claude/` changes never share a branch or PR with code or `.planning/`.
   - Unclear: whether the user wants it regenerated in this phase (SC2 only covers the README).
   - Recommendation: add a third small `.claude/`-only PR (`/gsd-docs-update` or regenerate sections) after PR B, or record it as a follow-up; flag to the user, do not fold into the code PRs.

3. **Rollback after PR B.** Once `cc-*` and the old compose are deleted, a user who wants to roll back relies on the untouched old container (`docker start`/`docker exec`). If that container was already removed with `cc-down`, rebuilding the old image needs the deleted files from git history. Recommendation: MIGRATION.md says "stop with `docker stop`, do not `cc-down`", and PR B's description names the last commit that holds `ClaudeCode/`.

4. **`NAME` for existing sandboxes.** The roadmap example keeps `MyCode`; the name rule forces lowercase. Recommendation: the example shows `CODE=MyCode`, `NAME=mycode`, so the rename is visible.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker | Everything runtime (migration check, `./host-test.sh`) | No (in the dev sandbox) | n/a | Mac-side manual verification, per project constraint |
| bash, sed, cp, git, node (GNU/Linux) | Authoring and dry-run here | Yes | system | none needed |
| macOS BSD tools + bash 3.2 | The user's real run | On the Mac only | n/a | The Mac run (D-18) is the proof; keep options POSIX |
| `gh`, `gsd-tools` | PR creation | Not needed for research | n/a | `gh pr create` by the executor on the user's go |

**Missing dependencies with no fallback:** none for planning. The migration itself can only be validated on the Mac with Docker.
**Missing dependencies with fallback:** Docker (Mac-side steps in the plan).

## Validation Architecture

> `workflow.nyquist_validation` is `true` in `.planning/config.json`.

D-01, D-18 and D-19 forbid new automated tests. Validation reuses what exists plus one-off, uncommitted checks.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Plain bash suites; no framework |
| Config file | none |
| Quick run command | `bash tests/guard/run-all.sh` |
| Full suite command | `./host-test.sh` on the Mac (host checks, guard, self-tests, pin digests) |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| SCR-08 | `ClaudeCode/`, `OpenCode/`, `cc-*` gone; guard and host run still pass | guard + host | `bash tests/guard/run-all.sh`; `git ls-files ClaudeCode OpenCode` prints nothing; `./host-test.sh` on the Mac | Yes |
| DOC-01 | Every file, script and command in README exists; no `cc-upgrade.sh` | one-off check (uncommitted) | see below | n/a |
| DOC-02 | Recipe works end to end | manual acceptance on the Mac (D-18) | user pastes MIGRATION.md on the smallest sandbox; three eyes-on checks | n/a |
| DOC-03 | Threat-model section present with the three required topics | manual doc review | `grep -n -i 'exfiltrat\|hook' README.md` shows the section | n/a |
| DOC-04 | Checklist runs end to end on the Mac | existing | `./host-test.sh`; helpers in `tests/host/manual/` | Yes |

One-off README accuracy check for the verifier (run, do not commit; proven on `SANDBOX.md` this session, where it printed only expected false positives such as bare file names, container names and `sbx-demo`):

```bash
grep -oE '`[^`]+`' README.md MIGRATION.md | sed 's/^[^:]*://' | tr -d '`' \
  | grep -E '^(\./)?[A-Za-z0-9_.-]+(/[A-Za-z0-9_.*-]+)*\.(sh|md|yml|env|json|js)$|^(bin|base|claude|tests|prompts)/[A-Za-z0-9_./*-]+$' | sort -u \
  | while read -r p; do q=${p#./}; q=${q%%#*}; case "$q" in *'*'*) ls $q >/dev/null 2>&1 || echo "MISSING-glob $p";; *) [ -e "$q" ] || echo "MISSING $p";; esac; done
grep -oE '\bsbx-[a-z-]+\b' README.md MIGRATION.md | sed 's/^[^:]*://' | sort -u \
  | while read -r s; do [ -e "bin/$s" ] || [ -e "claude/bin/$s" ] || echo "no script: $s"; done
grep -rn 'cc-up\|cc-bash\|cc-down\|cc-upgrade\|SANDBOX.md' --exclude-dir=.git --exclude-dir=.planning . | grep -v '^./MIGRATION.md'
```

Triage each line by hand: bare names that are paths relative to a folder named in the sentence, container names such as `sbx-demo`, and image tags are fine. The last command must print nothing in PR A for `SANDBOX.md`, and nothing for `cc-*` after PR B outside MIGRATION.md (and `.claude/CLAUDE.md` until its own PR).

### Sampling Rate
- **Per task commit:** `bash tests/guard/run-all.sh` (and `bash tests/selftest/guard/run-all.sh` after editing guard files)
- **Per wave merge:** the one-off README check above, plus `bash tests/selftest/sbx/run-all.sh`
- **Phase gate:** `./host-test.sh` green on the Mac for PR A and again for PR B; then the user's migration of the smallest sandbox (D-18) before PR B is merged

### Wave 0 Gaps
None. No new test files, and no new framework. Everything above exists.

## Security Domain

`security_enforcement` is enabled (absent or true). ASVS level 1. This phase changes docs and deletes files; the security-relevant content is what the docs tell the user and what the recipe copies.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No (no auth code changes) | Credentials are only copied; they keep mode 600 via `cp -p` |
| V3 Session Management | No | n/a |
| V4 Access Control | Yes (documentation) | One mount, no socket, dropped caps; documented in the threat model; no change to `compose.yml` logic |
| V5 Input Validation | Yes (recipe) | Quote every expansion; `NAME` is validated by `sbx-add` against the name rule; `sed` patterns use `|` delimiter and quoted variables |
| V6 Cryptography | No | n/a |
| V14 Configuration | Yes | Do not weaken guard rules: remove only `old_layout_untouched`; keep `no_compromised_gsd_package` and its file list pointing at `README.md` and `MIGRATION.md` |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Credentials copied to a world-readable location | Information disclosure | `cp -p` keeps 600; `$NEW/state` sits beside, not inside, the project folder; README warns not to open `state/` in an IDE |
| Token exfiltration under skip-permissions | Information disclosure | Documented limit (open network); fine-grained gh token; no egress allowlist yet |
| Planted git hooks, git config, IDE run configs | Elevation of privilege on the Mac | Documented rule: git inside the sandbox; treat Mac-side git/IDE on that folder as running agent code |
| Path/shell injection through folder names in the recipe | Tampering | Quote every variable; spaces tested; `NAME` rule-limited |
| Reintroducing the compromised GSD package | Tampering | Keep the guard rule and add `MIGRATION.md` to its file list in PR A; do not copy text that names the old package into docs except as the guard's own forbidden pattern |
| Doc claims stronger isolation than exists | Repudiation/misleading | Threat model states what is not isolated (network, `state/` secrets, planted files) |

Add `MIGRATION.md` to the `no_compromised_gsd_package` file list in `tests/guard/supply-chain.sh` (it currently lists `SANDBOX.md tests/host-checklist.md`; this becomes `README.md MIGRATION.md tests/host-checklist.md`). That is an edit of an existing list, not new shell. The old OpenCode entrypoint contained the forbidden package; PR B removes it.

## Sources

### Primary (HIGH confidence)
- Pinned Claude Code binary 2.1.285 at `/usr/local/bin/claude` in this sandbox: path-encoding functions `k`, `LA`, `Bre=200`; global config path logic with `CLAUDE_CONFIG_DIR`; `.credentials.json` under the config dir
- Repo files read this session: `compose.yml`, `versions.env`, `build.sh`, `SANDBOX.md`, `README.md`, `ClaudeCode/*`, `OpenCode/*`, `base/Dockerfile`, `claude/Dockerfile`, `base/sbx-start-lib.sh`, `claude/start.d/05-gsd`, `claude/start.d/10-best-practices`, `claude/bin/sbx-claude`, `claude/bin/sbx-gh-login`, `bin/sbx-add`, `bin/sbx-shell`, `bin/sbx-lib.sh`, `tests/guard/*.sh`, `tests/host/coexistence.sh`, `tests/host/run-all.sh`, `tests/host/lib-docker.sh`, `tests/host/h05`, `h09`, `h24`, `h25`, `h30`, `tests/host-checklist.md`, `tests/README.md`, `host-test.sh`, `.planning/{REQUIREMENTS,STATE,PROJECT,ROADMAP}.md`, the folded todo
- Live data of this old-layout sandbox: `~/.claude/projects`, `~/.claude.json` (keys), `~/.claude/history.jsonl`, `~/.gitconfig`, `~/.claude/CLAUDE.md`
- Dry-run of the recipe on a fake old home (GNU tools, paths with spaces)

### Secondary (MEDIUM confidence)
- https://code.claude.com/docs/en/claude-directory: `.claude.json` follows `CLAUDE_CONFIG_DIR`; project-folder encoding; `projects/<project>/memory/`; `history.jsonl` holds project path; `claude purge` plan lists the `projects[...]` entry as "trust, history, MCP servers"
- https://ccusage.com/guide/claude/: `CLAUDE_CONFIG_DIR`, default directories, comma-separated list

### Tertiary (LOW confidence)
- Training knowledge: BSD vs GNU `cp`/`sed` differences, macOS rsync age, OAuth refresh rotation, IDE planted-file examples (all tagged [ASSUMED])

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH, nothing new is added; every tool already exists
- Architecture (what moves where): HIGH, checked in the binary, docs and repo
- Pitfalls: MEDIUM, the BSD behaviour, GSD settings merge and token rotation are unverified until the Mac run

**Research date:** 2026-11-08
**Valid until:** 2026-12-08 for the repo facts; re-check the path-encoding rule if `CLAUDE_CODE_VERSION` is bumped before the user migrates (the rule is stable but the pin is what the sandbox runs).
