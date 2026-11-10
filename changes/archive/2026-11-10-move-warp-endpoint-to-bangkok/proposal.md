# Proposal: move-warp-endpoint-to-bangkok

## Why

The server sends its WARP tunnel to `162.159.192.1`. From this host that address is answered by Cloudflare's Singapore site, 27 ms away, while Cloudflare's Bangkok site is 1.4 ms away. Every round trip of every client connection pays the detour: on 2026-11-10 a new HTTPS connection through the tunnel took about 200 ms to set up on the server, against about 100 ms through a Bangkok endpoint. The owner asked on 2026-11-10 for a trial switch of the live server, measured from a client device.

## What changes

Client traffic enters Cloudflare WARP at Cloudflare's Bangkok site. Cloudflare's connection report, requested through the tunnel, names Bangkok (`BKK`) as the site, where it named Singapore (`SIN`) before. The exit stays a WARP address placed in Thailand; clients keep the same link.

The switch is a trial. It is kept when, measured from the owner's Mac through the VPN, connection setup is faster and downloads are not slower than before. Otherwise the endpoint goes back to `162.159.192.1` and this change records why.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-server | existing | `specs/vpn-server/spec.md` |

## Out of scope

- The client's DNS over UDP, which fails in the Happ tunnel on the owner's Mac. It is a client setting.
- The UDP gap in `scripts/verify-vpn.sh` for R-vpn-server-03.a (it tests DNS over TCP only). Reported, not fixed here.
- A second WARP registration, kernel WireGuard, a different tunnel transport, or removing WARP.

## Decisions checked

- ADR-0008 "Do not add a `freedom` outbound … or route client traffic out from the server's own address": kept. WARP stays the only way out; only the address of the WARP endpoint changes.
- ADR-0008 decision "endpoint given as an address literal": kept.

## Open questions

None.
