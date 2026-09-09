# 19 — Installer: drop old-script steps and use a full checkout in build.yml, carry consumer skill rows, merge into existing branch protection
Issue: #19

## Asked
Four things the locklane repository would hit on adoption, found by reading it before running the installer:

1. **A slot step that runs a deleted script is copied into the build workflow.** locklane's old CI slot has a step running the old `check-manifest.sh`; copied into `build.yml`, it fails on every PR. Any slot step that runs something under `.t-workflow/scripts/` must be dropped, with its leading comments.
2. **The generated checkout is shallow.** locklane's build-inputs step diffs against `origin/main` and needs full history, which the old CI had through `fetch-depth: 0`. The generated checkout must have it.
3. **A consumer's own skill rows land in the leftovers file.** locklane's `/l-release` row from the old pipeline slot should go into `AGENTS.md`'s project notes as a small table, not into `REPLACED.md`.
4. **Branch protection is replaced wholesale, or left blocking the adoption PR.** locklane is public, requires the old `checks` and `cold-review` contexts, and enforces them on admins. With `--no-protect` the adoption PR can never merge, because it deletes the workflows that produced those contexts; without it, `protect.sh` replaces the whole protection document, dropping review rules and admin enforcement. `protect.sh` must read the existing protection and change only the required-checks list: remove the old template's two contexts in replace mode, add `t-workflow`, add `build` when the installer wrote `build.yml`, and leave everything else exactly as it was. With no existing protection it applies the minimal set as today.

## Done when
- In the generated `build.yml`, a slot step whose lines mention `.t-workflow/scripts/` is dropped together with the comment lines directly above it; the checkout step carries `fetch-depth: 0`.
- Rows of the old pipeline slot (`| \`/x\` | … |`) are written into `AGENTS.md` under a "Skills of this repository" table after the project notes, and are not reported in `REPLACED.md`.
- `protect.sh` takes `--remove <context>` and `--add <context>` (repeatable). With existing protection it sends a PATCH to the required-status-checks endpoint only, with the merged list, and prints the list before and after; with none it applies the minimal set. The installer calls it with `--remove checks --remove cold-review` in replace mode and `--add build` when it wrote `build.yml`.
- `tests/test.sh` covers: the dropped step and its comments, the checkout depth, the skill-row table, and `protect.sh` against a stubbed `gh` for both the merge and the no-protection cases, asserting the exact request body.
- Read-only dry run of the installer on a scratch copy of locklane's tree yields a `build.yml` without the manifest step, with `fetch-depth: 0`, and an `AGENTS.md` carrying the `/l-release` row.

## Explicitly not
- The rest of #12: the dirty-tree and collision refusals, the printed plan, and the license.
- Requiring a consumer's other checks; only `build` is added, and only when the installer wrote it.

## Decisions made along the way
- A comment at the list level of the old slot belongs to the step after it, so a dropped step takes its comment with it and a kept step keeps its own (agent, 2026-09-09).
- `protect.sh` never sends the whole protection document when one exists; only the required-checks endpoint is written, with `strict` carried over (agent, 2026-09-09).

## Deviations / notes
- Verified read-only against a scratch copy of locklane's real tree: the manifest-check step and its comment dropped, the build-inputs logic and the cache step kept with their comments, `fetch-depth: 0`, YAML valid, the `/l-release` row in `AGENTS.md`, no leftovers file, ADRs 100–109 and the three architecture documents kept.
- Fix pass after the cold review, all eight findings at the human's ask: `protect.sh` decides by the HTTP status it read — the minimal set only on a confirmed 404, a plan refusal on 403, and any other read failure stops it with nothing written; empty argument lists use the bash 3.2-safe expansion in both scripts; a protection with no required-checks rule (reviews only) gets one enabled with every existing rule carried over; the error file comes from `mktemp`; removed contexts are matched literally; text beside the skill rows in the old pipeline slot is reported instead of dropped, and a trailing comment in the CI slot is kept; the README sentence reads whole again; the dead stub case is gone. Tests cover each status path and the two slot cases.
- The plan's third point (branch protection) was first proposed as a hand step and corrected at the human's question before this task was opened.
