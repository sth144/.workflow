# AGENTS.md

## Purpose
This repository manages workstation/server dotfiles, utility scripts, cronjobs, systemd units, and root-level config templates. The primary workflow is: edit source files under `src/`, stage into `stage/`, then optionally install to the host.

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

## High-Risk Commands
Only run with explicit user approval:
- `make install`
- `make update_cronjobs`
- `make update_systemd_services`
- `make update_root`
- Any command that writes to `/etc`, `/usr/local/bin`, `/`, or uses `sudo`.

These commands can overwrite system state, enable/start services, or modify root-owned paths.

## Validation Expectations
For content changes:
1. Run `make stage` (and `make prune` if relevant).
2. Inspect staged results under `stage/` for expected output.
3. Report exactly which source files were changed and what staging impact they have.

If a task cannot safely run full install steps, state that clearly and stop at staging validation.

## Conventions
- Prefer small, focused edits that preserve existing shell/Python style.
- Use `rg` for searching.
- Avoid destructive git operations (`reset --hard`, checkout discard) unless explicitly requested.
- Assume existing uncommitted user edits are intentional; do not revert unrelated changes.
