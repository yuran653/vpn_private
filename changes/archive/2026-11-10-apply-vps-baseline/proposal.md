# Proposal: apply-vps-baseline

Status: approved by the owner on 2026-11-10, after the script had already run on the VPS at the owner's request. Archived with the criteria still `untested`; see the spec.

## Why

The VPS needs a repeatable baseline for SSH keepalive, fail2ban and ufw. The steps were run by hand and existed only in the shell history, so a rebuild or a second run could not be reproduced from the repository.

## What changes

For a Ubuntu 24.04 host run as root through `sudo -n bash scripts/harden-vps.sh <ADMIN_IP>`:

- SSH sessions are probed every 60 seconds and dropped after 3 unanswered probes.
- The host's own name resolves locally, so `sudo` prints no hostname warning.
- fail2ban runs with the sshd jail. The admin IP is never banned.
- ufw allows the SSH port, sets deny-incoming and allow-outgoing, then enables.

The script exits with an error and makes no change when `ADMIN_IP` is missing or not IPv4.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vps-baseline | new | `changes/apply-vps-baseline/specs/vps-baseline/spec.md` |

## Out of scope

- Xray, the 3x-ui panel, and their ports. No firewall rule is added for them.
- Unattended-upgrades, DNS leak protection, IPv6 handling and panel discovery. These are in the project purpose but not in this script.
- Lint, type-check and test commands. `AGENTS.md` has none yet.

## Decisions checked

None apply. `docs/decisions/INDEX.md` lists no "Do not" lines.

## Open questions

- [TODO-CLARIFY: should the SSH rule in ufw be limited to the admin IP? It is open to any address now, because the admin IP changes.]
- [TODO-CLARIFY: approve this change, or request changes to the proposal.]
