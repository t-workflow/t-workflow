# 30 — Review rates findings by pipeline outcome and verifies external-service claims live; #26 record notes the verified branch creation
Issue: #30

## Asked
Two findings in the cold reviews of #26 and #28 reached the merge question with a severity below what they did to the pipeline, and one fix that passed every test was wrong until a reviewer checked it against GitHub's real API. `/t-review`'s severity rule is a list of categories — a failed check, an unauthorized removal, a path outside scope, a protected path without a plan — so a defect that matches none of them, such as a skill sentence that sends a second `/t-cancel` to close the revert PR it came to merge, was rated Medium although it left an initiative unable to ship. And where a script's correctness depends on what an external service accepts, a stub test cannot prove it; the reviewer had to make a read-only call to find that a missing non-null GraphQL variable is rejected. The review skill rates every finding by its outcome in the pipeline, and verifies claims about an external service with a read-only call when one can settle it. Separately, the record of #26 says the branch-creation risk under the pattern rule was unverified; it was verified on 2026-09-10 (a matching branch is created without refusal; a direct push is refused for non-admins and bypassed by admins, as on the trunk) and the record says so.

## Done when
- `.claude/skills/t-review/SKILL.md` step 4 says that a finding is rated by what it does in the pipeline — a task or initiative that can no longer reach the trunk, a merge that should not happen, or a gate silently skipped is high wherever it lives, a skill sentence included — with the existing category list kept as examples.
- `.claude/skills/t-review/SKILL.md` step 3 says that a claim about what an external service accepts (an API's request shape, a permission, a branch rule) is verified with a read-only call when one can settle it, never taken from the tests' stubs.
- `docs/tasks/26-initiative-children-land-on-an-integrati.md` Deviations says the branch-creation risk was verified and what was found, replacing the sentence that it could not be.
- The two additions to the skill total at most six lines; `tests/test.sh` passes.

## Explicitly not
- A change to `/t-drive`'s single fix pass: rating by outcome is what makes it trigger.
- Any new mechanical check; the judgement stays the reviewer's.

## Decisions made along the way
- The outcome sentence leads step 4 and the old category list follows it as the never-lower floor, so a reviewer reads the test before the examples.
- The read-only-call sentence sits in step 3 with the other "never reuse" rules, naming the three kinds of claim it covers so it is not read as licence to write.
- Five lines added to the skill in total (69 → 74).

## Deviations / notes
- Fix pass after the cold review, its Low wording notes 1, 4, and 5 taken: the category list now follows the outcome test as "So, never lower than high:", "when one can" has its object, and the #26 record says "recorded by #30". Its note 2 (nothing separates blocker from high) predates this task and is proposed as its own issue; note 3 is the line the human check covers and stays.
