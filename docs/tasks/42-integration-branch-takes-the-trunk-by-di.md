# 42 — Integration branch takes the trunk by direct merge, not a squashed child PR
Issue: #42

## Asked
An initiative's integration branch (`wip/<parent>-integration`) must take the trunk by a plain merge pushed to the branch, never by a squashed child PR. Today, when the trunk moves while an initiative is open, `gate.sh ship <parent>` blocks with "the integration branch conflicts with main — it is PR-only, so merge origin/main into it through a child task". Following that instruction cannot work: the child branch carries a real merge commit, but `/t-ship` squashes the child into the integration branch, which keeps the resolved files and drops the merge parent. Git then still sees the old merge base, replays the same conflict, and the gate blocks again with the same message. Seen twice in a row on thyme-clinic #96 (child #115 / PR #116, then the gate again); resolved only by pushing `git merge -s ours origin/main` directly to the integration branch.

The fix, in three parts:

1. **Rule.** In `AGENTS.md` under Naming (the initiative paragraph): "An integration branch takes the trunk by merge, pushed to the branch directly, never through a PR; the trunk itself still moves only by a confirmed PR." Rule 3 is about the trunk and is unchanged.
2. **Step.** `/t-ship <parent>` merges `origin/<trunk>` into the integration branch before opening or gating the integration PR: `git checkout wip/<id>-integration && git merge origin/<trunk>`; a clean merge is pushed and the run continues; a conflict stops the run with the files listed and the exact commands to resolve and push, then re-run `/t-ship <parent>`. `/t-drive <parent>` inherits this because it calls `/t-ship`. This is the "merge main into the feature branch every morning" habit, done once at the end.
3. **Guard.** `gate.sh ship <child>` refuses a child PR whose branch contains trunk commits the integration branch does not (`git log origin/<integration>..origin/<child-branch>` including any commit reachable from `origin/<trunk>`), with: "this branch carries trunk commits; merge origin/<trunk> into wip/<parent>-integration directly instead of through a child". And the parent-conflict message in `gate.sh` line ~197 changes from "PR-only, through a child task" to the direct-merge commands.

## Done when
- `gate.sh ship <parent>` on an integration branch that conflicts with the trunk names `git merge origin/<trunk>` on the integration branch itself, never a child task.
- `/t-ship <parent>` performs the merge step; a test (or the skill's own dry run) shows a moved trunk being merged in and the integration PR opening clean.
- A child PR that carries trunk commits is refused by `gate.sh ship <child>` with the message above.
- `AGENTS.md` carries the rule sentence.

## Explicitly not
- Changing how ordinary tasks rebase onto the trunk.
- Changing the squash rule for the trunk or for children.

## Decisions made along the way
- The gate names the merge whenever `origin/<trunk>` is not an ancestor of the integration branch, not only when GitHub reports a conflict. `/t-drive` runs `gate.sh ship <parent>` before the review, so the merge lands first and the review is never stale on it. Same commands in the CONFLICTING message.
- The child guard counts commits in `origin/<integration>..origin/<child>` that are also in `origin/<integration>..origin/<trunk>`; a child rebased on an integration branch that already took the trunk carries none.
- `/t-drive` was edited after all: it runs the ship gate itself for a parent, so it must run the merge the gate names, or the drive would stop where `/t-ship` continues.
- The direct push relies on bypassing the `wip/*-integration` rule's required check (admin, enforcement off). A non-admin is refused; the skill reports that verbatim. Changing `protect.sh` is not in scope; noted in `docs/decisions.md`.

## Deviations / notes
- `shellcheck` is not installed here; that check runs in CI on the PR.
- Review fix (High): the named merge now checks out the integration branch fresh from origin (`git checkout -B`), since the local branch is stale once children merged on GitHub; the test runs the merge from a stale local branch.
- Review fix (Medium, asked for by the human at the merge gate): that stale-branch setup was a no-op — `git branch -f` on the checked-out branch failed silently. Now `git reset --hard`, asserted, chained so a failed setup is a failed test.
- Test fixture note: the existing fixture pushes a child's record to `main` after the integration branch exists, which is exactly the "trunk moved" case; the new tests use it and then run the named merge so the older assertions still hold.

## Agents
- plan: claude-code 2.1.273 / claude-fable-5-1
- work: claude-code 2.1.273 / claude-fable-5-1
- review: claude-code 2.1.273 / claude-fable-5-1 (subagent)
- work (fix): claude-code 2.1.273 / claude-fable-5-1
- review: claude-code 2.1.273 / claude-fable-5-1 (subagent)
- work (fix): claude-code 2.1.273 / claude-fable-5-1
