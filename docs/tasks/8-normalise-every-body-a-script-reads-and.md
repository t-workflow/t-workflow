# 8 — Normalise every body a script reads, and never read an absent review section as none
Issue: #8

## Asked
The gate reads a review's meaning out of markdown headings and a `readiness:` line, and any reader that takes the body raw can miss: a review typed in GitHub's web editor ends lines with carriage returns, and the section reader was fixed for that in #6 while the isolation line and the plan-section counter still read raw text. Instead of fixing readers one at a time as reviews find them, every body a script reads — a review or an issue — is normalised once at entry (carriage returns removed, trailing whitespace on each line trimmed), so no reader can miss on line endings again. And a review that carries a verdict but has no `## Findings` section reports its open findings as unknown and blocks the ship, exactly as a missing `## Pending human checks` section already does: the gate never reads an absent section as "none".

## Done when
- A single helper in `.t-workflow/scripts/lib.sh` normalises a body, and every place a review or issue body is read goes through it (`review_verdict`, `section`, `count_sections`, the `isolation:` read, `issue.sh plan`, `record.sh create`, `gate.sh`'s scope extraction, `ci.sh`, `snapshot.sh`).
- `review_verdict` on a body with CRLF line endings yields the same verdict, isolation, pending checks, and open findings as the same body with LF; a test asserts it.
- A review with a `readiness:` line and no `## Findings` section yields `open-findings: unknown`, and `gate.sh ship` emits a `BLOCKED:` line for it naming what to add; a test asserts both. A review with the section and `- none` under every severity still yields `open-findings: none`.
- `/t-ship` (`.claude/skills/t-ship/SKILL.md`) names that block alongside the pending-checks one.
- `gate.sh`'s no-argument usage prints its whole header, exit-code line included (the `sed` range is off by one).
- `tests/test.sh` passes.

## Explicitly not
- A machine-readable verdict block embedded in reviews: a person reviewing by hand would never write it, so it fails the same way with more machinery.
- Changing the review format itself.

## Decisions made along the way
- The ship gate's review rules moved into one function, `review_blocks`, fed by `review_verdict`'s output, so every rule is tested without a tracker; `gate.sh ship` only prints what it returns (agent, 2026-09-09).
- `normalize` trims trailing whitespace on every line as well as carriage returns; markdown meaning does not depend on it and no reader compares bodies byte-for-byte (agent, 2026-09-09).

## Deviations / notes
- `gate.sh`'s usage printer reads its own header up to the first non-comment line instead of a fixed line range, so it cannot drift again.
