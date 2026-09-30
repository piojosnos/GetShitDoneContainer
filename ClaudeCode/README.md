# Claude Code + GSD container launcher

A small Docker setup that runs the Claude Code CLI plus GSD (`@opengsd/gsd-core`)
in an Ubuntu container, with your project source bind-mounted from the Mac.

## How it works

`docker-compose.yml` bind-mounts a host folder over the container's home:

```yaml
volumes:
  - ${PROJECT_PATH}:/home/sandbox
```

So the container's `$HOME` (`/home/sandbox`) **is** the host folder you pass as
`PROJECT_PATH`. That folder holds your `.claude` config, GSD, Claude login, and
your project source.

### Why the entrypoint installs GSD (not the Dockerfile)

The bind mount covers the **entire** home at runtime. Anything the Dockerfile
bakes into `~/.claude` is therefore **invisible** -- the host folder shadows it.

So the two tools are installed in two different places, on purpose:

| Tool             | Lives in            | Installed by         | Survives the mount?                 |
|------------------|---------------------|----------------------|-------------------------------------|
| Claude Code CLI  | `/usr/local/bin`    | Dockerfile (baked)   | Yes -- outside the mount            |
| GSD              | `~/.claude`         | `docker-entrypoint.sh` (first run) | Installed INTO the live home |

The entrypoint runs as the `sandbox` user and is gated by a `.initialized`
marker file. On the first start of a fresh home it runs:

```
npx -y @opengsd/gsd-core@latest --claude --global
```

which installs GSD into `/home/sandbox/.claude`, then touches `.initialized` so
it does not run again. Delete that marker to force a reinstall.

> Security note: GSD's old distribution (`get-shit-done-cc` /
> `github.com/gsd-build`) was compromised and is no longer used. The trusted
> package is `@opengsd/gsd-core` (`github.com/open-gsd/gsd-core`). Do not
> reintroduce the old package name.

## Scripts

| Script           | Usage                                              | Does                                              |
|------------------|----------------------------------------------------|---------------------------------------------------|
| `cc-up.sh`       | `./cc-up.sh <proj> <host_path>`                    | Build (if needed) and start the container         |
| `cc-bash.sh`     | `./cc-bash.sh <proj>`                              | Open a shell in the running container             |
| `cc-down.sh`     | `./cc-down.sh <proj>`                              | Stop and remove the container                     |
| `cc-upgrade.sh`  | `./cc-upgrade.sh <proj> <host_path> [--rebuild]`  | One-command routine upgrade (see below)           |

`<proj>` is any short name (used for the container/project name).
`<host_path>` is the Mac folder to mount as the container home.

## Everyday: start working

```bash
./cc-up.sh   myproj /Users/you/path/to/project
./cc-bash.sh myproj
claude
```

You can leave the container running and just `./cc-bash.sh myproj` + `claude`
whenever you want. Your Claude login persists in the host folder between shells
and restarts.

## Upgrading

### Routine GSD upgrade (keeps your Claude login)

The common case. One command:

```bash
./cc-upgrade.sh myproj /Users/you/path/to/project
./cc-bash.sh    myproj
claude
```

Or by hand, if you prefer the explicit steps:

```bash
./cc-down.sh myproj
rm -f /Users/you/path/to/project/.initialized   # the ONLY file to delete
./cc-up.sh   myproj /Users/you/path/to/project   # entrypoint reinstalls latest GSD
./cc-bash.sh myproj
claude
```

The GSD installer upgrades in place, so you do not need to wipe
`~/.claude/get-shit-done` or the `gsd-*` skill/agent folders by hand -- removing
`.initialized` is enough to retrigger it. The first `cc-up` after this pauses
while `npx` downloads GSD; that is the reinstall step, now automatic.

### Also upgrade the Claude Code binary

The Claude binary is baked into the image, so to pick up a newer one, rebuild:

```bash
./cc-upgrade.sh myproj /Users/you/path/to/project --rebuild
```

(The `--rebuild` flag runs `docker-compose build --no-cache` before bringing the
container back up.)

### Full clean slate (also drops your Claude login)

When you want to throw everything away and start from zero:

```bash
./cc-down.sh myproj
rm -rf /Users/you/path/to/project/.claude /Users/you/path/to/project/.initialized
./cc-up.sh   myproj /Users/you/path/to/project
./cc-bash.sh myproj
claude            # you will be prompted to log in again
```

## The delete rule, summarized

| Goal                              | Delete                          | Login after  |
|-----------------------------------|---------------------------------|--------------|
| Refresh GSD                       | `.initialized`                  | preserved    |
| Refresh GSD + Claude Code binary  | `.initialized` (+ `--rebuild`)  | preserved    |
| Full clean slate                  | `.claude` + `.initialized`      | re-login     |

## Troubleshooting

- **`/gsd:*` commands missing in Claude Code.** GSD did not install into the live
  home. Confirm `~/.claude/get-shit-done` and `~/.claude/skills/gsd-*` exist
  inside the container (`./cc-bash.sh myproj`, then `ls ~/.claude`). If absent,
  `rm -f <host_path>/.initialized` and `./cc-up.sh` again, and watch the
  entrypoint log (`docker logs cc_gsd_myproj`) for the install output.
- **Skills still missing after install.** Claude Code loads skills at startup --
  restart `claude` (and reconnect with `./cc-bash.sh`) after an install.
- **`npx` fails on `cc-up`.** The first start needs network access to the npm
  registry to fetch `@opengsd/gsd-core`. Retry once connectivity is back.
