# sbx sandbox (new layout)

One Docker container per project. It sees exactly one folder on your Mac, `$SBX_DIR`:

| On the Mac | Holds |
|---|---|
| `$SBX_DIR/<name>/` | your code |
| `$SBX_DIR/state/` | Claude login, settings and sessions; bash history; gh login; git identity |

- Nothing is mounted over the container's home directory, so everything the image provides stays visible.
- It runs side by side with the old `ClaudeCode/` layout, which keeps working and stays documented in `README.md`.

## Requirements

- Docker Desktop on the Mac.
- Compose v2. Run `docker compose version` and note the version for the host checklist.
- `SBX_NAME` follows the sandbox name rule: starts with a lowercase letter, then lowercase letters, digits or hyphens, 31 characters at most (`^[a-z][a-z0-9-]{0,30}$`). `my-project` works; `MyProject`, `my_project` and `my.project` are refused. Such a name is valid as a folder, a container name, a hostname and a Compose project.

## Build the images

From the repo root. Build the base first: the Claude image starts `FROM` it.

```bash
docker build -f base/Dockerfile -t sbx-base:local .
docker build -f claude/Dockerfile -t sbx-claude:local .
```

Both build from the repo root (the final `.`). A `.dockerignore` lets only `base/`, `claude/` and `best-practices/` into the build.

## Create a sandbox folder

Once per terminal, export both variables. Every compose subcommand (up, down, ps, config) needs both.

```bash
export SBX_NAME=demo SBX_DIR=/Users/you/sbx-demo
```

Once per sandbox, create the project and state folders. The container creates the subfolders of `state/` itself.

```bash
mkdir -p "$SBX_DIR/$SBX_NAME" "$SBX_DIR/state"
```

What lives where:

| On the Mac | In the container | Env var |
|---|---|---|
| `$SBX_DIR` (the one mount) | `/home/sandbox/workspace` | |
| `$SBX_DIR/$SBX_NAME` (your code) | `/home/sandbox/workspace/$SBX_NAME` (the command runs here; shells use `-w`) | |
| `$SBX_DIR/state/claude` | `/home/sandbox/workspace/state/claude` (also `~/.claude`) | `CLAUDE_CONFIG_DIR` |
| `$SBX_DIR/state/shell` (holds `bash_history`) | `/home/sandbox/workspace/state/shell` | `HISTFILE` |
| `$SBX_DIR/state/gh` (holds `hosts.yml`) | `/home/sandbox/workspace/state/gh` | `GH_CONFIG_DIR` |
| `$SBX_DIR/state/git` (holds `config`) | `/home/sandbox/workspace/state/git` | `GIT_CONFIG_GLOBAL` |

- Everything else in `/home/sandbox` (`.bashrc`, `.local`, ...) comes from the image.
- On the Mac, open `$SBX_DIR/$SBX_NAME` in your IDE, not `$SBX_DIR`: `state/` holds credentials.
- Bash history is written right after each command, not when the shell exits. It is on the Mac at once and survives `docker compose down` and a fresh `up`. Other shells that are already open see it only after they restart.

### gh and git identity

- `gh auth login` once in the sandbox; it persists.
  - There is no keyring in the container, so gh stores its token as plain text in `state/gh/hosts.yml`.
  - `state/` sits next to your project folder, not inside it, so the token never ends up in a git repo.
- `git config --global user.name "Your Name"` and `git config --global user.email you@example.com` persist in `state/git/config`.
  - The Mac's own `~/.gitconfig` is never read or touched.

## Start, enter, stop

Start, from the repo root. `--wait` reports a container that fails to start instead of returning early.

```bash
docker compose up -d --wait
```

Open a shell. Open as many as you like:

```bash
docker exec -it -w "/home/sandbox/workspace/$SBX_NAME" "sbx-$SBX_NAME" bash
```

`-w` starts the shell in your project folder; without it a shell starts in `/home/sandbox/workspace`. Start Claude there:

```bash
claude
```

- Log in once with a claude.ai account: Claude prints a URL, the browser shows a code, you paste it at the prompt.
- The login is written to `$SBX_DIR/state/claude` on the Mac.
- Sessions are keyed by directory: run `claude --continue` or `claude --resume` from the same directory as before.

Stop:

```bash
docker compose down
```

- Everything in `$SBX_DIR` stays.
- Never ask down to remove volumes. This layout uses none, and that request is how the old layout lost data.

## Rebuild without losing login

Stop, rebuild both images (add `--no-cache` for a clean build), start again:

```bash
docker compose down
docker build -f base/Dockerfile -t sbx-base:local .
docker build -f claude/Dockerfile -t sbx-claude:local .
docker compose up -d --wait
```

The login and history live in `state/` on the Mac, so the new container picks them up unchanged.

## Best-practices bundle

Every sandbox starts with the same standing rules and skills (`/pr-reply`, `/merged`), so you set nothing up per project.

| Where | What |
|---|---|
| `best-practices/` in this repo | The source: `rules/` and `skills/`, plain Markdown |
| `/opt/sbx/best-practices` in the image | A copy, outside the mount, read-only to the sandbox user |
| `$SBX_DIR/state/claude` (`~/.claude`) | The working copy Claude reads, refreshed at every start |

A start needs no network. What it does in `state/claude`:

| In `state/claude` | What a start does |
|---|---|
| `rules/` | Replaced by the image's rules. A hand edit or a stray file is lost. |
| Each bundle skill folder in `skills/` | Replaced by the image's copy. Its name is recorded in `.best-practices-skills`. |
| Other skills (GSD's, your own) | Never touched. |
| `projects/` (memories), `CLAUDE.md`, `settings.json`, the login | Never touched. |

How a rule loads:

| Rule file | Loads |
|---|---|
| No frontmatter | In every session |
| `paths:` frontmatter (globs in quotes) | When Claude touches a matching file |

Change a rule or a skill:

1. Edit `best-practices/` in this repo.
2. Open a PR and merge it.
3. Rebuild both images (see "Rebuild without losing login").
4. Restart the sandbox.

An edit to the copy in `state/claude` is lost at the next start.

Edit protection:

- Managed settings in the image make Claude refuse to edit the synced rules, the skill list and the bundle skills, even with permissions bypassed.
- It guards against accidental edits by Claude. It is not a security boundary: a script Claude runs can still write there until the next start.
- Your own skills and `state/claude/CLAUDE.md` stay editable.

Memories are not shipped. They belong to each project. A memory that proves general becomes a bundle rule by PR.

Moving an existing project into a sandbox: its old memories and `CLAUDE.md` may repeat bundle rules. Paste the prompt in [`prompts/consolidate-memories.md`](prompts/consolidate-memories.md) into Claude once; it sorts them and removes duplicates only after you approve.

## Safety checks

At start, the container refuses to run unless:

- `/home/sandbox/workspace` is a real, writable mount point of a folder on the Mac. Otherwise your work would land in the container's own layer and be lost on recreate.
- The project folder (`$SBX_DIR/$SBX_NAME`) and `$SBX_DIR/state` exist, and `state` is writable. A mistyped `SBX_DIR` has neither. A mistyped `SBX_NAME` has no project folder: the start is refused, and nothing is created on your Mac.
- `SBX_NAME` follows the sandbox name rule. Otherwise the start stops before any folder is used, with `[sbx] ERROR: SBX_NAME "<value>" breaks the sandbox name rule: ...` (the value in double quotes) and the example `my-project`.

A name that breaks the rule is refused in one of two places:

| Name | Refused by | When |
|---|---|---|
| An uppercase letter, `MyProject` | `docker compose up`: the image name of the `name-check` service must be lowercase | Before anything is created or replaced |
| Any other name outside the rule, `my_project`, `my.project` | The container start, with the `[sbx] ERROR` line above | Before the project folder is used |

Compose turns the project name into lowercase, and only `up` checks the name. Use the exact lowercase name with `down`, `ps` and `logs`.

After the checks, the start runs the image's start hooks (the bundle sync is one):

- A failing hook stops the start, so a sandbox never runs with a half-synced bundle.
- Any other entry in the hook folder stops the start too. A hook file that is not executable gives `[sbx] ERROR: start hook <path> is not executable`. Anything that is not a regular file (a link that points nowhere, a fifo, a socket) gives `[sbx] ERROR: start hook <path> is not a regular file`. A hook is never skipped silently; only folders and names that start with a dot are ignored.

### Image-only smoke tests

A plain `docker run` of either image, without the compose mount, is refused by design (an `[sbx] ERROR` line, exit status 1). To check an image on its own, bypass the entrypoint:

```bash
docker run --rm --entrypoint claude sbx-claude:local --version
```

### Before every start: check the sandbox folder

- Compose is told not to create a missing folder, but some Compose versions ignore that (docker/compose issue 13602).
- A mistyped `SBX_DIR` could then get an empty folder on your Mac. The container still refuses to start, but the bogus folder is left behind.
- `SBX_DIR` must be an absolute path: Compose reads a relative one from the repo folder and does not expand `~`.

Paste this right before `docker compose up -d --wait`. If it prints anything, fix `SBX_DIR` or run the `mkdir` above, and do not start:

```bash
case "$SBX_DIR" in /*) ;; *) echo "NOT ABSOLUTE: $SBX_DIR" ;; esac
for d in "$SBX_NAME" state; do [ -d "$SBX_DIR/$d" ] || echo "MISSING: $SBX_DIR/$d"; done
```

If `up` fails, `docker compose logs` shows the `[sbx] ERROR` line that says what is missing.

## Verify a new build

After building, or after changing anything under `base/`, `claude/`, `best-practices/` or `compose.yml`, run `bash tests/host/run-all.sh` on the Mac. When it passes, the automated checks hold. Claude's login and Claude's own behaviour are checked only by the helpers in `tests/host/manual/`: H-07 (login), the second half of H-09 (login and session survive a rebuild), the `claude doctor` part of H-13, and H-19 (the bundle as Claude uses it). Run them after a Claude Code pin change, a change to the managed settings, or a change to login handling. [`tests/host-checklist.md`](tests/host-checklist.md) explains the result and the helpers.

It uses its own test sandbox, `sbx-hosttest`, and does not touch your sandboxes.

## Troubleshooting and known limits

| Symptom | Fix |
|---|---|
| Claude hangs at start after an unclean stop | Check no claude is running (`docker exec sbx-demo pgrep -a claude` prints nothing), then delete `$SBX_DIR/state/claude/.claude.json.lock`. Everything else in `state/claude` is safe on the Mac. |
| Console keyless sign-in is lost on recreate | It is stored outside `CLAUDE_CONFIG_DIR`. Log in with a claude.ai account instead. |
| A check fails only because of the capability drop | Remove the `cap_drop` block from `compose.yml`, keep `no-new-privileges`, and report it. |
| "Mounts denied" or "path is not shared" | Add the parent of `SBX_DIR` in Docker Desktop, Settings, Resources, File sharing. |
| `required variable SBX_DIR is missing a value` | Export both `SBX_NAME` and `SBX_DIR` in this terminal. |
| `up` fails with `... must be lowercase` and names `sbx-<name>-name-check` | `SBX_NAME` has an uppercase letter. Use the lowercase name; see the name rule in Requirements. |
| `[sbx] ERROR: SBX_NAME "..." breaks the sandbox name rule` | Pick a name that follows the rule and rename the project folder to match. A sandbox named with `_` or `.` before this rule needs the same rename. |
| `[sbx] ERROR: ... (the project folder) is missing` | Create it: `mkdir -p "$SBX_DIR/$SBX_NAME"`. Or `SBX_DIR` / `SBX_NAME` is mistyped. |
| `claude --resume` shows nothing | Sessions are keyed by directory; start it from the same directory as before. |
| A plain `docker run` is refused | Intended. Bypass the entrypoint, as in "Image-only smoke tests". |
| The container stops right after `up` | Run `docker logs sbx-<name>`. The `[sbx] ERROR: start hook ... failed` line and the hook's own error above it say what broke. If the line says `is not executable`, the image lost the hook's execute bit; rebuild the image. If it says `is not a regular file`, a hook link in the image points nowhere (or something that is not a file sits in the hook folder); rebuild the image. |
| Claude refuses to edit a file under `~/.claude/rules` or a bundle skill | Intended. Edit `best-practices/` in this repo (see "Best-practices bundle"). |
| A sandbox migrated from the old layout loads the same rules twice | Remove the `@AGENTS.md` and `@code-conventions.md` imports from `state/claude/CLAUDE.md`. |
| Host check H-10 showed Docker creating the missing folder | Report it. An `env_file` sentinel at the root of `SBX_DIR` would make Compose itself refuse a missing folder; it is not planned while H-10 passes, and the container refuses to start either way. |
