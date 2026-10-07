# 56 — Choose separately which paths need a plan and which need a cold review
Issue: #56 · Part of: #54

## Asked
Today a diff that touches a `protected` path needs both a `## Plan` on its issue and a cold review (`gate.sh`, the plan checks near the `protected.sh` calls). The two are worth different amounts. The cold review catches real defects the implementer missed: a consuming repo reports about one task in five needing a fix pass after review, including a broken API link and untested refusal paths. A plan, for an issue whose Scope already names its paths, mostly restates that Scope. A project that wants review on risky code (e.g. its database migrations) without a plan for every such change cannot say so today. Let it: `protected` keeps deciding which diffs need a cold review, and a new config key, `plan_required`, decides which need a plan.

## Done when
- `.t-workflow/config`'s default template has a `plan_required` key with a comment. It holds globs in the same syntax as `protected` and, when the key is absent or set to the literal `protected`, means "the same as `protected`".
- `gate.sh` requires a `## Plan` only where the scope or diff matches `plan_required` (plus the built-in set, which always needs both). It requires a cold review wherever it matches `protected` (plus the built-in set), as now.
- `/t-plan` and `/t-work`'s guidance and `.t-workflow/AGENTS.md` rule 4 say which setting triggers which.
- Compatibility: after `/t-update` the installer appends `plan_required` with its default. Gate behaviour on an existing project is identical (tested: a fixture config without the key gives today's verdicts).
- `tests/test.sh` covers: key absent; key `protected`; key a narrower list (a protected path outside it needs a review and no plan); the built-in set still needs both.
- `docs/decisions.md` records why.

## Explicitly not
- Protected areas described in words (a sibling task).
- Letting a project drop the cold review for the built-in set.

## Decisions made along the way
- `protected.sh --plan` answers "needs a plan", so the skills and both gates ask one script the two questions.
- `plan_required=""` means only the built-in set needs a plan; absent or `protected` means the same as `protected`.
- The installer also rewrites the old one-line `protected` comment ("needs a plan and a cold review"), which would mislead once `plan_required` is narrowed.
- `ci.sh`'s policy line now names `plan_required` among the values read from the base.

## Deviations / notes
- No child PR, by the human's choice for initiative #54: committed straight onto `wip/54-integration`; the cold review runs once, on #54's combined diff.
- `/t-drive` step 1 still says "protected scope with no plan"; it is outside this scope and the gate's BLOCKED line still names `/t-plan`. Left for #57, which touches that file.

## Agents
- plan: claude-code 2.1.292 / claude-opus-5-5
- work: claude-code 2.1.292 / claude-opus-5-5
