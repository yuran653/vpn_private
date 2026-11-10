# Design: move-warp-endpoint-to-bangkok

## Approach

Change the one constant that names the WARP endpoint in `scripts/deploy-vpn.sh` from `162.159.192.1:2408` to `188.114.97.1:2408`, re-run the script on the VPS, and add a check to `scripts/verify-vpn.sh` that Cloudflare's connection report names the Bangkok site. The WARP registration, keys, MTU and every other outbound setting stay as they are.

Both addresses are Cloudflare anycast addresses for WARP. Which site answers depends on the route from the host. Measured from the VPS on 2026-11-11:

| Endpoint | Round trip | Result with this server's registration |
|---|---|---|
| `162.159.192.1` (`engage.cloudflareclient.com`) | 27 ms | Works; Cloudflare site `SIN` |
| `162.159.192.5`, `162.159.195.1`, `162.159.195.5` | 26 ms | Not tested |
| `162.159.193.1` | 1.4 ms | Passes no traffic |
| `188.114.96.1` to `188.114.99.1` | 1.4 ms | `188.114.97.1` works; Cloudflare site `BKK`, placed in Thailand |

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| vpn-server | `scripts/deploy-vpn.sh` | `WARP_ENDPOINT` and its comment |
| vpn-server | `scripts/verify-vpn.sh` | New check R-vpn-server-12.f |
| docs | `docs/decisions/ADR-0009-warp-endpoint-in-bangkok.md`, `docs/decisions/INDEX.md`, `docs/vps-access.md` | Decision record, "Do not" line, operator note |

New modules or dependencies between modules: none.

## Contracts and data

None. `/root/vpn/warp.json` is read, not rewritten. The client link is unchanged.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Keep `162.159.192.1` | 27 ms added to every round trip of every connection. |
| `162.159.193.1`, the other 1.4 ms address | Passed no traffic in the test on 2026-11-11. |
| Pick the endpoint at deploy time by measuring round trips | The nearest address is not always a working one (`162.159.193.1`), so a probe would also need a traffic test; more moving parts than one constant. |
| A second WARP registration for a side-by-side test | Accepts Cloudflare's terms again, and still does not measure what a client device gets. |

Decision record needed: ADR-0009

## Verification

| Criterion | Test |
|---|---|
| R-vpn-server-12.f | `scripts/verify-vpn.sh` (R-vpn-server-12.f) |
| R-vpn-server-12.a, .b, .c, .d | `scripts/verify-vpn.sh`, unchanged checks, re-run after the switch |

Trial measurement, not an acceptance criterion: `curl` timings and downloads from the owner's Mac through the VPN, before and after the switch, recorded in ADR-0009.

## Risks

- Downloads from sites outside Cloudflare may be slower through the Bangkok site. Contained by the before/after measurement; going back is the same one-line change and a re-run.
- Cloudflare may later route the address to another site. R-vpn-server-12.f then fails and names the site; privacy checks 12.a to 12.d are separate and still decide whether the exit is valid.
- Re-running the deploy script restarts Xray and drops client connections for a few seconds, including an SSH session that travels through this VPN. The script is started detached.
