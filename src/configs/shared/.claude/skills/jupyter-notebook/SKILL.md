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
- **Research notebooks**: `~/notebooks/<topic>/`
- **Weekly daybook notebooks**: `~/notebooks/daybook/YYYY-WXX.ipynb`
- **Ticket investigations**: `~/notebooks/<TICKET-KEY>/`
- **Sprint reviews**: `~/notebooks/sprints/YYYY-WXX-sprint.ipynb`

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
2. Create a new notebook at `~/notebooks/YYYY-MM-DD_<topic>.ipynb`
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
2. Create directory: `~/notebooks/ESP-456/`
3. Create notebook from `ticket-investigation.ipynb` template:
   ```bash
   python ~/.claude/skills/jupyter-notebook/lib/jupyter_utils.py create \
     --template ticket-investigation \
     --output ~/notebooks/ESP-456/investigation.ipynb \
     --title "ESP-456 Investigation" \
     --ticket ESP-456
   ```
4. Use NotebookEdit to add the ticket summary, description, and
   pre-populate relevant DB queries based on the ticket's component/labels
5. Offer to open in VSCode

### Weekly Daybook Notebook

Created automatically by the `weekly-notebook.sh` routine on Fridays, or on demand.

- Location: `~/notebooks/daybook/YYYY-WXX.ipynb`
- Contains: Week summary, visualization scratchpad, links to Joplin entries
- To create manually:
  ```bash
  python ~/.claude/skills/jupyter-notebook/lib/jupyter_utils.py create \
    --template esp-db-explore \
    --output ~/notebooks/daybook/$(date +%Y-W%V).ipynb \
    --title "Week $(date +%V) Daybook — $(date +'%B %Y')"
  ```

### Sprint Review Notebook

Created automatically by the `sprint-notebook.sh` routine on Fridays, or on demand.

- Location: `~/notebooks/sprints/YYYY-WXX-sprint.ipynb`
- To create manually:
  ```bash
  python ~/.claude/skills/jupyter-notebook/lib/jupyter_utils.py create \
    --template sprint-review \
    --output ~/notebooks/sprints/$(date +%Y-W%V)-sprint.ipynb \
    --title "Sprint Review — Week $(date +%V)"
  ```

## Linking Notebooks & Images to Joplin

After creating a notebook, offer to add a reference in the Joplin daybook.

### Notebook Links
Plain markdown links work for notebook files:
```
[notebook: <title>](file://$HOME/notebooks/<path>)
```

### Embedding Images in Joplin Notes
**Do NOT use `file://` links for images** — Joplin will not render them inline.
Instead, upload the image as a Joplin resource via the REST API and reference
it with the `:/<resource_id>` syntax.

```bash
# 1. Get the Joplin API token
JOPLIN_TOKEN=$(python3 -c "import json; print(json.load(open('$HOME/.config/joplin-desktop/settings.json'))['api.token'])")

# 2. Upload the image as a resource
RESOURCE_ID=$(curl -s -X POST "http://localhost:41184/resources?token=$JOPLIN_TOKEN" \
  -F "data=@/path/to/image.png" \
  -F 'props={"title":"Image Title","mime":"image/png"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

# 3. Reference in note body using Joplin resource syntax
# ![Alt text](:/RESOURCE_ID)
```

The Joplin MCP server does not have an attach-resource tool, so this must
be done via curl against the Joplin REST API (port 41184 by default).

## Plotting Style

The `setup_plotting()` function in `jupyter_utils.py` uses the **fivethirtyeight**
matplotlib style by default for clean, publication-ready plots. This provides:
- Clean, minimalist aesthetic
- Readable fonts and colors
- Good defaults for presentations and reports

To use in a notebook:
```python
from jupyter_utils import setup_plotting
plt, sns = setup_plotting()  # Uses fivethirtyeight by default
# or explicitly:
plt, sns = setup_plotting(style="fivethirtyeight")
```

## ESP Database Schema Reference

When generating SQL for ESP notebooks, use these correct table and column names.
**Do not guess column names** — refer to this reference.

### Row-Level Security (RLS)
All ESP tables enforce `tenant = CURRENT_USER`. The `jupyter_utils.get_db_engine()`
function auto-detects the correct tenant user (`db_l7esp` or `l7esp`). Do not
hardcode a user in notebooks — rely on `jupyter_utils`.

### Core Tables & Primary Keys
| Table | Primary Key | Notes |
|-------|-------------|-------|
| `resource` | `resource_id` (int) | Universal entity table — NOT `id` |
| `resource_action` | `resource_action_id` (int) | Audit trail — NOT `id` |
| `resource_var` | (resource_id + var) | Attribute/variable definitions |
| `resource_val` | (resource_id + var) | Attribute values |
| `resource_group` | `resource_group_id` | Groups |
| `resource_tag` | composite | Tag associations |
| `esp_cls_definition` | `clsid` (int) | Class/type registry — NOT `id` |
| `lab7_user` | (resource_id FK) | User accounts |
| `user_session` | `user_session_id` | Login sessions |
| `notifications` | `id` | System notifications |
| `workflow_definition` | `workflow_id` | Workflow templates |
| `protocol_definition` | `protocol_id` | Protocol templates |
| `workflow_instance` | `workflow_id` | Running/completed workflows |
| `protocol_instance` | `protocol_id` | Running/completed protocols |
| `sample` | `sample_id` | Sample records |
| `sample_type_definition` | `sample_type_id` | Sample type templates |

### Key Columns on `resource`
`resource_id`, `uuid`, `name`, `url`, `desc`, `barcode`, `cls` (FK to
`esp_cls_definition.clsid`), `archived`, `created_timestamp`,
`updated_timestamp`, `owner_resource_id`, `r_state`, `tenant`

### Key Columns on `resource_action`
`resource_action_id`, `resource_id` (FK), `agent_id` (FK to resource),
`desc`, `timestamp`, `level`, `meta` (jsonb), `tenant`

### Common Join Pattern
```sql
-- Resource with its class name
SELECT r.name, cd.name AS type
FROM resource r
JOIN esp_cls_definition cd ON r.cls = cd.clsid
```

### `pg_stat_user_tables` Warning
`n_live_tup` is **unreliable under RLS** — it may show 0 or 1 for tables
that actually have thousands of rows. When accurate counts matter, run
`SELECT COUNT(*) FROM <table>` instead.

### Pandas Type Casting
SQL `COUNT(*)` / `bigint` columns may arrive as `float64` in pandas. Cast
with `.astype(int)` before passing to matplotlib bar/barh charts to avoid
`TypeError: 'value' must be an instance of str or bytes, not a float`.

### Required Python Packages
The notebook kernel (`.venv`) must have: `matplotlib`, `seaborn`, `plotly`,
`pandas`, `numpy`, `sqlalchemy`, `psycopg2-binary`, `nbformat`.
Install via: `pip install matplotlib seaborn plotly pandas sqlalchemy psycopg2-binary nbformat`

## Error Handling
- **Missing dependencies**: Suggest `pip install pandas matplotlib plotly seaborn sqlalchemy psycopg2-binary nbformat jupyter`
- **DB connection fails**: Check ESP is running; `jupyter_utils` auto-detects the tenant user
- **Template not found**: Run `python ~/.claude/skills/jupyter-notebook/lib/jupyter_utils.py list` to show available templates
- **Directory doesn't exist**: The CLI creates parent directories automatically
