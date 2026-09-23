# 44 — gate.sh and snapshot.sh read PR files through gh's 100-file cap; snapshot.sh dies on a large diff
Issue: #44

## Asked
`gate.sh ship <id>` and `snapshot.sh review <id>` read a pull request's file list from `gh pr view --json files`, which returns at most 100 entries. On a PR with more files the last paths alphabetically silently fall off, and since `docs/tasks/` sorts late, a parent's gate then reports a false blocker: `BLOCKED: completed child #<n> has no record docs/tasks/<n>-<slug>.md in the PR or on main — it never merged into wip/<id>-integration` although the record is in the diff. `snapshot.sh review <id>` fails outright on the same PR: its final `jq -n ... --arg diff "$diff"` puts the whole diff on the command line and dies with `jq: Argument list too long` (exit 126). `ci.sh` is not affected because it lists files with `git diff --name-only` (line 26), so CI's `t-workflow` check passes while the local gate blocks and the reviewer has no snapshot.

Seen on thyme-clinic initiative #264 (PR #286, 102 then 103 files): the gate blocked first on child #272, then on #271 and #272 after one more commit; both records were present (`git diff --name-only origin/main...origin/wip/264-integration` and `gh api repos/{owner}/{repo}/pulls/286/files --paginate` both listed them). The reviewer had to assemble the snapshot by hand. The human confirmed the merge over the false blocker.

The fix, in two parts:

1. **Files.** List a PR's files the way `ci.sh` already does, from git (`git -c core.quotePath=false diff --name-only origin/<base>...<head>` after a fetch), or paginate the API (`gh api "repos/{owner}/{repo}/pulls/<pr>/files" --paginate -q '.[].filename'`); the same source in `gate.sh` (line ~148–150, `files=$(... '.files[].path')`) and `snapshot.sh` (line ~16–21, `files: [.files[].path]` and the `--argjson files` that builds `children[].record`). One helper in `lib.sh` so the two cannot drift.
2. **Diff.** In `snapshot.sh`, pass the diff to `jq` from a temporary file with `--rawfile diff <file>` (or `--slurpfile`), never as an argument.

## Done when
- `gate.sh ship <parent>` on a PR with more than 100 files, all children's records present, reports every child's record and no `has no record` blocker; a PR whose record really is missing still blocks.
- `snapshot.sh review <id>` on a PR whose diff exceeds the argument-length limit succeeds and its `pr.files` lists every file.
- A test in `tests/test.sh` covers both: a PR of more than 100 files (records last alphabetically) and a diff larger than `getconf ARG_MAX` allows on the command line.

## Explicitly not
- Changing what the gate checks, only where it reads the file list from.
- Changing `ci.sh`, which already reads from git.
- Any other `gh ... --json` field that may be capped (`reviews`, `commits`); note it if seen, fix it separately.

## Decisions made along the way
- Files come from git (`pr_files` in `lib.sh`, the same `git diff --name-only origin/<base>...origin/<head>` `ci.sh` uses), not the paginated API, so the local gate and CI read one source. `pr_files` fails when either branch cannot be read, so an empty list never means "no files".
- `snapshot.sh` also passes the PR object (with its file list) to `jq` through a file (`--slurpfile`), not only the diff: a long file list could hit the same argument limit.
- Tests: the stubbed `gh` no longer carries a `files` list — it would be ignored. Three gate cases that only faked a list (a missing record, a cancelled child's record, a protected file) now commit that change on the integration branch and restore it after (`tweak_integration`); one child case that faked its own record now really changes it.

## Deviations / notes
- none

## Agents
- plan: claude-code-2.1.280 / claude-opus-5-5[1m]
- work: claude-code-2.1.280 / claude-opus-5-5[1m]
