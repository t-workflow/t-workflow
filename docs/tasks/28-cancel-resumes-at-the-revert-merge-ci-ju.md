# 28 — Cancel resumes at the revert merge; CI judges a deleted record by its own issue; protect.sh guards its contexts array
Issue: #28

## Asked
Close the three findings the second cold review of #26 left open. First, `/t-cancel` on a child of an initiative that was already merged into the integration branch and whose diff is protected stops after opening the revert PR and says to run `/t-cancel <id>` again after the cold review; a second run starts at step 1, and step 4 closes the open revert PR and deletes its branch before step 5 can merge it, so the cancelled child's work stays on the integration branch and the parent can never ship. A second invocation on an issue already closed as not planned with an open `wip/<id>-revert` PR resumes at the merge step instead. Second, `ci.sh`'s acceptance of a deleted record reads the state of the PR's own issue rather than the record's issue, which only differ on a parent's PR; it reads the record's issue. Third, `protect.sh` expands the contexts array unguarded under `set -u`, unlike every other array in the script; on bash 3.2 an empty list aborts with "unbound variable" instead of sending an empty list.

## Done when
- `.claude/skills/t-cancel/SKILL.md` says, at its start or at step 5, that when the issue is already closed as not planned and an open `wip/<id>-revert` PR exists, the run resumes at the merge of that PR; steps 2 to 4 are not repeated.
- `ci.sh` judges a deleted record by the state of the issue the record belongs to; `tests/test.sh` covers a parent's PR whose diff deletes a cancelled child's record (passes) and an open child's record (fails).
- `protect.sh` uses the `${ctx[@]+"${ctx[@]}"}` idiom; `tests/test.sh` covers `--remove t-workflow` on an existing pattern rule sending an empty list without aborting.
- `tests/test.sh` passes; ShellCheck at warning severity passes.

## Explicitly not
- The unverified branch-creation risk under the pattern rule (a separate decision).
- Applying the pattern rule in update mode.

## Decisions made along the way
- The second-pass rule sits at the top of the cancel skill, before step 1, because a literal second run reaches step 4 before step 5; step 5 only points back to it.
- `ci.sh` reads the record's own issue only when the record is deleted and belongs to a different issue than the PR's (a child's on a parent's PR): one tracker read, in the one case where it matters. The parent loop now tells a deleted record from a present one, so a cancelled child's record deleted by the PR is judged by that child's state instead of read as "still on the branch".
- The empty contexts list is sent as an empty list, matching what the trunk's REST path already does for the same flag.

## Deviations / notes
- none

## Origin
The second cold review of #26 (PR #27) rated these Medium and Low; they were carried
through the merge and should not have been — the first one leaves an initiative
unshippable after cancelling a protected child that had already landed.
