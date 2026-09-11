---
name: t-cancel
description: Cancel a task that will not be done — record why on the issue, decide every dependent and child, close its PR, delete its branch. The pipeline's terminal exit. Use to cancel, abandon, or drop a task.
---

# Cancel a task

Read `.t-workflow/AGENTS.md`. Cancellation is a stage: the reason and every
neighbour's disposition land on the issue before anything is destroyed.

1. Read the issue (`.t-workflow/scripts/issue.sh view <id>`), what it blocks
   (`issue.sh blocking <id>`), its children (`issue.sh children <id>`), and any issue
   whose body ends `Split from: #<id>` (`gh issue list --search "Split from: #<id>"`).
2. For each neighbour, ask one question with options `proceed` (remove the
   dependency: `gh issue edit <n> --remove-blocked-by <id>`), `cancel too` (run this
   skill on it), or `leave` (it stays blocked by a cancelled issue and shows as such).
   A cancelled blocker is abandoned, never satisfied.
3. Comment the reason and every decision on the issue (`gh issue comment <id>`), then
   `gh issue close <id> --reason "not planned"`.
4. Close the PR if one exists (`gh pr close <pr> --delete-branch`); otherwise delete
   the remote branch (`git push origin --delete wip/<id>-<slug>`). Leave local
   branches and worktrees alone. A parent: its integration PR closes and
   `wip/<id>-integration` is deleted the same way.
5. A child already merged into its parent's integration branch (its PR is merged, its
   record is on `wip/<parent>-integration`) is reverted there, so the initiative stays
   consistent without it: branch `wip/<id>-revert` from `origin/wip/<parent>-integration`,
   `git revert` the child's squash commit, restore the record with a line under
   Deviations saying it was cancelled and reverted, push, and open a PR against the
   integration branch titled `[<id>] Revert: <title>`. It merges on the mechanical
   gate: mark it ready, `gh pr checks --watch`, `gh pr merge --squash`. A protected
   revert needs a cold review first — stop and name `/t-review <id>`, then
   `/t-cancel <id>` again to merge it.
6. Report what was cancelled, each neighbour's disposition, and what was deleted.
