# 12 — Installer: refuse a dirty tree and collisions, merge branch protection instead of replacing it, add a license
Issue: #12

## Asked
Make the installer safe to run on a repository that already has things in it, and stop it from touching GitHub settings it did not create. Three problems, found in an outside review:

1. **It deletes before it looks.** The installer removes every path it owns and then copies the new copy in. It only insists on a clean working tree when it is going to open a pull request; with `--no-pr` it will happily overwrite uncommitted work. If a repository already has a `.claude/skills/t-open` or a `.github/workflows/t-workflow.yml` from somewhere else, that content is gone.
2. **It replaces branch protection wholesale.** `protect.sh` sends a complete branch-protection document with only our check in it. On a repository that already had required reviews, code owners, or other required checks, those are silently removed. (Today this only fails harmlessly on private free-plan repositories, where GitHub refuses the call.)
3. **There is no license.** The old repository was MIT. This one is public and copies files into other people's repositories, so it needs one.

## Done when
- The installer refuses to run on a dirty working tree in every mode, including `--no-pr`. A clean tree is what makes every change reversible with git.
- In adopt mode (no t-workflow present), the installer refuses when a path it would write already exists, and lists them. The known aliases (`CLAUDE.md`, `GEMINI.md` pointing at `AGENTS.md`) are still merged as they are today.
- The installer prints everything it is about to do — files removed, files written, settings changed — before it changes anything.
- `protect.sh` reads the existing branch protection first. If there is none, it applies the minimal set as today. If there is one, it adds the `t-workflow` check to the required checks and changes nothing else. It prints the before and after.
- A `LICENSE` file (MIT) is in the repository, and the README says in one sentence that the installed files are MIT-licensed copies the consumer may keep under its own license.
- `tests/test.sh` covers the dirty-tree refusal, the collision refusal, and the printed plan.

## Explicitly not
- GitHub rulesets. They would be cleaner than the legacy protection endpoint but are another API to learn; not now.
- A staging directory or a `--force-dirty` flag. A clean tree already makes the run reversible.

## Decisions made along the way
- `protect.sh` was not touched: #20 already shipped the read-first merge (required-checks only) with before/after output, and `tests/test.sh` already covers it, so the branch-protection done-when bullets are verified, not re-implemented.
- The dirty-tree check moved above the `pr=yes` gate but stays after the update no-op exit, so `already at <tag>` still succeeds on a dirty tree; every other mode refuses first.
- The printed plan lists remove/write/create-when-absent/settings, but not the live branch-protection diff: that is only known when `protect.sh` queries GitHub near the end of the run, after the issue/branch/PR exist.
- `LICENSE` carries no year: the tree never names a date, and the holder is `t-workflow` per the plan pending a human's confirmation.

## Deviations / notes
- The plan's allowed paths govern: `protect.sh` (in the issue's scope) was deliberately left untouched for the reason above; the report asks a human to confirm the protection bullets read as done.
- `tests/test.sh` needed a commit between successive `install.sh --no-pr` calls on each reused fixture (`c`, `f`, `d`, `g`); the no-op and manifest-refusal assertions otherwise fail on the new dirty check rather than what they mean to test.
