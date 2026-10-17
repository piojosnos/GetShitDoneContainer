# sbx sandbox (new layout)

One Docker container per project. It sees exactly one folder on your Mac, `$SBX_DIR`:

| On the Mac | Holds |
|---|---|
| `$SBX_DIR/<name>/` | your code |
| `$SBX_DIR/best-practices/` | this sandbox's clone of the best-practices repo (standing rules and skills) |
| `$SBX_DIR/state/` | Claude login, settings and sessions; bash history; gh login; git identity; npm, uv and Maven caches |

- Nothing is mounted over the container's home directory, so everything the image provides stays visible.
- It runs side by side with the old `ClaudeCode/` layout, which keeps working and stays documented in `README.md`.

## What the images hold

| Image | Holds |
|---|---|
| `sbx-base:local` | Ubuntu 24.04, git, gh, Node.js 24, Python 3 (pip, venv) and uv, the Temurin JDK 21, Maven, jq, ripgrep, zip and unzip, the ssh client, make and a C compiler, shellcheck and hadolint |
| `sbx-claude:local` | `sbx-base` plus Claude Code, GSD, ccusage and the `sbx-gh-login`, `sbx-bundle-clone` and `sbx-claude` wrappers (no bundle) |

- Python projects use uv or a venv, because Ubuntu blocks plain pip installs into the system Python.
- Every version is in `versions.env` (see "Build the images").

## Requirements

- Docker Desktop on the Mac.
- Compose v2. Run `docker compose version` and note the version for the host checklist.
- `SBX_NAME` follows the sandbox name rule: starts with a lowercase letter, then lowercase letters, digits or hyphens, 31 characters at most (`^[a-z][a-z0-9-]{0,30}$`). `my-project` works; `MyProject`, `my_project` and `my.project` are refused. Such a name is valid as a folder, a container name, a hostname and a Compose project. `state` and `best-practices` are taken, because they are the sandbox's own folders.

## Build the images

From the repo root:

```bash
./build.sh
```

- Builds `sbx-base:local`, then `sbx-claude:local`, which starts `FROM` the base.
- Every version (base OS image, toolchains, Claude Code) lives in `versions.env` at the repo root. `build.sh` passes it to both builds.
- The Dockerfiles have no default versions, so a plain `docker build` stops and names the missing pin.
- Extra options pass through to both builds, for example `./build.sh --no-cache` for a clean build.
- `build.sh` runs from any folder; the repo root is the build context.
- Plain apt packages are not pinned. They follow the pinned Ubuntu release and pick up its security fixes at each rebuild.
- In a sandbox shell, `cat /etc/sbx/versions.env` shows the pins the image was built with.
- A `.dockerignore` lets only `base/`, `claude/` and `versions.env` into the build.
- `versions.env` also holds `BUNDLE_REPO_URL`, the repo `sbx-bundle-clone` clones. It is a setting, not a version; change it and rebuild.

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
| `$SBX_DIR/best-practices` (the clone) | `/home/sandbox/workspace/best-practices` | `SBX_BUNDLE_DIR` |
| `$SBX_DIR/state/claude` | `/home/sandbox/workspace/state/claude` (also `~/.claude`) | `CLAUDE_CONFIG_DIR` |
| `$SBX_DIR/state/shell` (holds `bash_history`) | `/home/sandbox/workspace/state/shell` | `HISTFILE` |
| `$SBX_DIR/state/gh` (holds `hosts.yml`) | `/home/sandbox/workspace/state/gh` | `GH_CONFIG_DIR` |
| `$SBX_DIR/state/git` (holds `config`) | `/home/sandbox/workspace/state/git` | `GIT_CONFIG_GLOBAL` |
| `$SBX_DIR/state/cache/npm` | `/home/sandbox/workspace/state/cache/npm` | `NPM_CONFIG_CACHE` |
| `$SBX_DIR/state/cache/uv` | `/home/sandbox/workspace/state/cache/uv` | `UV_CACHE_DIR` |
| `$SBX_DIR/state/m2` | `/home/sandbox/workspace/state/m2` (also `~/.m2`) | |

- The caches survive recreate and rebuild, so an upgrade does not download everything again.
- Many small files over the Mac file sharing are slower than the container's own disk, and the caches can grow to several GB per sandbox.
- Deleting `state/cache` or `state/m2` is always safe; the tools download again.
- Everything else in `/home/sandbox` (`.bashrc`, `.local`, ...) comes from the image.
- On the Mac, open `$SBX_DIR/$SBX_NAME` in your IDE, not `$SBX_DIR`: `state/` holds credentials.
- Bash history is written right after each command, not when the shell exits. It is on the Mac at once and survives `docker compose down` and a fresh `up`. Other shells that are already open see it only after they restart.

### gh and git identity

- `sbx-gh-login` once in the sandbox; it persists. It runs `gh auth login` and `gh auth setup-git`, so git pushes and pulls over HTTPS with that login.
  - There is no keyring in the container, so gh stores its token as plain text in `state/gh/hosts.yml`. Git's helper entry is in `state/git/config`. Neither is ever in a clone.
  - `state/` sits next to your project folder, not inside it, so the token never ends up in a git repo.
- `git config --global user.name "Your Name"` and `git config --global user.email you@example.com` persist in `state/git/config`.
  - The Mac's own `~/.gitconfig` is never read or touched.

## Start, enter, stop

Start, from the repo root. `up` returns before the start hooks (the GSD sync and the bundle links) finish, so it does not report a failing hook: the container exits afterwards.

```bash
docker compose up -d --wait
```

The hooks are done when the container runs its command. This succeeds then, and fails when the container has exited (`docker logs "sbx-$SBX_NAME"` shows why):

```bash
docker exec "sbx-$SBX_NAME" pgrep -x sleep
```

Open a shell. Open as many as you like:

```bash
docker exec -it -w "/home/sandbox/workspace/$SBX_NAME" "sbx-$SBX_NAME" bash
```

`-w` starts the shell in your project folder; without it a shell starts in `/home/sandbox/workspace`. Start Claude there:

```bash
sbx-claude
```

- `sbx-claude` runs `claude`, after a warning when no best-practices clone is linked. Plain `claude` works too, without the warning.
- On the first run, set up the clone first: see "Best-practices bundle".
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

Stop, rebuild both images (add `--no-cache` to `build.sh` for a clean build), start again:

```bash
docker compose down
./build.sh
docker compose up -d --wait
```

The login and history live in `state/` on the Mac, so the new container picks them up unchanged.

## Bump a version or add a tool

1. Change the value in `versions.env`. For a new tool, add one `NAME=value` line there, and in the Dockerfile that installs it an `ARG NAME` right above the `RUN` that uses it. `build.sh` needs no change.
2. Run `./build.sh`.
3. Run `docker compose up -d --wait`. Compose recreates the container on the new image; login and history stay in `state/`.

- A new or bumped pin gets the same review as any new dependency: exact version, publish date, provenance, and the digest or checksum.

## Best-practices bundle

Every sandbox reads the same standing rules and skills (`/pr-reply`, `/merged`) from its own clone, and can improve them by PR.

| Where | What |
|---|---|
| `piojosnos/claude-best-practices` (private GitHub repo) | The source: `rules/` and `skills/`, plain Markdown. Named by `BUNDLE_REPO_URL`. |
| `$SBX_DIR/best-practices` (`/home/sandbox/workspace/best-practices`, `SBX_BUNDLE_DIR`) | This sandbox's own git clone. Usable from the Mac with the container down. |
| `$SBX_DIR/state/claude` (`~/.claude`) | Links into the clone: `rules` and one link per bundle skill |

First run, once per sandbox:

| Step | Command | What it does |
|---|---|---|
| 1 | `sbx-gh-login` | Logs gh in and lets git use that login over HTTPS |
| 2 | `sbx-bundle-clone` | Clones the repo into `SBX_BUNDLE_DIR` and links it. It refuses an existing folder and prints how to update or relink it. |
| 3 | `sbx-claude` | Starts Claude. It warns and waits 5 seconds when no clone is linked. |

What a start does in `state/claude`:

| In `state/claude` | What a start does |
|---|---|
| `rules` | A link to `../../best-practices/rules` |
| One link per skill folder of the clone | Created, and listed in `.best-practices-skills` |
| GSD's skills and your own | Never touched by the bundle links. GSD's skills are synced by GSD, see below. |
| `projects/` (memories), `CLAUDE.md`, `settings.json`, the login | Never touched. |

- With no clone, the start goes on and prints `[sbx] no best-practices clone at ...; run sbx-bundle-clone`.
- A start never fetches or pulls, and needs no network.
- An existing sandbox's first start after the rebuild replaces its old copies with links, or drops them until you run `sbx-bundle-clone`.

How a rule loads:

| Rule file | Loads |
|---|---|
| No frontmatter | In every session |
| `paths:` frontmatter (globs in quotes) | When Claude touches a matching file |

Update the practices:

| From | Command |
|---|---|
| The Mac | `git -C "$SBX_DIR/best-practices" pull` |
| A sandbox shell | `git -C /home/sandbox/workspace/best-practices pull` |
| Claude | Ask it to pull the practices |

- An edit or a pull is on disk at once. A running Claude session sees a changed rule at its next session or after `/clear`.
- A pull that adds or removes a skill shows after a restart, or after `/etc/sbx/start.d/10-best-practices`.
- A clone made on the Mac while the sandbox runs needs that hook once.
- If the Mac's git has no login for the private repo, pull inside the sandbox.

Change a rule or a skill:

1. Edit the file in the clone by its real path (or ask Claude to amend the practices), on a new branch cut from the updated `main`.
2. Commit.
3. Push with your go and open a PR against `main` with `gh pr create`.
4. You merge it on GitHub. Other sandboxes get it when they pull.

Edit protection:

- Managed settings let Claude edit the clone from any project folder (`additionalDirectories`).
- Claude's Edit tool is refused on `.best-practices-skills` and every path under `state/claude/skills/` (the bundle's links, GSD's skills and your own), even with permissions bypassed. Edit a bundle skill in the clone, and your own skills from a shell or a host editor.
- It is not a security boundary: a script Claude runs can still write there.
- `state/claude/CLAUDE.md` stays editable.

The trade:

- Claude can change rules that every later session in this sandbox loads, also when a prompt injection asks it to.
- `git -C "$SBX_DIR/best-practices" status` and `git diff` on the Mac show every change. Nothing reaches another sandbox without a PR you merge.
- `sbx-gh-login` gives the sandbox gh's default scopes, so pushing to any of your repos is possible. "Push only with my go" is a rule Claude follows, not a lock.
- A fine-grained token limited to the bundle repo caps that. It is optional.
- Branch protection on a private repo may need a paid GitHub plan.

Memories are not shipped. They belong to each project. A memory that proves general becomes a bundle rule by PR against the bundle repo.

Moving an existing project into a sandbox: its old memories and `CLAUDE.md` may repeat bundle rules. Paste the prompt in [`prompts/consolidate-memories.md`](prompts/consolidate-memories.md) into Claude once; it sorts them and removes duplicates only after you approve.

## GSD

GSD comes baked into the Claude image at the version in `versions.env`, from `@opengsd/gsd-core` only. At every start, before the bundle links, the image's GSD is synced into `state/claude`. It needs no network.

| In `state/claude` | What a start does |
|---|---|
| `gsd-core/`, `agents/`, `hooks/`, every `skills/gsd-*` folder | Replaced by the image's GSD. A hand edit is first saved to `gsd-local-patches/`. |
| `settings.json` | GSD adds its hooks and permissions. Your own keys stay. |
| Your own skills, `projects/` (sessions and memories), `CLAUDE.md`, the login | Never touched. |

- GSD owns every skill whose name starts with `gsd-`. Give your own skills another name: a start removes a `gsd-*` skill that GSD does not ship.
- GSD runs before the bundle, so a bundle skill wins a name clash.
- A failed sync stops the start with an `[sbx] ERROR` line and the installer output above it.
- GSD's own update notice in a session does not apply here. To upgrade GSD, change `GSD_CORE_VERSION` in `versions.env` and rebuild (see "Bump a version or add a tool").
- The GSD package brings a second Claude binary for its agent SDK under `/usr/local/lib`. It is not on `PATH` and never updates itself.

## Usage reports (ccusage)

In a sandbox shell, run `ccusage daily`, `ccusage monthly` or `ccusage session`. Add `--json` for JSON.

- It reads `CLAUDE_CONFIG_DIR`, which is this sandbox's `state/claude`, so it reports this project only.
- By default it fetches the current price table from the network when it runs. `--offline` uses the table it ships with.
- Starting the sandbox needs no network either way.

## Safety checks

At start, the container refuses to run unless:

- `/home/sandbox/workspace` is a real, writable mount point of a folder on the Mac. Otherwise your work would land in the container's own layer and be lost on recreate.
- The project folder (`$SBX_DIR/$SBX_NAME`) and `$SBX_DIR/state` exist, and `state` is writable. A mistyped `SBX_DIR` has neither. A mistyped `SBX_NAME` has no project folder: the start is refused, and nothing is created on your Mac.
- `SBX_NAME` follows the sandbox name rule. Otherwise the start stops before any folder is used, with `[sbx] ERROR: SBX_NAME "<value>" breaks the sandbox name rule: ...` (the value in double quotes) and the example `my-project`.
- `SBX_NAME` is not `state` or `best-practices`, the sandbox's own folders. Otherwise the start stops with `[sbx] ERROR: SBX_NAME "..." is taken: ...`.

A name that breaks the rule is refused in one of two places:

| Name | Refused by | When |
|---|---|---|
| An uppercase letter, `MyProject` | `docker compose up`: the image name of the `name-check` service must be lowercase | Before anything is created or replaced |
| Any other name outside the rule, `my_project`, `my.project` | The container start, with the `[sbx] ERROR` line above | Before the project folder is used |

Compose turns the project name into lowercase, and only `up` checks the name. Use the exact lowercase name with `down`, `ps` and `logs`.

After the checks, the start runs the image's start hooks (the GSD sync and the bundle links):

- A failing hook stops the start, so a sandbox never runs with a half-synced GSD.
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

After building, or after changing anything under `base/`, `claude/` or `compose.yml`, run `./host-test.sh` on the Mac. It runs `tests/host/run-all.sh` and the other Docker checks and keeps the output in `host-test.log`. When it passes, the automated checks hold. Claude's login and Claude's own behaviour are checked only by the helpers in `tests/host/manual/`: H-07 (login), the second half of H-09 (login and session survive a rebuild), the `claude doctor` part of H-13, the GSD bump part of H-16 (`manual/h16-gsd-bump.sh`), and H-19 (the real bundle flow: login, clone, read, amend, refuse). Run them after a Claude Code or GSD pin change, a change to the managed settings, or a change to login handling. [`tests/host-checklist.md`](tests/host-checklist.md) explains the result and the helpers.

It uses its own test sandbox, `sbx-hosttest`, and does not touch your sandboxes. [`tests/README.md`](tests/README.md) lists every test suite, where it runs and what it catches.

## Free disk space

Rebuilds and host-test runs pile up images, build cache and run folders. From the repo root:

```bash
./clean.sh          # shows disk use, containers, host-test run folders and images; removes nothing
./clean.sh --yes    # removes them
```

| Removed | Kept |
|---|---|
| The test sandbox `sbx-hosttest` and its network | Every other container, running or stopped, old sandboxes included |
| Every host-test run folder (`sbx-hosttest-*` in the macOS temp folder; each may hold a test Claude login) | The images those containers use |
| The Docker build cache | All volumes |
| Every image no container uses | Every sandbox folder and its `state/` |

- `sbx-base:local` and `sbx-claude:local` go too when no container uses them. `./build.sh` rebuilds them; the first build after a clean takes a few minutes.
- A build that fails with `No space left on device` usually means the Docker Desktop disk is full: run `./clean.sh --yes`, or raise the disk limit in Docker Desktop, Settings, Resources.

## Troubleshooting and known limits

| Symptom | Fix |
|---|---|
| Claude hangs at start after an unclean stop | Check no claude is running (`docker exec sbx-demo pgrep -a claude` prints nothing), then delete `$SBX_DIR/state/claude/.claude.json.lock`. Everything else in `state/claude` is safe on the Mac. |
| Console keyless sign-in is lost on recreate | It is stored outside `CLAUDE_CONFIG_DIR`. Log in with a claude.ai account instead. |
| A check fails only because of the capability drop | Remove the `cap_drop` block from `compose.yml`, keep `no-new-privileges`, and report it. |
| "Mounts denied" or "path is not shared" | Add the parent of `SBX_DIR` in Docker Desktop, Settings, Resources, File sharing. |
| `required variable SBX_DIR is missing a value` | Export both `SBX_NAME` and `SBX_DIR` in this terminal. |
| Maven fails with `java.io.IOException: Input/output error` and `Failed to delete tracking file` | Maven 3.9.12 and later cannot keep their local repository on the Docker Desktop for Mac mount. Keep `MAVEN_VERSION` at 3.9.11 until a newer release passes host check H-23. |
| `up` fails with `... must be lowercase` and names `sbx-<name>-name-check` | `SBX_NAME` has an uppercase letter. Use the lowercase name; see the name rule in Requirements. |
| `[sbx] ERROR: SBX_NAME "..." breaks the sandbox name rule` | Pick a name that follows the rule and rename the project folder to match. A sandbox named with `_` or `.` before this rule needs the same rename. |
| `[sbx] ERROR: ... (the project folder) is missing` | Create it: `mkdir -p "$SBX_DIR/$SBX_NAME"`. Or `SBX_DIR` / `SBX_NAME` is mistyped. |
| `claude --resume` shows nothing | Sessions are keyed by directory; start it from the same directory as before. |
| A plain `docker run` is refused | Intended. Bypass the entrypoint, as in "Image-only smoke tests". |
| The container stops right after `up` | Run `docker logs sbx-<name>`. The `[sbx] ERROR: start hook ... failed` line and the hook's own error above it say what broke. If the line says `is not executable`, the image lost the hook's execute bit; rebuild the image. If it says `is not a regular file`, a hook link in the image points nowhere (or something that is not a file sits in the hook folder); rebuild the image. |
| `[sbx] ERROR: the GSD sync into ... failed` | The installer output above the line says why. Rebuild the image. A hand edit of a GSD file is kept in `state/claude/gsd-local-patches/`. |
| A skill of yours named `gsd-...` is gone after a start | GSD owns that prefix. Rename the skill. |
| Claude refuses to edit a bundle skill under `~/.claude/skills` | Intended. Edit it in the clone by its real path (see "Best-practices bundle"). |
| The start prints `no best-practices clone` | Run `sbx-gh-login`, then `sbx-bundle-clone`. |
| `sbx-claude` prints the WARNING | Same. If the clone folder exists, relink it with `/etc/sbx/start.d/10-best-practices`. |
| `sbx-bundle-clone` says the folder already exists | Pull it (`git -C /home/sandbox/workspace/best-practices pull`), or relink it with `/etc/sbx/start.d/10-best-practices`. Move the folder away to clone fresh. |
| `sbx-bundle-clone` says it cannot clone | Run `sbx-gh-login` first; the repo is private. |
| A skill you pulled is missing in Claude | Restart, or run `/etc/sbx/start.d/10-best-practices`. |
| A sandbox migrated from the old layout loads the same rules twice | Remove the `@AGENTS.md` and `@code-conventions.md` imports from `state/claude/CLAUDE.md`. |
| Host check H-10 showed Docker creating the missing folder | Report it. An `env_file` sentinel at the root of `SBX_DIR` would make Compose itself refuse a missing folder; it is not planned while H-10 passes, and the container refuses to start either way. |
