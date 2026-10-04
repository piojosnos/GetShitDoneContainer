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
- `SBX_NAME`: lowercase letters, digits, `-` and `_`. `MyProject` is rejected; `myproject` works.

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
| `$SBX_DIR/$SBX_NAME` (your code) | `/home/sandbox/workspace/$SBX_NAME` (the shell starts here) | |
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
docker exec -it "sbx-$SBX_NAME" bash
```

The shell starts in your project folder. Start Claude there:

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

## Safety checks

At start, the container refuses to run unless:

- `/home/sandbox/workspace` is a real, writable mount of a folder on the Mac. Otherwise your work would land in the container's own layer and be lost on recreate.
- The project folder (`$SBX_DIR/$SBX_NAME`) and `$SBX_DIR/state` exist. A mistyped `SBX_DIR` has neither.

After the checks, the start runs the image's start hooks (the bundle sync is one):

- A failing hook stops the start, so a sandbox never runs with a half-synced bundle.

### Image-only smoke tests

A plain `docker run` of either image, without the compose mount, is refused by design (an `[sbx] ERROR` line, exit status 1). To check an image on its own, bypass the entrypoint:

```bash
docker run --rm --entrypoint claude sbx-claude:local --version
```

### Before every start: check the sandbox folder

- Compose is told not to create a missing folder, but some Compose versions ignore that (docker/compose issue 13602).
- A mistyped `SBX_DIR` could then get an empty folder on your Mac. The container still refuses to start, but the bogus folder is left behind.

Paste this right before `docker compose up -d --wait`. If it prints anything, fix `SBX_DIR` or run the `mkdir` above, and do not start:

```bash
for d in "$SBX_NAME" state; do [ -d "$SBX_DIR/$d" ] || echo "MISSING: $SBX_DIR/$d"; done
```

If `up` fails, `docker compose logs` shows the `[sbx] ERROR` line that says what is missing.

## Verify a new build

After building, or after changing anything under `base/`, `claude/`, `best-practices/` or `compose.yml`, run `bash tests/host/run-all.sh` on the Mac, then the short manual pass in [`tests/host-checklist.md`](tests/host-checklist.md).

It uses its own test sandbox, `sbx-hosttest`, and does not touch your sandboxes.

## Troubleshooting and known limits

| Symptom | Fix |
|---|---|
| Claude hangs at start after an unclean stop | Check no claude is running (`docker exec sbx-demo pgrep -a claude` prints nothing), then delete `$SBX_DIR/state/claude/.claude.json.lock`. Everything else in `state/claude` is safe on the Mac. |
| Console keyless sign-in is lost on recreate | It is stored outside `CLAUDE_CONFIG_DIR`. Log in with a claude.ai account instead. |
| A check fails only because of the capability drop | Remove the `cap_drop` block from `compose.yml`, keep `no-new-privileges`, and report it. |
| "Mounts denied" or "path is not shared" | Add the parent of `SBX_DIR` in Docker Desktop, Settings, Resources, File sharing. |
| `required variable SBX_DIR is missing a value` | Export both `SBX_NAME` and `SBX_DIR` in this terminal. |
| Invalid project name | `SBX_NAME` must be lowercase. |
| `[sbx] ERROR: ... (the project folder) is missing` | Create it: `mkdir -p "$SBX_DIR/$SBX_NAME"`. Or `SBX_DIR` / `SBX_NAME` is mistyped. |
| `claude --resume` shows nothing | Sessions are keyed by directory; start it from the same directory as before. |
| A plain `docker run` is refused | Intended. Bypass the entrypoint, as in "Image-only smoke tests". |
| The container stops right after `up` | Run `docker logs sbx-<name>`. The `[sbx] ERROR: start hook ... failed` line and the hook's own error above it say what broke. |
| Claude refuses to edit a file under `~/.claude/rules` or a bundle skill | Intended. Edit `best-practices/` in this repo (see "Best-practices bundle"). |
| A sandbox migrated from the old layout loads the same rules twice | Remove the `@AGENTS.md` and `@code-conventions.md` imports from `state/claude/CLAUDE.md`. |
| Host check H-10 showed Docker creating the missing folder | Planned follow-up: an `env_file` sentinel file at the root of `SBX_DIR`, which makes Compose fail when the folder is missing. It changes the folder layout, so it waits for your approval. |
