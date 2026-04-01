# Global Claude Code Configuration

## About Me

- Name: Sean
- Primary stack: Python, TypeScript, Git
- Editor: VSCode with Claude Code integration

## General Preferences

- Prefer concise explanations over verbose ones
- Use conventional commits (feat:, fix:, docs:, refactor:, etc.)
- Prefer small, incremental changes over large rewrites

## Persistent Memory

- You have access to a Joplin MCP server. If it is available and working, try to use this for persistent memory in addition to your built-in mechanisms. You may read from any notebooks within the library, and write freely to the `Areas / Agents` notebook. You may write to other notebooks as well, but do so cautiously.
- When the user refers to "drawer" or "desktop", they are referring to $HOME/Drawer or $HOME/Desktop, where there may be files relevant to a task for you to reference, such as screenshots.

## Workflow

- When tackling complex tasks, use sub-agents to isolate concerns
- Before making architectural changes, research the current state first
- After code changes, verify with a testing sub-agent

Follow this general workflow for large tasks:

```
1. Plan First
2. Verify Plan
3. Track Progress
4. Explain Changes
5. Document Results
6. Capture Lessons
```

### 1. Plan Mode Default

- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately — don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy

- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop

- After ANY correction from the user, make a persistent note of the pattern. Update the Joplin note `Areas / Agents / lessons.md` or another note in that notebook if it makes sense, in addition to updating `tasks/lessons.md`. If the Joplin MCP server is not available, update only `tasks/lessons.md`
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done

- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: “Would a staff engineer approve this?”
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)

- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes — don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing

- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Skills

@~/.claude/skills/fetch-jira-tickets.md

## Agents

- `documentation-agent` — documentation tasks (docstrings, READMEs, API docs)
- `test-development-agent` — test writing (unit, integration, E2E)
- `code-review-agent` — code review (correctness, security, performance, style)
- `architecture-agent` — system design, refactoring strategy, dependency analysis
- `atlassian-agent` — Jira and Confluence (tickets, sprints, wiki pages)

## Coding Standards

- Python: follow PEP 8, use type hints, write docstrings for public functions
- Shell scripts: indent with 2 tabs per level
- Use virtual environments for Python projects
- Handle errors explicitly — no bare `except:` clauses
- Log meaningful messages at appropriate levels
- Simplicity First
- No Laziness
- Minimal Impact

## Secrets & Tokens

- Bitbucket API token: `~/.config/.env.BITBUCKET_API_TOKEN`
  - This file contains the raw token value (no `export` prefix)

## Bitbucket API

- **Auth method**: HTTP Basic — `email:token` (read token from `~/.config/.env.BITBUCKET_API_TOKEN`)
- **Token type**: Atlassian API token with scopes (not an App Password — those are deprecated)
- **Auth setup**: `TOKEN=$(cat ~/.config/.env.BITBUCKET_API_TOKEN)` then use `-u "{email}:$TOKEN"` with curl
- **Important**: Always pass `-L` to curl (the API returns 302 redirects on some endpoints)

### Common Bitbucket API Endpoints

- **Current user**: `GET /user`
- **List repos**: `GET /repositories/{organization}?pagelen=100`
- **Open PRs for a repo**: `GET /repositories/{organization}/{repo}/pullrequests?state=OPEN`
- **PR details**: `GET /repositories/{organization}/{repo}/pullrequests/{id}`
- **PR diffstat** (files changed): `GET /repositories/{organization}/{repo}/pullrequests/{id}/diffstat`
- **PR diff** (raw diff): `GET /repositories/{organization}/{repo}/pullrequests/{id}/diff`
- **PR comments**: `GET /repositories/{organization}/{repo}/pullrequests/{id}/comments`
- **PR commits**: `GET /repositories/{organization}/{repo}/pullrequests/{id}/commits`

### Parsing Bitbucket PR URLs

Given a URL like `https://bitbucket.org/{organization}/{repo}/pull-requests/{id}`, extract:

- `repo` = the repo slug
- `id` = the PR number
  Then use the API endpoints above (note: API uses `pullrequests`, URLs use `pull-requests`)

## Git Workflow

- Branch naming: `feature/`, `fix/`, `docs/`, `refactor/` prefixes
- Keep commits atomic and focused
- Write descriptive commit messages explaining _why_, not just _what_
