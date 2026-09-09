# Decisions

One short entry per decision this repository made about itself. Newest first. Not
shipped to consumers.

## 2026-09-09 — One CI run per commit; the review re-runs it

A protected diff's CI run is red until its cold review exists. Triggering a second run
from the review event left two runs at one commit, and branch protection counted the
red one, so every protected merge needed a hand re-run. Now the workflow fires only on
pull-request events and `/t-review` re-runs the existing run after posting.

## 2026-09-08 — A release is a tag; the tree never names a version

The README installs from `main` and the installer resolves the newest tag. There is no
changelog and no release notes: the update PR's diff and `git log` between tags say
what changed, and the installer appends missing config keys so a release never needs a
hand step. `.t-workflow/VERSION` exists only in consumers, written from the installed
tag. Anything else would need a task per release to keep it true.

## 2026-09-08 — Start over rather than trim the old template

The old `haninaguib-devtools/t-workflow` had grown to 82 consumer files and 725 KB,
54k tokens of instructions for a one-line fix, and half its recent commits fixed
consumers broken by its own sync machinery. Its ratchet made every removal an
ADR-grade change, so it was rebuilt from scratch with size budgets instead.

## 2026-09-08 — Owned files are copied verbatim; customization lives in two files

Everything t-workflow ships is replaced wholesale on update. A consumer customizes only
`AGENTS.md` and `.t-workflow/config`. No manifest, no local slots, no migrations: there
is nothing to detect and nothing to migrate. A hand edit to an owned file is
overwritten by the next update, by design.

## 2026-09-08 — Scripts judge, skills narrate

Every gate a script can decide is a script (`gate.sh`, `ci.sh`, `protected.sh`,
`docs-only.sh`, `record.sh`). Skills are short procedures that call them, so an agent
reads a few hundred words per stage and cannot misremember an exit code's meaning.

## 2026-09-08 — GitHub only, `gh` inline

No adapter layer until a second backend exists. The old one had none either after
Jira and GitLab support was dropped.

## 2026-09-08 — Protected set is small and named

`.t-workflow/AGENTS.md`, `.t-workflow/scripts/`, `.claude/`, `.agents/`,
`.github/workflows/`, and the instruction files. Docs, README, `.gitignore`, and
`.t-workflow/config` are ordinary. The consumer adds its own via config.

## 2026-09-08 — No initiative integration branches, no external-collaboration model

`/t-drive` on a parent walks the children one PR at a time and stops at each merge
gate. Origin sections, observer markers, verification states, feedback mode, and
preview adapters are gone; the issue number in every branch, record, and commit is the
only correlation key.

## 2026-09-08 — An adoption PR is not under the rules it introduces

`ci.sh` checks whether the base branch already has `.t-workflow/VERSION`. If not, only
check 1 runs. An update PR is a protected diff like any other.

## 2026-09-08 — Size is reported, not asserted

`tests/test.sh` prints the consumer footprint. A hard limit would be a test that
breaks for reasons nobody cares about at the time; the number in the log is enough to
notice drift.
