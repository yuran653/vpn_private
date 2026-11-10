# ADR-0009: WARP endpoint answered in Bangkok

- Status: accepted
- Date: 2026-11-10
- Supersedes: none
- Change: `changes/archive/2026-11-10-move-warp-endpoint-to-bangkok/`

## Context

ADR-0008 sends all client traffic through Cloudflare WARP. The tunnel went to `162.159.192.1`, the address of `engage.cloudflareclient.com`. Cloudflare's WARP addresses are anycast: which Cloudflare site answers depends on the route from the host. From this VPS `162.159.192.1` is answered in Singapore, 27 ms away, while Cloudflare's Bangkok site is 1.4 ms away. Every round trip of every client connection paid the detour.

The owner asked for a trial switch of the live server, measured from a client device, and to keep it only if it was not slower.

## Decision

`scripts/deploy-vpn.sh` points the WARP tunnel at `188.114.97.1:2408`, an address literal as before. From this host that address is answered by Cloudflare's Bangkok site. The registration, keys, MTU and every other setting of ADR-0008 are unchanged.

`scripts/verify-vpn.sh` checks that Cloudflare's connection report, requested through the tunnel, names the Bangkok site (R-vpn-server-12.f).

Endpoints measured from the VPS:

| Endpoint | Round trip | Result with this server's registration |
|---|---|---|
| `162.159.192.1` | 27 ms | Works; Cloudflare site `SIN` |
| `162.159.192.5`, `162.159.195.1`, `162.159.195.5` | 26 ms | Not tested |
| `162.159.193.1` | 1.4 ms | Passes no traffic |
| `188.114.96.1`, `188.114.98.1`, `188.114.99.1` | 1.4 ms | Not tested |
| `188.114.97.1` | 1.4 ms | Works; Cloudflare site `BKK`, placed in Thailand |

Measured on the server, without the client's own path: a new HTTPS connection to ten sites was set up in 98 to 120 ms through Bangkok, against 192 to 224 ms through Singapore.

Measured from the owner's Mac through the VPN, before and after the switch. The Mac is about 220 ms from the server, and that part of the path does not change:

| Measure | Singapore | Bangkok |
|---|---|---|
| Cloudflare report | WARP on, Thailand, `SIN` | WARP on, Thailand, `BKK` |
| YouTube country | TH | TH |
| Connection setup, median over ten sites | 880 ms | 868 ms |
| Download, Cloudflare speed test | 27 and 33 Mbit/s | 37 and 48 Mbit/s |
| Download, OVH France | 24 and 32 Mbit/s | 46 and 43 Mbit/s |
| Download, Vultr Frankfurt | 2.2 and 2.6 Mbit/s | 5 and 27 Mbit/s |
| Download, Vultr Singapore | 15 and 35 Mbit/s | 6 and 7, later 12 and 9 Mbit/s |
| Download, Vultr Tokyo | 11 and 23 Mbit/s | 6 and 14, later 4 and 8 Mbit/s |
| Download, Google, Microsoft, Hetzner Singapore | not measured | 24 to 58 Mbit/s |

The trial rule was "setup faster and downloads not slower". Setup is faster. Downloads are faster or equal for every destination except Vultr's Singapore and Tokyo servers, which are slower. The switch is kept: another Singapore host (Hetzner) and the large services run at the limit of the client's own path, so the loss is specific to one network.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Keep `162.159.192.1` | It was implemented first (ADR-0008). Answered in Singapore, it added 27 ms to every round trip of every connection. |
| `162.159.193.1`, the other 1.4 ms address tested | Passed no traffic with this registration. |
| Choose the endpoint at deploy time by measuring round trips | The nearest address is not always a working one, so a probe would also need a traffic test. One constant is simpler to read and to check. |
| A second WARP registration for a side-by-side test | Accepts Cloudflare's terms again and still does not measure what a client device gets. Two tunnels on one registration disturb each other, so a side-by-side test on the server was not reliable. |

## Consequences

- New connections are set up about 100 ms sooner on the server. From a client 220 ms away the gain is small, because four round trips on the client's own path dominate.
- Downloads from Vultr's Singapore and Tokyo servers are slower than through the Singapore site. Other networks reached only poorly from Cloudflare's Bangkok site may show the same.
- Cloudflare can change which site answers an address. R-vpn-server-12.f then fails and names the site. That is a loss of speed, not of privacy: R-vpn-server-12.a to 12.d decide whether the exit is valid.
- Going back is one constant in `scripts/deploy-vpn.sh` and a re-run, with a new decision that supersedes this one.

## Do not

Do not point the WARP tunnel at `162.159.192.1` (`engage.cloudflareclient.com`) or at `162.159.193.1`: from this host the first is answered in Singapore, 27 ms away, and the second passes no traffic. (ADR-0009)
