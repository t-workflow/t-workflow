# 52 — Review reads /t-work's test output instead of re-running whole suites
Issue: #52

## Asked
`/t-review` should read the test results `/t-work` already produced, not run the same suites again. In a consuming repo on v0.0.11 (Java/Maven, three apps, a full suite of about 10 minutes for the largest), `/t-work` ran every suite at the PR's head sha. It listed each one in `## Checks run` as `PASS` at that sha. The subagent reviewer then started the largest full suite again, and the human stopped it by hand. That was about 10 minutes of waiting added to a `/t-drive` run for no new evidence. A second full re-run would have followed on the re-review after the fix pass.

Step 3 of `/t-review` already allows reuse when `## Checks run` names the exact command at a sha equal to `pr.headRefOid`. But the rule reads as permission, not as the default. It ends "anything less → run it yourself". And the reviewer has nothing to read except the PR's one-line claim, so re-running looks like the only way to test that claim cold. A fairer contributing cause: the `/t-drive` session's prompt to the reviewer said it "may run" targeted tests, and it went on to the full suite.

## Done when
- `/t-work` keeps the raw output of every check it runs. It names where that output is, per line, in `## Checks run`: a path the reviewer can read, or an attachment on the PR.
- `/t-review` step 3: a check reported `PASS` at `pr.headRefOid` with its output available is **reused by reading that output**, never re-run. The reviewer judges the raw output itself (totals, BUILD line, skipped/failed counts), not the one-line claim. The review body says `reused — read <output>`.
- `/t-review` re-runs a check only when the sha differs, the output is missing or does not support the claim, or the reviewer has a specific doubt. It then runs the narrowest command that settles that doubt (for example one test class), never the whole suite by default. It says in the review which case applied.
- A re-review after a fix pass reuses the fix pass's own reported checks the same way. It does not repeat the first pass's runs.
- `/t-drive`'s instructions for spawning the reviewer say nothing that invites re-running suites.
- `tests/test.sh` covers whatever script support this needs (for example `snapshot.sh review` exposing the check-output locations).

## Explicitly not
- Weakening what counts as a check, or letting a claim stand without evidence: reuse still requires the same command at the same sha, and output the reviewer actually reads.
- Running a project's build in t-workflow's CI (#17 stays as it is).

## Decisions made along the way
- New script `.t-workflow/scripts/check.sh` runs a check and decides the line: it refuses a dirty or untracked tree, runs the command, keeps the raw output under `<git common dir>/t-workflow/checks/` (never the tree) with a header (`# command:`, `# commit:`) and trailer (`# exit:`), prints the `## Checks run` line with `output <path>`, and shows only the last 20 lines. One new consumer file, in exchange for no line-format or sha prose in the skill.
- `/t-work` now commits before running checks, so the sha on the line is the tree that ran. The record is brought up to date before that commit.
- `snapshot.sh review` adds `local.check_outputs: [{path, readable}]`, read from the `output` paths in `## Checks run`.
- Output stays local; no PR attachment. A reviewer on another machine sees `readable: false` and does a narrow re-run.

## Deviations / notes
- The issue's Scope says "`AGENTS.md` (Checks section)"; the Checks section is in `.t-workflow/AGENTS.md` (the root `AGENTS.md` is the project pointer). The plan names `.t-workflow/AGENTS.md`.

## Agents
- plan: claude-code / claude-opus-5-5[1m]
- work: claude-code / claude-opus-5-5[1m]
