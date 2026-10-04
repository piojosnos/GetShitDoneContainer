---
paths:
  - "**/*.sh"
---
<!-- Source: best-practices/ in the GetShitDoneContainer repo. Each sandbox gets a fresh copy of this file at every container start, so edits to a copy are lost; change the source, then rebuild the image and restart. -->

# Shell scripts

Committed shell scripts run on the user's macOS (BSD tools, bash 3.2). Agents author and test them on Linux (GNU tools). GNU-only idioms pass on Linux and then break on the Mac, so keep scripts portable.

- In-place edit: `sed "s/old/new/" file > file.tmp && mv file.tmp file`, not `sed -i`. BSD sed requires a backup suffix after `-i`, so it takes the s/// script as the suffix and reads the file path as the program. If `-i` is unavoidable, `sed -i.bak` works on both.
- Avoid GNU-only options and bash 4 features in shipped scripts: `grep -P`, `readlink -f`, `date -d`, `mapfile`.
- A script that emits JSON must emit valid JSON; check it.
- When you hand shell work to another agent, tell it to keep macOS and BSD portability in mind.
