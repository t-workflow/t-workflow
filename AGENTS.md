Read `.t-workflow/AGENTS.md` first — the delivery workflow for this repository.

## Project notes

This repository *is* t-workflow, and uses itself. The files a consumer receives are
listed in `install.sh` (`OWNED`); everything else here is this repository's own.
`tests/test.sh` is the check command. Rationale for decisions lives in
`docs/decisions.md`, one short entry per decision.

**Keep ceremony and friction low.** t-workflow exists to make agent-worked repositories
safe at the lowest possible cost to the people and agents using it. Every change here
is judged first by that cost:

- What it costs a consumer: files in their tree, words an agent reads per stage,
  commands a human types, tool calls per change. A change that raises any of these
  says why in its issue.
- Prefer removing a rule to adding one. A rule that guards against a problem nobody has
  had is not added.
- A version, date, or release name never appears in a shipped file (the `OWNED` list in
  `install.sh`). Nothing is written that a tag or the git log already says.
- Anything a script can decide, a script decides; skills stay short procedures that
  call them.
- Friction a consumer hits is fixed here, never worked around in the consumer.
- A hand step at install or update time is a defect in the installer.
- Before changing a stage or CI, trace one concrete PR through every event it will
  produce — push, checks red, review, checks green, merge — and name what turns each
  red state green without a human. When dropping something the old system had, first
  say what it did differently and why; keep the reason, drop the machinery.
