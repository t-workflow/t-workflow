---
name: t-update
description: Move this repository's t-workflow to a newer release as an ordinary task — the installer opens the issue, branch, record, and PR; consumer actions from the changelog are applied by hand. Use to update or sync t-workflow.
---

# Update t-workflow

`/t-update <tag>`; with no tag, the latest release
(`gh release view --repo t-workflow/t-workflow --json tagName -q .tagName`).

1. Current version: `cat .t-workflow/VERSION`. Same as `<tag>` → nothing to do.
2. Run the release's own installer; it opens the issue, creates the branch, replaces
   every t-workflow-owned file, writes the record, and opens the PR:

```bash
curl -fsSL https://raw.githubusercontent.com/t-workflow/t-workflow/<tag>/install.sh | bash -s -- <tag>
```

3. Read `CHANGELOG.md` at `<tag>` for every release after the current version. A
   **Consumer actions** entry names something the installer cannot do: a new config
   key, a changed convention. Apply each one on the branch, note it in the record,
   commit, push.
4. Report what changed between the versions in plain language, which consumer actions
   were applied, and the PR URL. The update touches protected paths, so a cold review
   comes before shipping: name `/t-drive <id>`, which runs `/t-review` and `/t-ship`
   and stops at the merge question, or the two commands separately.
