# Design: add-subscription-through-tunnel

## Approach

3x-ui's subscription service is switched on, listening on 127.0.0.1 only. A client reaches it through the tunnel: the Xray template gets one `freedom` outbound whose `redirect` is `127.0.0.1:<sub port>`, and a routing rule, placed before the private-address block, sends requests for `192.0.2.1:80` to it. `192.0.2.1` is in TEST-NET-1, reserved for documentation, so no real host answers it and a client app does not bypass it as a LAN address. WARP stays the first outbound, so it is still the default; the `sub` outbound is reached only by that rule and can reach nothing but loopback.

Settings changed through the panel API, all idempotent:

| Setting | Value | Why |
|---|---|---|
| `subEnable` | true | The service runs. |
| `subListen` | 127.0.0.1 | Not reachable from the internet. |
| `subDomain` | empty | The service refuses a request whose Host is not this domain (403); the client's Host is `192.0.2.1`. |
| `subTitle` | `VPN ไทย` | The group name in Happ. |
| `subUpdates` | 1 | Happ refreshes the counter hourly. |
| `remarkTemplate` | `{{INBOUND}}` | The profile name is the inbound's name only: no email, no quota text. |

The inbound's remark becomes `กรุงเทพฯ cloud.z.com` and its external proxy entry carries the host's public address and port 443, so the link names the real server. Both are updated through the panel API when they differ. The client gets a subscription ID once, if it has none.

The `sub` outbound has `finalRules` that allow only `127.0.0.1:<sub port>` and block the rest: Xray blocks a remote client's connection to loopback by default, which made the request hang. Two routing rules, by address and by name, because HTTP sniffing turns the destination into the Host name. The client keeps its quota (0) and expiry (0), so the response carries `total=0` and no expiry. The client link file gets the same name, percent-encoded, after the `#`.

The subscription address is `http://192.0.2.1` + the panel's subscription path + the client's subscription ID, written to `/root/vpn/subscription-url.txt` (mode 600). It is plain HTTP inside the encrypted tunnel.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| deploy | `scripts/deploy-vpn.sh` | Subscription settings, `sub` outbound and rule, inbound name, link name, address file. |
| verify | `scripts/verify-vpn.sh`, `scripts/verify-external.sh` | R-vpn-server-13 checks; R-vpn-server-12.c accepts the loopback-only outbound. |
| docs | `docs/decisions/ADR-0010-subscription-through-tunnel.md`, `docs/decisions/INDEX.md`, `docs/decisions/ADR-0002-panel-on-loopback.md`, `docs/vps-access.md` | Decision, index, operator note. |

New modules or dependencies between modules: none.

## Contracts and data

- The client link's name changes; the UUID, keys and short ID do not, so the phone's existing profile keeps working.
- Traffic counters are the panel's per-client counters: bytes through the inbound for that client, in both directions.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Subscription on port 443 behind the Reality cover site | Reality passes anyone without the key to the cover site as raw TCP; Xray never sees the request path. A separate TLS server and a domain would be needed. |
| Subscription on a public port | Contradicts ADR-0002 and can be found by scanners. |
| A hostname for the subscription, e.g. `sub.vpn.internal` | The phone must resolve it before connecting; the server's resolvers cannot, so the request would fail on the phone. An IP literal needs no lookup. |
| A private address such as `10.255.255.1` | Client apps commonly send private ranges outside the tunnel. |

Decision record needed: ADR-0010.

## Verification

| Criterion | Test |
|---|---|
| R-vpn-server-13.a, .b, .c, .e | `scripts/verify-vpn.sh` (R-vpn-server-13.a, .b, .c, .e) |
| R-vpn-server-13.d | `scripts/verify-vpn.sh` (R-vpn-server-13.d); `scripts/verify-external.sh` (R-vpn-server-05.b) |
| R-vpn-server-13.f | `scripts/verify-vpn.sh` (R-vpn-server-13.f) |
| R-vpn-server-05.a to .c | `scripts/verify-vpn.sh`, `scripts/verify-external.sh` (unchanged) |
| R-vpn-server-12.c | `scripts/verify-vpn.sh` (R-vpn-server-12.c, now accepts only a loopback redirect) |

## Risks

- Happ may fetch the subscription outside its tunnel, in which case it cannot reach `192.0.2.1` and the import fails. Contained: the existing key keeps working unchanged; if the test on the phone fails, this change is reverted or reworked, and the owner is told.
- HTTP sniffing in Xray could rewrite the destination before routing. The R-vpn-server-13 checks run through a real client, so they fail if it does.
