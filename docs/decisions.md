# Decisions

One short entry per decision this repository made about itself. Newest first. Not
shipped to consumers.

## 2026-09-10 — A child's record on the trunk counts for its parent

A partly shipped initiative from before integration branches has children that merged
into the trunk one at a time. The parent's gate and CI want every completed child's
record in the parent PR's diff; such a child's is on the trunk instead, and the parent
could never ship. Both now accept a completed child whose record already sits at
`docs/tasks/<child>-*.md` on the trunk, and say so. The acceptance is narrow — that
exact path on the trunk, nothing else — so a child that merged nowhere still blocks.

## 2026-09-10 — The issue form goes; `section()` does not learn `###`

GitHub issue forms emit every field as a `###` heading and the scripts read `##`, so
a form-filed issue was never read. Teaching `section()` both levels would make every
reader tolerate two shapes for one field forever; the form is the thing nobody needed.
It leaves the owned set, and the updater removes a consumer's copy only when its bytes
are one of the two this repository's trunk ever carried (no tag had it; a consumer
has one only from an install off the trunk). A `$` in a config value is refused the same way an inner
quote is: the value was never expanded, so a literal `$HOME` was never what anyone
meant, and an ignored line is now said on stderr rather than read as empty in silence.

## 2026-09-11 — The contract carries rules, not rationale

The CI paragraph in `.t-workflow/AGENTS.md` had grown to about 180 words of threat
model that every agent read at every stage. It is cut to the rules an agent acts on;
the reasoning stays in the workflow file's header comment and in this file. For the
same reason the task issue form requires only Goal and Done when: the pipeline runs
without a declared Scope or Non-goals, so a form must not demand them.

## 2026-09-11 — The gate's workflow bootstraps itself on the PR that changes it

`pull_request_target` (#13) is read from the base branch, so the PR that introduces or
changes that trigger gets no run from it, and the required check never reports: #22
itself merged by admin bypass, and every adoption and every update from v0.0.5 would
have needed the same. The workflow now also listens on `pull_request`, filtered to
PRs that touch the workflow file, which are exactly the ones whose base copy is missing
or has the wrong trigger; no other PR gets that run at all. Where both fire, GitHub
requires every run under the check's name to pass (verified 2026-09-11 in a live
repository, four PRs, every order of red and green), so the PR's own run cannot
override the base's. The concurrency key carries the event so the two runs do not
cancel each other, and `rerun-ci.sh` re-runs every red run at the head rather than the
first listed. The alternative, an installer that drops the required check and puts it
back after the merge, was rejected as a hand step with a window where the trunk has
no gate.

## 2026-09-10 — An initiative lands through one integration branch

A child's PR on its own is not always self-consistent — a rename in one child and its
callers in the next — so shipping children to the trunk one at a time, each behind a
human question, put half-changes on the trunk and asked the human N times for one
decision. Now every child of an initiative merges mechanically into
`wip/<parent>-integration` (CI green, a cold review when its diff is protected), and
the human confirms once, on the parent's PR from that branch to the trunk, whose
records, plans, and `Task:` lines are the children's. The gate before a child merge
is mechanical only, and a child is judged by the integration branch's copy of the
scripts; the trunk's guarantee that a PR cannot rewrite its own enforcement is kept
at the trunk, where it matters. The external-collaboration machinery the old
template had (origin sections, observer markers, verification states, feedback mode,
preview adapters) stays gone; the issue number is still the only correlation key.

## 2026-09-09 — The build is not t-workflow's

t-workflow's CI job runs the workflow gates only. A project's build needs the runner
set up — a Java version, a cache — and the first adoption of a real project failed on
exactly that. Owning the build meant owning its environment through a hook or a slot,
which is the coupling the old template had. The build stays in the project's own CI,
the ship gate watches every check on the PR, and the config's check command is what
the agent runs locally.

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

## 2026-09-08 — An adoption PR is not under the rules it introduces

`ci.sh` checks whether the base branch already has the contract file. If not, the task
gates are not in force on that PR. An update PR is a protected diff like any other.

## 2026-09-08 — Size is reported, not asserted

`tests/test.sh` prints the consumer footprint. A hard limit would be a test that
breaks for reasons nobody cares about at the time; the number in the log is enough to
notice drift.
