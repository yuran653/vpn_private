# ADR-0001: Stack

- Status: accepted
- Date: 2026-11-10
- Supersedes: none
- Change: none
- Note (2026-11-19): the transport is now VLESS over XHTTP behind Cloudflare, with a dedicated Thai exit proxy, nginx, certbot and Docker. The current list is in `AGENTS.md` (ADR-0012, ADR-0013, ADR-0026).

## Context

Deploy and harden a VLESS + XTLS-Reality VPN server on a bare Ubuntu VPS. The server must prevent every identity disclosure that can be enforced server-side: DNS leaks, IPv6 egress, tunnel fingerprinting by DPI, and panel discovery.

## Decision

The stack is: Ubuntu 22.04/24.04 LTS, Xray core managed through the 3x-ui panel, ufw, fail2ban, unattended-upgrades.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| [TODO-CLARIFY: alternatives considered] | |

## Consequences

[TODO-CLARIFY: consequences of this stack choice]

## Do not

None.
