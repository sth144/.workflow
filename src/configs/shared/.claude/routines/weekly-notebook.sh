#!/bin/bash
# Weekly Daybook Notebook - Create a weekly Jupyter scratchpad for visualizations
# Schedule: Friday at 3pm
# Cron: 0 15 * * 5

set -euo pipefail
mkdir -p ~/.claude/routines/logs
mkdir -p ~/Coding/Research/daybook

WEEK=$(date +%V)
YEAR=$(date +%Y)
MONTH=$(date +%B)
OUTPUT_PATH="$HOME/Coding/Research/daybook/${YEAR}-W${WEEK}.ipynb"

# Skip if notebook already exists (may have been created manually earlier in the week)
if [ -f "$OUTPUT_PATH" ]; then
    echo "=== Weekly Notebook - $(date) ==="
    echo "Notebook already exists: $OUTPUT_PATH — skipping creation"
    exit 0
fi

PROMPT="Create a weekly daybook Jupyter notebook for Week $WEEK of $YEAR ($MONTH).

## Output
Create the notebook at: $OUTPUT_PATH

## Steps

1. Create the notebook using NotebookEdit with these cells:

### Cell 1 — Markdown header
\`\`\`markdown
# Week $WEEK Daybook — $MONTH $YEAR

Visual scratchpad for the week. Use this notebook for:
- Quick data explorations that deserve a chart
- SQL query results worth visualizing
- Any analysis promoted from the terminal via \"notebook this\"

**Joplin daybook**: Search for daily entries in Areas / Daybook
\`\`\`

### Cell 2 — Common imports and setup
\`\`\`python
import sys
sys.path.insert(0, str(Path.home() / '.claude/skills/jupyter-notebook/lib'))

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
from datetime import datetime, timedelta

# Optional imports — skip gracefully if not installed
try:
    import plotly.express as px
    import plotly.graph_objects as go
    HAS_PLOTLY = True
except ImportError:
    HAS_PLOTLY = False
    print('plotly not installed — using matplotlib only')

# Plotting defaults
sns.set_style('whitegrid')
plt.rcParams['figure.figsize'] = (12, 6)
plt.rcParams['font.size'] = 11

print(f'Week {datetime.now().strftime(\"%V\")} notebook ready')
\`\`\`

### Cell 3 — ESP database connection (optional)
\`\`\`python
# Uncomment and configure if you need DB access this week
# from jupyter_utils import get_db_engine, query_df
# engine = get_db_engine()
# df = query_df('SELECT current_timestamp AS now')
# df
\`\`\`

### Cell 4 — Scratchpad (empty code cell)
Ready for the first exploration of the week.

2. After creating the notebook, search Joplin for this week's daybook entries
   (title format: DD Mon, YYYY for each day this week) and add a markdown cell
   listing any links to them for cross-reference.

## Notes
- Keep the notebook lightweight at creation — it will grow during the week
- The import cell should be runnable immediately with standard data science packages
- Leave the DB connection cell commented out so the notebook doesn't error on open"

echo "=== Weekly Notebook - $(date) ==="
echo "$PROMPT" | claude --print
