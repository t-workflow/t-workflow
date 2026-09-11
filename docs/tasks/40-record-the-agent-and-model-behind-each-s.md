# 40 — Record the agent and model behind each stage in the task record and squash commit
Issue: #40

## Asked

Record which agent and model did each stage of a task, in the task record and as trailers on the squash commit, so a repository can later compare how models perform at writing code.

Today the only attribution is whatever `Co-Authored-By` trailer a harness happens to inject, and it is unreliable: in one consumer repository, of the last three squash merges one names the model and two do not. The record is the reliable place because the gate enforces its existence, and the squash commit is the machine-readable place because `git log --format=%(trailers:key=...)` can read it.

## Done when

- `record.sh create` writes an `## Agents` section, and `record.sh check` fails a record whose section is missing or a placeholder, so the CI gate enforces it.
- `/t-plan`, `/t-work`, `/t-review`, and `/t-ship` each append their own entry, with the model id the session actually ran under; a stage that cannot determine its model writes `unknown` rather than guessing.
- `/t-ship` emits one trailer per stage entry on the squash commit, for a task and for an initiative's parent PR.
- `AGENTS.md` documents the section and the trailers, and the migration is stated: an existing record without the section passes `check` until the consumer re-runs a stage on it, or the section is required only for records created at or after this release.

## Explicitly not

- No measurement, scoring, or dashboard: this issue only makes the data exist. Joining it with a quality tool's per-PR measures is the consumer repository's concern.
- No change to how `reviewer_model` is chosen.
- No retroactive attribution of tasks already shipped.

## Decisions made along the way
- Only `/t-work` writes to the record's `## Agents` section, since `.t-workflow/AGENTS.md`
  confines tree edits to a task's own `/t-work` session. `/t-plan` leaves `Planned by:`
  on the issue's `## Plan`, `/t-review` leaves `model:` on its PR review; `/t-work`
  seeds both into the record before appending its own entry. `/t-ship` never writes to
  the record at all — it reads `record.sh trailers <id>` for `Planned-By`/
  `Implemented-By`, the live review for `Reviewed-By`, and its own session for
  `Shipped-By`, all as commit trailers.
- The record's `## Agents` section is required by `record.sh check` only once it is
  present: absent entirely (a record from before this change) passes; present but
  empty or a placeholder fails. No version or date gates this, per the project's own
  rule against version literals in shipped files — see `docs/decisions.md`.
- A `review` entry that later lands in the record (from a fix pass) is not turned into
  a trailer — it may be stale by the time of shipping. `/t-ship` reads the current
  gating review directly instead.

## Deviations / notes
- This task's own `## Plan` (posted before this feature existed) has no `Planned by:`
  line, so this record's `## Agents` section has no `plan` entry — a bootstrap gap,
  not a bug; every task planned after this merges will have one.
- Re-planned once mid-work to add `.t-workflow/scripts/lib.sh` to Allowed paths: both
  `/t-work` (fix mode) and `/t-ship` need a review's model, and one shared parse in
  `review_verdict` (forwarded by `gate.sh` as `review-agent:`) beats duplicating it.
- check 1 (this repo's own `tests/test.sh`) covers every new `record.sh` behavior
  (the `agent` and `trailers` subcommands, the `## Agents` migration rule in `check`)
  and `review_verdict`'s new `agent:` line; see the `## Checks run` section on the PR.

## Agents
- work: claude-code / claude-sonnet-5
