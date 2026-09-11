# 35 — Check out full history in tests.yml so the test's bare clone is not shallow
Issue: #35

## Asked
The `tests` workflow's `tests/test.sh` step takes 2 to 9 minutes on the hosted runners, while the same suite runs in about 16 seconds locally. The CI log timestamps place all of that time inside the `# install.sh` section, in the four installs that use a git source (`--from file://$tmp/src.git`). `actions/checkout` fetches at depth 1, so the `git clone --bare "$ROOT"` the test makes is a shallow repository, and `install.sh`'s `git clone --filter=blob:none` from a shallow file:// source degrades: the source does not offer the filter, git falls into its lazy-fetch path and forks one fetch subprocess per missing blob, printing "filtering not recognized by server, ignoring" once per blob (3642 times, about 57 seconds per clone when reproduced against a runner-shaped checkout; 0.1 seconds against a full bare repo). The clone still exits 0 with a complete tree, so the suite passes and nothing looks wrong. Check the repository out with full history in `.github/workflows/tests.yml` (`fetch-depth: 0` on the checkout step of the `tests` job) so the bare clone the test builds is not shallow. A full checkout also makes the "changes from v9.9.10 to v9.9.2" assertion run against real history rather than a single commit.

## Done when
- `.github/workflows/tests.yml` checks out with `fetch-depth: 0` in the `tests` job.
- The `tests/test.sh` step on both matrix runners completes in under a minute on the PR's own run (currently 2 to 9 minutes).
- `tests/test.sh` still passes with every test; no test is changed or removed.

## Explicitly not
- Changing `install.sh`'s clone strategy. The filtered clone is right for the real github.com source; a shallow file:// source is a shape only this test produces.
- Changing `tests/test.sh` or the fixtures it builds.
- The `shellcheck` job's checkout, which runs no installs.

## Decisions made along the way
- Only the `tests` job's checkout gets `fetch-depth: 0`; the `shellcheck` job runs no installs and keeps the default shallow checkout.
- The reason is written as a comment on the `fetch-depth` line, so the next person to trim it sees why it is there.
- The under-a-minute Done-when can only be judged on the PR's own CI run; the local check proves the suite still passes, not the speed-up.

## Deviations / notes
- none
