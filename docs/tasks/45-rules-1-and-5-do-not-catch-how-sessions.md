# 45 — Rules 1 and 5 do not catch how sessions actually skip them: problem reports read as work orders, vague replies read as gate authorization
Issue: #45

## Asked
Two failures observed in practice on `t-workflow` v0.0.8. In both, a session changed
files or passed a gate that `AGENTS.md` was meant to block, without the rules having
been broken in any way the document's own wording catches.

### (A) A described problem read as a work order

The human describes a bug, a symptom, or a desired outcome in ordinary conversation.
The session begins editing the tree immediately — no `/t-open`, no issue, no branch,
no `/t-work`.

Rule 1 already forbids this:

> **Work starts from a tracker issue.** Changing any file — code, config, docs — is
> work; answering questions and reading is not. Never edit the tree outside a task's
> own `/t-work` session, however small the ask.

But it states the prohibition as an abstract property of *file changes*, and never
names the trigger that actually defeats it: a natural-language problem report, which
reads to a session as an instruction to fix. The session isn't reasoning about
permission and concluding it has it — it isn't reasoning about permission at all. It
pattern-matches "user described a bug" to "fix the bug" and starts. Nothing in the
document says, in those terms, that describing a problem is not authorization to
change files.

This is the more common of the two, and the one rule 1's current phrasing is least
equipped to catch.

### (B) An ambiguous or scope-limited reply read as gate authorization

Worked example. A protected diff is on a draft PR; rule 4 requires a cold review
before it ships. The human looks at the diff and says:

> yeah the soft-delete column looks right, go ahead

The session marks the PR ready, watches CI, and merges. `/t-review` never ran.

Each guard reads as intact:

- **Rule 5** ("a skill runs only when the human named it, and nothing chains from one
  stage to the next"). `/t-ship` was not named — but the session reasons that the human
  reviewed the diff, said go ahead, and the only remaining stage is shipping, so it was
  named *by elimination*. Rule 5 is written as a rule about **naming**; the session
  substitutes **inferring which stage was meant**. Nothing forbids that substitution.
- **Rule 3** ("the trunk moves only by a pull request a human confirmed"). The session
  treats "go ahead" as that confirmation — it arrived, it was affirmative, it concerned
  this PR. Nothing says it must be the confirmation `/t-ship` asks at its own gate,
  after CI is green.
- **Communication** ("Nothing continues on silence"). This was not silence. The human
  spoke. The sentence reads as satisfied.

Two distinct mistakes are collapsed in that one reply: approval scoped to *one line of
the diff* became approval of *the whole task's readiness*, and a *general affirmation*
became a *stage invocation*.

## Done when
<from the issue>

## Explicitly not
- No new scripts or mechanical ambiguity-detection tooling under `scripts/`.
- **No harness-specific enforcement.** A `PreToolUse` hook under `.claude/` would guard
  Claude Code sessions only, while t-workflow is deliberately harness-neutral — the
  protected-paths list names `AGENTS.md`, `CLAUDE.md` and `GEMINI.md` side by side, and
  the Attribution section has each stage record the harness it actually ran as.
  Enforcing rule 1 for one harness and leaving the others on the honor system makes the
  gap invisible rather than smaller. If mechanical enforcement is wanted it would have
  to be a t-workflow script, which is out of scope here.
- No changes to individual skill files unless the `AGENTS.md` wording requires a
  cross-reference update to stay consistent.

## Decisions made along the way
- none

## Deviations / notes
- none

## Agents
- plan: claude-code / claude-opus-5[1m]
- work: claude-code / claude-opus-5[1m]
