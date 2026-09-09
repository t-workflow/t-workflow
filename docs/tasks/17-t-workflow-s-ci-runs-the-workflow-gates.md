# 17 — t-workflow's CI runs the workflow gates only; the project's build stays in its own CI
Issue: #17

## Asked
t-workflow's CI job should not run a project's build. Today `ci.sh` runs the config's check command on a bare GitHub runner, so the runner's setup — a Java version, a Node version, a cache — becomes t-workflow's problem; t-preview's first adoption PR failed on exactly that ("release version 25 not supported", because `setup-java` no longer ran before `./mvnw -B verify`). Instead, t-workflow's job runs only the workflow gates (record, title, plan, review, blockers), which need nothing but git and `gh`. A project's build stays in the project's own CI, with whatever setup it needs, and the ship gate already watches every check on the PR. The `check` command in `.t-workflow/config` is what the agent runs locally before opening a PR, and only that.

For a project migrating from the old t-workflow, whose build lived inside the old workflow's slot, the installer writes those steps once into a plain workflow of the project's own, `.github/workflows/build.yml`, and never touches it again.

## Done when
- `ci.sh` no longer runs the check command; its output says the project's own CI is where the build runs.
- `.t-workflow/AGENTS.md` §Checks says check 1 is run locally by the agent, and CI runs the gates only. `.t-workflow/config`'s comment on `check` and on `exempt` say the same. The README says it in its "What lands" table and pipeline section.
- In replace mode, the steps in the old `ci.yml` slot become `.github/workflows/build.yml` — on pull requests and pushes to the trunk, with a checkout step first, the old `timeout-minutes` slot as the job timeout when present — and are no longer written to `REPLACED.md`. The file is consumer-owned and created only when absent. Adopt mode creates nothing.
- `tests/test.sh` covers: `ci.sh` passes with `check="false"` and never runs it; both replace fixtures produce `build.yml` with the slot's steps and an empty leftovers report for the slot; adopt creates no workflow.
- `docs/decisions.md` records why the build is not t-workflow's.

## Explicitly not
- A setup hook or composite action of any kind; that was the first plan for this issue and was dropped because it kept the build coupled to t-workflow.
- Skipping a documentation-only diff in the consumer's own CI; that is the consumer's workflow to shape.

## Decisions made along the way
- The build is not t-workflow's: CI runs the workflow gates only, the project's own CI runs the build, and the ship gate already watches every check on the PR (human, 2026-09-09, after the first t-preview adoption PR failed on runner setup).
- A migrating project's old CI slot becomes a plain `build.yml` of its own, written once; a timeout slot becomes that job's timeout.

## Deviations / notes
- Re-planned mid-task at the human's ask: the first plan added a consumer-owned composite-action hook the workflow would run before the check; it kept the build coupled to t-workflow and was dropped. The issue's Goal, Done when, Plan, and title were rewritten; the branch keeps its original name.
- Also updated, found by searching for every place that assumed CI ran the build: `/t-review`'s reuse rule (a green CI run proves a check only when the project's own workflow ran that exact command) and the adoption issue's Checks line.
- Fix pass after the cold review, all findings but the required-check one (which went into #12): fifteen tests I had deleted by replacing too wide a block are restored from main; the review skill, this repository's config comments, and the decisions text are added to the plan; an existing `build.yml` is kept and the slot's steps reported; the timeout is taken from `ci.yml` only; the adoption issue names `build.yml`; a column-zero comment is indented rather than cut; the old docs-only clause is dropped from `if:` lines; an update rewrites the previous default config comments; the bootstrap fixture asserts the file exists.
- Second fix pass (the re-review's medium and first low, at the human's ask): the config-comment rewrite uses awk instead of a sed replacement containing a newline, which macOS sed would print as a literal `n`; the adoption PR body names `build.yml` when the installer wrote it.
- `install.sh`'s leftovers report no longer special-cases the old workflows' default timeout; timeouts are carried into `build.yml` instead.
