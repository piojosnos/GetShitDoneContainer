# sbx sandbox

One Docker container per project. It sees exactly one folder on your Mac, `$SBX_DIR`:

| On the Mac | Holds |
|---|---|
| `$SBX_DIR/<name>/` | your code |
| `$SBX_DIR/best-practices/` | this sandbox's clone of the best-practices repo (standing rules and skills) |
| `$SBX_DIR/state/` | Claude login, settings and sessions; bash history; gh login; git identity; npm, uv and Maven caches |

- Nothing is mounted over the container's home directory, so everything the image provides stays visible.

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

## Scripts

Seven scripts in `bin/` register, start, enter, list, stop, remove and upgrade a sandbox by name. Put `bin/` on your PATH once, in `~/.zshrc`:

```bash
export PATH="/path/to/GetShitDoneContainer/bin:$PATH"
```

- Put `bin/` on PATH; do not copy or link the scripts. They find `compose.yml` and `build.sh` from their own folder.
- Every script but `sbx-list` takes the name; `sbx-rm` also takes `--unregister` and `--yes`. They run with the Mac's stock bash and accept a folder with spaces.

| Command | What it does |
|---|---|
| `sbx-add NAME HOST_PATH` | Registers the sandbox once. Creates the folder, its project folder and `state/`, and writes the registry entry. The agent is claude. |
| `sbx-start NAME` | Checks the folders, runs `docker compose up -d --wait`, then waits up to 120 s for the start hooks. |
| `sbx-shell NAME` | Starts the sandbox when it does not run (the same checks and wait as `sbx-start`), then opens bash in its project folder. A running sandbox is entered as it is. |
| `sbx-list` | Lists every registered sandbox with its status and folder, from one `docker ps -a` call. |
| `sbx-stop NAME` | Runs `docker compose stop`. The container stays; nothing in the folder changes. |
| `sbx-rm NAME [--unregister] [--yes]` | Runs `docker compose down`: the container and its network go; volumes, images and the folder stay. A running sandbox asks first; `--yes` skips the question. `--unregister` also deletes the registry entry. |
| `sbx-upgrade NAME [BUILD_OPTION...]` | Builds both images with `./build.sh`, then recreates this sandbox and waits for it. Prints the tool versions last. |

## Register a sandbox

Once per sandbox:

```bash
sbx-add demo /Users/you/sbx-demo
```

- It creates `/Users/you/sbx-demo`, `/Users/you/sbx-demo/demo` (your code) and `/Users/you/sbx-demo/state`. The container creates the subfolders of `state/` itself.
- It refuses:
  - a name outside the name rule, `state` and `best-practices`, or a name that is already registered
  - a relative path, or one with a `.`, `..` or empty part
  - a folder that holds the registry folder, such as `/` or your home
  - a folder that is, holds or sits inside this repo's folder, because the Mac runs the repo's scripts and a sandbox there could change them
  - a folder that is, holds or sits inside another sandbox's folder
- Those folder checks compare folders, not spelling: a symlink, `/tmp` against `/private/tmp`, or another letter case on the Mac's disk is still the same folder.
- Registering a folder you already used with the raw commands, or one you unregistered with `sbx-rm --unregister`, keeps its login and history.

The registry is one file per sandbox, `~/.config/sbx/sandboxes/NAME`, with two lines:

```text
SBX_DIR=/Users/you/sbx-demo
SBX_AGENT=claude
```

- It lives outside every sandbox's folder on purpose, so no agent can change which folder a start mounts.
- The scripts read it as text and never run it.
- `SBX_CONFIG_DIR` moves the registry folder. Only the tests set it.

What lives where. `$SBX_DIR` is the folder you registered and `$SBX_NAME` is the sandbox name:

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
- Bash history is written right after each command, not when the shell exits. It is on the Mac at once and survives a stop, an upgrade and a fresh start. Other shells that are already open see it only after they restart.

### gh and git identity

- `sbx-gh-login` once in the sandbox; it persists. It runs `gh auth login` and `gh auth setup-git`, so git pushes and pulls over HTTPS with that login. Then it asks for `user.name` and `user.email` if they are empty; set ones are printed and left alone.
  - There is no keyring in the container, so gh stores its token as plain text in `state/gh/hosts.yml`. Git's helper entry is in `state/git/config`. Neither is ever in a clone.
  - `state/` sits next to your project folder, not inside it, so the token never ends up in a git repo.
- `git config --global user.name "Your Name"` and `git config --global user.email you@example.com` persist in `state/git/config`.
  - The Mac's own `~/.gitconfig` is never read or touched.

## Start, enter, stop

Start:

```bash
sbx-start demo
```

- It returns when the start hooks (the GSD sync and the bundle links) are done, and prints `sbx-shell demo`.
- A hook that fails stops the container, and `sbx-start` says so.
- A running sandbox on an older image is recreated by `sbx-start`, after a warning (see "Upgrade").

Open a shell. Open as many as you like:

```bash
sbx-shell demo
```

It opens bash in your project folder, `/home/sandbox/workspace/demo`. The shell prints the tool versions line when it opens, for example:

```text
claude 2.1.285 | gsd 1.15.0 | ccusage 20.0.26 | node 24.21.0 | jdk 21.0.12 | mvn 3.9.11 | python 3.12.3
```

- Scripts and one-off `docker exec` commands stay quiet.
- `sbx-upgrade` ends with the same line.
- A sandbox that is stopped or has no container is started first, with the same checks and wait as `sbx-start`.
- A running sandbox is entered as it is: no restart and no recreate, even when it runs on an older image (`sbx-list` shows that). Its other shells and Claude sessions stay open.
- It does not wait for the start hooks of a sandbox that already runs. A sandbox just started with the raw `docker compose up` may still be in its hooks for a few seconds; one started by `sbx-start` or `sbx-shell` is ready.
- It needs a terminal. From a pipe or a script Docker refuses the shell (`the input device is not a TTY`, or on newer Docker `stdin is not a terminal`) after the sandbox has started.
- Its exit status is the shell's.

Start Claude there:

```bash
sbx-claude
```

- `sbx-claude` runs `claude`, after a warning when no best-practices clone is linked. Plain `claude` works too, without the warning.
- On the first run, set up the clone first: see "Best-practices bundle".
- Log in once with a claude.ai account: Claude prints a URL, the browser shows a code, you paste it at the prompt.
- The login is written to `$SBX_DIR/state/claude` on the Mac.
- Sessions are keyed by directory: run `claude --continue` or `claude --resume` from the same directory as before.
- There is no command that starts Claude from the Mac. Open a shell with `sbx-shell`, then run `sbx-claude`.

Stop:

```bash
sbx-stop demo
```

- The container stays and the next `sbx-start` reuses it.
- Everything in `$SBX_DIR` stays.
- Never ask Compose to remove volumes. This layout uses none, and that request is how the old layout lost data.

### What the scripts run

For the user who wants the raw commands. From the repo root:

```bash
SBX_NAME=demo SBX_DIR=/Users/you/sbx-demo docker compose --env-file /dev/null -p sbx-demo -f compose.yml up -d --wait
SBX_NAME=demo SBX_DIR=/Users/you/sbx-demo docker compose --env-file /dev/null -p sbx-demo -f compose.yml stop
SBX_NAME=demo SBX_DIR=/Users/you/sbx-demo docker compose --env-file /dev/null -p sbx-demo -f compose.yml down
docker exec -it -w /home/sandbox/workspace/demo sbx-demo bash
docker ps -a --filter label=sbx.name --format '{{.Names}} {{.State}}'
docker stop sbx-demo
docker rm sbx-demo
```

- `down` is what `sbx-rm` runs. It never carries an option that removes volumes or images.
- `docker stop` and `docker rm` are what `sbx-rm --unregister` runs for a broken entry instead of `down`, by the exact container name and never with `-v` or `-f`.
- `docker exec` is what `sbx-shell` runs, after the `sbx-start` steps when the sandbox does not run. `-w` starts the shell in your project folder; without it a shell starts in `/home/sandbox/workspace`.
- `docker ps` is what `sbx-list` reads.
- `up` returns before the start hooks finish, so it does not report a failing hook: the container exits afterwards. `sbx-start` waits for them.
- The hooks are done when the container runs its command. `docker exec sbx-demo pgrep -x sleep` succeeds then, and fails when the container has exited (`docker logs sbx-demo` shows why).

## List sandboxes

```bash
sbx-list
```

```text
NAME                            STATUS               PATH
demo                            running              /Users/you/sbx-demo
docs                            running, older image /Users/you/my docs
scratch                         stopped              /Users/you/sbx-scratch
tryout                          no container         /Users/you/sbx-tryout
older image: sbx-start NAME recreates it on the current image; that closes its open shells and Claude sessions

Containers with the sbx.name label but no registry entry (sbx-add NAME HOST_PATH registers one again):
  sbx-hosttest                        stopped
```

- The status of every sandbox comes from one `docker ps -a` call.
- `running` is running. Every other Docker state (exited, created, paused, and so on) reads `stopped`. A sandbox Docker has no container for reads `no container`.
- `running, older image` means the container runs on an older build of `sbx-claude:local`, for example after `sbx-upgrade` of another sandbox. Its next `sbx-start` recreates it on the current image, after the sessions warning. `sbx-shell` enters it as it is.
- An entry the scripts cannot read shows `broken entry` and the entry file's path. `sbx-start NAME` prints what is wrong; `sbx-rm NAME --unregister` clears it (see "Remove a sandbox").
- Rows are sorted by name.
- A line under the table explains `running, older image`, and only when a row has it.
- After that, `Containers with the sbx.name label but no registry entry` lists, for example, the host-test sandbox `sbx-hosttest` or a sandbox whose entry was deleted by hand. `sbx-add NAME HOST_PATH` registers one again; anything else is plain `docker`.
- The old `cc_` containers never show.
- It only reads and changes nothing.

## Remove a sandbox

```bash
sbx-rm demo
sbx-rm demo --unregister
sbx-rm demo --yes
```

- `sbx-rm` runs `docker compose down` for that one sandbox. Its container and its network go. It never removes volumes or images, which the other sandboxes use.
- A running sandbox is removed only after a question. One line warns that its open shells and Claude sessions close, then `sbx-rm` asks `Remove the running sbx-demo? [y/N]`. `y` or `Y` removes it; any other answer, or Enter alone, keeps it and changes nothing.
- `--yes` skips the question, for scripts. It goes before or after the name, with or without `--unregister`.
- Without a terminal (a pipe or a script) and without `--yes`, a running sandbox is refused and nothing changes.
- Compose stops a running container with a 10 s grace, then kills it. A write in progress at that moment can be cut off, so close Claude and the shells before you answer `y`.
- A stopped sandbox, or one with no container, is removed with no question.
- Nothing in `$SBX_DIR` is read, written or deleted, and the last line says so. The folder may even have been moved away.
- Running it twice is fine: the second run finds no container and is quiet.
- `--unregister` also deletes the registry entry `~/.config/sbx/sandboxes/NAME`, only after the down worked. When the down fails, the entry stays and `sbx-rm` can run again.
- To bring a sandbox back, run `sbx-add demo /Users/you/sbx-demo` with the same folder, then `sbx-start demo` or `sbx-shell demo`. The login, history and caches come back from `state/`.
- A `broken entry` in `sbx-list` gives Compose no folder. `sbx-rm demo --unregister` then stops and removes the container `sbx-demo` by its exact name with plain `docker`, after the same question when it runs, and deletes the entry. Volumes stay. The network `sbx-demo_default` stays too; `docker network rm sbx-demo_default` removes it.
- Without `--unregister`, a broken entry is refused and nothing changes.
- `sbx-rm` needs the registry entry. A container that `sbx-list` shows as not registered is registered again with `sbx-add`, or handled with plain `docker`.

## Upgrade

Rebuild both images and recreate one sandbox on them:

```bash
sbx-upgrade demo
```

Add `--no-cache` for a clean build: `sbx-upgrade demo --no-cache`.

- The build runs while the sandbox keeps running. A failed build leaves it as it was.
- On success the sandbox is recreated without asking, after one line warning that its open shells and Claude sessions close.
- It ends running, even when it was stopped.
- The login and history live in `state/` on the Mac, so they stay.
- It ends by printing the tool versions line of the new container.
- Other sandboxes keep their old image until their next `sbx-start`, which recreates them on the new one; `sbx-list` marks them `running, older image`. For a running sandbox, `sbx-start` prints the same warning as `sbx-upgrade` first (the recreate closes its open shells and Claude sessions) and then goes on; it does not wait for an answer. Finish your sessions before you run `sbx-start` on a running sandbox.
- Each upgrade leaves the old images untagged. `./clean.sh` shows them and `./clean.sh --yes` frees them (see "Free disk space").

## Bump a version or add a tool

1. Change the value in `versions.env`. For a new tool, add one `NAME=value` line there, and in the Dockerfile that installs it an `ARG NAME` right above the `RUN` that uses it. `build.sh` needs no change.
2. Run `sbx-upgrade NAME`. It runs `./build.sh` and recreates that sandbox on the new images; login and history stay in `state/`. Other sandboxes pick the images up at their next `sbx-start`.

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
| 1 | `sbx-gh-login` | Logs gh in and lets git use that login over HTTPS. It also asks for the git name and email if none is set. |
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
| A sandbox shell | `git -C /home/sandbox/workspace/best-practices pull` |
| Claude | Ask it to pull the practices |

- Never run git on the clone from the Mac, and do not open it in an IDE with git integration. The agent (and anything it runs) can write the clone's `.git`, and git runs the hooks and config found there. Run git inside the sandbox and review changes in the PR on GitHub.
- An edit or a pull is on disk at once. A running Claude session sees a changed rule at its next session or after `/clear`.
- A pull that adds or removes a skill shows after a restart, or after `/etc/sbx/start.d/10-best-practices`.
- A clone made on the Mac while the sandbox runs needs that hook once.

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
- Review a change in its PR on GitHub. Another sandbox gets it only when it is pushed and that sandbox pulls.
- `sbx-gh-login` gives the sandbox gh's default scopes, so a push to `main` of the bundle repo, or to any of your repos, is possible without a PR. "Push only with my go" is a rule Claude follows, not a lock.
- Recommended: a fine-grained token limited to the bundle repo caps that.
- Branch protection on `main` stops a direct push. On a private repo it may need a paid GitHub plan.

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

- `sbx-start` and `sbx-upgrade` check that the project folder and `state/` exist before Docker runs. A missing one stops them with the path.
- The registered path is absolute: Compose reads a relative one from the repo folder and does not expand `~`.
- With the raw Compose commands, some Compose versions ignore the "do not create a missing folder" setting (docker/compose issue 13602), so a mistyped `SBX_DIR` could get an empty folder on your Mac. The container still refuses to start.

## Verify a new build

After building, or after changing anything under `base/`, `claude/` or `compose.yml`, run `./host-test.sh` on the Mac. It runs `tests/host/run-all.sh` and the other Docker checks and keeps the output in `host-test.log`. When it passes, the automated checks hold. Claude's login and Claude's own behaviour are checked only by the helpers in `tests/host/manual/`: H-07 (login), the second half of H-09 (login and session survive a rebuild), the `claude doctor` part of H-13, the GSD bump part of H-16 (`manual/h16-gsd-bump.sh`), H-19 (the real bundle flow: login, clone, read, amend, refuse), `h29-upgrade-resume.sh` (login and session survive `sbx-upgrade`), and `h31-jump-in.sh` (a real shell through `sbx-shell`, and `sbx-claude` there still logged in after a stop). Run them after a Claude Code or GSD pin change, a change to the managed settings, or a change to login handling. [`tests/host-checklist.md`](tests/host-checklist.md) explains the result and the helpers.

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
| `sbx-...: NAME is not registered` | Run `sbx-add NAME HOST_PATH`. |
| `sbx-claude:local is not built` | Run `sbx-upgrade NAME`. |
| `the input device is not a TTY` or `stdin is not a terminal` from `sbx-shell` | Run it in a terminal, not through a pipe or a script. The sandbox has already started. |
| `broken entry` in `sbx-list` | `sbx-start NAME` prints what is wrong with the entry. Fix the file, or run `sbx-rm NAME --unregister` and then `sbx-add` again. |
| `sbx-NAME is running and there is no terminal to confirm on` from `sbx-rm` | Run it in a terminal and answer `y`, or add `--yes`. Nothing was changed. |
| `docker compose down failed for sbx-NAME; the registry entry stays` | Read the Compose output above it, then run `sbx-rm NAME` again. |
| `cannot read the containers from Docker` or `cannot reach Docker; is Docker running?` | Start Docker Desktop. |
| `the build failed; sbx-NAME was left as it was` | Read the build output above it. The sandbox still runs on the old image. |
| `the start hooks of sbx-NAME did not finish within 120 s` or `sbx-NAME stopped during its start` | Run `docker logs sbx-NAME`. |
| `overlaps the registry folder`, `overlaps the repo folder` or `overlaps the folder of sandbox` | Pick a folder of its own for the sandbox. |
| `required variable SBX_DIR is missing a value` | Only the raw Compose commands read `SBX_NAME` and `SBX_DIR` from your terminal; export both, or use the `sbx-*` scripts. |
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
