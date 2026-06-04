---
name: bootstrap-host
description: Use when Codex needs to prepare a LAN machine for ongoing SSH and Ansible management, including previewing bootstrap scope, verifying reachability, and running the tracked bootstrap playbook with explicit approval.
---

# Bootstrap Host

Use this skill when a host is not yet reliably manageable through the normal LAN operations path.

## Use this skill when

- The user wants to prepare a new machine for SSH and Ansible management.
- A host is reachable but missing Python or baseline packages required by Ansible.
- The user wants to install an authorized public key or baseline packages through the tracked bootstrap playbook.

## Workflow

1. If local Ansible tools are missing, use `control-node-bootstrap` first.
1. Confirm the target host or group exists in the LAN inventory.
2. If the request is only exploratory, use:
   - `bin/lan/lan-ops.sh ssh-check <host>`
3. Preview bootstrap scope first:
   - `bin/lan/lan-bootstrap.sh --limit <pattern>`
4. Apply bootstrap only after explicit approval:
   - `bin/lan/lan-bootstrap.sh --limit <pattern> --approve`
5. If a public key should be installed, pass `--authorized-key-file <path>`.

## Guardrails

- Do not broaden scope beyond the requested hosts.
- Do not write secrets or private keys into the repo.
- Keep bootstrap changes inside the tracked playbook so the process stays reproducible.
- Report the bootstrap user, key source path if used, and whether the run was preview-only or applied.
