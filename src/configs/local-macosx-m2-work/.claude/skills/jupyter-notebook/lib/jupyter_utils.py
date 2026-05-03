#!/usr/bin/env python3
"""Jupyter notebook utilities for the Claude Code workflow.

Two modes of use:
  1. CLI: Create notebooks from templates
     python jupyter_utils.py create --template esp-db-explore --output path.ipynb --title "Title"
     python jupyter_utils.py list

  2. Library: Import in notebooks for DB connections, plotting setup, etc.
     from jupyter_utils import get_db_engine, setup_plotting, query_df
"""

import argparse
import json
import os
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

TEMPLATE_DIR = Path(__file__).parent.parent / "templates"
DEFAULT_NOTEBOOK_DIR = Path.home() / "Coding" / "Research" / "notebooks"
DEFAULT_DAYBOOK_DIR = Path.home() / "Coding" / "Research" / "daybook"

# ESP database defaults (override via environment)
ESP_DB_HOST = os.getenv("ESP_DB_HOST", "localhost")
ESP_DB_PORT = os.getenv("ESP_DB_PORT", "1487")
ESP_DB_NAME = os.getenv("ESP_DB_NAME", "lab7")
ESP_DB_USER = os.getenv("ESP_DB_USER", "db_l7esp")
ESP_DB_PASS = os.getenv("ESP_DB_PASSWORD", "db_l7esp")

# Candidate DB users to try, in order.  ESP uses row-level security keyed
# on ``tenant = CURRENT_USER``, so only the user whose name matches the
# tenant column will see data.  We try the common tenant users and pick
# the first one that actually has rows in ``resource``.
_ESP_DB_USER_CANDIDATES = ["db_l7esp", "l7esp"]


# ---------------------------------------------------------------------------
# Library functions (imported within notebooks)
# ---------------------------------------------------------------------------

def _db_url(user: str, password: str) -> str:
    """Build a SQLAlchemy PostgreSQL URL."""
    return f"postgresql://{user}:{password}@{ESP_DB_HOST}:{ESP_DB_PORT}/{ESP_DB_NAME}"


def get_db_url() -> str:
    """Return a SQLAlchemy-compatible PostgreSQL URL for the ESP database."""
    return _db_url(ESP_DB_USER, ESP_DB_PASS)


def get_db_engine():
    """Create and return a SQLAlchemy engine for the ESP database.

    If the configured user sees no rows in ``resource`` (likely an RLS
    tenant mismatch), automatically tries other known ESP tenant users.
    """
    from sqlalchemy import create_engine, text

    engine = create_engine(get_db_url())
    try:
        with engine.connect() as conn:
            count = conn.execute(text("SELECT COUNT(*) FROM resource")).scalar()
            if count and count > 1:
                return engine
    except Exception:
        pass

    # Try alternate tenant users
    for user in _ESP_DB_USER_CANDIDATES:
        if user == ESP_DB_USER:
            continue
        try:
            candidate = create_engine(_db_url(user, user))
            with candidate.connect() as conn:
                count = conn.execute(text("SELECT COUNT(*) FROM resource")).scalar()
                if count and count > 1:
                    return candidate
        except Exception:
            continue

    # Fall back to originally configured engine
    return engine


def query_df(sql: str, params=None):
    """Run a SQL query and return the result as a pandas DataFrame."""
    import pandas as pd
    engine = get_db_engine()
    return pd.read_sql(sql, engine, params=params)


def setup_plotting(style: str = "whitegrid", figsize: tuple = (12, 6)):
    """Configure matplotlib/seaborn with sensible defaults."""
    import matplotlib.pyplot as plt
    import seaborn as sns
    sns.set_style(style)
    plt.rcParams["figure.figsize"] = figsize
    plt.rcParams["font.size"] = 11
    plt.rcParams["axes.titlesize"] = 14
    plt.rcParams["axes.labelsize"] = 12
    return plt, sns


# ---------------------------------------------------------------------------
# CLI: Notebook creation from templates
# ---------------------------------------------------------------------------

def list_templates():
    """Print available templates."""
    if not TEMPLATE_DIR.exists():
        print(f"Template directory not found: {TEMPLATE_DIR}", file=sys.stderr)
        sys.exit(1)

    templates = sorted(TEMPLATE_DIR.glob("*.ipynb"))
    if not templates:
        print("No templates found.")
        return

    print("Available templates:")
    for t in templates:
        name = t.stem
        # Read first markdown cell for description
        with open(t) as f:
            nb = json.load(f)
        desc = ""
        for cell in nb.get("cells", []):
            if cell.get("cell_type") == "markdown":
                source = "".join(cell.get("source", []))
                # Extract first non-heading line as description
                for line in source.splitlines():
                    line = line.strip()
                    if line and not line.startswith("#"):
                        desc = line[:80]
                        break
                break
        print(f"  {name:30s} {desc}")


def create_notebook(template_name: str, output_path: str, title: str = "",
                    ticket: str = "", table: str = ""):
    """Copy a template notebook to the output path with parameter substitution."""
    # Resolve template
    template_file = TEMPLATE_DIR / f"{template_name}.ipynb"
    if not template_file.exists():
        # Try without extension
        template_file = TEMPLATE_DIR / template_name
        if not template_file.exists():
            print(f"Template not found: {template_name}", file=sys.stderr)
            print(f"Available: {', '.join(t.stem for t in TEMPLATE_DIR.glob('*.ipynb'))}")
            sys.exit(1)

    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    # Read template
    with open(template_file) as f:
        nb = json.load(f)

    # Parameter substitution in all cell sources
    today = datetime.now()
    replacements = {
        "{{TITLE}}": title or template_name.replace("-", " ").title(),
        "{{DATE}}": today.strftime("%Y-%m-%d"),
        "{{DATE_LONG}}": today.strftime("%B %d, %Y"),
        "{{WEEK}}": today.strftime("%V"),
        "{{YEAR}}": today.strftime("%Y"),
        "{{TICKET}}": ticket,
        "{{TABLE}}": table or "-- specify table here",
        "{{DB_HOST}}": ESP_DB_HOST,
        "{{DB_PORT}}": ESP_DB_PORT,
        "{{DB_NAME}}": ESP_DB_NAME,
    }

    for cell in nb.get("cells", []):
        source = cell.get("source", [])
        new_source = []
        for line in source:
            for placeholder, value in replacements.items():
                line = line.replace(placeholder, value)
            new_source.append(line)
        cell["source"] = new_source

    # Write output
    with open(output, "w") as f:
        json.dump(nb, f, indent=1)

    print(json.dumps({
        "status": "ok",
        "template": template_name,
        "output": str(output),
        "title": replacements["{{TITLE}}"],
        "date": replacements["{{DATE}}"],
    }))


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Jupyter notebook utilities")
    sub = parser.add_subparsers(dest="command")

    # list
    sub.add_parser("list", help="List available templates")

    # create
    create_parser = sub.add_parser("create", help="Create notebook from template")
    create_parser.add_argument("--template", required=True, help="Template name (without .ipynb)")
    create_parser.add_argument("--output", required=True, help="Output file path")
    create_parser.add_argument("--title", default="", help="Notebook title")
    create_parser.add_argument("--ticket", default="", help="Jira ticket key (e.g., ESP-456)")
    create_parser.add_argument("--table", default="", help="Database table name for exploration")

    args = parser.parse_args()

    if args.command == "list":
        list_templates()
    elif args.command == "create":
        create_notebook(args.template, args.output, args.title, args.ticket, args.table)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
