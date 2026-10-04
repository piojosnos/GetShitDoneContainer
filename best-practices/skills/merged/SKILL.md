---
name: merged
description: Sync local git state after a PR was merged on GitHub. Switches to the branch the PR merged INTO (the base), pulls it fast-forward, deletes the now-stale feature branch (direct command, no extra prompt), then shows the roadmap position and tells the user what phase is next. Use when the user says "/merged", "I merged the PR", "the PR landed", "sync after merge", or otherwise signals a merge just happened on the remote.
---
<!-- Source: best-practices/ in the GetShitDoneContainer repo. Each sandbox gets a fresh copy of this file at every container start, so edits to a copy are lost; change the source, then rebuild the image and restart. -->

# Post-merge sync workflow

The user merges every PR themselves from the GitHub UI. This skill runs right after
that merge to bring the local checkout back in step and orient the user for the next
piece of work. It changes branches and pulls; it never merges, pushes, or edits code.

## Arguments

- `/merged`: auto-detect the target branch from the current branch's merged PR.
- `/merged <target-branch>`: skip detection; sync the named base branch directly.

## Step 1: Resolve the target branch (the branch the PR merged INTO)

The "target" is the PR's base, not the feature branch that was merged.

1. If an argument was given, use it as `TARGET` and skip detection.
2. Otherwise detect from the current branch's PR:
   ```bash
   gh pr view --json number,state,baseRefName,headRefName,mergedAt,url
   ```
   - If `state` is `MERGED`: `TARGET = baseRefName`. Report the PR number and title.
   - If `state` is `OPEN`: STOP. Tell the user the PR for this branch is not merged
     yet; ask whether they merged a different PR (then re-run as `/merged <target>`).
   - If no PR is found for the current branch: ask the user for the target branch
     name; do not guess.

## Step 2: Guard the working tree before switching

```bash
git status --porcelain
```

- If there are tracked uncommitted changes, STOP and show them. Ask the user whether
  to stash (`git stash push -u`) or abort. Never discard changes silently.
- Untracked scratch (e.g. local demo/build output dirs, stray `*.png`) is fine to leave in place;
  a branch switch keeps it. Do not `git add`/stash it.

## Step 3: Switch and fast-forward

```bash
git fetch --quiet origin
git checkout "$TARGET"
git pull --ff-only origin "$TARGET"
```

- If `--ff-only` fails, the local `$TARGET` has diverged. Do NOT force. Report the
  divergence and stop so the user can reconcile.
- Confirm the new tip:
  ```bash
  git log --oneline -1
  ```

## Step 4: Delete the stale feature branch

The merged feature branch (`headRefName` from Step 1) is now redundant locally.

```bash
git branch --merged "$TARGET" | grep -F "$FEATURE_BRANCH"
```

- Once the PR is confirmed `MERGED` (Step 1), the local feature branch is safe to
  remove: its content is preserved in `$TARGET`, so a delete is reversible and loses
  nothing. Squash/rebase merges may NOT show up under `git branch --merged`; rely on
  the Step 1 `MERGED` state as the source of truth, not that grep.
- **Run the delete directly; do NOT ask a prose y/n question first.** Just issue
  `git branch -D "$FEATURE_BRANCH"`. The user approves (or declines) it inline via the
  tool permission prompt, which is the whole confirmation. A separate "Delete the
  branch? (y/n)" turn that forces the user to type "yes, delete it" is exactly the
  friction to avoid; the command-approval prompt already IS the yes/no. If the user
  declines the prompt, leave the branch and move on.
- Never delete the remote branch; GitHub handles that on merge.

## Step 5: Show the roadmap and say what's next

Load the current roadmap position:

```bash
node "$HOME/.claude/gsd-core/bin/gsd-tools.cjs" query progress 2>/dev/null
```

If that query is unavailable, fall back to the roadmap file directly.

### 5a: Gather the remaining (incomplete) phases with descriptions

Read `.planning/ROADMAP.md` and pull every incomplete phase from the checklist
(lines starting `- [ ] **Phase ...`). Each entry's description text follows the bold
title on the same and wrapped continuation lines, up to the next blank line:

```bash
grep -nE '^- \[ \] \*\*Phase ' .planning/ROADMAP.md
```

For each hit, read the full multi-line entry (the title line plus its wrapped
continuation lines until the blank line) so you have the real description, not just
the truncated first line. The FIRST incomplete entry is "Next up"; the rest are the
remaining backlog. Also check whether each has a phase directory
(`ls -d .planning/phases/*<number>* 2>/dev/null`) to label its state:
- no dir -> `not planned`
- dir exists, no `*-SUMMARY.md` -> `planned`
- dir exists with some summaries -> `in progress`

### 5b: Present the summary

Keep the header and "next" recommendation tight, then render the full remaining-phase
table so the user sees the whole road ahead, not just the next step:

```
## Merged: <PR title> (#<n>) -> <target-branch>

Local <target-branch> synced to <short-sha> <subject>.

### Just landed
Phase <X>: <name>

### What's next
<one recommended command, matched to the NEXT phase's state:>
- not planned yet -> /gsd-discuss-phase <Y>   (or /gsd-plan-phase <Y>)
- planned         -> /gsd-execute-phase <Y>
- mid-phase       -> /gsd-resume-work

### Remaining phases
| Phase | Name | What it does | State |
|-------|------|--------------|-------|
| <Y>   | <name> | <1-2 line description from ROADMAP> | not planned (next) |
| ...   | ...    | ...                                 | not planned |
```

Rules:
- Include EVERY incomplete phase in the current milestone, in roadmap order, each with
  a real one-to-two-line description drawn from ROADMAP (not just the title).
- If the arc is large, group the table by sub-arc (e.g. an `N.1.x` cleanup block and an
  `N.2+` feature block) with a subheading per group; keep descriptions concise.
- Recommend exactly ONE command (for the next phase); do not list every GSD command.
- Do not start the next phase automatically; the user decides.
