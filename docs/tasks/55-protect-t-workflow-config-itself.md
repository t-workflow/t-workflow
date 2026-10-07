# 55 — Protect .t-workflow/config itself
Issue: #55 · Part of: #54

## Asked
`.t-workflow/config` decides which changes need a plan and a cold review (`protected`), which branches skip the task gates (`exempt`), and which files count as documentation (`docs`). The config is not itself in the built-in protected set (`BUILTIN` in `.t-workflow/scripts/protected.sh`). So a PR can empty `protected=` or widen `exempt=` and in the same diff switch off the plan and review that would have examined it. Add `.t-workflow/config` to the built-in protected set, so any change to these settings is itself planned and cold-reviewed.

## Done when
- `.t-workflow/scripts/protected.sh .t-workflow/config` exits 0 and echoes the path in a repo whose `protected=` is empty.
- `.t-workflow/scripts/protected.sh --list` includes `.t-workflow/config`.
- `.t-workflow/AGENTS.md` §Protected paths lists `.t-workflow/config`.
- `tests/test.sh` covers both cases above; the existing suite stays green.
- `docs/decisions.md` records why.
- Compatibility: after `/t-update`, nothing changes for an existing project except that its next config edit needs a plan and review. The update PR itself already touches protected paths, so it is unaffected.

## Explicitly not
- Changing what any other setting does.

## Decisions made along the way
- The AGENTS.md list says why the config is protected in one clause, so a reader does not take it for a slip.

## Deviations / notes
- Run with no child PR, by the human's choice for initiative #54: committed straight onto `wip/54-integration`; the cold review runs once, on #54's combined diff.

## Agents
- plan: claude-code 2.1.292 / claude-opus-5-5
- work: claude-code 2.1.292 / claude-opus-5-5
