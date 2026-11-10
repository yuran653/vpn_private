# Proposal: route-egress-through-warp

## Why

Google places the server's IPv4 address in Myanmar, so YouTube Music and YouTube Premium refuse to work for a client of this VPN ("not available in this country"). Other geo-IP databases place the same address in Thailand or Japan. The address block was re-registered to Thailand in August 2026 and the databases have not caught up; only the provider can correct them. The owner decided on 2026-11-10 to send all client traffic out through Cloudflare WARP instead, so that sites see a Cloudflare address that is placed in Thailand.

## What changes

- A site that a client opens through the tunnel sees a Cloudflare WARP address, not the server's address.
- The server's own name lookups for client traffic also leave through WARP.
- When WARP is unreachable, a client request fails. It never leaves from the server's own address.
- The exit is placed in Thailand, and YouTube Music opens through the tunnel.
- The client link does not change: clients still connect to the server's address on port 443.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-server | existing | `specs/vpn-server/spec.md` |

## Out of scope

- Correcting the server address in Google's or any other geo-IP database. That is the provider's job.
- A paid WARP+ licence or a Zero Trust account.
- The Reality cover-site forwarding for probes without the key. It still leaves from the server's address, as it must to look like an ordinary site.
- The host's own traffic (updates, SSH). It does not use WARP.

## Decisions checked

- ADR-0002 (panel on loopback): the change opens no port and binds nothing to a public address.
- ADR-0004 (IPv6 off in the kernel): the WARP tunnel runs inside Xray in user space and is given an IPv4 address only.
- ADR-0005 (no `ufw limit`): no firewall rule changes.

## Open questions

None.
