# AGENTS.md

## Scope
This `.codex` directory is the machine-local Codex configuration for `local-macosx-m4`.

## Files
- `config.toml`: Codex client settings, trusted project paths, and MCP server definitions.
- `AGENTS.md`: local guidance that should apply when Codex is running with this home-directory configuration.

## Expectations
- Keep this directory machine-specific. Do not add secrets, API keys, or tokens to tracked files.
- Preserve the existing local workstation paths unless the user explicitly requests a path migration.
- Treat `/Users/sthinds/Coding/Projects/Personal/workflow-macm4` and `/Users/sthinds/Coding/Research/joplin-mcp-server` as intentional trusted-project entries.
- Prefer updating `src/configs/local-macosx-m4/.codex/*` instead of editing staged output.

## MCP
- The `joplin` MCP server is expected to run via `uv` from `/usr/local/src/joplin_mcp`.
- If that path changes, update `config.toml` rather than working around it in downstream scripts.

## Safety
- Do not broaden trust settings or add new trusted project paths without explicit user approval.
- Do not add commands that assume `sudo` or host-level installation side effects unless the user explicitly asks for them.
