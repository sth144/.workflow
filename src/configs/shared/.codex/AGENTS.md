# AGENTS.md

This file is a **global agent configuration**. The build installs it to `~/.codex/AGENTS.md` on the target machines. It gives the baseline instructions for all Codex agent sessions on this workstation.

## Scope

This `.codex` directory is the machine-local Codex configuration.

The `workflow` repository configured this workstation. That repository contains dotfiles, utility scripts, cron jobs, systemd units, and templates for root-level configuration files. If you work on that repository, use this workflow: edit the source files in `src/`, stage them into `stage/`, and then, if necessary, install them on the host. For the instructions that are specific to the repository, refer to the root `AGENTS.md` file of the repository.

## Files

- `config.toml`: The Codex client settings, the trusted project paths, and the MCP server definitions.
- `AGENTS.md`: The local instructions for Codex when it runs with this home-directory configuration.

## Expectations

- Keep this directory specific to this machine. Do not add secrets, API keys, or tokens to tracked files.
- Do not change the current local workstation paths, unless the user tells you to move them.
- The `/usr/local/src/workflow` and `/usr/local/src/joplin_mcp` trusted-project entries are intentional.
- If you edit the source configurations of the workflow repository, update `src/configs/**/.codex/*`. Do not edit the staged output.

## MCP

- The `joplin` MCP server runs through `uv` from `/usr/local/src/joplin_mcp`.
- If that path changes, update `config.toml`. Do not add workarounds in downstream scripts.

## Safety

- Do not make the trust settings broader. Do not add new trusted project paths, unless the user gives permission.
- Do not add commands that need `sudo` or that change the host installation, unless the user tells you to.
- Do not use destructive git operations (`reset --hard`, checkout discard), unless the user tells you to.
- The user made the uncommitted edits intentionally. Do not revert changes that are not related to your task.

## Persistent Memory

- On localhost, you can use the Joplin MCP server (`joplin_mcp`, available here through the `mcp__joplin__*` tools) as a persistent memory store.
- Use the `Areas / Agents` notebook for the working memory, status notes, and task context that you create.
- You can read notes in all notebooks when they apply to the task. But all note contents can be sensitive. Show only the minimum necessary data.
- You can edit an existing note in a different notebook if that note is clearly the correct canonical location for the update. Make small edits. Keep the user content. Be very careful: do not remove material that is not related.
- You can create new notes in an existing notebook if that notebook is the natural location for the data. If not, use `Areas / Agents`.
- Do not delete notes, unless the user tells you to delete them.
- Do not quote or copy sensitive note contents into the chat, unless the user needs that detail. Give summaries. Remove secrets. If you are not sure, do not show the data.

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
