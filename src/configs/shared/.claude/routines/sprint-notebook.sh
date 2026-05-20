#!/bin/bash
# Sprint Review Notebook - Generate a visual sprint review as a Jupyter notebook
# Schedule: Friday at 4:15pm
# Cron: 15 16 * * 5

set -euo pipefail
mkdir -p ~/.claude/routines/logs

# LaunchAgents have a minimal environment — load secrets and PATH
source /usr/local/bin/os/source_env_files.sh 2>/dev/null || true
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
mkdir -p ~/Coding/Research/notebooks/sprints

WEEK=$(date +%V)
YEAR=$(date +%Y)
OUTPUT_PATH="$HOME/Coding/Research/notebooks/sprints/${YEAR}-W${WEEK}-sprint.ipynb"

PROMPT="Generate a Jupyter notebook for this week's sprint review.

## Output
Create the notebook at: $OUTPUT_PATH

## Steps

1. Get my Atlassian user info to identify my account
2. Search for tickets completed this sprint:
   project = APPS AND sprint in openSprints() AND status in (Done, Closed) ORDER BY resolved DESC
3. Search for tickets still in progress:
   project = APPS AND sprint in openSprints() AND status not in (Done, Closed) AND resolution = Unresolved ORDER BY priority DESC
4. Search for tickets completed in the last 4 sprints for velocity data:
   project = APPS AND sprint in closedSprints() AND status in (Done, Closed) AND resolved >= startOfWeek(-4w) ORDER BY resolved DESC

## Notebook Structure

Build the notebook with these cells (use NotebookEdit):

### Cell 1 — Markdown header
Title: Sprint Review — Week $WEEK, $YEAR
Date, sprint name, total ticket counts

### Cell 2 — Imports
pandas, matplotlib, plotly.express, plotly.graph_objects, seaborn, numpy, datetime
Set up plotting style (whitegrid, figsize 14x7)

### Cell 3 — Data setup
Create DataFrames from the Jira ticket data gathered above.
Include columns: key, summary, type, priority, status, story_points (if available), assignee, resolved_date

### Cell 4 — Completion summary table
Display a styled pandas table of completed tickets with key, summary, type, points

### Cell 5 — Status breakdown pie chart
plotly pie chart: Done vs In Progress vs To Do vs Blocked

### Cell 6 — Tickets by type bar chart
Bar chart grouping completed tickets by type (Bug, Story, Task, etc.)

### Cell 7 — Velocity trend (if historical data available)
Line chart showing story points or ticket count completed per sprint over last 4 sprints

### Cell 8 — Remaining work table
Table of tickets still in progress with key, summary, status, assignee

### Cell 9 — Summary markdown
Key metrics: completion rate, points completed, blockers identified
One-paragraph narrative summary of the sprint

## Notes
- Use plotly for interactive charts where possible, matplotlib as fallback
- Include the raw data in the notebook so it can be re-analyzed
- If story points are not available, use ticket count as the metric
- Make the notebook self-contained — all data should be inline, not requiring live API calls to render"

echo "=== Sprint Notebook - $(date) ==="
echo "$PROMPT" | claude --print
