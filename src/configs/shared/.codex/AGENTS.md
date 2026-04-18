# AGENTS.md

## Scope
This `.codex` directory is the machine-local Codex configuration for `local-macosx-m4`.

This workstation configuration is used with the `workflow-macm4` repository, which manages workstation/server dotfiles, utility scripts, cronjobs, systemd units, and root-level config templates. The primary workflow is: edit source files under `src/`, stage into `stage/`, then optionally install to the host.

## Files
- `config.toml`: Codex client settings, trusted project paths, and MCP server definitions.
- `AGENTS.md`: local guidance that should apply when Codex is running with this home-directory configuration.

## Expectations
- Keep this directory machine-specific. Do not add secrets, API keys, or tokens to tracked files.
- Preserve the existing local workstation paths unless the user explicitly requests a path migration.
- Treat `/Users/sthinds/Coding/Projects/Personal/workflow-macm4` and `/Users/sthinds/Coding/Research/joplin-mcp-server` as intentional trusted-project entries.
- Prefer updating `src/configs/local-macosx-m4/.codex/*` instead of editing staged output.

## Project Structure
- `Makefile`: main entry points (`commission`, `stage`, `prune`, `install`, `backup`).
- `admin/`: orchestration scripts used by `make` targets.
- `admin/config/template/`: tracked defaults (`settings.json`, `exclude.conf`).
- `admin/config/`: local runtime config (ignored by git except `.gitkeep`).
- `src/`: source of truth.
- `src/configs/`: home-directory dotfiles and `.config` content.
- `src/utils/`: scripts copied to `~/bin` / `/usr/local/bin`.
- `src/cronjobs/`: files staged to `/etc/cron.d`.
- `src/systemd/`: service files staged to `/etc/systemd/system`.
- `src/root/`: files synced to `/` (for `/etc`, etc.).
- `src/docker/`: docker compose files staged under `stage/docker`.
- `stage/`: generated build output. Treat as ephemeral.
- `backup/`: local backup artifacts (ignored except `.keep`).

## Layering Model
Staging merges content in this order:
1. shared layer (if enabled in `admin/config/settings.json`)
2. each include from `settings.json` (`build.include`)
3. local layer (highest precedence)

Do not manually maintain duplicate behavior across layers unless required; prefer shared defaults and minimal overrides.

## What To Edit
- Edit files in `src/**` and `admin/**` (except runtime-local files in `admin/config/` unless the task is machine setup).
- Do not hand-edit `stage/**` for lasting changes. Rebuild with `make stage`.
- Keep environment-specific secrets out of tracked files.

## Standard Commands
- `make commission`: copy missing `admin/config/template/*` into `admin/config/`.
- `make stage`: rebuild `stage/` from `src/` layers.
- `make prune`: apply `admin/config/exclude.conf` removals to staged output.
- `make backup`: backup local configs (host-specific operation).

## MCP
- The `joplin` MCP server is expected to run via `uv` from `/usr/local/src/joplin_mcp`.
- If that path changes, update `config.toml` rather than working around it in downstream scripts.

## Safety
- Do not broaden trust settings or add new trusted project paths without explicit user approval.
- Do not add commands that assume `sudo` or host-level installation side effects unless the user explicitly asks for them.
- Only run the following with explicit user approval: `make install`, `make update_cronjobs`, `make update_systemd_services`, `make update_root`, or any command that writes to `/etc`, `/usr/local/bin`, `/`, or uses `sudo`.
- Avoid destructive git operations (`reset --hard`, checkout discard) unless explicitly requested.
- Assume existing uncommitted user edits are intentional; do not revert unrelated changes.

## Validation Expectations
For content changes:
1. Run `make stage` (and `make prune` if relevant).
2. Inspect staged results under `stage/` for expected output.
3. Report exactly which source files were changed and what staging impact they have.

If a task cannot safely run full install steps, state that clearly and stop at staging validation.

## Persistent Memory (`local-macosx-m4`)
- On `local-macosx-m4`, the Joplin MCP server (`joplin_mcp`, exposed here via `mcp__joplin__*` tools) may be used as a persistent memory store.
- Prefer the `Areas / Agents` notebook for agent-created working memory, status notes, and task context.
- Notes in any notebook may be read when relevant to the task, but treat all note contents as potentially sensitive and only surface the minimum necessary information.
- Existing notes in other notebooks may be edited when the note is clearly the correct canonical place for the update. Make narrow edits, preserve user content, and be especially careful not to remove unrelated material.
- New notes may be created in existing notebooks when that notebook is the natural home for the information; otherwise prefer `Areas / Agents`.
- Do not delete notes unless the user explicitly asks for deletion.
- Avoid quoting or copying sensitive note contents into chat unless the user explicitly needs that detail. Prefer summaries, redact secrets, and err on the side of non-disclosure.
