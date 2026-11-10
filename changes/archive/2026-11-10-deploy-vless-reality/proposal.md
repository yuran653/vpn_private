# Proposal: deploy-vless-reality

Status: requested by the owner on 2026-11-10 as a fully automated implementation and deployment. Not stopped for approval (change cycle, step 4); the owner reviews the archived change.

## Why

The VPS has the SSH, fail2ban and ufw baseline but no VPN. The project's purpose is a VLESS + XTLS-Reality server that prevents every identity disclosure enforceable on the server: DNS leaks, IPv6 egress, tunnel fingerprinting by DPI, and panel discovery. The owner needs one client key to paste into Happ or V2Box.

## What changes

For a Ubuntu host with the baseline applied, run as root through `sudo -n bash scripts/deploy-vpn.sh`:

- A client holding the issued `vless://` link connects on 443/tcp and reaches the internet from the server's IPv4 address.
- The host has no IPv6 address. IPv6 destinations and AAAA lookups through the tunnel return nothing.
- DNS queries sent through the tunnel to port 53 are answered by the server, which resolves over DNS-over-HTTPS only.
- A TLS client without the key sees a real third-party site with a valid certificate, not a VPN.
- The management panel and its subscription service are unreachable from the internet. The panel is reached through an SSH tunnel.
- The server keeps no record of client connections or lookups.
- Security updates install unattended.
- A second run changes no key and leaves the client link as it was.

`scripts/verify-vpn.sh` (on the VPS) and `scripts/verify-external.sh` (on the workstation) check these.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-server | new | `changes/deploy-vless-reality/specs/vpn-server/spec.md` |

## Out of scope

- Client-side leaks: WebRTC, a client app's own DNS settings, kill switch, split tunnelling. The server cannot enforce these.
- More than one client, traffic quotas, subscriptions, Telegram bot.
- Changes to the `vps-baseline` capability, including `PermitRootLogin`.
- CDN fronting, a fallback transport, or a second server.
- Lint, type-check and test commands in `AGENTS.md`. They stay `[TODO-CLARIFY]`.

## Decisions checked

None apply. `docs/decisions/INDEX.md` lists no "Do not" lines. This change adds ADR-0002 (panel on loopback, installed from a pinned release) and ADR-0003 (Reality cover site).

## Open questions

- [TODO-CLARIFY: should `scripts/verify-vpn.sh` and `scripts/verify-external.sh` become the Test command in `AGENTS.md`?]
