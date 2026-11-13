# Fetching a pull request

Commands for both hosts, plus the surrounding context. Read this before any API
call. Everything here is read-only.

---

## Bitbucket

Auth is HTTP Basic with `email:token`. The token is an Atlassian API token with
scopes, not an App Password — those are deprecated.

```bash
TOKEN=$(cat ~/.config/.env.BITBUCKET_API_TOKEN)
EMAIL="<your atlassian email>"
API="https://api.bitbucket.org/2.0/repositories/{org}/{repo}/pullrequests/{id}"
bb() { curl -sL -u "$EMAIL:$TOKEN" "$@"; }
```

**Always pass `-L`.** Several endpoints answer with a 302.

| Want | Call |
|---|---|
| Metadata, description, state | `bb "$API"` |
| Files changed with churn | `bb "$API/diffstat?pagelen=100"` |
| Raw unified diff | `bb "$API/diff"` |
| Commits | `bb "$API/commits?pagelen=100"` |
| Review comments | `bb "$API/comments?pagelen=100"` |
| Approvals and state | `bb "$API" \| jq '.participants[] \| {user: .user.display_name, approved}'` |

Note the path spelling: the API uses `pullrequests`, the browser URL uses
`pull-requests`.

Useful shapes:

```bash
# files and line counts, biggest first
bb "$API/diffstat?pagelen=100" |
  jq -r '.values[] | "\(.lines_added + .lines_removed)\t+\(.lines_added)\t-\(.lines_removed)\t\(.new.path // .old.path)"' |
  sort -rn

# comments as a flat thread, inline anchors kept
bb "$API/comments?pagelen=100" |
  jq -r '.values[] | select(.deleted | not) |
         "\(.user.display_name) [\(.inline.path // "general"):\(.inline.to // .inline.from // "-")] \(.content.raw)"'
```

---

## GitHub

Use the `gh` CLI. It carries its own auth — check with `gh auth status`.

| Want | Call |
|---|---|
| Metadata, body, state | `gh pr view {id} --repo {org}/{repo} --json title,body,state,author,baseRefName,headRefName,additions,deletions,changedFiles` |
| Files changed with churn | `gh pr view {id} --repo {org}/{repo} --json files` |
| Raw unified diff | `gh pr diff {id} --repo {org}/{repo}` |
| Commits | `gh pr view {id} --repo {org}/{repo} --json commits` |
| Review comments | `gh pr view {id} --repo {org}/{repo} --json comments,reviews` |
| Linked issues | `gh pr view {id} --repo {org}/{repo} --json closingIssuesReferences` |

```bash
# files and line counts, biggest first
gh pr view {id} --repo {org}/{repo} --json files |
  jq -r '.files[] | "\(.additions + .deletions)\t+\(.additions)\t-\(.deletions)\t\(.path)"' |
  sort -rn
```

`gh pr diff` gives a plain unified diff — the same text the Bitbucket `/diff`
endpoint returns, so downstream handling is identical.

---

## Reading the diff well

The diff alone misleads. Three habits fix that.

**Read the changed files whole.** Fetch each file at both refs and read them, not
just the hunks. A two-line change to a guard clause can invert a contract, and
the hunk shows none of the surrounding logic that makes it matter.

```bash
# Bitbucket
bb "https://api.bitbucket.org/2.0/repositories/{org}/{repo}/src/{commit}/{path}"
# GitHub
gh api "repos/{org}/{repo}/contents/{path}?ref={commit}" --jq '.content' | base64 -d
```

**Rank by meaning, not size.** A 400-line lockfile update is noise. A 3-line
change to an auth check is the PR. Sort by churn to find candidates, then judge
each one. Say in the artefact which files were mechanical, and move on.

**Find the test that names the bug.** New or changed tests are the most reliable
statement of intent in the whole PR. The assertion message usually *is* the
before state, already written in words.

```bash
# tests touched by the PR
<diff command> | grep -E '^\+\+\+ .*(test|spec)' | sed 's/^+++ b\///'
```

---

## Reproducing the before state

The strongest evidence, when the repo is checked out locally and the PR adds a
test:

```bash
git fetch origin pull/{id}/head:pr-{id}        # GitHub
git fetch origin pull-requests/{id}/from:pr-{id}  # Bitbucket

BASE=$(git merge-base HEAD pr-{id})
git checkout -b before-{id} "$BASE"
git checkout pr-{id} -- <path/to/new/test>     # the test only, not the fix
<run the test>                                  # the failure IS the before state
```

Capture the failure output verbatim. That text, trimmed, belongs in the
artefact — it is the most convincing before state available, because the program
wrote it.

Clean up the scratch branches when done.

If the repo is not checked out, or the test needs a service that is not running,
trace the old path by hand instead and say in the artefact that the trace is
derived by reading, not by running.

---

## Linked ticket

The branch name, PR title, description and commit messages usually carry the
key. Match `[A-Z][A-Z0-9]+-[0-9]+` across all four.

With the Atlassian MCP tools available, fetch the issue for the reported
symptom, the steps to reproduce and the severity. The symptom is what the before
state has to show.

Treat the ticket as the reporter's account, not as fact. When the diff and the
ticket disagree about the cause, the diff wins — and the disagreement itself is
worth a line in the artefact.

---

## Team discussion

Worth a search when the PR is contentious or the description is thin. The Slack
skill at `~/.claude/skills/slack/SKILL.md` has the API reference and the
channel-enumeration pattern.

Search for the PR number, the branch name and the ticket key. Take decisions and
disagreements. Ignore chatter.

Never quote a person by name in the artefact. Attribute to the review, not to
the reviewer: "raised in review" rather than a name. The artefact outlives the
conversation and gets forwarded.
