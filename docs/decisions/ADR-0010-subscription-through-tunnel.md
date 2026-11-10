# ADR-0010: Subscription served through the tunnel

- Status: superseded by ADR-0011 on 2026-11-11, the day it was made: Happ does not fetch a subscription through its own tunnel
- Date: 2026-11-11
- Supersedes: the "subscription service is off" part of ADR-0002, and the "no `freedom` outbound" part of ADR-0008 (both narrowed, not reversed)
- Change: `changes/archive/2026-11-11-add-subscription-through-tunnel/`

## Context

The owner's client app (Happ) shows a group name, a profile name and a traffic counter only for a subscription. ADR-0002 keeps the subscription service off, because it listens on every interface and a reachable service can be found. The tunnel's port 443 cannot carry it: Reality hands anyone without the key to the cover site as raw TCP, so Xray never sees a request path there.

## Decision

- The subscription service is on and listens on 127.0.0.1 only. Its domain setting stays empty: the service refuses any request whose Host differs from a set domain, and the client reaches it with `192.0.2.1` as Host. The link's server address comes from the inbound's external proxy entry.
- A connected client fetches `http://192.0.2.1/<subscription path><subscription ID>`. `192.0.2.1` is in TEST-NET-1; no host answers it, and client apps do not bypass it as a private network.
- The Xray template has one `freedom` outbound, tag `sub`, with `redirect` to `127.0.0.1:2096` and `finalRules` that allow only that address and port and block everything else. Two routing rules send `192.0.2.1:80` to it, one by address and one by name, because HTTP sniffing turns the destination into the Host name. WARP stays the first outbound and the default.
- No firewall rule and no public listener are added.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Subscription on port 443 | Reality never lets Xray see the path of a request from a client without the key. A second TLS server and a domain would be needed. |
| Subscription on its own public port | A scanner can find it; ADR-0002 forbids it. |
| A made-up hostname for the subscription | The phone must resolve it first, and the server's resolvers cannot. |
| A private address (`10.x`) | Client apps usually send private ranges outside the tunnel. |
| `freedom` with `redirect` and no `finalRules` | Xray blocks a remote client's connection to loopback by default, so the request hangs. Found by test on 2026-11-11. |

## Consequences

- The counter updates only while the VPN is connected, and only if the client app fetches the subscription through its own tunnel. The owner checks this on the phone.
- A request through the tunnel can reach the subscription service and nothing else on the host. The subscription path and ID are secrets: whoever holds them can read the client link.
- The Xray template carries a second outbound. R-vpn-server-12.c now requires that no outbound can reach anything but loopback.

## Do not

- Do not add a `freedom` outbound to the Xray template that can reach anything but the subscription service on loopback, or route client traffic out from the server's own address: Google places that address in Myanmar, and a second way out leaks when WARP is down. (ADR-0008, ADR-0010)
