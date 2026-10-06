---
paths:
  - "**/*.sh"
---
<!-- Source: best-practices/ in the GetShitDoneContainer repo. Each sandbox gets a fresh copy of this file at every container start, so edits to a copy are lost; change the source, then rebuild the image and restart. -->

# Shell scripts

## Portability

Committed shell scripts run on the user's macOS (BSD tools, bash 3.2). Agents author and test them on Linux (GNU tools). GNU-only idioms pass on Linux and then break on the Mac, so keep scripts portable.

- In-place edit: `sed "s/old/new/" file > file.tmp && mv file.tmp file`, not `sed -i`. BSD sed requires a backup suffix after `-i`, so it takes the s/// script as the suffix and reads the file path as the program. If `-i` is unavoidable, `sed -i.bak` works on both.
- Avoid GNU-only options and bash 4 features in shipped scripts: `grep -P`, `readlink -f`, `date -d`, `mapfile`.
- A script that emits JSON must emit valid JSON; check it.
- When you hand shell work to another agent, tell it to keep macOS and BSD portability in mind.

## Script layout

- Put a banner before each logical section, stating what the section does:

  ```bash
  # --------------------------------------------------------------------------------
  # Removes the skills the last sync listed
  # --------------------------------------------------------------------------------
  ```

- Once a section does more than a few lines, move it into a function under its banner, and keep the top level a short list of calls.
- Give every function its own banner, in libraries and runners too, so every file has the same shape. In a library, the banner names the function and its arguments: `# name ARGS: what it does`.
- End with a `Main / Entry Point` banner over that list of calls, so a reader sees the whole flow in one place.

## Libraries and programs

- A file is either a library or a program, never both. A library defines variables and functions, runs nothing and sets no shell options. A program runs; nothing sources it.
- Put a helper in a shared library only when two or more scripts really use it. A helper only one script uses stays in that script.
- Before writing a helper, check the libraries for one that already does it.
- When the same command line repeats, wrap it in one function, so its flags (security flags above all) live in one place.
- When a library grows large, split it into libraries by topic, for example `lib.sh` for general helpers and `lib-bundle.sh` for bundle checks.

## Failures and exit codes

- A function that hits a failure the rest cannot recover from reports it and returns non-zero. It does not exit; the caller decides whether to stop: `step || exit 1`.
- Under `set -e`, a function called with `||` runs without `set -e`, so make it return on its own failures: `mkdir -p "$dir" || return 1`.
- Fail closed: an input the script cannot use (a hook that is not an executable file, a folder that is missing) stops it with an error. Never skip it silently.
- Exit codes: 0 for success, 1 for a failure, 2 for a usage error.

## Arguments

- Read arguments first in the Main block, the same way in every script. A script without options refuses any argument; a script with options reads them in one function with a `while`, `case` and `shift` loop. A usage error prints one `Usage:` line to stderr, and the caller exits 2.

## Refactoring

- A refactor that claims to keep behaviour proves it: capture the scripts' output (pass and failure paths) before and after, and diff them.
