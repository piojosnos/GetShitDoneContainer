# sbx sandbox

One Docker container per project. It sees exactly one directory of the host, `$SBX_DIR`:

| On the host | Holds |
|---|---|
| `$SBX_DIR/<name>/` | your code |
| `$SBX_DIR/best-practices/` | this sandbox's clone of the best-practices repo (standing rules and skills) |
| `$SBX_DIR/state/` | Claude or Cursor login, settings and sessions; bash history; gh login; git identity; npm, uv and Maven caches |

- Nothing is mounted over the container's home directory, so everything the image provides stays visible.
- Moving a sandbox from the old layout (the whole home mounted at `/home/sandbox`): see [`MIGRATION.md`](MIGRATION.md).
- Setting up a sandbox on a computer behind Zscaler: see [`ZSCALER.md`](ZSCALER.md).
- The terms the code, tests and docs use: see [`GLOSSARY.md`](GLOSSARY.md).
- What the sandbox does and does not protect: see "Threat model".

## Quick start

| Step | Where | Command | What it does |
|---|---|---|---|
| 1 | Host | `brew install uv` | Once. uv runs the Python code of every command (see "Commands"). |
| 2 | Host | `git clone https://github.com/piojosnos/GetShitDoneContainer.git "$HOME/sbx-tools/GetShitDoneContainer"` | The tools clone. |
| 3 | Host | `echo 'export PATH="$HOME/sbx-tools/GetShitDoneContainer/bin:$PATH"' >> ~/.zshrc` | Puts its `bin/` on PATH. Open a new terminal. |
| 4 | Host | `sbx-add demo /Users/you/sbx-demo` | Registers the sandbox and creates its directories. A third argument, `cursor`, makes a Cursor sandbox. |
| 5 | Host | `sbx-upgrade demo` | Builds the images and starts it. |
| 6 | Host | `sbx-shell demo` | Opens bash in the project directory. |
| 7 | Sandbox | `sbx-init` | Sets the sandbox up: state directories, GSD, best-practices links. It says to clone first when there is no clone. |
| 8 | Sandbox | `sbx-gh-login` | gh and git login. |
| 9 | Sandbox | `sbx-best-practices-clone` | The best-practices clone. It runs `sbx-init` again, which links it. |
| 10 | Sandbox | `sbx-claude` | Claude. Log in once. A Cursor sandbox runs `sbx-cursor` instead; log in once with `sbx-cursor login`. |

Each step is explained below in "Commands", "Register a sandbox", "Set up a sandbox: sbx-init" and "Best-practices clone".

## What the images hold

| Image | Holds |
|---|---|
| `sbx-base:local` | Ubuntu 24.04, git, gh, Node.js 24, Python 3 (pip, venv) and uv, the Temurin JDK 21, Maven, jq, ripgrep, zip and unzip, the ssh client, make and a C compiler, shellcheck and hadolint, GSD, the `sbx-gh-login` and `sbx-best-practices-clone` helpers, `sbx-run-agent` (the init check and agents PATH both agent wrappers run), `sbx-init` with the shared steps, and `sbx-selfcheck` with the shared checks |
| `sbx-claude:local` | `sbx-base` plus Claude Code, ccusage, the Claude steps of `sbx-init`, the `sbx-claude` agent wrapper, the managed settings and the Claude checks of `sbx-selfcheck`. `claude` sits in `/opt/sbx/agents/bin`, off the PATH, and only `sbx-claude` starts it. |
| `sbx-cursor:local` | `sbx-base` plus the Cursor CLI, the Cursor steps of `sbx-init`, the `sbx-cursor` agent wrapper and the Cursor checks of `sbx-selfcheck`. `cursor-agent` sits in `/opt/sbx/agents/bin`, off the PATH, and only `sbx-cursor` starts it. |

- Python projects use uv or a venv, because Ubuntu blocks plain pip installs into the system Python. Every version is in `versions.env` (see "Build the images").

## Requirements

- Docker Desktop on the host, with Compose v2. `./host-test.sh` stops when Compose is older and writes the versions it found to `host-test.log`.
- uv on the host (`brew install uv`). Nothing else is installed there: uv fetches Python 3.12 on its first run, and every command, `build.sh`, `clean.sh` and `host-test.sh` runs through it (see "Commands"). Behind a company proxy, set `UV_SYSTEM_CERTS=true` for that first run (see [`ZSCALER.md`](ZSCALER.md)).
- `SBX_NAME` follows the sandbox name rule: a lowercase letter, then lowercase letters, digits or hyphens, 31 characters at most (`^[a-z][a-z0-9-]{0,30}$`). `my-project` works; `MyProject`, `my_project` and `my.project` are refused.
- `state` and `best-practices` are taken, because they are the sandbox's own directories.

## Build the images

- `./build.sh` builds `sbx-base:local`, then `sbx-claude:local` and `sbx-cursor:local`. It runs from any directory; the repo root is the build context. Extra options pass through, for example `./build.sh --no-cache`.
- `SBX_IMAGE_TAG` picks the tag of all three images. Unset or empty means `local`, the images your sandboxes run; `test` gives `sbx-base:test`, `sbx-claude:test` and `sbx-cursor:test` for `./host-test.sh`, which sets it itself. Any other value is refused. The `sbx-*` commands read it too, so leave it unset in your shell. When it is `test`, `build.sh` and the `sbx-*` commands name it in a line on stderr.
- Every version (base OS image, toolchains, GSD, Claude Code, the Cursor CLI) lives in `versions.env`. The Dockerfiles have no default versions, so a plain `docker build` stops and names the missing pin.
- Plain apt packages are not pinned. They follow the pinned Ubuntu release and pick up its security fixes at each rebuild.
- In a sandbox shell, `cat /etc/sbx/versions.env` shows the pins the image was built with. `sbx-selfcheck` compares the installed tools with them.
- A `.dockerignore` lets only `base/`, `claude/`, `cursor/` and `versions.env` into the build. The root of `SBX_CA_CERT` comes in as its own named build context, `cacert`, from a temporary directory, never through the tools clone.
- `SBX_CA_CERT`, when set, makes `./build.sh` add that root certificate to every image (see "Behind a company HTTPS proxy"). Unset or empty changes nothing.
- `versions.env` also holds `BEST_PRACTICES_REPO_URL`, the repo `sbx-best-practices-clone` clones. It is a setting, not a version; change it and rebuild.

## Behind a company HTTPS proxy

A proxy such as Zscaler opens HTTPS and signs it again with its own root certificate. It does so for `release-assets.githubusercontent.com`, where the `gh` release download lives, and IT does not allow turning it off. A macOS host trusts that root through the Keychain; the images do not. So the base build stops at the `gh` download with `curl: (60) SSL certificate problem`.

`SBX_CA_CERT` names a PEM file on the host. When it is set, `./build.sh` adds every certificate in it to every image. Unset or empty, the images are built exactly as without it.

| Step | Where | Command | What it does |
|---|---|---|---|
| 1 | Host | `security find-certificate -a -c "Zscaler Root CA" -p /Library/Keychains/System.keychain > "$HOME/zscaler-root-ca.pem"` | Exports the root as PEM. Certificates only, no key. |
| 2 | Host | `echo 'export SBX_CA_CERT="$HOME/zscaler-root-ca.pem"' >> ~/.zshrc` | Must be exported, and an absolute path. Open a new terminal. |
| 3 | Host | `sbx-upgrade NAME` | Builds with the root and recreates the sandbox. A banner of `*` lines before and after names the file, subject and fingerprint. |

- A shell without the variable builds images without the root, and behind the proxy that build stops with `curl: (60)`. Keep the `export` in `~/.zshrc`.
- The host's own uv needs the same trust once: the first command that runs through uv fetches Python 3.12, so set `UV_SYSTEM_CERTS=true` for that first run. uv then trusts the macOS Keychain, which already holds the root.
- The first build with a root, or after it changes or goes away, rebuilds every layer after the apt step once.

What trusts the root, and how:

| Tool | How it trusts the root |
|---|---|
| curl, git, gh, Python, system pip, Claude Code, the Cursor CLI | The system store (`update-ca-certificates`) |
| Java and Maven | The JDK `cacerts`, one `sbx-extra-ca-N` alias per certificate |
| npm and GSD | `cafile` in `/usr/local/etc/npmrc` |
| pip in a venv | `cert` in `/etc/pip.conf` |
| uv | `system-certs = true` in `/etc/uv/uv.toml` |
| Node programs | `NODE_EXTRA_CA_CERTS`, set by `/etc/bash.bashrc` |

- The Cursor CLI trusts the extra root through the system store, and the build downloads it from `downloads.cursor.com`.
- `/etc/sbx/extra-ca.pem` holds the added certificates, and `/etc/sbx/extra-ca-fingerprints` their SHA-256 fingerprints, one per line, as `build.sh` computed them. Both exist only in an image built with a root.
- The trade-off: the images trust anything the proxy signs (see "Threat model").
- Known limit: a Node program run by a non-interactive `docker exec` does not get `NODE_EXTRA_CA_CERTS`. Run it from `sbx-shell`.

`sbx-selfcheck` in a sandbox shell confirms that each fingerprint in `/etc/sbx/extra-ca-fingerprints` is in the system store and in Java `cacerts` (its `extra-ca-system-bundle` and `extra-ca-java-cacerts` lines). A root lost in the build fails there, and so does a root installed without its recorded fingerprint; with neither it prints `no extra root certificate requested`. The commands below also prove each tool gets through the proxy.

Check a new build by hand: run these in a sandbox shell. Each prints a status code, a version or a login. None may print `curl: (60)`, `UNABLE_TO_VERIFY_LEAF_SIGNATURE`, `CERTIFICATE_VERIFY_FAILED` or `PKIX path building failed`.

| Tool | Command |
|---|---|
| curl | `curl -sS -o /dev/null -w '%{http_code}\n' https://release-assets.githubusercontent.com/` |
| gh | `gh api user --jq .login` (after `sbx-gh-login`) |
| npm | `npm view left-pad version` |
| Node | `node -e "fetch('https://registry.npmjs.org/').then(r => console.log(r.status))"` |
| Maven | `mvn -q dependency:get -Dartifact=junit:junit:4.13.2` |
| pip in a venv | `python3 -m venv /tmp/v && /tmp/v/bin/pip install requests` |
| uv | `uv venv /tmp/u && uv pip install --python /tmp/u/bin/python requests` |
| Claude Code | `sbx-claude`, log in and send one message |

## Commands

Nine commands in `bin/` register, start, enter, list, stop, remove and upgrade a sandbox by name, set its file modes from git, and move an old registry. Put the tools clone's `bin/` on your PATH once, in `~/.zshrc`:

```bash
export PATH="$HOME/sbx-tools/GetShitDoneContainer/bin:$PATH"
```

- The host needs uv once (`brew install uv`). Each command in `bin/`, and `build.sh`, `clean.sh` and `host-test.sh` in the repo root, is a two-line launcher: a `#!/bin/sh` line and one `exec uv run` line that runs a Python module of `sbx/` (standard library only). uv makes its own environment, so nothing is installed and the repo's `.venv` is never touched.
- Never run a bare `uv run` in the tools clone. The `.venv` it would make belongs to the dev sandbox; on the host the suites run only through `./host-test.sh`.
- Never copy the scripts or put a copy inside a sandbox directory. They find `compose.yml` and `build.sh` from their own directory.
- Every command but `sbx-list` and `sbx-migrate-registry` takes the name; `sbx-rm` also takes `--unregister` and `--yes`. They accept a directory with spaces.

| Command | What it does |
|---|---|
| `sbx-add NAME HOST_PATH [claude\|cursor]` | Registers the sandbox once. Creates the sandbox directory, its project directory and `state/`, and writes the registry entry with its agent, claude when left out. Compose starts that agent's image. |
| `sbx-start NAME` | Checks the directories and runs `docker compose up -d --wait`. The container only keeps running; in a new container, run `sbx-init` in a shell before the agent. |
| `sbx-shell NAME` | Starts the sandbox when it does not run (the same checks as `sbx-start`), then opens bash in its project directory. |
| `sbx-list` | Lists every registered sandbox with its status and sandbox directory, from one `docker ps -a` call. |
| `sbx-stop NAME` | Runs `docker compose stop`. The container stays; nothing in the sandbox directory changes. |
| `sbx-rm NAME [--unregister] [--yes]` | Runs `docker compose down`: the container and its network go; volumes, images and the sandbox directory stay. |
| `sbx-upgrade NAME [BUILD_OPTION...]` | Builds every image with `./build.sh`, which reads `SBX_CA_CERT` from your shell, then recreates this sandbox. The recreate wipes the init marker, so it says to run `sbx-init` in the sandbox shell. Prints the tool versions last. |
| `sbx-fix-modes NAME` | Sets every file git tracks in the project directory to 644 or 755, as git committed, on the host and in the sandbox. Prints how many it changed. |
| `sbx-migrate-registry` | One-off. Writes `NAME.json` next to each old two-line registry file and leaves the old files in place (see [`MIGRATION.md`](MIGRATION.md), "Move the registry to JSON"). It goes in a later release. |

In the sandbox: `sbx-init`, `sbx-gh-login`, `sbx-best-practices-clone` and `sbx-selfcheck` (both agents), `sbx-claude` (Claude) and `sbx-cursor` (Cursor); see "Set up a sandbox: sbx-init", "Best-practices clone" and "Check a sandbox".

## Register a sandbox

- `sbx-add demo /Users/you/sbx-demo`, once per sandbox, creates `/Users/you/sbx-demo`, `/Users/you/sbx-demo/demo` (your code) and `/Users/you/sbx-demo/state`. `sbx-init` makes the subdirectories of `state/` when you first run it in the sandbox.
- It refuses a name outside the name rule, `state`, `best-practices`, or a name already registered; and a relative path, or one with a `.`, `..` or empty part.
- It refuses a directory that holds the registry directory (such as `/` or your home), that is, holds or sits inside the tools clone (the host runs its scripts), or that is, holds or sits inside another sandbox's directory.
- The directory checks compare directories, not spelling: a symlink, `/tmp` against `/private/tmp` or another letter case (on a macOS host) is still the same directory.
- Registering a directory you used before, or one you unregistered with `sbx-rm --unregister`, keeps its login and history.

The registry is one JSON file per sandbox, `~/.config/sbx/sandboxes/NAME.json`, with two keys:

```json
{
  "path": "/Users/you/sbx-demo",
  "agent": "claude"
}
```

- `path` is the sandbox directory, absolute. `agent` is `claude` or `cursor`.
- It lives outside every sandbox directory on purpose, so no agent can change which directory a start mounts. The commands read it as data and never run it. `SBX_CONFIG_DIR` moves it; only the tests set that.
- An old registry of two-line `NAME` files (`SBX_DIR=...`, `SBX_AGENT=...`) is moved once with `sbx-migrate-registry`; see "Move the registry to JSON" in [`MIGRATION.md`](MIGRATION.md).

To change the agent of a sandbox, no command does it. Either:

- edit the `agent` value of its registry entry, then run `sbx-start NAME`, which recreates it on the other image; or
- run `sbx-rm NAME --unregister`, then `sbx-add NAME HOST_PATH [claude|cursor]` with the same directory and the other agent.

The files stay either way. The login of the other agent starts empty, in its own `state/` directory.

### What lives where

`$SBX_DIR` is the sandbox directory you registered and `$SBX_NAME` is the sandbox name:

| On the host | In the container | Env var |
|---|---|---|
| `$SBX_DIR` (the one mount) | `/home/sandbox/workspace` | |
| `$SBX_DIR/$SBX_NAME` (your code) | `/home/sandbox/workspace/$SBX_NAME` (the command runs here; shells use `-w`) | |
| `$SBX_DIR/best-practices` (the clone) | `/home/sandbox/workspace/best-practices` | `SBX_BEST_PRACTICES_DIR` |
| `$SBX_DIR/state/claude` | `/home/sandbox/workspace/state/claude` (also `~/.claude`) | `CLAUDE_CONFIG_DIR` |
| `$SBX_DIR/state/cursor` | `/home/sandbox/workspace/state/cursor` (also `~/.cursor` and `~/.config/cursor`) | `CURSOR_CONFIG_DIR` |
| `$SBX_DIR/state/shell` (holds `bash_history`) | `/home/sandbox/workspace/state/shell` | `HISTFILE` |
| `$SBX_DIR/state/gh` (holds `hosts.yml`) | `/home/sandbox/workspace/state/gh` | `GH_CONFIG_DIR` |
| `$SBX_DIR/state/git` (holds `config`) | `/home/sandbox/workspace/state/git` | `GIT_CONFIG_GLOBAL` |
| `$SBX_DIR/state/cache/npm` | `/home/sandbox/workspace/state/cache/npm` | `NPM_CONFIG_CACHE` |
| `$SBX_DIR/state/cache/uv` | `/home/sandbox/workspace/state/cache/uv` | `UV_CACHE_DIR` |
| `$SBX_DIR/state/m2` | `/home/sandbox/workspace/state/m2` (also `~/.m2`) | |

- The caches survive recreate and rebuild, and can grow to several GB per sandbox. Deleting `state/cache` or `state/m2` is always safe; the tools download again.
- Everything else in `/home/sandbox` (`.bashrc`, `.local`, ...) comes from the image. On the host, open `$SBX_DIR/$SBX_NAME` in your IDE, not `$SBX_DIR`: `state/` holds credentials.
- Bash history is written right after each command and survives a stop, an upgrade and a fresh start. Shells that are already open see it only after they restart.

### gh and git identity

- Run `sbx-gh-login` once in the sandbox; it persists. It runs `gh auth login` and `gh auth setup-git`, so git pushes and pulls over HTTPS with that login.
- It then asks for `user.name` and `user.email` if they are empty; set ones are left alone. `git config --global` persists in `state/git/config` too. The host's own `~/.gitconfig` is never read or touched.
- There is no keyring in the container, so gh stores its token as plain text in `state/gh/hosts.yml`. `state/` sits next to your project directory, so the token never ends up in a git repo.

## Start, enter, stop

`sbx-start`, `sbx-shell` and `sbx-stop` run on the host; `sbx-init`, `sbx-claude` and `sbx-cursor` run in the sandbox shell.

- `sbx-start` returns once the container runs, and prints `sbx-shell demo`. A start only keeps the container running; it sets nothing up. In a new or recreated container, run `sbx-init` in a shell (see "Set up a sandbox: sbx-init").
- A running sandbox on an older image is recreated by `sbx-start`, after a warning (see "Upgrade").
- `sbx-shell` opens bash in your project directory, `/home/sandbox/workspace/demo`. Open as many shells as you like.
- It prints the tool versions line, which `sbx-upgrade` also ends with: `claude 2.1.285 | ccusage 20.0.26 | gsd 1.15.0 | node 24.21.0 | jdk 21.0.12 | mvn 3.9.11 | python 3.12.3`. A Cursor sandbox starts it with `cursor-agent 2026.11.11-b912975 | gsd 1.15.0 | node ...`. Scripts and one-off `docker exec` commands stay quiet.
- A stopped sandbox, or one with no container, is started first, with the same checks as `sbx-start`.
- A running sandbox is entered as it is: no restart and no recreate, even on an older image (`sbx-list` shows that). Its other shells and Claude sessions stay open.
- It needs a terminal. From a pipe or a script Docker refuses the shell (`the input device is not a TTY`, or on newer Docker `stdin is not a terminal`) after the sandbox has started. Its exit status is the shell's.
- `sbx-claude` refuses with `run sbx-init first` until `sbx-init` has passed in this container, then runs `claude`. Plain `claude` is not on the PATH, so `sbx-claude` is the way in. It puts `/opt/sbx/agents/bin` first on the PATH it hands to Claude, so tools Claude starts (such as `/gsd-review`) still find both CLIs. Nothing starts Claude from the host.
- `sbx-claude` passes its arguments to `claude`. `sbx-claude --dangerously-skip-permissions` runs without permission prompts; Claude can then read and send out the tokens in `state/` (see "Threat model").
- Log in once with a claude.ai account: Claude prints a URL, the browser shows a code, you paste it at the prompt. The login is written to `$SBX_DIR/state/claude` on the host.
- Sessions are keyed by directory: run `claude --continue` or `claude --resume` from the same directory as before.
- `sbx-stop` keeps the container, and the next `sbx-start` reuses it. Everything in `$SBX_DIR` stays.
- Never ask Compose to remove volumes. This layout uses none, and removing them deletes data.

A Cursor sandbox:

- `sbx-shell` opens bash as for Claude; start `sbx-cursor` from it. It refuses with `run sbx-init first` until `sbx-init` has passed in this container, then runs `cursor-agent` with its arguments. Plain `cursor-agent` is not on the PATH.
- Log in once with `sbx-cursor login` and open the printed link in the host browser.
- The login (`auth.json`) and the settings live in `$SBX_DIR/state/cursor`, so they survive a recreate and `sbx-upgrade`.
- Self-update is off: `sbx-init` sets the static channel in `cli-config.json`, so the CLI stays at the version of the image.

## Set up a sandbox: sbx-init

`sbx-init` sets a new or recreated container up. Run it in the sandbox shell, once, before the agent.

| Order | Step | What it does | Agent |
|---|---|---|---|
| 1 | `state-dirs` | Makes the directories under `state/` that the tools write to | both |
| 2 | `claude-gsd-sync` or `cursor-gsd-sync` | Syncs the image's GSD into the agent config directory, offline | by agent |
| 3 | `cursor-self-update-off` | Sets the static channel in `cli-config.json` | Cursor |
| 4 | `state-owner` | Gives root-owned files in `state/` back to `sandbox` | both |
| 5 | `claude-best-practices-links` or `cursor-best-practices-links` | Links the best-practices clone into the agent config directory | by agent |

A Claude sandbox runs 4 steps (1, 2, 4, 5); a Cursor sandbox runs 5.

A full pass in a Claude sandbox:

```text
OK: state-dirs: shell, gh, git, cache/npm, cache/uv, m2, claude exist under /home/sandbox/workspace/state
OK: claude-gsd-sync: the GSD installer finished into /home/sandbox/workspace/state/claude
OK: state-owner: 0 paths given back to sandbox
OK: claude-best-practices-links: 12 skills linked from /home/sandbox/workspace/best-practices, rules linked
sbx-init: 4 steps passed; run sbx-selfcheck to check the sandbox
```

The same run with no clone yet:

```text
OK: state-dirs: shell, gh, git, cache/npm, cache/uv, m2, claude exist under /home/sandbox/workspace/state
OK: claude-gsd-sync: the GSD installer finished into /home/sandbox/workspace/state/claude
OK: state-owner: 0 paths given back to sandbox
FAIL: claude-best-practices-links: no best-practices clone at /home/sandbox/workspace/best-practices
      fix: run sbx-gh-login, then sbx-best-practices-clone; it clones the repo and runs sbx-init again
sbx-init: stopped at claude-best-practices-links
```

- Each step prints an `OK` or a `FAIL` line, and a `FAIL` has a `fix:` line under it. A full pass ends with `sbx-init: N steps passed; run sbx-selfcheck to check the sandbox`, and exit status 0.
- It stops at the first `FAIL`, except that the best-practices step links every other skill before it reports a clash.
- Run it once per new or recreated container. It removes the marker `/home/sandbox/.sbx-init-done` first and writes it, in the container's own layer, only when every step passed, so the agent wrappers refuse after a failed run. A recreate or `sbx-upgrade` wipes the marker, so run `sbx-init` again; `sbx-stop` and `sbx-start` keep the container and its marker.
- A rerun redoes every step. It is also how to relink after a `git pull` of the clone that adds or removes a skill.
- A second run while one runs prints `FAIL: lock: another sbx-init is running` and changes nothing.
- Ctrl-C, a closed terminal or a stop ends the run with `sbx-init: interrupted; run sbx-init again` and exit status 130. The GSD installer is stopped with it and its log is removed, and no marker is written, so run `sbx-init` again.
- It checks nothing. `sbx-selfcheck` is the check (see "Check a sandbox"); its `init-marker` line says whether `sbx-init` passed in this container.
- The marker lives in the container, never in the sandbox directory, so a directory moved to another sandbox does not carry it.

## List sandboxes

`sbx-list` prints one row per registered sandbox, sorted by name, with its status and sandbox directory, and changes nothing.

- `running` is running. Every other Docker state (exited, created, paused, and so on) reads `stopped`. A sandbox Docker has no container for reads `no container`.
- `running, older image` means the container runs on an older build of its agent image, for example after `sbx-upgrade` of another sandbox. Its next `sbx-start` recreates it on the current image, after the sessions warning. A line under the table says so.
- An entry the commands cannot read shows `broken entry` and the entry file's path. `sbx-start NAME` prints what is wrong; `sbx-rm NAME --unregister` clears it (see "Remove a sandbox").
- A last block lists containers with the `sbx.name` label but no registry entry, such as a test sandbox of `./host-test.sh` (`sbx-hosttest-claude`) or a sandbox whose entry was deleted by hand. `sbx-add NAME HOST_PATH` registers one again.

## Remove a sandbox

- `sbx-rm demo` runs `docker compose down` for that one sandbox. Its container and its network go. It never removes volumes or images, which the other sandboxes use.
- A running sandbox is removed only after a question. One line warns that its open shells and Claude sessions close, then `sbx-rm` asks `Remove the running sbx-demo? [y/N]`. Only `y` or `Y` removes it.
- `--yes` skips the question, for scripts. Without a terminal and without `--yes`, a running sandbox is refused and nothing changes.
- Compose stops a running container with a 10 s grace, then kills it. Close Claude and the shells before you answer `y`.
- A stopped sandbox, or one with no container, is removed with no question. Running it twice is fine.
- Nothing in `$SBX_DIR` is read, written or deleted; the directory may even have been moved away.
- `--unregister` also deletes the registry entry `~/.config/sbx/sandboxes/NAME.json`, only after the down worked. When the down fails, the entry stays and `sbx-rm` can run again.
- To bring a sandbox back, run `sbx-add demo /Users/you/sbx-demo` with the same directory, then `sbx-start demo`. The login, history and caches come back from `state/`.
- A `broken entry` gives Compose no directory. Without `--unregister` it is refused. With it, `sbx-rm` stops and removes the container `sbx-demo` by its exact name with plain `docker`, after the same question, and deletes the entry.
- The network `sbx-demo_default` stays; `docker network rm sbx-demo_default` removes it. Volumes stay.
- `sbx-rm` needs the registry entry. A container that `sbx-list` shows as not registered is registered again with `sbx-add`, or handled with plain `docker`.

## Upgrade

1. Change the pin in `versions.env` of the tools clone whose `bin/` is on your PATH (or merge the change and `git pull` there).
2. Run `sbx-upgrade NAME`, for example `sbx-upgrade demo`. Add `--no-cache` for a clean build.

- `sbx-upgrade` builds every image with `./build.sh` from the tools clone, so it reads the tools clone's `versions.env`.
- `sbx-upgrade` passes on `SBX_CA_CERT` from the shell it runs in. Without it the images lose the extra root, and behind a company proxy the build stops with `curl: (60)`. Keep the `export` in `~/.zshrc` (see "Behind a company HTTPS proxy").
- The build runs while the sandbox keeps running. A failed build leaves it as it was.
- On success the sandbox is recreated without asking, after one line warning that its open shells and Claude sessions close. It ends running, even when it was stopped.
- The login and history live in `state/` on the host, so they stay.
- A recreate, by `sbx-upgrade` or by `sbx-start` on an older image, wipes the init marker. Run `sbx-init` in the sandbox shell before the agent.
- Other sandboxes keep their old image until their next `sbx-start`, which recreates them; `sbx-list` marks them `running, older image`.
- For a running sandbox, `sbx-start` prints the same warning first and goes on without an answer. Finish your sessions before you run it.
- Each upgrade leaves the old images untagged. `./clean.sh` shows them and `./clean.sh --yes` frees them (see "Free disk space").

### Bump a version or add a tool

- Change the value in `versions.env`, then run `sbx-upgrade NAME`. For a new tool, add one `NAME=value` line there, and in the Dockerfile that installs it an `ARG NAME` right above the `RUN` that uses it. `build.sh` needs no change.
- A new or bumped pin gets the same review as any new dependency: exact version, publish date, provenance, and the digest or checksum.
- GSD is installed in `sbx-base`, so a GSD bump rebuilds both agent images.
- To bump the Cursor CLI, read the newest version from the vendor installer without running it, then put it in `CURSOR_AGENT_VERSION`:

```bash
curl -fsSL https://cursor.com/install | grep -oE 'lab/[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9a-f]+' | head -1
```

- Review it like any pin: the date in the version, and that both checksum files (`x64` and `arm64`) exist under `https://downloads.cursor.com/lab/VERSION/linux/`.

## Best-practices clone

Every sandbox reads the same standing rules and skills (`/pr-reply`, `/merged`) from its own clone, and can improve them by PR. This section describes a Claude sandbox; a Cursor sandbox is described at its end.

| Where | What |
|---|---|
| `piojosnos/claude-best-practices` (private GitHub repo) | The source: `rules/` and `skills/`, plain Markdown. Named by `BEST_PRACTICES_REPO_URL`. |
| `$SBX_DIR/best-practices` (`/home/sandbox/workspace/best-practices`, `SBX_BEST_PRACTICES_DIR`) | This sandbox's own git clone. Usable from the host with the container down. |
| `$SBX_DIR/state/claude` (`~/.claude`) | Links into the clone: `rules` and one link per best-practices skill |

First run, once per sandbox:

| Step | Command | What it does |
|---|---|---|
| 1 | `sbx-init` | Sets the sandbox up. With no clone yet, its best-practices step FAILs and says to clone first. |
| 2 | `sbx-gh-login` | Logs gh in and lets git use that login over HTTPS. It also asks for the git name and email if none is set. |
| 3 | `sbx-best-practices-clone` | Clones the repo into `SBX_BEST_PRACTICES_DIR`, then runs `sbx-init` again, which links it. It refuses an existing directory and prints how to update or relink it. |
| 4 | `sbx-claude` or `sbx-cursor` | Starts the agent. It refuses until `sbx-init` has passed in this container. |

What `sbx-init` does in `state/claude`:

| In `state/claude` | What `sbx-init` does |
|---|---|
| `rules` | Makes or replaces a link to `../../best-practices/rules`, only when `rules` is missing or already such a link. A real `rules` directory is left as it is and FAILs the step. |
| One link per skill directory of the clone | Makes or replaces it, only when that name is missing or already a link into the clone. A directory of yours, a copy or a GSD skill with the same name is left as it is and FAILs the step. |
| A link of its own whose skill the clone dropped | Removes it. |
| GSD's skills and your own other skills | Never touched by the links. GSD's skills are synced by GSD (see "GSD"). |
| `projects/` (memories), `CLAUDE.md`, `settings.json`, the login | Never touched. |

- The clash rule: a name that is not a link into the clone is never replaced. The step links every other skill, then FAILs with `rename or move <path>, then run sbx-init again`. It never deletes anything of yours.
- With no clone, the best-practices step FAILs: run `sbx-gh-login`, then `sbx-best-practices-clone`. Until `sbx-init` has passed, `sbx-claude` and `sbx-cursor` refuse, so the clone must exist first. `sbx-init` never fetches or pulls, and needs no network.
- Copies of clone skills from an older layout are not replaced; they clash (see [`MIGRATION.md`](MIGRATION.md)).
- A rule with no frontmatter loads in every session; one with `paths:` frontmatter (globs in quotes) loads when Claude touches a matching file.
- Update the practices with `git -C /home/sandbox/workspace/best-practices pull` in a sandbox shell, or ask Claude to pull them.
- An edit or a pull is on disk at once. A running session sees a changed rule at its next session or after `/clear`. A pull that adds or removes a skill shows after `sbx-init` and a restart of the agent.
- A clone made on the host while the sandbox runs needs one `sbx-init`.
- Never run git on the clone from the host, and do not open it in an IDE with git integration. The agent can write the clone's `.git`, and git runs the hooks and config found there. Run git inside the sandbox and review changes in the PR on GitHub.

Change a rule or a skill:

1. Edit the file in the clone by its real path (or ask Claude to amend the practices), on a new branch cut from the updated `main`.
2. Commit, push with your go, and open a PR against `main` with `gh pr create`.
3. You merge it on GitHub. Other sandboxes get it when they pull.

Edit protection:

- Managed settings let Claude edit the clone from any project directory (`additionalDirectories`).
- Claude's Edit tool is refused on every path under `state/claude/skills/`, even with permissions bypassed. Edit a best-practices skill in the clone, and your own skills from a shell or a host editor.
- It is not a security boundary: a script Claude runs can still write there. `state/claude/CLAUDE.md` stays editable.

The trade:

- Claude can change rules that every later session in this sandbox loads, also when a prompt injection asks it to. Another sandbox gets a change only when it is pushed and that sandbox pulls.
- `sbx-gh-login` gives the sandbox gh's default scopes, so a push to `main` of the best-practices repo, or to any of your repos, is possible without a PR. "Push only with my go" is a rule Claude follows, not a lock.
- Recommended: a fine-grained token limited to the best-practices repo caps that. Branch protection on `main` stops a direct push; on a private repo it may need a paid GitHub plan.

In a Cursor sandbox:

- `sbx-init` links the best-practices skills into `state/cursor/skills` (`~/.cursor/skills`), the same way and with the same clash rule. The rules are not linked, because Cursor reads global rules only from `.mdc` files and every best-practices rule is `.md`.
- Some skills and rules name Claude paths or slash commands, so they may not work in Cursor as they are.
- Relinking is `sbx-init`.

Memories are not shipped; they belong to each project. A memory that proves general becomes a best-practices rule by PR against the best-practices repo.

To move an existing project into a sandbox, paste [`prompts/consolidate-memories.md`](prompts/consolidate-memories.md) into Claude once. It sorts the old memories and `CLAUDE.md` against the best-practices rules and removes duplicates only after you approve.

## GSD

GSD comes baked into the base image at the version in `versions.env`, from `@opengsd/gsd-core` only. `sbx-init` syncs the image's GSD into `state/claude` or `state/cursor`, whichever the sandbox's agent uses, before it links the best-practices clone. It needs no network.

| In `state/claude` | What `sbx-init` does |
|---|---|
| `gsd-core/`, `agents/`, `hooks/`, every `skills/gsd-*` directory | Replaced by the image's GSD. A hand edit is first saved to `gsd-local-patches/`. |
| `settings.json` | GSD adds its hooks and permissions. Your own keys stay. |
| Your own skills, `projects/` (sessions and memories), `CLAUDE.md`, the login | Never touched. |

- GSD owns every skill whose name starts with `gsd-`. Give your own skills another name: the sync removes a `gsd-*` skill that GSD does not ship.
- A best-practices skill with a `gsd-` name clashes with GSD's: it is left as it is, and the best-practices step FAILs with a rename or move fix.
- GSD's own Cursor support has limits: some workflows still name Claude paths.
- A failed sync is a `FAIL: ...-gsd-sync` line that names the installer's log file; read it, fix what it says, then run `sbx-init` again.
- GSD's own update notice in a session does not apply here. To upgrade GSD, change `GSD_CORE_VERSION` in `versions.env` and rebuild (see "Bump a version or add a tool").
- The GSD package brings a second Claude binary for its agent SDK under `/usr/local/lib`. It is not on `PATH` and never updates itself.

## Usage reports (ccusage)

In a sandbox shell, run `ccusage daily`, `ccusage monthly` or `ccusage session`. Add `--json` for JSON.

- It reads `CLAUDE_CONFIG_DIR`, which is this sandbox's `state/claude`, so it reports this project only.
- By default it fetches the current price table from the network when it runs. `--offline` uses the table it ships with.
- Starting the sandbox needs no network either way.

## Check a sandbox

In a sandbox shell (`sbx-shell NAME`), `sbx-selfcheck` checks that sandbox and prints one line per check.

```text
PASS: user-sandbox: uid 1000, gid 1000, name sandbox
FAIL: git-identity: user.email is not set
      fix: run sbx-gh-login in this sandbox; it asks for the name and email
...
sbx-selfcheck: 55 checks, 1 failed
```

- Each FAIL line has a `fix:` line under it. When the fix is on the host, it says so and gives the command, such as `sbx-upgrade NAME`.
- Exit status 0 means every check passed.
- It changes nothing, apart from a test file it makes and removes in `state/`.
- The base image holds the runner and the shared checks (tools and pins, the init marker, user and home, git, environment, state directory, image paths, extra root certificates), one file per concern in `/usr/local/lib/sbx-selfcheck/checks/`; the runner loads the files in name order. Adding a check is adding a file. The Claude and Cursor images add their own, one file per concern too, in `/etc/sbx/selfcheck.d/claude/` and `/etc/sbx/selfcheck.d/cursor/` (CLI version and that the agent is off the PATH, login file, GSD sync, best-practices links, image ownership). What the checks of one agent share (its agent config directory) sits in one library file per agent, `claude_shared.py` or `cursor_shared.py`, in `/usr/local/lib/sbx-selfcheck/agents/`; the launcher puts that directory on the import path, and the runner never loads it as a check. The checks that walk directories (the image ownership and protected-paths checks and the root-owned state scan) share one walker, `tree_walk.py`, and keep their rule in a hook. `sbx-init` and `sbx-selfcheck` share one module, `step_files.py`, that loads a numbered file's list, runs each entry so an error becomes a FAIL line, and prints the lines; only the words differ (`STEP_LIST` and `OK` for `sbx-init`, `CHECK_LIST` and `PASS` for `sbx-selfcheck`). The image checks walk root directories (base: `/usr/local/lib/sbx-init`, `/usr/local/lib/sbx-selfcheck`, `/etc/sbx`, `/opt/sbx/agents` and the `sbx-*` commands; Claude: `/etc/claude-code`; Cursor: `/usr/local/lib/cursor-agent`) and require root ownership, no group or other write, and an executable bit on directories, `sbx-*` commands and the two launchers (`sbx-selfcheck` and `sbx-init`), so a new file is covered with no list to update.
- A fresh sandbox fails the init marker check until you run `sbx-init`, and the login and git identity checks until you log in and run `sbx-gh-login`.
- In a container made by hand with `docker run`, the checks that need the sandbox's mounts fail and say to start it with `sbx-start`.

## Threat model

| Isolated | Not isolated |
|---|---|
| One bind mount: `$SBX_DIR` at `/home/sandbox/workspace`. No host home, no `~/.ssh`, no Docker socket. | Outbound network: normal, with no allowlist. |
| User `sandbox` (uid 1000), not root. | The tokens in `state/` (`state/claude/.credentials.json`, `state/cursor/auth.json`, `state/gh/hosts.yml` in plain text, `state/git/config`). The agent (Claude or Cursor) can read and send them out; Claude can do it without a prompt when it runs with permissions bypassed (`--dangerously-skip-permissions`). |
| All capabilities dropped (`cap_drop: ALL`) and `no-new-privileges`. | Files the agent writes in `$SBX_DIR/<name>` that a host tool later runs. |
| The registry and the tools clone whose `bin/` the host runs cannot sit inside a sandbox directory (`sbx-add` refuses). | With `SBX_CA_CERT` set, the images trust anything the proxy signs. Its operator can read and change the sandbox's HTTPS traffic, Claude API requests included, and the release downloads and checksum files that `base/Dockerfile` fetches through it. Pinned image digests still hold. |

Files the agent can plant that the host runs:

- `.git/hooks/*`, and the git config keys `core.fsmonitor`, `core.pager`, `diff.external`, `credential.helper` and `core.sshCommand`.
- IDE run configurations and tasks: `.idea/`, `.vscode/tasks.json`, `.vscode/launch.json`.
- Build files and scripts you run on the host: `Makefile`, `package.json` scripts, `.mvn/`, `.envrc`.

Rules. They hold whatever the timing: an agent working while host-side git or an IDE runs can plant any of these at any moment.

- Run git inside the sandbox (`sbx-shell`) and review changes on GitHub.
- Treat host-side git, IDE git integration and IDE run configurations on `$SBX_DIR/<name>` as running agent code.
- Open only `$SBX_DIR/<name>` in an IDE, never `state/`.
- Give `sbx-gh-login` a fine-grained token limited to the repos the sandbox needs.
- The best-practices trade and the limit of the Edit protection are in "Best-practices clone".

## Verify a new build

Run `./host-test.sh` on the host after building, or after a change under `base/`, `claude/`, `cursor/`, `compose.yml` or `sbx/`. It runs the pytest suites `tests/unit/sbx`, `tests/integration` and `tests/guard` through uv, and writes everything to `host-test.log` as it comes. It uses two test sandboxes, `hosttest-claude` and `hosttest-cursor` (containers `sbx-hosttest-claude` and `sbx-hosttest-cursor`), and builds and checks its own images, `sbx-base:test`, `sbx-claude:test` and `sbx-cursor:test`, so it never replaces the `:local` images your sandboxes run. They stay after the run, so the next run reuses their build cache.

Each integration scenario runs once for Claude and once for Cursor. A scenario stops at its first failed step and the report names that step.

| Question | Proven by | Run |
|---|---|---|
| Login survives a rebuild | The persistence scenario: a planted fake credentials file, session file, memory, history line, cache files and project file survive one `sbx-upgrade`, and no volume exists | `./host-test.sh` |
| A failed upgrade changes nothing | The failed upgrade scenario: a bogus build option fails and the container stays the same | `./host-test.sh` |
| Versions match the pins | The images match versions.env scenario (the image's `versions.env` equals the repo's), the init and selfcheck scenario (`sbx-selfcheck` compares every tool and the tool versions line with `versions.env`), and the pin digests test (every digest pin still resolves in its registry) | `./host-test.sh` |
| The home is not hidden | The init and selfcheck scenario (`.bashrc` and `.local` in `/home/sandbox`, and every tool resolves into the image, not under `/home`) | `./host-test.sh` |
| An extra root certificate is trusted | The init and selfcheck scenario (`sbx-selfcheck` compares the fingerprint `build.sh` recorded for a throwaway root with the system store and Java `cacerts`, and fails when a check says no root was requested) | `./host-test.sh` |
| A bypassed guard is refused | The refusal scenarios: plain `docker compose` with a missing sandbox directory, and with an uppercase name | `./host-test.sh` |
| Works behind a company proxy | The checklist in "Behind a company HTTPS proxy", by hand | Set `SBX_CA_CERT`, run `sbx-upgrade NAME`, then the checklist in a sandbox shell |

- The integration scenarios also cover add, start, stop, shell, list and rm, git on a repository made on the host, isolation of the running container, the first run with the clone and the relink after a pull, and `sbx-init` giving root-owned state back. The suites and the scenario rule are in [`tests/README.md`](tests/README.md).
- A Cursor login and prompt are still checked by hand: add a Cursor sandbox, log in, send one prompt, then run `sbx-upgrade` and check the login is still there. How to read `host-test.log` is in [`tests/host-checklist.md`](tests/host-checklist.md).
- `./host-test.sh` makes a throwaway root certificate once, keeps it in `$TMPDIR/sbx-test-root-ca/` with its key deleted, and reuses it, so the test images keep their build cache. With your own `SBX_CA_CERT` set, the test images trust both roots.
- `--keep` leaves the test sandboxes and the run directory after the run, to look around after a failure.

## Free disk space

Rebuilds and host-test runs pile up images, build cache and run directories. From the repo root:

```bash
./clean.sh          # shows disk use, containers, host-test run directories and images; removes nothing
./clean.sh --yes    # removes them
```

- Removed: the test containers `sbx-hosttest-claude` and `sbx-hosttest-cursor` (and an older `sbx-hosttest`) that mount a host-test run directory, with their networks; every host-test run directory (`sbx-hosttest-*` in the macOS temp directory); the test root certificate directory `$TMPDIR/sbx-test-root-ca` (the next run makes it again) and the older `sbx-hosttest-root-ca`; the Docker build cache; and every image no container uses.
- Kept: every other container, running or stopped, the images those containers use, all volumes, and every sandbox directory and its `state/`.
- `sbx-base`, `sbx-claude` and `sbx-cursor` go too when no container uses them, under both tags, `:local` and `:test`. `./build.sh` rebuilds the `:local` ones and `./host-test.sh` the `:test` ones; the first build after a clean takes a few minutes.
- A build that fails with `No space left on device` usually means the Docker Desktop disk is full: run `./clean.sh --yes`, or raise the disk limit in Docker Desktop, Settings, Resources.

## Safety checks

The container checks nothing when it starts: it only keeps running, and `sbx-init` is the first thing that runs in it. The checks sit before it and after it:

- Before `up`, `sbx-start` and `sbx-upgrade` check the sandbox name and that the project directory and `state/` exist, and stop with the path. The registered path is absolute: Compose reads a relative one from the tools clone and does not expand `~`.
- Compose refuses a missing mount directory (`create_host_path: false`), so your work cannot land in the container's own layer.
- After `sbx-init`, `sbx-selfcheck` checks the mount, the directories, the owners and the tools (see "Check a sandbox").
- A hand-typed `docker run` gives a throwaway container with no mount. Its `sbx-selfcheck` FAILs on the mount, and anything written there is lost on recreate.

A name with an uppercase letter, `MyProject`, is refused by `docker compose up`, because the image name of the `name-check` service must be lowercase. Nothing is created or replaced.

Compose turns the project name into lowercase, and only `up` checks the name. Use the exact lowercase name with `down`, `ps` and `logs`.

With the raw Compose commands, some Compose versions ignore the "do not create a missing directory" setting (docker/compose issue 13602), so a mistyped `SBX_DIR` could get an empty directory on the host. `sbx-selfcheck` FAILs in such a container, because its project directory is missing.

## Raw Docker commands

What the commands run, from the repo root:

```bash
SBX_NAME=demo SBX_DIR=/Users/you/sbx-demo docker compose --env-file /dev/null -p sbx-demo -f compose.yml up -d --wait
SBX_NAME=demo SBX_DIR=/Users/you/sbx-demo docker compose --env-file /dev/null -p sbx-demo -f compose.yml stop
SBX_NAME=demo SBX_DIR=/Users/you/sbx-demo docker compose --env-file /dev/null -p sbx-demo -f compose.yml down
docker exec -it -w /home/sandbox/workspace/demo sbx-demo bash
docker ps -a --filter label=sbx.name --format '{{.Names}} {{.State}}'
docker stop sbx-demo
docker rm sbx-demo
```

- `down` is what `sbx-rm` runs, never with an option that removes volumes or images. `docker stop` and `docker rm` are what `sbx-rm --unregister` runs for a broken entry, by the exact container name and never with `-v` or `-f`.
- `docker exec` is what `sbx-shell` runs. `-w` starts the shell in your project directory; without it a shell starts in `/home/sandbox/workspace`. `docker ps` is what `sbx-list` reads.
- A raw `docker compose` starts the Claude image unless `SBX_AGENT=cursor` is set next to `SBX_NAME` and `SBX_DIR`. It uses the `:local` tag unless `SBX_IMAGE_TAG=test` is set too.
- `up` returns once the container runs. Open a shell with the `docker exec` line above, then run `sbx-init`.

### Image-only smoke tests

To check an image on its own, run its agent by full path; the agents are off the PATH:

```bash
docker run --rm sbx-claude:local /opt/sbx/agents/bin/claude --version
```

## Troubleshooting and known limits

| Symptom | Fix |
|---|---|
| `sbx-selfcheck` prints a FAIL line | Do what its `fix:` line says. A `load-...` line means a checks file in the image is broken or missing; rebuild with `sbx-upgrade NAME`. |
| `sbx-claude: sbx-init has not passed in this container` (or `sbx-cursor: ...`) | Run `sbx-init`. |
| `command not found: claude` or `cursor-agent` | The agents are off the PATH. Start them with `sbx-claude` or `sbx-cursor`. |
| `FAIL: lock: another sbx-init is running` | Wait for that run to finish, then run `sbx-init` again. |
| `FAIL: claude-best-practices-links: ... is not a link into the best-practices clone` (or `cursor-...`) | A directory or file of yours has the name of a clone skill, or `rules` is a real directory. It was left as it is. Rename or move that path, then run `sbx-init` again. |
| `FAIL: claude-gsd-sync:` (or `cursor-gsd-sync:`) | Read the log file the line names, fix what it says, then run `sbx-init` again. A hand edit of a GSD file is kept in `state/claude/gsd-local-patches/`. |
| `FAIL: claude-best-practices-links: no best-practices clone at ...` (or `cursor-...`) | Run `sbx-gh-login`, then `sbx-best-practices-clone`; it clones the repo and runs `sbx-init` again. |
| `FAIL: claude-best-practices-links: ... exists but has no rules/ directory` (or `skills/`, or `cursor-...`) | Check that the directory is a clone of the best-practices repo. If it is, run `git -C` on it with `pull`, then `sbx-init`. If not, move it aside, then run `sbx-gh-login` and `sbx-best-practices-clone`. |
| `FAIL: state-owner:` | Run the host command of its `fix:` line, then run `sbx-init` again. |
| Claude hangs at start after an unclean stop | Check no claude is running (`docker exec sbx-demo pgrep -a claude` prints nothing), then delete `$SBX_DIR/state/claude/.claude.json.lock`. Everything else in `state/claude` is safe on the host. |
| Console keyless sign-in is lost on recreate | It is stored outside `CLAUDE_CONFIG_DIR`. Log in with a claude.ai account instead. |
| A check fails only because of the capability drop | Remove the `cap_drop` block from `compose.yml`, keep `no-new-privileges`, and report it. |
| "Mounts denied" or "path is not shared" | Add the parent of `SBX_DIR` in Docker Desktop, Settings, Resources, File sharing. |
| `sbx-...: NAME is not registered` | Run `sbx-add NAME HOST_PATH`. |
| `sbx-claude:local is not built` or `sbx-cursor:local is not built` | Run `sbx-upgrade NAME`. |
| A script is executable in the sandbox but not on the host, or git shows mode changes on one side | On a macOS host, Docker Desktop keeps the mode the sandbox sees in the attribute `user.containers.override_stat` of the host file; a `chmod` in the sandbox changes only that. Run `sbx-fix-modes NAME` on the host. |
| `the input device is not a TTY` or `stdin is not a terminal` from `sbx-shell` | Run it in a terminal, not through a pipe or a script. The sandbox has already started. |
| `broken entry` in `sbx-list` | `sbx-start NAME` prints what is wrong with the entry. Fix the file, or run `sbx-rm NAME --unregister` and then `sbx-add` again. |
| `sbx-NAME is running and there is no terminal to confirm on` from `sbx-rm` | Run it in a terminal and answer `y`, or add `--yes`. Nothing was changed. |
| `docker compose down failed for sbx-NAME; the registry entry stays` | Read the Compose output above it, then run `sbx-rm NAME` again. |
| `cannot read the containers from Docker` or `cannot reach Docker; is Docker running?` | Start Docker Desktop. |
| `the build failed; sbx-NAME was left as it was` | Read the build output above it. The sandbox still runs on the old image. |
| `curl: (60) SSL certificate problem` during the build | Behind a company proxy, set `SBX_CA_CERT` (see "Behind a company HTTPS proxy"). If it is set, run `echo "$SBX_CA_CERT"` in the shell that ran the build: a missing `export`, or another terminal, loses it. |
| `build.sh: SBX_CA_CERT ...` | The rest of the line says what is wrong with the variable or the file. It must be an absolute path to a readable PEM file. Nothing was built. |
| `UNABLE_TO_VERIFY_LEAF_SIGNATURE` from a Node program run with `docker exec` | Run it from `sbx-shell`, or pass `-e NODE_EXTRA_CA_CERTS=/etc/sbx/extra-ca.pem` to `docker exec`. |
| `ccusage` cannot fetch its price table behind a company proxy | Add `--offline`. |
| `overlaps the registry directory`, `overlaps the tools clone` or `overlaps the directory of sandbox` | Pick a directory of its own for the sandbox. |
| `required variable SBX_DIR is missing a value` | Only the raw Compose commands read `SBX_NAME` and `SBX_DIR` from your terminal; export both, or use the `sbx-*` commands. |
| Maven fails with `java.io.IOException: Input/output error` and `Failed to delete tracking file` | Maven 3.9.12 and later cannot keep their local repository on the Docker Desktop mount of a macOS host. Keep `MAVEN_VERSION` at 3.9.11. Before raising it, run a Maven build in a sandbox on a macOS host by hand; no automatic check covers this. |
| `up` fails with `... must be lowercase` and names `sbx-<name>-name-check` | `SBX_NAME` has an uppercase letter. Use the lowercase name; see the name rule in Requirements. |
| `claude --resume` shows nothing | Sessions are keyed by directory; start it from the same directory as before. |
| A skill of yours named `gsd-...` is gone after `sbx-init` | GSD owns that prefix. Rename the skill. |
| Claude refuses to edit a best-practices skill under `~/.claude/skills` | Intended. Edit it in the clone by its real path (see "Best-practices clone"). |
| `sbx-best-practices-clone` says the directory already exists | Pull it (`git -C /home/sandbox/workspace/best-practices pull`), or relink it with `sbx-init`. Move the directory away to clone fresh. |
| `sbx-best-practices-clone` says it cannot clone | Run `sbx-gh-login` first; the repo is private. |
| A skill you pulled is missing in Claude | Run `sbx-init`, then restart Claude. |
| A sandbox migrated from the old layout loads the same rules twice | Follow "After the checks" in [`MIGRATION.md`](MIGRATION.md). |
| The missing directory scenario (`tests/integration/test_refusal.py`) showed Docker creating the missing directory | Report it. An `env_file` sentinel at the root of `SBX_DIR` would make Compose itself refuse a missing directory; it is not planned while that scenario passes. |

## License

Licensed under the Mozilla Public License 2.0 (MPL-2.0). See [LICENSE](LICENSE).
