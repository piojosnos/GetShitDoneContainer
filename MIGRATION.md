# Move a sandbox from the old layout

- It moves one old sandbox (the whole old folder mounted at `/home/sandbox`, started with `cc-up.sh`) into a new sandbox folder.
- The old folder is only read and the old container is only stopped, so the old sandbox stays your way back until you delete it. Wait about a week.
- Move one sandbox at a time. Move this repo's own sandbox last (see the end of this page).
- Daily use of the new sandbox is in [`README.md`](README.md).

## What moves where

`$OLD` is the old sandbox folder and `$NEW` is the new one. The values are set in step 1.

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
- The new name follows the sandbox name rule: lowercase letters, digits and hyphens, starting with a letter, 31 characters at most. So `MyCode` becomes `mycode`.
- On the Mac, reopen the project in your IDE at `$NEW/$NAME`, not at `$NEW`: `state/` holds credentials.

## Once: the tools clone

```bash
git clone https://github.com/piojosnos/GetShitDoneContainer.git "$HOME/sbx-tools/GetShitDoneContainer"
echo 'export PATH="$HOME/sbx-tools/GetShitDoneContainer/bin:$PATH"' >> ~/.zshrc
```

- Open a new terminal afterwards.
- Remove an older `~/.zshrc` line that puts another copy's `bin/` on the PATH.
- This clone only runs the `sbx-*` scripts and `build.sh`. Update it with `git -C "$HOME/sbx-tools/GetShitDoneContainer" pull` after a PR merges.
- Why outside every sandbox folder: `sbx-add` refuses a sandbox folder that holds the repo whose `bin/` runs it, so the scripts the Mac runs must live elsewhere.

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
| `OLD` | The folder you gave to `cc-up.sh`. |
| `NEW` | A new folder that does not exist yet, not inside `OLD` and not inside another sandbox's folder. |
| `NAME` | The new sandbox name, by the name rule above. |
| `CODE` | The name of the code folder inside `OLD`. |
| `PROJECT` | The project name you gave to `cc-up.sh`. The container is `cc_gsd_$PROJECT`; `docker ps -a --format '{{.Names}}'` lists them. |
| `ENC` | How Claude Code names the history folder of `/home/sandbox/$CODE`: every character other than a letter or digit becomes `-`. Derived, not typed. |

- Replace the first five values with yours. Leave the last two lines as they are.
- The last line checks `NAME`. If it prints `NAME breaks the name rule`, fix `NAME` and paste the block again before step 2: `sbx-add` in step 6 refuses the name, and by then it is in the copied folders. `state` and `best-practices` are taken too.
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

### 4. Rename the history folder

```bash
mv "$NEW/state/claude/projects/-home-sandbox-$ENC" "$NEW/state/claude/projects/-home-sandbox-workspace-$NAME"
```

- Claude Code names a session folder after the working folder. `/home/sandbox/MyCode` is `-home-sandbox-MyCode`, and `/home/sandbox/workspace/mycode` is `-home-sandbox-workspace-mycode`.
- The folder holds the sessions for `/resume`, the auto memory and what `ccusage` counts.
- Check it first with `ls "$NEW/state/claude/projects"`. If no session ever ran in the code folder, there is nothing to rename; skip this step.
- Sessions started in `/home/sandbox` itself sit in `-home-sandbox`. `ccusage` still counts them; `/resume` from the project folder does not list them.

### 5. Optional: keep trust, MCP servers and up-arrow history

```bash
sed "s|\"/home/sandbox/$CODE\"|\"/home/sandbox/workspace/$NAME\"|g" "$NEW/state/claude/.claude.json" > "$NEW/state/claude/.claude.json.new" && mv "$NEW/state/claude/.claude.json.new" "$NEW/state/claude/.claude.json"
sed "s|\"project\":\"/home/sandbox/$CODE\"|\"project\":\"/home/sandbox/workspace/$NAME\"|g" "$NEW/state/claude/history.jsonl" > "$NEW/state/claude/history.jsonl.new" && mv "$NEW/state/claude/history.jsonl.new" "$NEW/state/claude/history.jsonl"
```

- Without these two lines Claude asks once to trust the folder, and its per-project allowed tools, MCP servers and up-arrow history start empty.
- They assume `CODE` holds none of `|`, `*`, `[` and `&`.
- `OLD` keeps the originals.

### 6. Register and enter

```bash
sbx-add "$NAME" "$NEW"
sbx-shell "$NAME"
```

- `sbx-add` accepts the filled folder and creates only what is missing.
- If `sbx-shell` says `sbx-claude:local` is not built, run `sbx-upgrade "$NAME"` once.
- The first start syncs GSD into `state/claude` and relinks the bundle clone, or tells you to run `sbx-bundle-clone`.
- The shell opens in `/home/sandbox/workspace/$NAME`, the folder the renamed history belongs to.

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

## After the checks

- For the best-practices bundle, run `sbx-bundle-clone` in the sandbox (the gh login came along). Then remove the `@AGENTS.md` and `@code-conventions.md` lines from `state/claude/CLAUDE.md`, or the same rules load twice.
- Old memories and `CLAUDE.md` may repeat bundle rules. Paste [`prompts/consolidate-memories.md`](prompts/consolidate-memories.md) into Claude once.
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
- Run every command from a Mac terminal with the tools clone on the PATH, never with a `bin/` from inside a sandbox folder.
- Stopping its container ends the Claude session inside it. Commit or note your work first.
- Afterwards the copy at `$NEW/$NAME` is the agent's working copy, and the tools clone stays the only copy whose `bin/` the Mac runs.
