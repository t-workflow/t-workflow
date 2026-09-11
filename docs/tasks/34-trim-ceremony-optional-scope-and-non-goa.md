# 34 — Trim ceremony: optional Scope and Non-goals in the issue form, CI paragraph to its rules
Issue: #34

## Asked
Two things added since v0.0.5 cost a consumer more than they return, found while reviewing the changes before a tag. First, the task issue form `.github/ISSUE_TEMPLATE/task.yml` (#14) makes all four fields required, but the pipeline runs without a declared Scope (`gate.sh work` says "scope not declared in backticks; judged from the diff later") and without Non-goals, so a person filing a small task by hand fills four boxes where two carry the decision. Goal and Done when stay required; Scope and Non-goals become optional. Second, the CI paragraph in `.t-workflow/AGENTS.md` (#13, #26) is about 180 words of rationale that every agent reads at every stage, where #13 asked for one sentence saying what the mechanical gate defends against and what it does not. The rationale already lives in the header comment of `.github/workflows/t-workflow.yml` and in `docs/decisions.md`. The paragraph is cut to the rules an agent acts on: CI reads the workflow and the gate scripts from the base branch; a PR that changes the workflow file also runs its own copy, which can add a red result but never replace the base's; the gate checks process only, and the cold review and the human-confirmed merge cover honesty and correctness; the project's build runs in the project's own CI and the ship gate watches every check. Everything about integration branches stays, in as few words as it needs.

## Done when
- In `.github/ISSUE_TEMPLATE/task.yml`, `goal` and `done-when` have `required: true`; `scope` and `non-goals` have no `required: true`.
- The CI paragraph in `.t-workflow/AGENTS.md` (from "CI reads this workflow file" to the end of the "mechanical gate" sentence) is at most 90 words and still states each of the five rules listed in the goal.
- No other paragraph of `.t-workflow/AGENTS.md` changes.
- `tests/test.sh` passes.

## Explicitly not
- Applying the `wip/*-integration` protection rule in update mode. That is an installer behaviour change with its own trace, not a trim.
- Any change to the skills' word count.
- Any change to the workflow file or its header comment; #32 owns that.

## Decisions made along the way
- The paragraph keeps five rules and one clause: gate scripts come from the base; a child of an initiative is judged by the integration branch's copy; a PR that changes the workflow file also runs its own copy, which can only add a red result; the gate checks process, the cold review and the human-confirmed merge cover honesty and correctness; the build runs in the project's own CI and the ship gate watches every check. Everything else in the old paragraph was rationale and is in the workflow file's header comment or `docs/decisions.md`.
- The form's `scope` and `non-goals` lose `required: true` and nothing else; `record.sh create` reads sections by heading and already tolerates an absent one, and `gate.sh work` says "scope not declared" and judges from the diff.

## Deviations / notes
- The first cut of the paragraph came to 107 words against the 90 the issue allows; the initiative sentence was shortened to a clause and the em-dash asides replaced with parentheses. Final count is under 90 by `wc -w`.
- No test reads the paragraph's wording or the form's required fields, so `tests/test.sh` is unchanged.
