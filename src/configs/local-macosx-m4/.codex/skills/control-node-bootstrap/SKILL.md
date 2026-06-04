---
name: control-node-bootstrap
description: Use when Codex needs to prepare the local workstation to act as the LAN control node, including checking for Homebrew, SSH, Python, and the Ansible CLI tools, then installing the tracked local control-plane prerequisites with explicit approval.
---

# Control Node Bootstrap

Use this skill when the local machine needs to be prepared to manage the LAN inventory.

## Use this skill when

- `ansible`, `ansible-playbook`, or `ansible-inventory` are missing on the local workstation.
- The user wants Codex to verify the local control-node toolchain before running LAN operations.
- The user wants to install or repair the local Ansible control-plane prerequisites.

## Workflow

1. Diagnose first:
   - `bin/lan/lan-control-node.sh doctor`
2. Preview local install actions:
   - `bin/lan/lan-control-node.sh install`
3. Only install after explicit approval:
   - `bin/lan/lan-control-node.sh install --approve`
4. After install, re-run:
   - `bin/lan/lan-control-node.sh doctor`

## Guardrails

- Prefer the tracked wrapper over ad hoc `brew install` commands.
- Treat `install --approve` as the state-changing boundary for the local workstation.
- Do not create or store SSH private keys in tracked files.
- Report which local prerequisites were missing and which ones were installed.
