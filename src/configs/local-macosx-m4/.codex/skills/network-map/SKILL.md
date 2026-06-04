---
name: network-map
description: Use when Codex needs a current map of which known LAN systems appear reachable, including host aliases, groups, configured addresses, and simple online status probes based on the tracked inventory.
---

# Network Map

Use this skill to answer "what systems are online?" without mutating any remote host.

## Workflow

1. Use the tracked inventory as the source of known systems.
2. Run:
   - `bin/lan/lan-network-map.py`
3. For machine-readable output, use:
   - `bin/lan/lan-network-map.py --format json`
4. If the user only wants inventory topology, disable probing:
   - `bin/lan/lan-network-map.py --probe-mode none`

## Notes

- The default probe is a TCP connection to port `22`.
- A host marked `online` means the configured address accepted the probe.
- A host marked `offline` may still exist but be powered down, firewalled, or listening elsewhere.
- If reachability looks inconsistent, follow up with `ansible-ops` or `bootstrap-host`.
