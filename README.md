# t-workflow

A small delivery workflow for repositories worked by AI coding agents. Every change
starts from an issue, carries a record, and reaches the trunk only through a pull
request a human confirmed. Skills are the [Agent Skills](https://agentskills.io)
format, so Claude Code, Codex, Gemini CLI, Copilot, and others run them; nothing here
depends on one agent.

## Install

From the trunk branch of a clean checkout, with `gh` authenticated:

```bash
curl -fsSL https://raw.githubusercontent.com/t-workflow/t-workflow/main/install.sh | bash
```

That installs the newest tag; to pin one, append it:
`… | bash -s -- <tag>`. It opens an issue, a branch, and a pull request that adds
t-workflow, and sets branch protection: a repository that already has protection keeps
every rule it had, and only the required-checks list changes to include `t-workflow`;
a second rule protects every initiative's integration branch (`wip/*-integration`) the
same way, deletions allowed. Review the PR — in particular the detected check command in
`.t-workflow/config` — and merge it. The workflow is in force from then on.

Options: `--check "<cmd>"` to name the build/test command, `--no-protect` to leave
GitHub settings alone, `--no-pr` to change files only.

A repository that carries the old template-based t-workflow (it has
`.template-manifest.json`) runs the same command: the old files are removed, its local
slots move into `.t-workflow/config` and `AGENTS.md`, and anything without an
automatic home is listed in `.t-workflow/REPLACED.md`.

## Update

Ask your agent to `/t-update`, or run the same install command again. Every
t-workflow-owned file is replaced with the release's copy; `AGENTS.md` and
`.t-workflow/config` are never touched, except that a key a release added is appended
with its default. The update PR's diff, and the commits between the two tags that the
installer prints, are the changelog. A release is a tag; nothing else.

## What lands in your repository

| Path | Owner |
|---|---|
| `.t-workflow/AGENTS.md` | t-workflow — the contract, about 3 KB, read at session start |
| `.t-workflow/scripts/` | t-workflow — gates, CI, record, snapshot |
| `.claude/skills/t-*/` and the `.agents/skills` symlink | t-workflow — nine skills |
| `.github/workflows/t-workflow.yml` | t-workflow — runs the workflow gates on every PR; your build stays in your own CI |
| `docs/tasks/TEMPLATE.md` | t-workflow — the record shape |
| `.t-workflow/VERSION` | t-workflow — the installed tag |
| `.t-workflow/config` | **you** — check command, protected paths, exempt branches, reviewer model |
| `AGENTS.md` (`CLAUDE.md`, `GEMINI.md` symlink to it) | **you** — one pointer line, then your own notes |
| `docs/tasks/<id>-<slug>.md` | **you** — one record per task |

Owned files are copied verbatim and replaced wholesale on update. An edit to one is
overwritten next time; put customization in the two files you own. The installed
files are MIT-licensed copies you may keep under your own license.

## The pipeline

| Skill | Stage |
|---|---|
| `/t-open` | Conversation → issue(s). How all work starts. |
| `/t-plan` | Allowed paths, risks, checks onto the issue. Required before a protected diff. |
| `/t-work` | Branch, record, implement, checks, draft PR. Again on the same task to address findings. |
| `/t-review` | Cold, read-only review with a readiness verdict. Required before shipping a protected diff. |
| `/t-ship` | Human-confirmed squash merge. |
| `/t-cancel` | Abandon a task with the reason and every dependent decided. |
| `/t-drive` | Chains the stages for a task, or a parent's children in order, stopping at the parent's merge gate. |
| `/t-status` | What is in flight. |
| `/t-update` | Newer t-workflow release, as an ordinary task. |

An initiative (a parent issue with children) lands as one change: each child's PR
merges mechanically into `wip/<parent>-integration`, and the human confirms once, on
the parent's PR from that branch to the trunk.

The rules are in [`.t-workflow/AGENTS.md`](.t-workflow/AGENTS.md). Protected paths
(the workflow's own files, CI, the instruction files, plus whatever `config` adds) need
a plan before and a cold review after; everything else needs an issue, a record, and a
confirmed merge. CI enforces the record, title, plan, review, and blocker rules
mechanically. Your build runs in your own CI, as before; the check command in the
config is what the agent runs locally before opening a PR.

## This repository

Uses itself. `tests/test.sh` is its check command; `docs/decisions.md` holds the
reasoning behind its shape. `install.sh`, `tests/`, and this README never reach a
consumer. Nothing in the tree names a version: a release is a tag on `main`.
