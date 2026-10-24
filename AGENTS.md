# AGENTS.md

## Purpose

This repository contains dotfiles, utility scripts, cron jobs, and systemd units for workstations and servers. It also contains templates for root-level configuration files.

The primary workflow has three steps:

1. Edit the source files in `src/`.
2. Stage the files into `stage/`.
3. If necessary, install the staged files on the host.

## Project Structure

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

## Layering Model

The staging step merges content in this sequence:

1. The shared layer (if `admin/config/settings.json` enables it).
2. Each include in `settings.json` (`build.include`).
3. The local layer. This layer has the highest precedence.

Each layer can have a `<layer>-vault` sibling (for example, `src/configs/local-macosx-m4-vault/` or `shared-vault/`). git-crypt encrypts vault directories (see `.gitattributes`). The staging step includes a vault right after its layer, and it skips a locked vault with a warning. To move gitignored `src/*/local/` files into the vault for this host, run `make migrate_vault`.

Do not copy the same behavior into more than one layer, unless it is necessary. Put the defaults in the shared layer. Keep the overrides small.

## What To Edit

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

## Standard Commands

- `make commission`: Copies the missing `admin/config/template/*` files into `admin/config/`.
- `make stage`: Builds `stage/` again from the `src/` layers.
- `make prune`: Removes the items in `admin/config/exclude.conf` from the staged output.
- `make backup`: Makes a backup of the local configuration files. This command is specific to the host.

## High-Risk Commands

Run these commands only if the user gives you permission:

- `make install`
- `make update_cronjobs`
- `make update_systemd_services`
- `make update_root`
- Each command that writes to `/etc`, `/usr/local/bin`, or `/`.
- Each command that uses `sudo`.

These commands can overwrite the system state. They can also enable or start services, and change paths that root owns.

## Validation Expectations

After you change content, do these steps:

1. Run `make stage`. If it is applicable, also run `make prune`.
2. Examine the staged files in `stage/`. Make sure that the output is correct.
3. Tell the user which source files you changed. Tell the user how each change affects the staged output.

If it is not safe to do all of the installation steps, tell the user. Then stop after the staging validation.

## Conventions

- Make small edits that have one purpose. Keep the current shell and Python style.
- Use `rg` to search.
- Do not use destructive git operations (`reset --hard`, checkout discard), unless the user tells you to.
- The user made the uncommitted edits in the working tree intentionally. Do not revert changes that are not related to your task.

## Note on Global Configs

The `src/configs/**/.codex/AGENTS.md` and `src/configs/**/.claude/CLAUDE.md` files do **not** apply to this repository. They are global agent configurations. The build stages them and installs them to `~/.codex/` and `~/.claude/` on the target machines. When you edit these files, you change the global agent instructions for the deployed workstations. You do not change the instructions for this repository.
