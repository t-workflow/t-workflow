# 47 — The installer's preflight accepts any signed-in account, so a no-access repository fails late in GitHub's words
Issue: #47

## Asked

The installer's preflight accepts any signed-in GitHub account instead of checking
that the account can actually see this repository, so an access problem is reported
late and in GitHub's words rather than early and in the installer's.

`install.sh` guards its GitHub work with `command -v gh` and `gh auth status`.
`gh auth status` exits 0 whenever *some* account is authenticated — it says nothing
about the repository the installer is being run in. When the authenticated account has
no access to that repository (a second account, a private repository in another
organization), the preflight passes and the run continues. The first call that needs
the repository is `repo_nwo()` in `.t-workflow/scripts/lib.sh` (`gh repo view --json
nameWithOwner`), reached from `.t-workflow/scripts/protect.sh`, which fails with
GitHub's GraphQL wording:

```
GraphQL: Could not resolve to a Repository with the name '<owner>/<repo>'. (repository)
```

GitHub returns "not found" rather than "no access" for a private repository the token
cannot see, so the message reads as though the repository does not exist. Nothing in it
names the account in use or the remedy, and by the time it appears the run is already
past its preflight.

The preflight should establish what it is actually guarding: that the signed-in account
can reach the repository this tree points at. When it cannot, the installer stops before
doing any work, names the repository, the account it is signed in as, and what to do
(sign in as an account with access, or `--no-pr` to change files only).

## Done when

- Running the installer with an authenticated account that cannot see the repository
  stops during the preflight, before any file, issue, branch, or PR is created, and
  before `protect.sh` runs.
- The failure message names the repository, the account in use, and both remedies
  (sign in with an account that has access; `--no-pr`).
- `--no-pr` still runs with no GitHub access at all, and with `gh` absent.
- `tests/test.sh` passes.

## Explicitly not

- Changing how `.t-workflow/scripts/protect.sh` or `repo_nwo()` report their own
  failures; only the preflight moves.
- Choosing, switching, or authenticating a GitHub account on the user's behalf.

## Decisions made along the way
- The preflight runs `gh repo view` (what `repo_nwo()` runs), so it tests exactly what the
  later scripts need. The repository name in the message comes from the `origin` URL,
  since `gh` cannot name a repository it cannot see; the account comes from `gh api user`.
- New test: a stub `gh` that is signed in but cannot see the repository stops the run
  before any file changes or `gh issue create`; the same stub with `--no-pr` succeeds.
  The existing worktree stub now answers `repo view`.

## Deviations / notes
- none

## Checks
- `bash tests/test.sh` — PASS (253 passed, 0 failed)

## Agents
- work: claude-code / claude-opus-5-5
