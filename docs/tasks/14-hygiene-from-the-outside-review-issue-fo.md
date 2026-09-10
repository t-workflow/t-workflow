# 14 — Hygiene from the outside review: issue form, stricter records, tag filter, pinned actions, ShellCheck and macOS, wording
Issue: #14

## Asked
Small things an outside review found that are each cheap on their own. Listed here so they can be accepted or dropped one by one.

1. **A task issue form.** The old issue forms went with the old documentation; now a person opening an issue by hand gets a blank box, and a body without Goal, Done when, Scope, and Non-goals is what the record script then has to work from. One minimal form for a task would help.
2. **Stricter record validation.** `record.sh check` only verifies that each heading appears somewhere. It should require each section exactly once, in order, with content that is not a template placeholder.
3. **Only release-shaped tags.** The installer picks the newest tag with `sort -V` over every tag in the repository. Filtering to `v[0-9]*` keeps an unrelated tag from being chosen one day.
4. **Pin the GitHub Actions by commit.** `actions/checkout@v4` is a moving tag. Pinning to a commit makes CI reproducible.
5. **ShellCheck and a macOS job.** The scripts promise Bash 3.2 compatibility (macOS ships it), but CI only runs on Ubuntu. Add ShellCheck and run the tests on a macOS runner too.
6. **Say what "human-confirmed merge" means.** It is a rule the skills follow, not something GitHub enforces: branch protection deliberately requires no PR reviews. One sentence in the contract.

## Done when
- `.github/ISSUE_TEMPLATE/task.yml` exists with four fields: Goal, Done when, Scope, Non-goals, and nothing else. It is on the installer's owned list.
- `record.sh check` fails on a duplicated, missing, out-of-order, or placeholder-only section, with the reason, and the tests cover each.
- Tag resolution in `install.sh` considers only tags matching `v[0-9]*`.
- Every `uses:` in `.github/workflows/` is pinned to a commit SHA with the version in a comment.
- `.github/workflows/tests.yml` runs ShellCheck and runs `tests/test.sh` on both `ubuntu-latest` and `macos-latest`, green.
- `.t-workflow/AGENTS.md` states that the merge confirmation is a rule the skills follow, not a GitHub-enforced approval.

## Explicitly not
- An initiative issue form. A parent issue is Goal and Non-goals only; the task form covers it.
- Anything from the review's larger findings; those are #12 and #13.

## Decisions made along the way
- ShellCheck gates at `--severity=warning`: info/style findings are dominated by intentional idioms (literal backticks in messages, `A && B || C` guards), so gating on them would force churn or blanket disables.
- ShellCheck itself is a pinned release binary (v0.10.0) in CI, not apt: the same version verified locally, fast, reproducible.
- Tag filter applies to auto-resolution only; naming a non-matching tag explicitly still installs it (the existing `rel/...` test pins that).
- `sort -V` replaced with a zero-padded awk key: BSD sort on the new macOS leg has no `-V`, and the old code would have gone red there.
- `seq` and `perl` removed from `tests/test.sh` for the same reason (macOS has neither reliably); `printf`/`tr` and command substitution cover both.
- Three targeted ShellCheck disables (SC2034/SC2154) for config values arriving through dynamic sourcing, which single-file analysis cannot see — the file convention already uses targeted disables.

## Deviations / notes
- none
