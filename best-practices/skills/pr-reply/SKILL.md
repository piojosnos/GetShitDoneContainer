---
name: pr-reply
description: Read the current pull request's inline review comments, investigate the code behind each, and post a proposed-approach reply threaded under each comment. Propose only; do NOT change code until the user approves. On approval, apply approved fixes as atomic commits. Use when the user says something like "read/answer the PR comments", "reply to each review comment", "triage the PR feedback", or points at a PR's review comments.
---
<!-- Source: best-practices/ in the GetShitDoneContainer repo. Each sandbox gets a fresh copy of this file at every container start, so edits to a copy are lost; change the source, then rebuild the image and restart. -->

# PR review-comment reply workflow

A two-phase loop: PROPOSE (reply to every comment with an approach, change nothing),
then APPLY (only after the user green-lights specific comments).

## Phase 1: Propose (default; never edits code)

1. Resolve the PR for the current branch:
   ```bash
   gh pr view --json number,headRefName,baseRefName,url
   ```
   If no PR is found, ask the user for the PR number.

2. Fetch every inline review comment (threaded, on-diff):
   ```bash
   gh api repos/{owner}/{repo}/pulls/{n}/comments \
     --jq '.[] | {id, path, line, user: .user.login, body, in_reply_to_id}'
   ```
   Also check issue-level PR comments and review bodies if relevant:
   ```bash
   gh api repos/{owner}/{repo}/issues/{n}/comments --jq '.[] | {id, user: .user.login, body}'
   gh api repos/{owner}/{repo}/pulls/{n}/reviews     --jq '.[] | {id, user: .user.login, state, body}'
   ```
   Skip comments that already have your reply as the latest in the thread (match on
   `in_reply_to_id` chains) so a re-run does not double-post.

3. For EACH comment, investigate the referenced code before replying:
   - Read the file at `path` around `line`.
   - For "why was this deleted / where did it move" questions, use
     `git diff {baseRef}..HEAD -- {path}` and grep for the moved symbol's new home
     so the answer is grounded, not guessed.
   - Verify factual claims (unused import? regression? global selector?) against the
     actual tree.

4. Post a threaded reply under each comment. Prefer the canonical replies endpoint:
   ```bash
   gh api -X POST repos/{owner}/{repo}/pulls/{n}/comments/{comment_id}/replies \
     -F body=@reply-body.txt --jq '.html_url'
   ```
   Each reply states a concrete proposed approach or fix (with a recommendation and,
   where relevant, options + trade-offs). Keep it concise. Do NOT edit any file in
   this phase.

5. After posting, summarize per-comment in a table and explicitly flag which comments
   need a DECISION (not just yes/no) vs which are a simple approve-to-apply. Then STOP
   and wait for the user.

## Phase 1b: Follow-up rounds (the user replied in the PR)

The conversation continues in the PR threads, not only in chat. Each time the user
says they have responded on the PR, re-fetch and reconcile before doing anything:

1. Re-fetch all comments (step 2) and group them into threads by `in_reply_to_id`
   (the root comment id chains the whole thread). For each thread, look at the LAST
   comment and who wrote it.
2. Classify every thread by its latest state:
   - **New top-level comment** (root, no reply from you yet): investigate + reply,
     same as Phase 1.
   - **Still open**: the user asked a further question or pushed back on your
     proposal. Reply again with a refined answer or option; keep looping until the
     thread is settled.
   - **Approved**: the user said go/do-it. Add the concrete fix to the apply-list.
   - **No-op / resolved**: the user said "just understanding" / "no change" /
     "resolving". Record as no-op; do not reply again (a needless reply reopens a
     thread the user just closed).
   - **Decision captured**: the user chose an option or asked for a planning/backlog
     note. Record it as an action (often a `.planning` edit, not PR code).
3. Never double-post: skip any thread whose latest comment is already your reply with
   no newer user response.
4. When NO thread is still open (every one is approved, no-op, or a captured action),
   stop replying and post a single consolidated summary in chat: the code fixes to
   apply, the planning/backlog actions, and the no-ops, then ask for ONE final
   approval before touching code. Flag any interactions between fixes (e.g. two fixes
   touching the same selector/specificity) so nothing regresses.

## Phase 2: Apply (only after explicit approval)

6. Apply only the fixes the user approved. One atomic commit per comment/fix, message
   referencing what it addresses, EXCEPT: when several approved comments land on the
   same file and pull in the same direction (e.g. four "simplify this doc" notes on one
   .md), handle them as ONE focused pass (a single coherent rewrite and one commit)
   rather than N scattered edits. It reads consistently, produces one diff to review,
   and avoids re-touching the same file repeatedly. Verify behavior-preserving changes
   actually preserve behavior (e.g. regenerate output and diff, or run the build/tests)
   before moving on.
   Follow the repo's CLAUDE.md conventions and branch protocol (feature branch; push
   only on explicit per-branch go; never merge the PR).

7. Push only after the user's explicit per-branch go. Commit refs are not meaningful on
   the PR until pushed, so do NOT post "done" replies referencing a commit before the
   push lands.

8. After pushing, close the loop on GitHub: post a short reply under each ADDRESSED
   thread (fixes and captured planning notes) stating it is done and linking the
   concrete artifact: the commit sha for a code fix, or the roadmap/backlog location
   for a planning note. When one batched commit closes several threads (step 6), post a
   done-reply on EVERY thread it addressed, not just one; a reviewer reading any one
   thread should see its own closure. Skip threads the user already marked no-op or
   resolved (a needless reply reopens them). Leave any un-approved comments untouched.

9. Report back in chat: what landed (per commit), what was deferred/logged, and the
   push/PR state. If a fix touched something risky (rendering, data), offer the user a
   visual or functional gut-check and be willing to hold.

## Conventions

- Never `git add -A` when untracked scratch dirs exist; stage explicit paths.
- Ground every "it moved / it's unused / it's safe" claim in a grep or diff first.
- Propose, do not assume consent: approval for one comment is not approval for the rest.
- **Pending-review block.** If posting a reply fails with `422 ... one pending review
  per pull request`, the user has an unsubmitted review open in the GitHub UI holding
  draft comments, and it blocks the replies endpoint. Do NOT retry-loop. Inspect it
  (`gh api .../pulls/{n}/reviews` for `state=="PENDING"`, then its `/comments`), then
  surface it: offer to submit it as a plain COMMENT-type review or ask the user to
  submit/discard it in the UI. NEVER discard a pending review unilaterally; it may
  hold the user's draft comments.
- **Take the latest instruction.** A later comment can reverse an earlier approval
  (e.g. "add a TODO" then, seeing it, "that is noise, put it elsewhere"). Honor the
  most recent; do not cite the earlier approval to keep the change.
- **Push back honestly on design questions.** When the user invokes a principle and
  asks you to explain or push back, evaluate the real constraint in the code rather
  than defending existing docs; if the doc overstates the reason, say so.
