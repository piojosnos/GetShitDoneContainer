# Move a sandbox from the old layout

- It moves one old sandbox (the whole old directory mounted at `/home/sandbox`, started with `cc-up.sh`) into a new sandbox directory.
- The old directory is only read and the old container is only stopped, so the old sandbox stays your way back until you delete it. Wait about a week.
- Move one sandbox at a time. Move this repo's own sandbox last (see the end of this page).
- Daily use of the new sandbox is in [`README.md`](README.md).

## What moves where

`$OLD` is the old sandbox directory and `$NEW` is the new one. The values are set in step 1.

| Old (`$OLD`) | New (`$NEW`) |
|---|---|
| `$CODE/` | `$NAME/` |
| `.claude/` | `state/claude/` |
| `.claude.json` | `state/claude/.claude.json` |
| `.bash_history` | `state/shell/bash_history` |
| `.config/gh/` | `state/gh/` |
| `.gitconfig` | `state/git/config` (the gh helper path is rewritten) |
| `state/claude/projects/-home-sandbox-$ENC` | renamed to `-home-sandbox-workspace-$NAME` |

- Not carried: `.npm`, `.cache`, `.local` and `.initialized`. The tools fetch them again.
- Not carried either: anything else next to `$CODE` in `OLD`, such as documents, a `package.json` or an `.idea` directory. Check with `ls -la "$OLD"` and copy what you need into `$NEW/$NAME/` by hand.
- The new name follows the sandbox name rule: lowercase letters, digits and hyphens, starting with a letter, 31 characters at most. So `MyCode` becomes `mycode`.
- On the host, reopen the project in your IDE at `$NEW/$NAME`, not at `$NEW`: `state/` holds credentials.

## Once: the tools clone

```bash
git clone https://github.com/piojosnos/GetShitDoneContainer.git "$HOME/sbx-tools/GetShitDoneContainer"
echo 'export PATH="$HOME/sbx-tools/GetShitDoneContainer/bin:$PATH"' >> ~/.zshrc
```

- Open a new terminal afterwards.
- Remove an older `~/.zshrc` line that puts another copy's `bin/` on the PATH.
- This clone only runs the `sbx-*` commands and `build.sh`. Update it with `git -C "$HOME/sbx-tools/GetShitDoneContainer" pull` after a PR merges.
- Why outside every sandbox directory: `sbx-add` refuses a sandbox directory that holds the tools clone whose `bin/` runs it, so the scripts the host runs must live elsewhere.

## Move one sandbox

### 1. Set once

```bash
OLD="/Users/you/GSD_StaticSiteGenerator"
NEW="/Users/you/sbx-mycode"
NAME=mycode
CODE=MyCode
PROJECT=ssg
ENC=$(printf '%s' "$CODE" | LC_ALL=C sed 's/[^a-zA-Z0-9]/-/g')
printf '%s\n' "$NAME" | LC_ALL=C grep -Eqx '[a-z][a-z0-9-]{0,30}' && echo "NAME ok" || echo "NAME breaks the name rule"
```

| Value | Meaning |
|---|---|
| `OLD` | The directory you gave to `cc-up.sh`. |
| `NEW` | A new directory that does not exist yet, not inside `OLD` and not inside another sandbox's directory. |
| `NAME` | The new sandbox name, by the name rule above. |
| `CODE` | The name of the code directory inside `OLD`. |
| `PROJECT` | The project name you gave to `cc-up.sh`. The container is `cc_gsd_$PROJECT`; `docker ps -a --format '{{.Names}}'` lists them. |
| `ENC` | How Claude Code names the history directory of `/home/sandbox/$CODE`: every character other than a letter or digit becomes `-`. Derived, not typed. |

- Replace the first five values with yours. Leave the last two lines as they are.
- The last line checks `NAME`. If it prints `NAME breaks the name rule`, fix `NAME` and paste the block again before step 2: `sbx-add` in step 6 refuses the name, and by then it is in the copied directories. `state` and `best-practices` are taken too.
- Every command below pastes unchanged in the same terminal.
- To redo a move, delete `NEW` and start again at "3. Copy". `OLD` still has everything.
- An interrupted move is redone the same way.

### 2. Stop the old sandbox

```bash
docker stop "cc_gsd_$PROJECT"
```

- Close Claude in the old sandbox first. Nothing may write to `OLD` while it is copied.
- `docker stop` keeps the container, so it can start again for the way back. `cc-down.sh` would delete it.
- "No such container" means it was removed before. Carry on.

### 3. Copy

```bash
mkdir -p "$NEW/$NAME" "$NEW/state/claude" "$NEW/state/shell" "$NEW/state/gh" "$NEW/state/git"
cp -Rp "$OLD/$CODE/." "$NEW/$NAME/"
cp -Rp "$OLD/.claude/." "$NEW/state/claude/"
cp -p "$OLD/.claude.json" "$NEW/state/claude/.claude.json"
cp -p "$OLD/.bash_history" "$NEW/state/shell/bash_history"
cp -Rp "$OLD/.config/gh/." "$NEW/state/gh/"
sed 's|!/usr/bin/gh |!/usr/local/bin/gh |' "$OLD/.gitconfig" > "$NEW/state/git/config"
rm -f "$NEW/state/claude/.claude.json.lock"
```

- The `SRC/.` form copies dotfiles too and behaves the same on macOS and Linux.
- `-p` keeps file modes, so the login files stay readable only by you.
- The `sed` line points git's credential helper at the gh the new image has. It writes a new file; `OLD` is not edited.
- Skip a line whose source does not exist. A sandbox that never logged in to gh has no `.config/gh`, and one that never ran a shell has no `.bash_history`.
- No file is edited in place anywhere in this recipe: BSD and GNU `sed` disagree on in-place editing, so each change writes a new file.

### 4. Rename the history directory

```bash
mv "$NEW/state/claude/projects/-home-sandbox-$ENC" "$NEW/state/claude/projects/-home-sandbox-workspace-$NAME"
```

- Claude Code names a session directory after the working directory. `/home/sandbox/MyCode` is `-home-sandbox-MyCode`, and `/home/sandbox/workspace/mycode` is `-home-sandbox-workspace-mycode`.
- The directory holds the sessions for `/resume`, the auto memory and what `ccusage` counts.
- Check it first with `ls "$NEW/state/claude/projects"`. If no session ever ran in the code directory, there is nothing to rename; skip this step.
- Sessions started in `/home/sandbox` itself sit in `-home-sandbox`. If `ls` shows only that directory and the old sandbox held only this project, rename that one instead, so `/resume` lists them.
- That rename is `mv "$NEW/state/claude/projects/-home-sandbox" "$NEW/state/claude/projects/-home-sandbox-workspace-$NAME"`.
- After that rename, skip step 5: its lines look for `/home/sandbox/$CODE`, and those sessions ran in `/home/sandbox`.

### 5. Optional: keep trust, MCP servers and up-arrow history

```bash
sed "s|\"/home/sandbox/$CODE\"|\"/home/sandbox/workspace/$NAME\"|g" "$NEW/state/claude/.claude.json" > "$NEW/state/claude/.claude.json.new" && mv "$NEW/state/claude/.claude.json.new" "$NEW/state/claude/.claude.json"
sed "s|\"project\":\"/home/sandbox/$CODE\"|\"project\":\"/home/sandbox/workspace/$NAME\"|g" "$NEW/state/claude/history.jsonl" > "$NEW/state/claude/history.jsonl.new" && mv "$NEW/state/claude/history.jsonl.new" "$NEW/state/claude/history.jsonl"
```

- Without these two lines Claude asks once to trust the directory, and its per-project allowed tools, MCP servers and up-arrow history start empty.
- They assume `CODE` holds none of `|`, `*`, `[` and `&`.
- `OLD` keeps the originals.

### 6. Register and enter

```bash
sbx-add "$NAME" "$NEW"
find "$NEW" -type f ! -perm -u+w -print0 > "${TMPDIR:-/tmp}/sbx-readonly.list"
[ ! -s "${TMPDIR:-/tmp}/sbx-readonly.list" ] || xargs -0 chmod u+w < "${TMPDIR:-/tmp}/sbx-readonly.list"
docker run --rm --network none -u root --entrypoint chown -v "$NEW:/move" sbx-claude:local -R 1000:1000 /move
[ ! -s "${TMPDIR:-/tmp}/sbx-readonly.list" ] || xargs -0 chmod u-w < "${TMPDIR:-/tmp}/sbx-readonly.list"
rm "${TMPDIR:-/tmp}/sbx-readonly.list"
sbx-fix-modes "$NAME"
sbx-shell "$NAME"
```

- `sbx-add` accepts the filled directory and creates only what is missing.
- The old container ran as uid 1001; the new one runs as `sandbox` (uid 1000). Docker Desktop keeps the container owner of each file, and `cp -p` copies it, so the copies still belong to 1001.
- Without the `chown` line, files the old container kept private (mode 600, such as `.git/config`) give `Permission denied` in the new sandbox.
- The `chown` runs in a throwaway container: the sandbox drops every capability, so even its root cannot change owners.
- macOS refuses the owner change on a read-only file, such as a git object. The `find` and `xargs` lines make those files writable for the `chown` only, then make them read-only again.
- On a macOS host, Docker Desktop keeps the owner and mode the sandbox sees in the attribute `user.containers.override_stat` of each host file, and the `chown` resets those modes.
- `sbx-fix-modes` then sets every file git tracks to 644 or 755, as git committed, on both sides.
- For a sandbox already moved without these lines, set `NEW` and run the six lines between `sbx-add` and `sbx-shell` once.
- If `sbx-shell` says `sbx-claude:local` is not built, run `sbx-upgrade "$NAME"` once.
- In the first shell, run `sbx-init`. It syncs GSD into `state/claude` and links the best-practices clone. With no clone it says so; run `sbx-gh-login`, then `sbx-best-practices-clone`, which runs `sbx-init` again.
- Copies of clone skills (or a real `rules` directory) from the old layout are never replaced. They make the first `sbx-init` FAIL until you move them; the FAIL line names the path.
- A `state/claude/.best-practices-skills` file from an older image is no longer read. It stays where it is and can be deleted by hand.
- The shell opens in `/home/sandbox/workspace/$NAME`, the directory the renamed history belongs to.

## Check

Inside the sandbox shell:

```bash
sbx-claude
```

1. Claude starts with no login prompt.
2. In Claude, `/resume` lists the sessions from before the move. Leave with `/exit`.
3. Back in the shell, `ccusage daily` shows days from before the move. Add `--offline` if the price lookup is slow.

```bash
ccusage daily
```

4. `sbx-selfcheck` prints PASS for every check. A FAIL line has a `fix:` line under it that says what to run.

```bash
sbx-selfcheck
```

## After the checks

- For the best-practices clone, run `sbx-best-practices-clone` in the sandbox (the gh login came along).
- If `state/claude/CLAUDE.md` exists and holds `@AGENTS.md` or `@code-conventions.md` lines, remove them, or the same rules load twice. The old sandbox loaded its rules that way; the clone now does it.
- Old memories and `CLAUDE.md` may repeat best-practices rules. Paste [`prompts/consolidate-memories.md`](prompts/consolidate-memories.md) into Claude once.
- After a week of use, set `PROJECT` again, run `docker rm "cc_gsd_$PROJECT"` and delete `OLD` by hand.

## If something is wrong

Unregister the new sandbox:

```bash
sbx-rm "$NAME" --unregister
```

Then start the old one again:

```bash
docker start "cc_gsd_$PROJECT"
docker exec -it "cc_gsd_$PROJECT" /bin/bash
```

- Answer `y` if `sbx-rm` asks. It changes nothing in `NEW` or `OLD`.
- The old sandbox still has its code and history.
- If Claude there asks to log in again, log in. The new sandbox may have refreshed the shared login.
- Delete `NEW` by hand when you no longer want it.

## This repo's own sandbox (last)

- Move it after the others.
- Values: `CODE=GetShitDoneContainer` (letters only, so `ENC` equals `CODE`), a `NAME` such as `gsd-container`, and `PROJECT` as the name you gave to `cc-up.sh`.
- Run every command from a host terminal with the tools clone on the PATH, never with a `bin/` from inside a sandbox directory.
- Stopping its container ends the Claude session inside it. Commit or note your work first.
- Afterwards the copy at `$NEW/$NAME` is the agent's working copy, and the tools clone stays the only copy whose `bin/` the host runs.

## Renamed commands and variables

A rebuild renames these, and the old names stop working (there is no alias). A running container keeps the old names until it is recreated, so run `sbx-upgrade NAME` for each sandbox.

| Old | New | Where you meet it |
|---|---|---|
| `sbx-bundle-clone` | `sbx-best-practices-clone` | the sandbox shell |
| `SBX_BUNDLE_DIR` | `SBX_BEST_PRACTICES_DIR` | the sandbox environment |
| `BUNDLE_REPO_URL` | `BEST_PRACTICES_REPO_URL` | `versions.env` |
| `state-folders` (a step and a check) | `state-dirs` | the `sbx-init` and `sbx-selfcheck` output |
| `project-folder` | `project-dir` | the `sbx-selfcheck` output |
| `env-bundle` | `env-best-practices` | the `sbx-selfcheck` output |
| `no-bundle-copy` | `no-best-practices-copy` | the `sbx-selfcheck` output |
| `claude-bundle-links` and `cursor-bundle-links` | `claude-best-practices-links` and `cursor-best-practices-links` | the `sbx-init` and `sbx-selfcheck` output |
| `wrappers-root-owned`, `claude-wrappers` and `cursor-wrappers` | `image-root-owned`, `claude-image-root-owned` and `cursor-image-root-owned` | the `sbx-selfcheck` output |
