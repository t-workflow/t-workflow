# 1 — Give the test fixtures a git identity so tests pass on CI
Issue: #1

## Asked
`tests/test.sh` fails on a CI runner because its fixture commits have no git identity: every `git commit` inside a temporary repository is refused, so the install, trunk, and CI-script tests all fail. Locally it passes only because the developer's global git config supplies a name and email. The tests should carry their own identity so they pass anywhere.

## Done when
- `GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null tests/test.sh` exits 0.
- The `tests` workflow is green on this PR.

## Explicitly not
- Changing what the tests cover.

## Decisions made along the way
- none

## Deviations / notes
- none
