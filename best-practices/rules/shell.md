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
- End with a `Main / Entry Point` banner over that list of calls, so a reader sees the whole flow in one place.
- Put a helper in a shared library only when two or more scripts really use it. A helper only one script uses stays in that script.
- When a library grows large, split it into libraries by topic, for example `lib.sh` for general helpers and `lib-bundle.sh` for bundle checks.
