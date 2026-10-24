# AGENTS.md

This file is a **global agent configuration**. The build installs it to `~/.codex/AGENTS.md` on the `local-macosx-m4` workstation. It gives the baseline instructions for all Codex agent sessions on this machine.

## Scope

This `.codex` directory is the machine-local Codex configuration for `local-macosx-m4`.

The `workflow-macm4` repository configured this workstation. That repository contains dotfiles, utility scripts, cron jobs, systemd units, and templates for root-level configuration files. If you work on that repository, use this workflow: edit the source files in `src/`, stage them into `stage/`, and then, if necessary, install them on the host. For the instructions that are specific to the repository, refer to the root `AGENTS.md` file of the repository.

## Files

- `config.toml`: The Codex client settings, the trusted project paths, and the MCP server definitions.
- `AGENTS.md`: The local instructions for Codex when it runs with this home-directory configuration.

## Expectations

- Keep this directory specific to this machine. Do not add secrets, API keys, or tokens to tracked files.
- Do not change the current local workstation paths, unless the user tells you to move them.
- The `/Users/sthinds/Coding/Projects/Personal/workflow-macm4` and `/Users/sthinds/Coding/Research/joplin-mcp-server` trusted-project entries are intentional.
- If you edit the source configurations of the workflow repository, update `src/configs/local-macosx-m4/.codex/*`. Do not edit the staged output.

## MCP

- The `joplin` MCP server runs through `uv` from `/usr/local/src/joplin_mcp`.
- If that path changes, update `config.toml`. Do not add workarounds in downstream scripts.

## Safety

- Do not make the trust settings broader. Do not add new trusted project paths, unless the user gives permission.
- Do not add commands that need `sudo` or that change the host installation, unless the user tells you to.
- Do not use destructive git operations (`reset --hard`, checkout discard), unless the user tells you to.
- The user made the uncommitted edits intentionally. Do not revert changes that are not related to your task.

## LAN Ops

- The local-network Codex workflows are in `src/configs/local-macosx-m4/.codex/{agents,skills}` and `src/utils/local-macosx-m4/lan/`.
- Use `src/utils/local-macosx-m4/lan/inventory/lan.yml` as the default LAN inventory for this workstation configuration, unless the user gives a different inventory.
- Use the tracked wrappers, not ad hoc commands:
  - `bin/lan/lan-network-map.py`
  - `bin/lan/lan-ops.sh`
  - `bin/lan/lan-bootstrap.sh`
  - `bin/lan/lan-control-node.sh`
- For remote operations, use discovery mode or preview mode by default.
- If the local Ansible tools are not installed, prepare the control node first. Run `bin/lan/lan-control-node.sh doctor`. Then, if the user gives permission, run `bin/lan/lan-control-node.sh install --approve`.
- Get permission from the user before each remote action that changes state. This includes the application of approved Ansible playbooks.
- Use Ansible playbooks for changes. Use direct SSH only for small diagnostic tasks.
- Do not put SSH keys, secrets, or passwords in tracked files.

## Persistent Memory

- On `local-macosx-m4`, you can use the Joplin MCP server (`joplin_mcp`, available here through the `mcp__joplin__*` tools) as a persistent memory store.
- Use the `Areas / Agents` notebook for the working memory, status notes, and task context that you create.
- You can read notes in all notebooks when they apply to the task. But all note contents can be sensitive. Show only the minimum necessary data.
- You can edit an existing note in a different notebook if that note is clearly the correct canonical location for the update. Make small edits. Keep the user content. Be very careful: do not remove material that is not related.
- You can create new notes in an existing notebook if that notebook is the natural location for the data. If not, use `Areas / Agents`.
- Do not delete notes, unless the user tells you to delete them.
- Do not quote or copy sensitive note contents into the chat, unless the user needs that detail. Give summaries. Remove secrets. If you are not sure, do not show the data.

## Daybook Logging

After you complete a non-trivial task, write a short entry in a Joplin daybook note. This is the same as the Claude Code daybook behavior on this machine. Use the `mcp__joplin__*` tools:

1. Use the format `DD Mon, YYYY` for the title of today's note (for example, `10 Apr, 2026`).
2. In `Areas / Journal`, search Joplin (`mcp__joplin__search_notes`) for a note that has that exact title.
3. **If you find the note**: Read its current body (`mcp__joplin__get_note`). Add the new entry at the end. Then write the combined body back (`mcp__joplin__update_note`).
4. **If you do not find the note**: Create a new note with that title in `Areas / Journal` (`mcp__joplin__create_note`).
5. **Do not overwrite** the existing content. Always read the full body first. Then add the entry at the end.

Entry format: `- HH:MM — <one-sentence summary of what was done>`

Do not write an entry for a trivial session, a read-only session, or a chat-only session that changed nothing.

---

## Workflow Repository Reference

These sections describe the structure of the `workflow` repository. Use them as a reference when you work on that repository from this machine.

### Project Structure

- `Makefile`: The main entry points (`commission`, `stage`, `prune`, `install`, `backup`).
- `admin/`: The scripts that the `make` targets use.
- `admin/config/template/`: The tracked default files (`settings.json`, `exclude.conf`).
- `admin/config/`: The local runtime configuration. Git ignores all files in this directory, except `.gitkeep`.
- `src/`: The source of truth.
- `src/configs/`: The dotfiles for the home directory and the `.config` content.
- `src/utils/`: The scripts that the build copies to `~/bin` and `/usr/local/bin`.
- `src/cronjobs/`: The files that the build stages to `/etc/cron.d`.
- `src/systemd/`: The service files that the build stages to `/etc/systemd/system`.
- `src/root/`: The files that the build syncs to `/` (for example, `/etc`).
- `src/docker/`: The Docker Compose files that the build stages to `stage/docker`.
- `stage/`: The generated build output. This output is temporary.
- `backup/`: The local backup files. Git ignores all files in this directory, except `.keep`.

### Layering Model

The staging step merges content in this sequence:

1. The shared layer (if `admin/config/settings.json` enables it).
2. Each include in `settings.json` (`build.include`).
3. The local layer. This layer has the highest precedence.

Do not copy the same behavior into more than one layer, unless it is necessary. Put the defaults in the shared layer. Keep the overrides small.

### What To Edit

- Edit the files in `src/**` and `admin/**`.
- Do not edit the runtime files in `admin/config/`, unless the task is a machine setup.
- Do not put environment-specific secrets in tracked files.

**WARNING: Do not edit or create files in `stage/`.** Git ignores `stage/`. `make stage` replaces the contents of `stage/` on each build, and it does not show a warning. If you change a file in `stage/`, the next build deletes your change. Put all source changes in `src/`:

- Dotfiles and configuration files → `src/configs/<layer>/`
- Utility scripts → `src/utils/<layer>/`
- Cron jobs → `src/cronjobs/<layer>/`
- Systemd units → `src/systemd/<layer>/`
- Docker Compose files → `src/docker/<platform>/`

`<layer>` is one of these values: `shared`, `macosx`, `local-macosx-m4`, `local`, or a different layer. Refer to the Layering Model section for the merge sequence.

### Standard Commands

- `make commission`: Copies the missing `admin/config/template/*` files into `admin/config/`.
- `make stage`: Builds `stage/` again from the `src/` layers.
- `make prune`: Removes the items in `admin/config/exclude.conf` from the staged output.
- `make backup`: Makes a backup of the local configuration files. This command is specific to the host.

### High-Risk Commands

Run these commands only if the user gives you permission:

- `make install`
- `make update_cronjobs`
- `make update_systemd_services`
- `make update_root`
- Each command that writes to `/etc`, `/usr/local/bin`, or `/`.
- Each command that uses `sudo`.

### Validation Expectations

After you change content, do these steps:

1. Run `make stage`. If it is applicable, also run `make prune`.
2. Examine the staged files in `stage/`. Make sure that the output is correct.
3. Tell the user which source files you changed. Tell the user how each change affects the staged output.

If it is not safe to do all of the installation steps, tell the user. Then stop after the staging validation.

## CAD / 3D Project Storage

Blender and FreeCAD are installed on this machine with MCP servers (`blender`, `freecad`).
Save CAD and 3D project files to the CAD archive on `sthinds.local` (the Ubuntu box). This
machine mounts the archive over SMB:

- **Blender** projects → `~/media/.mounts/D/Documents/CAD/Blender/`
- **FreeCAD** projects → `~/media/.mounts/D/Documents/CAD/FreeCAD/`

On `sthinds.local`, these paths are in the `D` Samba share: `Documents/CAD/Blender` and
`Documents/CAD/FreeCAD`.

- Keep a working copy in `~/blender-projects/` while you work. When the work is complete,
  copy the `.blend` or `.FCStd` file to the CAD archive.
- Save `.blend` files as self-contained files (pack the external data). Then each file
  opens without other files.
- Render the Blender and FreeCAD preview frames to `~/blender-preview.png`. The live VS
  Code tab shows this file.
- `uvx blender-mcp` and `uvx freecad-mcp` must run as **arm64-native** processes. The
  configuration sets `--python 3.12` and `UV_PYTHON_PREFERENCE=only-managed`. Do not start
  them from a Rosetta shell.

## GIS / QGIS

QGIS is installed here with an MCP server (`qgis`). It has the same socket-plugin
architecture as Blender and FreeCAD (`qgis-mcp` is a fork of BlenderMCP). Save `.qgz` /
`.qgs` projects to `~/media/.mounts/D/Documents/GIS/` on the `D` Samba share. Also keep the
layer sources on the mount. QGIS stores relative layer paths. Thus, if you move a project
off the mount, its layers do not open.

- Start the bridge first: QGIS → *QGIS MCP* dock → **Start Server** (`localhost:9876`).
  If you get "connection refused", the dock server is not running. Tell the user. Do not
  try the call again without a change.
- The plugin (*QGIS MCP*, QGIS 3.28 or later) and the server (pinned to git tag `v0.7.1`
  in `config.toml`) must have the same version. Update the two parts together.
- `QGIS_MCP_TOOL_MODE=compound` is set. This mode shows approximately 23 grouped tools
  instead of approximately 102 granular tools.
- Map renders return base64 PNGs. This is the same token problem as `get_view` in
  `freecad-mcp`. During iterations, use `print()` to verify layer counts, feature counts,
  extents, and CRS. Render only at milestones.
- `execute_code` runs arbitrary PyQGIS against the live app. It can overwrite projects and
  layers on the disk. If a typed tool is available, use the typed tool.
- By default, the socket accepts only localhost connections and has no authentication. To
  require a secret, set `QGIS_MCP_TOKEN` in *both* the QGIS process environment and the
  `env` block of the server.
