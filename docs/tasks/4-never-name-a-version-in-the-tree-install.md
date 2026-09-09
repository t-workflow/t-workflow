# 4 — Never name a version in the tree: install from main, resolve the newest tag, tag is the release
Issue: #4

## Asked
Nothing in this repository names its own version, and a release is just a tag. The README's install command currently hardcodes a tag, `CHANGELOG.md` lists versions, and `.t-workflow/VERSION` sits in the tree: every release would need a task to keep those in sync, which is the kind of maintenance t-workflow exists to avoid. Instead the install command takes `install.sh` from `main` with no tag and the installer resolves the newest tag itself; release notes are replaced by the update PR's diff plus the git log between tags; config evolution is handled by the installer appending missing keys. This repo's own `AGENTS.md` gains project notes that keep future work biased toward lowering ceremony.

## Done when
- `grep -rn 'v[0-9]\+\.[0-9]\+\.[0-9]\+' README.md AGENTS.md .t-workflow .claude install.sh` finds no version literal (the tests' fixture tags excepted).
- `CHANGELOG.md` and `.t-workflow/VERSION` no longer exist in this repository; the installer writes `.t-workflow/VERSION` in a consumer from the tag it installed.
- `install.sh` with no tag installs the newest tag from the source (`git ls-remote --tags`); with a tag, that tag.
- On update, the installer appends any config key the consumer's `.t-workflow/config` lacks, with its default and comment, leaving present values alone; and prints `git log --oneline <old>..<new>`.
- `ci.sh` decides "adoption PR" by whether the base branch has `.t-workflow/AGENTS.md`.
- `/t-update` with no tag runs the installer with no tag, and reports from the installer's log output.
- `AGENTS.md` (this repo) carries the low-ceremony project notes.
- `tests/test.sh` passes, with tests for latest-tag resolution and config key appending.

## Explicitly not
- Cutting the tag; that happens on `main` after this merges.

## Decisions made along the way
- A local directory source (`--from <dir>`) still needs an explicit tag: it has no tags to resolve, and the tag is only a label written into VERSION (agent, 2026-09-08).
- Config keys are appended with their comment block by matching the default config, so the consumer file keeps reading as documentation (agent, 2026-09-08).

## Deviations / notes
- Issue #3 (rename to v0.0.1) was opened before this direction was settled and closed as superseded by this task.
