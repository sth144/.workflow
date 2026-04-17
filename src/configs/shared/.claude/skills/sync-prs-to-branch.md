# Skill: Sync Open PRs to Target Branch

## When to Use

Use this skill when the user wants to update/sync all open pull request branches
with a target branch (e.g., merge `master` into all open PR branches). Trigger
phrases include: "sync PRs", "update PRs", "merge master into PRs",
"sync branches", "update all open PRs".

## Prerequisites

- Must be inside a git repository with a Bitbucket remote
- Bitbucket API token available at `~/.config/.env.BITBUCKET_API_TOKEN`
- The user's Bitbucket email and org are configured in CLAUDE.md
- Working tree must be clean (no uncommitted changes)

## Parameters

- **target_branch**: The branch to sync into PR branches (default: `master`).
  Ask the user if not obvious from context.
- **repo**: The Bitbucket repo slug. Infer from the current git remote if not
  provided.
- **org**: The Bitbucket workspace/org. Infer from the current git remote if
  not provided.
- **dry_run**: If the user says "dry run" or "just check", only report status
  without performing merges.

## Instructions

### Step 1: Validate preconditions

1. Run `git status --porcelain` to confirm the working tree is clean. If not,
   stop and tell the user to commit or stash changes first.
2. Record the current branch with `git symbolic-ref --short HEAD` so it can be
   restored at the end.
3. Parse **org** and **repo** from the git remote if not provided:
   ```bash
   git remote get-url origin
   ```
   Extract from the URL pattern `bitbucket.org/{org}/{repo}` (strip `.git`
   suffix if present).

### Step 2: Fetch latest from remote

```bash
git fetch origin
```

### Step 3: List open PRs targeting the branch

Use the Bitbucket API to list open PRs whose destination is the target branch:

```bash
TOKEN=$(cat ~/.config/.env.BITBUCKET_API_TOKEN)
curl -sL -u "{email}:$TOKEN" \
  "https://api.bitbucket.org/2.0/repositories/{org}/{repo}/pullrequests?state=OPEN&pagelen=50"
```

Filter the results to only PRs where `destination.branch.name` equals the
target branch. Extract for each PR:

- `id` — PR number
- `title` — PR title
- `source.branch.name` — the branch to sync
- `author.display_name` — who opened it

If there are multiple pages (`next` field in response), follow pagination to
collect all PRs.

### Step 4: Attempt merge for each PR branch

For each PR branch (in alphabetical order by branch name):

1. **Check if already up to date**:

   ```bash
   git merge-base --is-ancestor origin/{target_branch} origin/{source_branch}
   ```

   If exit code is 0, the branch is already up to date — skip it and note it
   as "already synced".

2. **Check for merge conflicts** (dry check):

   ```bash
   git checkout origin/{source_branch} --detach
   git merge --no-commit --no-ff origin/{target_branch}
   ```

   - If this succeeds (exit code 0): the merge is clean.
   - If this fails: there are conflicts. Run `git merge --abort` and record
     the branch as having conflicts.
   - Either way, run `git merge --abort 2>/dev/null; git checkout -` to clean
     up after the dry check.

3. **Perform the actual merge** (if clean and not a dry run):
   ```bash
   git checkout {source_branch}
   git pull origin {source_branch}
   git merge origin/{target_branch} --no-edit -m "chore: sync {source_branch} with {target_branch}"
   git push origin {source_branch}
   ```
   If the push fails (e.g., force-push protection, permissions), record the
   error and move on to the next branch.

### Step 5: Restore original state

```bash
git checkout {original_branch}
```

### Step 6: Report results

Present a summary table grouped by outcome:

**Synced successfully:**

- **PR #123** `feature/foo` — "Add foo feature" (by Alice)

**Already up to date:**

- **PR #456** `fix/bar` — "Fix bar bug" (by Bob)

**Merge conflicts (skipped):**

- **PR #789** `feature/baz` — "Redesign baz" (by Carol)

**Errors:**

- **PR #101** `refactor/qux` — push failed: permission denied

Include totals: "Synced 3, already current 2, conflicts 1, errors 0"

## Error Handling

- If working tree is dirty: stop immediately, ask user to commit/stash
- If Bitbucket API returns 401/403: advise checking the API token
- If no open PRs found: inform user, confirm the repo and target branch
- If a branch no longer exists on the remote: skip it, note it in the report
- If git checkout fails mid-process: attempt `git merge --abort` and
  `git checkout {original_branch}` before reporting the error
- Always restore the original branch, even if errors occur (use a finally-style
  pattern: attempt restore after each failure path)

## Safety

- Never force-push. Only fast-forward or merge-commit pushes.
- Never modify the target branch itself.
- Never delete any branches.
- If a merge produces an unexpected state, abort and skip that branch.
- The skill is idempotent: running it again will report already-synced branches
  as "already up to date".
