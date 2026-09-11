# 13 — CI gate: never execute the config, read policy and gate scripts from the base branch, state the threat model
Issue: #13

## Asked
Make the CI gate harder to fool, and say plainly what it does and does not defend against. Two problems, found in an outside review:

1. **The config file is a shell script and CI reads the PR's copy.** `.t-workflow/config` is loaded with the shell's `source`, so anything in it runs. In CI, the gate reads the copy from the pull request being judged. A PR could therefore add its own branch to `exempt`, or blank the `check` command, and the gate would wave it through on those values.
2. **CI runs the gate scripts from the pull request.** A PR that edits `ci.sh` to always succeed is judged by that edited `ci.sh`. Calling those files "protected" does not mechanically protect them, because the changed script performs its own check. The old system had exactly the same property.

Neither of these matters for a single cooperative author reading their own diff before merging. They matter the moment a PR is written by something that is malfunctioning or malicious. Right now the contract's wording sounds stronger than the implementation.

## Done when
- The config is parsed as plain `key="value"` lines and never executed. Anything else on a line is ignored.
- In CI, the policy values — `exempt`, `protected`, `docs` — are read from the base branch, not from the PR. The `check` command is still read from the PR, because a PR that changes the build must be tested with its own command, and that change is visible in the diff.
- The workflow runs the gate scripts from the base branch against the PR's files. On an adoption PR, where the base has no scripts yet, it runs the PR's copy, as it does today.
- `.t-workflow/AGENTS.md` says in one sentence what the mechanical gate defends against (mistakes) and what it does not (a PR that edits the enforcement itself), and that the cold review and the human merge are what cover the rest.
- `tests/test.sh` covers the parser (a line like `check="x"; rm -rf /` yields the value `x"; rm -rf /` or is rejected, but nothing runs) and the base-branch policy read.

## Explicitly not
- Making `.t-workflow/config` a protected path. Reading policy from the base branch removes the self-approval problem without adding a plan and a cold review to every change of the check command.
- A pinned external action for the gate. The base-branch checkout gives the same guarantee with no new dependency.

## Decisions made along the way
- Strict full-line parser: only `key="value"` with no `"` inside and nothing else on the line; a `check="x"; rm -rf /` line is rejected (one of the issue's two allowed outcomes) rather than kept as a junk literal.
- `TW_CONFIG_FILE` override in `lib.sh` so `ci.sh` can hand its children (e.g. `protected.sh`, which re-reads the config) the merged base-policy copy; otherwise the child would still judge `protected` by the PR.
- Base policy is `exempt`, `protected`, `docs`; `check` stays the PR's and `reviewer_model` stays out of the CI gate, per the issue.
- Left `.t-workflow/config`'s own `# Shell syntax` header comment and `install.sh` untouched (out of the plan's paths; installer only greps/seds the file, never executes it) — proposed as a follow-up wording fix.
- (second pass) Trigger switched from `pull_request` to `pull_request_target`: for `pull_request`, GitHub reads the workflow YAML itself from the PR's branch, so a PR could delete the base-branch-fetch logic above and never be judged by it — scripts alone can't close this, only the trigger can.
- (second pass) The checkout stays on the base branch; the PR's commit is fetched separately into a local ref (`PR_REF`, `refs/heads/_pr_head`) and only ever read with `git show`/`git diff`, never checked out or executed. This also sidesteps `actions/checkout`'s own mid-2026 change that refuses to check out a fork PR's commit under `pull_request_target` (the classic "pwn request" shape) — a plain `git fetch` of that ref isn't something that action's guard can see or block.
- `ci.sh` gained `PR_REF` (default `HEAD`, so every existing local/test invocation is unaffected): the changed-file diff, the PR's own `check` value, and the record file are all read through it via `git diff`/`git show` instead of assuming the working tree is the PR's content. The record is materialized into a temp file at the same relative path (`docs/tasks/<id>-*.md`) so `record.sh check`'s own naming check still applies unchanged.
- The workflow now picks one script source for the whole gate — the base branch's `.t-workflow/scripts` normally, the PR's own only when the base has none yet (adoption) — and always runs it against the checkout (base) plus `PR_REF`, rather than special-casing "run the checkout's own copy" for adoption PRs.

## Deviations / notes
- Re-planned after the PR (`#22`) was already open and review-ready: an outside-the-workflow review found that `.github/workflows/t-workflow.yml`'s own trigger (`pull_request`) meant a PR could edit that file to skip the base-branch-fetch logic entirely, defeating the fix for the one file most able to bypass it. Old scope: parser + `ci.sh` policy read + base-branch script fetch, all under `pull_request`. New scope: the same, plus the trigger switch, the checkout-stays-on-base redesign, and `ci.sh`'s `PR_REF` plumbing — all still within this issue's original `## Scope` (no new files touched).
- Discovered while implementing the trigger switch: checking out a fork PR's head SHA under `pull_request_target` is now blocked by `actions/checkout` itself (backported to `@v4` as of 2026-07-16, per GitHub's changelog) precisely because it's the "pwn request" pattern — confirming the checkout-stays-on-base design (which never does this) rather than the first draft of this fix, which briefly did check out the PR's commit before being corrected.
