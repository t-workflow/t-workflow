# 57 — Let a project describe protected areas in words, not only paths
Issue: #57 · Part of: #54

## Asked
Some of what a project most needs reviewed is not a path. Example from a consuming EMR project: every module records audit events through one audit module. A change that stops a clinical action being audited can therefore sit entirely in clinical or scheduling code and never touch an audit package. "Who can read a patient's notes" and "how a visit is billed" are similar. Path globs cannot express these. Let a project describe protected *areas* in words, and make a change that touches one need a cold review (and a plan, per `plan_required`).

The gate is mechanical today, and the session doing the work should not be the one deciding its change is not covered. So the judgment is made where the human sees it, and the gate only reads the result:
1. The project lists its areas in a new protected file (e.g. `.t-workflow/areas.md`, in the built-in set). Each area gets a name, one or two sentences on what it covers, and optional path hints.
2. `/t-open` judges each issue against the areas and writes the ones it touches on the issue, each with a one-line reason (e.g. a `## Protected areas` section). The human reads the issue before work starts.
3. `gate.sh` reads that section mechanically. Any named area makes the task protected, exactly as a protected path does.
4. `/t-review` reports any area the diff touches that the issue does not name, as a blocking finding. An agent may add an area to an issue, never remove one: removing needs the human's word.
5. Path globs stay as the backstop.

Known gap, to decide in this task: an issue wrongly classified as touching no area may never get a review to catch it. Decide whether `/t-ship` makes one short judgment of the final diff against the area descriptions (one model call per ship), and record the choice and its reason either way.

## Done when
- With no areas file, every script and skill behaves exactly as today (tested). An issue opened before the upgrade, with no areas section, is treated as naming none and is not blocked for lacking one.
- The areas file format is documented in `.t-workflow/AGENTS.md`, and the installer does not create or overwrite it.
- `/t-open` writes the areas section when the file exists. `gate.sh` treats a named area as protected. `/t-review` checks the classification as in steps 2–4.
- The `/t-ship` check above is decided, and built if chosen.
- `tests/test.sh` covers the gate reading the section (none, one, several, absent file).
- `docs/decisions.md` records the design and the alternatives considered.

## Explicitly not
- Writing any project's areas.
- Replacing path globs.

## Decisions made along the way
- The `/t-ship` question: no model call per ship. The gate prints an `areas:` line (the issue's areas, or "none named" with the project's list) and the merge question shows it, so the human judges the gap at the gate they already answer. Recorded in `docs/decisions.md`.
- A named area needs a review always, and a plan only while `plan_required` is `protected`: an area has no path for `plan_required` to name.
- The areas file is policy: CI and the ship gate read it from the base branch, and it joins the built-in protected set.
- A parent counts its children's areas (cancelled ones aside). `children_json` fetches each child's body in the same GraphQL call, so this adds no calls.
- A missing area found by review is added by `/t-plan` (which already edits the issue), not by `/t-work`.
- `Paths:` lines in the areas file are hints for the judging agent, never matched by a script.

## Deviations / notes
- No child PR, by the human's choice for initiative #54: committed straight onto `wip/54-integration`; the cold review runs once, on #54's combined diff.
- `install.sh` needed no change (the areas file is not in `OWNED`); tests pin that it is never created or overwritten.
- `/t-drive` step 1 now says "blocks for a missing plan", left over from #56.

## Agents
- plan: claude-code 2.1.292 / claude-opus-5-5
- work: claude-code 2.1.292 / claude-opus-5-5
