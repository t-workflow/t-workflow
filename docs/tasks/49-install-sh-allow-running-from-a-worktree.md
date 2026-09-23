# 49 — install.sh: allow running from a worktree whose HEAD equals origin/<trunk>
Issue: #49

## Asked
`install.sh` in PR mode refused any HEAD not literally on the trunk branch, though it only ever branches from `origin/<trunk>`. A detached worktree at `origin/<trunk>` — the normal state when the trunk is checked out elsewhere — was refused.

## Done when
- PR mode runs when the current branch is the trunk, or when HEAD equals `origin/<trunk>` after the fetch.
- It still refuses otherwise (e.g. a feature branch with its own commits); the clean-tree check stays.

## Explicitly not
none

## Decisions made along the way
- The fetch moved ahead of the branch check so the comparison is against the fresh `origin/<trunk>`.
- Tested with a stubbed `gh` that passes `auth status` and fails `issue create`: reaching `issue create` proves the branch check passed. Verified the new test fails against the old `install.sh`.
- README's install line now names the detached-worktree case.

## Deviations / notes
- none

## Agents
- work: claude-code / claude-opus-5-5
