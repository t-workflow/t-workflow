# 15 — issue.sh children and blocking read GitHub's nodes wrapper as a plain list and fail
Issue: #15

## Asked
`issue.sh children <id>` fails on every parent issue: GitHub returns sub-issues wrapped in a `nodes` object, and the script reads them as a plain list. Driving a parent issue (`/t-drive` on an initiative) and the cancel stage's children check both break on it. `issue.sh blocking <id>` has the same wrapper and passes it through unchanged, so callers see `{"nodes": [...]}` instead of the list the header promises. Found by running the scripts read-only against t-preview's Phase 2 initiative.

## Done when
- `issue.sh children <id>` prints `[{number,title,state}]` for a parent with sub-issues, and `[]` for an issue with none.
- `issue.sh blocking <id>` prints `[{number,title,state}]`, the same shape.
- `tests/test.sh` covers both with a stubbed `gh` returning GitHub's real shape.

## Explicitly not
- Any other command in `issue.sh`; `blockers` already uses the right shape.

## Decisions made along the way
- none

## Deviations / notes
- The stubbed `gh` in the tests applies the script's own `--jq` expression to GitHub's real JSON, so the expression is what is tested, not a copy of it.
- Verified live, read-only, against t-preview's Phase 2 parent: fourteen children returned.
