# 24 — Ask every human decision as a structured question with fixed options, so the agent CLI notifies
Issue: #24

## Asked
Make every stop that needs the human's decision reach them the same way. Today the skills ask in two different shapes. `/t-ship` step 4 ends its message with the prose sentence "Merge PR #<pr> into <trunk>?"; `/t-work` says "confirm before editing" and, with no id, "list open tasks and ask"; `/t-cancel` step 2 asks a proceed / cancel too / leave decision per neighbour, all as prose. A prose question ends the turn and the agent CLI treats it as an ordinary idle prompt: in Claude Code the desktop notification only fires after the idle timeout, and Claude Desktop shows nothing at all until then. A question asked through the CLI's structured question tool (Claude Code's `AskUserQuestion`, and its equivalents elsewhere) is treated as "input needed" and notifies at once. Which shape a given run uses currently depends on the model's reading of the skill text, so the human is notified for some merge gates and not for others. The rules never name a shape, and the skills that come closest only imply one.

The fix is one rule in `.t-workflow/AGENTS.md` under Communication, stating how a human decision is asked, plus the four skills that carry such a decision restating their question and options in that shape. The rule stays agent-agnostic: it names "the structured question the agent CLI offers, when it has one", and falls back to the last sentence of the message otherwise. Stops that ask nothing, such as `/t-plan`'s "stop and name `/t-work`", `/t-review` step 7, `/t-work` section 7, any `BLOCKED:` line, red CI, a dirty tree or a rebase conflict, are unchanged: they end the turn with a report and the next command, and notifying for those is the harness's job, not the workflow's.

## Done when
- `.t-workflow/AGENTS.md` § Communication carries one rule, in substance: a stop that needs the human's decision is asked as a question with fixed options, through the structured question the agent CLI offers when it has one, and as the last sentence of the message otherwise; the evidence goes in the message before the question; nothing continues on silence.
- `.claude/skills/t-ship/SKILL.md` step 4 states its gate as question `"Merge PR #<pr> into <trunk>?"` with options `merge` / `no`, keeping the evidence paragraph, "do not merge on silence", and the `gh pr ready <pr> --undo` on `no` exactly as they are; step 7 states the parent-closing ask as a question with options `close` / `leave open`, still never automatic.
- `.claude/skills/t-work/SKILL.md`: with no id, the open tasks are the options of one question; "confirm before editing" becomes a question `"Work #<id> now?"` with options `work` / `not now`.
- `.claude/skills/t-cancel/SKILL.md` step 2 says each neighbour is one question with the three options it already names: `proceed` / `cancel too` / `leave`.
- `.claude/skills/t-drive/SKILL.md` changes no behaviour; its "report at every stop" line points at the AGENTS.md rule rather than restating it.
- No skill gains a new stop, and no stop that asks nothing today gains a question.
- `grep -n "Merge PR #<pr> into <trunk>?" .claude/skills/t-ship/SKILL.md` still matches, and `tests/test.sh` passes.

## Explicitly not
- Hooks. A notification hook (desktop notifier, terminal bell, push) is per-user harness configuration; the template does not ship one for any agent CLI.
- Notifying on stops that ask nothing. Those already end the turn; the idle notification of the CLI, or the host's own attention signal, covers them.
- Naming any one agent CLI's tool in the rule. The rule describes the shape; each CLI's skill loader maps it to whatever that CLI offers.
- Consumer-local skills (a consumer's own `/x-*` skill that asks a question) — they follow the rule on their own once it exists.

## Decisions made along the way
- Kept the AGENTS.md rule and all five skill edits agent-agnostic: none of them names Claude Code's `AskUserQuestion` or any other CLI's tool, per the issue's own non-goal.
- t-drive's "report at every stop" line now points at the AGENTS.md rule instead of restating it, so the shape lives in one place.

## Deviations / notes
- none
