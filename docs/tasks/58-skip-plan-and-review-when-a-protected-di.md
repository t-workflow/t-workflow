# 58 — Skip plan and review when a protected diff only moves files
Issue: #58 · Part of: #54

## Asked
A diff that only moves or renames protected files, changing none of their content, needs a plan and a cold review today. Example: a consuming project moving two superseded decision records into a subfolder. There is nothing for a reviewer to judge but the move itself. Let `gate.sh` recognise a diff in which every protected path is a pure rename (git similarity 100%) and require neither for it. Low priority: worth doing only if such chores recur.

## Done when
- `gate.sh` treats a protected path changed only by a 100%-similarity rename as unprotected. Any content change, addition or deletion of a protected file still protects the diff.
- A move *into* the built-in set, or of a file within it, stays protected (moving a script can change what runs).
- Compatibility: no config change. After `/t-update`, the only difference for an existing project is that pure moves of its own protected files skip the plan and review.
- `tests/test.sh` covers a pure rename, a rename plus edit, and a rename within the built-in set.
- `docs/decisions.md` records why.

## Explicitly not
- Exempting any change to file content, however small.

## Decisions made along the way
- `protected.sh --status` reads `git diff --name-status -M`, so the built-in set stays defined in one place and the gate, CI, and `/t-work` ask the same question.
- A pure move out of the built-in set stays protected, like a move into or within it.

## Deviations / notes
- No child PR, by the human's choice for initiative #54: committed straight onto `wip/54-integration`; the cold review runs once, on #54's combined diff.
- `ci.sh` and `/t-work` step 5.3 are outside the issue's Scope and inside the plan's Allowed paths: without them CI and `/t-work` would still ask a pure move for a plan and review.
- Found along the way: `git diff --name-only` lists only a renamed file's new path, so an edited move out of a protected directory read as unprotected. `--status` closes this for the gates. `snapshot.sh` and `/t-review` step 3 still read the name list; worth its own issue.

## Agents
- plan: claude-code 2.1.292 / claude-opus-5-5
- work: claude-code 2.1.292 / claude-opus-5-5
