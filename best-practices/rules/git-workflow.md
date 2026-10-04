<!-- Source: best-practices/ in the GetShitDoneContainer repo. Each sandbox gets a fresh copy of this file at every container start, so edits to a copy are lost; change the source, then rebuild the image and restart. -->

# Git workflow

These rules cover every change an agent makes. If a project file states a conflicting rule, the stricter rule wins.

## Branch-and-PR protocol: ALWAYS

This is the process for **every** change, with no exceptions:

1. **Identify the target branch**: the branch the change will be merged into (for example `main`, or an integration branch for phased work). This is the PR *base*.
2. **Update the target branch first.** Make sure your local copy of the target is current with its remote (`git fetch` + fast-forward, or branch off `origin/<target>` directly). Never branch off a stale target.
3. **Create a new branch FROM the updated target branch.** Naming: `fix/<desc>` for bug fixes, `feat/<desc>` for features, `chore/<desc>` otherwise.
4. **Make all changes on that new branch.** Commit there. Never commit work directly onto the target or integration branch.
5. **Open a PR from the new branch against the target branch** it was cut from (`gh pr create --base <target> --head <new-branch>`). The base MUST be the same branch you branched from in step 3.
6. **The human merges the PR** from the GitHub UI after review. Agents never merge (`gh pr merge` and equivalents are forbidden).

Why: the target branch always stays clean and equal to its remote, so it is reviewable and reversible at any time; every change arrives as an isolated, reviewable PR against the exact branch it targets.

### Corollary: keep integration branches clean

If work has accidentally landed directly on the target or integration branch, fix it before doing anything else:

1. Move those commits onto a proper feature branch (cherry-pick onto a branch cut from the clean remote tip).
2. Hard-reset the integration branch back to match its remote.
3. Preserve unrelated working-tree edits (stash them across the reset).

## Push and merge gates

- **`git push` requires explicit human approval every time.** State exactly which branch you are about to push and wait for the go. Never infer push permission from a commit or PR instruction.
- **Never push to `main`** (or `master`), with no exceptions.
- **Never merge a PR programmatically.** The human does every merge from the GitHub UI, after a final look at the code review. Do not run `gh pr merge`, even when told "let's merge this". Prepare the PR (commits, pushes once approved, comment replies, review-ready state) and stop.
- `git add` and `git commit` on a feature branch are fine without asking. Write a clear conventional message with no AI attribution. The user may amend or squash.
- Do not `git add -A` when untracked scratch or build dirs are present; stage explicit paths.
- Do not start coding unprompted. Unless you are executing an already-agreed plan, propose the approach and wait for an explicit go, especially for big changes. A one-line fix that was just asked for is fine; anything with design choices needs the round trip.

## PR review comments

- Always pass `--paginate` to `gh api` when fetching `pulls/{n}/comments` and `pulls/{n}/reviews`. Without it only the first page (about 30 items) comes back and newer comments are silently dropped.
- Reconcile the full set: group by `in_reply_to_id` and take the latest comment per thread. Never time-filter a first page when the thread count may exceed 30.

Why: a missed second page leads to telling the user "no new comments" when there are some, which erodes trust.

## GSD workflow

- Phase work runs through the GSD skills (`/gsd-execute-phase`, etc.). The `.planning/` tree is the working surface.
- Internal phase and decision IDs must not leak into committed source, fixtures, or READMEs.
- `/gsd-ship` and `/gsd-pr-branch` do not cleanly handle a non-default target branch. For phased work that targets an integration branch, push (with approval) and open the PR by hand with `gh pr create --base <target>`.
