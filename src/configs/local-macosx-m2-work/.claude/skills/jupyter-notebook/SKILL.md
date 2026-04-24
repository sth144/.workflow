# Skill: Jupyter Notebook

## When to Use
Use this skill when the user wants to create, populate, or promote work into a
Jupyter notebook. Trigger phrases include: "notebook", "notebook for", "notebook this",
"visualize this", "explore [table]", "investigate [ticket]", "sprint notebook",
"weekly notebook".

## Prerequisites
- Python 3.11+ with jupyter, pandas, matplotlib, plotly, seaborn, sqlalchemy, psycopg2
- For ESP DB notebooks: PostgreSQL connection accessible
- For Jira notebooks: Atlassian MCP server connected
- Utility library at `~/.claude/skills/jupyter-notebook/lib/jupyter_utils.py`

## Notebook Locations
- **Research notebooks**: `~/Coding/Research/notebooks/<topic>/`
- **Weekly daybook notebooks**: `~/Coding/Research/daybook/YYYY-WXX.ipynb`
- **Ticket investigations**: `~/Coding/Research/notebooks/<TICKET-KEY>/`
- **Sprint reviews**: `~/Coding/Research/notebooks/sprints/YYYY-WXX-sprint.ipynb`

## Templates
Templates are stored at `~/.claude/skills/jupyter-notebook/templates/`:

| Template | Use Case |
|----------|----------|
| `esp-db-explore.ipynb` | ESP PostgreSQL exploration with EAV patterns |
| `sprint-review.ipynb` | Sprint metrics, burndown, velocity charts |
| `incident-analysis.ipynb` | Production incident timeline and log analysis |
| `ticket-investigation.ipynb` | Bug investigation tied to a Jira ticket |

## Instructions

### Creating a Notebook from Template

1. Determine the appropriate template based on the request
2. Create the notebook using the CLI:
   ```bash
   python ~/.claude/skills/jupyter-notebook/lib/jupyter_utils.py create \
     --template <template-name> \
     --output <output-path> \
     --title "Notebook Title" \
     [--ticket ESP-123] \
     [--table entity_type]
   ```
3. If the user wants specific content beyond the template, use NotebookEdit to
   add or modify cells
4. Offer to open in VSCode: `code <output-path>`

### "Notebook This" — Promoting Current Work

When the user says "notebook this" or "visualize this" during a session:

1. Identify the SQL query, data, or analysis from the current conversation
2. Create a new notebook at `~/Coding/Research/notebooks/YYYY-MM-DD_<topic>.ipynb`
3. Add cells:
   - Markdown header with context (what was being explored, why)
   - Import cell (pandas, matplotlib, relevant DB libraries)
   - The SQL query wrapped in `pd.read_sql()`
   - A visualization cell appropriate to the data shape
   - A summary/findings markdown cell
4. Offer to link the notebook from the Joplin daybook entry

### Ticket Investigation Notebook

When the user says "notebook for ESP-456" or similar:

1. Look up the ticket in Jira to get summary, description, component
2. Create directory: `~/Coding/Research/notebooks/ESP-456/`
3. Create notebook from `ticket-investigation.ipynb` template:
   ```bash
   python ~/.claude/skills/jupyter-notebook/lib/jupyter_utils.py create \
     --template ticket-investigation \
     --output ~/Coding/Research/notebooks/ESP-456/investigation.ipynb \
     --title "ESP-456 Investigation" \
     --ticket ESP-456
   ```
4. Use NotebookEdit to add the ticket summary, description, and
   pre-populate relevant DB queries based on the ticket's component/labels
5. Offer to open in VSCode

### Weekly Daybook Notebook

Created automatically by the `weekly-notebook.sh` routine on Fridays, or on demand.

- Location: `~/Coding/Research/daybook/YYYY-WXX.ipynb`
- Contains: Week summary, visualization scratchpad, links to Joplin entries
- To create manually:
  ```bash
  python ~/.claude/skills/jupyter-notebook/lib/jupyter_utils.py create \
    --template esp-db-explore \
    --output ~/Coding/Research/daybook/$(date +%Y-W%V).ipynb \
    --title "Week $(date +%V) Daybook — $(date +'%B %Y')"
  ```

### Sprint Review Notebook

Created automatically by the `sprint-notebook.sh` routine on Fridays, or on demand.

- Location: `~/Coding/Research/notebooks/sprints/YYYY-WXX-sprint.ipynb`
- To create manually:
  ```bash
  python ~/.claude/skills/jupyter-notebook/lib/jupyter_utils.py create \
    --template sprint-review \
    --output ~/Coding/Research/notebooks/sprints/$(date +%Y-W%V)-sprint.ipynb \
    --title "Sprint Review — Week $(date +%V)"
  ```

## Linking Notebooks to Joplin

After creating a notebook, offer to add a reference in the Joplin daybook:
```
[notebook: <title>](file:///Users/seanhinds/Coding/Research/notebooks/<path>)
```

## Error Handling
- **Missing dependencies**: Suggest `pip install pandas matplotlib plotly seaborn sqlalchemy psycopg2-binary jupyter`
- **DB connection fails**: Check ESP is running and `ESP_DB_*` env vars are set
- **Template not found**: Run `python ~/.claude/skills/jupyter-notebook/lib/jupyter_utils.py list` to show available templates
- **Directory doesn't exist**: The CLI creates parent directories automatically
