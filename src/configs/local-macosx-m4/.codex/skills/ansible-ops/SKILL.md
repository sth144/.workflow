---
name: ansible-ops
description: Use when Codex needs to inspect LAN inventory, run safe Ansible connectivity checks, gather host facts, or execute a tracked Ansible playbook against explicit local-network hosts or groups. Prefer this skill over ad hoc SSH for repeatable remote operations.
---

# Ansible Ops

Use this skill for repeatable LAN operations that should go through the tracked inventory and wrappers.

## Use this skill when

- The user wants to inspect inventory scope or list hosts/groups.
- The user wants connectivity or facts for one or more LAN hosts.
- The user wants to preview or apply a tracked playbook against explicit hosts or groups.

## Do not use this skill when

- The task is only "what systems are online?" Use `network-map`.
- The task is first-time host preparation. Use `bootstrap-host`.
- The local workstation is missing Ansible CLI tools. Use `control-node-bootstrap`.
- The user has not identified a target host or group.

## Workflow

1. Resolve scope first with `bin/lan/lan-ops.sh inventory` or `bin/lan/lan-ops.sh list-playbooks`.
2. For read-only checks, prefer:
   - `bin/lan/lan-ops.sh ping <pattern>`
   - `bin/lan/lan-ops.sh facts <pattern>`
3. For playbooks, default to preview mode:
   - `bin/lan/lan-ops.sh playbook --playbook <name> --limit <pattern>`
4. Only apply playbooks after explicit approval:
   - `bin/lan/lan-ops.sh playbook --playbook <name> --limit <pattern> --approve`

## Guardrails

- Require explicit host or group scope on every action.
- Prefer tracked playbooks under `bin/lan/playbooks/`.
- Treat `--approve` as a state-changing boundary.
- Summarize the exact inventory target, playbook, and mode used.
