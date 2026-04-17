#!/bin/bash
# Jira Daily Digest - Morning summary of assigned tickets
# Schedule: Weekdays 8am
# Cron: 0 8 * * 1-5

set -euo pipefail
mkdir -p ~/.claude/routines/logs

PROMPT='You are my daily Jira assistant. Generate a morning digest of my work queue.

## Steps

1. Get my Atlassian user info to identify my account
2. Search for my assigned tickets using JQL:
   assignee = currentUser() AND resolution = Unresolved ORDER BY priority DESC, updated DESC
3. Also check for tickets I am watching that are blocked:
   watcher = currentUser() AND status = Blocked AND resolution = Unresolved

## Output Format

### 🔴 Needs Attention
- Tickets blocked or stale (no update in 5+ days)
- High-priority items not yet started

### 🟡 In Progress
- Active work with recent updates
- Note any approaching due dates

### 🟢 Ready to Start
- Prioritized backlog items
- Quick wins (tasks < 2 hours estimated)

### 📊 Sprint Health
- Total tickets and completion rate
- Blockers affecting the team

## Notes
- Flag tickets missing estimates or descriptions
- Keep it scannable — bullet points, not paragraphs
- Be concise, this is a daily summary not a deep dive'

# Read any additional context from stdin if provided
EXTRA_CONTEXT=""
if [ ! -t 0 ]; then
    EXTRA_CONTEXT=$(cat)
fi

if [ -n "$EXTRA_CONTEXT" ]; then
    PROMPT="$PROMPT

## Additional Context
$EXTRA_CONTEXT"
fi

echo "=== Jira Daily Digest - $(date) ==="
echo "$PROMPT" | claude --print
