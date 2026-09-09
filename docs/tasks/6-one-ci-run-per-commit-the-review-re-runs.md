# 6 — One CI run per commit: the review re-runs it instead of triggering a second one
Issue: #6

## Asked
Merging a protected PR needs a hand step today: every push produces a red `t-workflow` CI run, because the cold review cannot exist yet, and the review then triggers a second, green run through the workflow's `pull_request_review` trigger. GitHub's branch protection counts both runs at the same commit, so the merge stays blocked until someone re-runs the red one by hand (PR #5 needed exactly that). Instead, the workflow runs only on pull-request events, and the review stage re-runs the existing run for its commit after posting, so there is one run per commit and it goes green on its own once the review exists.

## Done when
- `.github/workflows/t-workflow.yml` has no `pull_request_review` trigger; its job condition is only "not a draft".
- A script, `.t-workflow/scripts/rerun-ci.sh <pr>`, re-runs the latest `t-workflow` workflow run at the PR's head commit when one exists and has concluded, and says plainly when there is none (a draft PR: CI starts when it is marked ready) or one is still running.
- `/t-review` calls that script right after posting its review.
- `tests/test.sh` covers the script's three cases with a stubbed `gh`.
- `snapshot.sh review` reports `local.branch`, which the reviewer wanted and found missing.

## Explicitly not
- Changing what `ci.sh` checks.

## Decisions made along the way
- The review re-runs the existing run rather than the workflow listening for review events: one check run per commit is what branch protection evaluates cleanly (agent, 2026-09-09).

## Deviations / notes
- Re-planned mid-task at the human's ask: `AGENTS.md` added to the allowed paths for one project note on tracing a PR through every event before changing a stage. Old plan: six paths; new plan: those plus `AGENTS.md`.
- Fix pass after the cold review, all findings at the human's standing ask: a draft PR is recognised from the PR itself and a skipped run is never re-run; a failed run listing is an error, not "no run"; the run is found by `--commit` rather than a window; the in-progress message says to run again if it ends red; the stub `gh` checks the exact flags the script relies on; the header documents exit 2; `/t-ship` calls the script before watching CI, so a review posted from the UI on an already-ready PR needs no hand re-run either (re-planned to add `.claude/skills/t-ship/SKILL.md`).
- The old template kept its review gate in a separate workflow with its own check name for exactly this reason; that reason was dropped with the machinery in the first cut, and PR #5 needed a hand re-run as a result.
