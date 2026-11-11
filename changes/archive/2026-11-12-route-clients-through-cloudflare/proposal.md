# Proposal: route-clients-through-cloudflare

## Why

Red flag 2 (`docs/censor-red-flags.md`): clients send gigabytes to an address in a Thai hosting provider's block, the basic proxy pattern. The owner chose on 2026-11-12 to put Cloudflare in front of the server and to keep no direct way in (ADR-0013).

## What changes

- The client link points at `status.casedigestai.com:443`, a name that resolves to Cloudflare. The tunnel is VLESS over XHTTP inside HTTPS, on a random path.
- Both site names resolve to Cloudflare addresses only, never to the server's.
- The server's ports 80 and 443 answer only Cloudflare's published IPv4 ranges. A probe straight at the server's address gets nothing.
- On the server, nginx holds port 443: the tunnel path goes to Xray on loopback, every other path is the cover site.
- The VLESS + Reality inbound and its link are removed. Per-address limits on 443 are removed.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-server | existing | `specs/vpn-server/spec.md` |

## Out of scope

- SSH stays open to everyone (flag 5).
- A second transport or spare addresses (flag 6).
- The presentation `docs/how-it-works.html`, which still describes Reality. Reported as a follow-up.

## Decisions checked

- ADR-0002 (panel on loopback): kept.
- ADR-0005 (`ufw limit` on SSH): untouched; the port-443 limits are superseded by ADR-0013.
- ADR-0008, ADR-0009 (WARP exit, Bangkok endpoint): kept; the exit side does not change.
- ADR-0012 (cover site; no third-party cover site; Docker on loopback): the site and the container stay as they are; the Reality inbound is superseded by ADR-0013.

## Open questions

- [TODO-CLARIFY: Cloudflare's free plan is reported throttled in Russia and has no nodes in China. Which country's users are first, so speed there can be checked?]
