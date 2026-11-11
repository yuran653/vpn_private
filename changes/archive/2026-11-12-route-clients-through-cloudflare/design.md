# Design: route-clients-through-cloudflare

## Approach

Cloudflare proxies both site names. The server's nginx moves from `127.0.0.1:8443` to the public port 443 (it was Reality's) and gains one location, the tunnel path, which it hands to an Xray VLESS + XHTTP inbound on `127.0.0.1:10443` with `grpc_pass` (HTTP/2 without TLS on loopback). ufw admits 80 and 443 only from Cloudflare's ranges. The Reality inbound is deleted once the new inbound exists.

The deploy order keeps a failed run harmless until the cut-over: site and certificate checks, then a DNS check (both names must resolve to Cloudflare only), then the new inbound, then the cut-over (delete Reality, restart Xray, firewall, nginx on 443).

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| deploy | `scripts/deploy-vpn.sh` | Cloudflare ranges, DNS check, XHTTP inbound, Reality removal, nginx on 443 with the tunnel path, firewall by range, port-443 limits block removed, new link format |
| verify | `scripts/verify-vpn.sh`, `scripts/verify-external.sh` | Client built from the XHTTP link; checks for R-vpn-server-04, 05, 11.b, 14, 15, 17 rewritten; R-vpn-server-01.b and 10.a checks removed |
| docs | `AGENTS.md`, `docs/vps-access.md`, `docs/censor-red-flags.md` | Describe the Cloudflare path; flag 2 marked fixed |

New modules or dependencies between modules: none.

## Contracts and data

- Client link: `vless://<id>@status.casedigestai.com:443?encryption=none&security=tls&sni=…&fp=chrome&alpn=h2%2Chttp%2F1.1&type=xhttp&host=…&path=%2F<hex>&mode=auto#<name>`. Every device imports it once; the Reality link stops working at the cut-over.
- The tunnel path is 24 random hex characters, made once and stored in the inbound. A re-run reads it back.
- `/root/vpn/cloudflare-ips-v4.txt`: the last ranges fetched. Used when the fetch fails on a re-run.
- `/root/vpn/inbound-previous.json`: the deleted Reality inbound, root-only, so it can be restored by hand.

## Alternatives rejected

See ADR-0013 (WebSocket, gRPC, keeping Reality, another CDN).

| Alternative | Why rejected |
|---|---|
| Cloudflare Origin CA certificate instead of Let's Encrypt | Its private key is made in the Cloudflare dashboard and would have to be copied to the server by hand; certbot already renews unattended, and HTTP-01 passes through Cloudflare. |
| ufw rules in `before.rules` for the ranges | `ufw status` would not show them, and R-vpn-server-05.c is read from it. |

Decision record needed: ADR-0013

## Verification

| Criterion | Test |
|---|---|
| R-vpn-server-04.a | `scripts/verify-external.sh`, `scripts/verify-vpn.sh` (R-vpn-server-04.a) |
| R-vpn-server-04.b | `scripts/verify-external.sh`, `scripts/verify-vpn.sh` (R-vpn-server-04.b) |
| R-vpn-server-04.c | `scripts/verify-vpn.sh` (R-vpn-server-04.c) |
| R-vpn-server-05.a–c | `scripts/verify-vpn.sh`, `scripts/verify-external.sh` (R-vpn-server-05.*) |
| R-vpn-server-11.b | `scripts/verify-vpn.sh` (R-vpn-server-11.b) |
| R-vpn-server-14.a, 14.c | `scripts/verify-vpn.sh` (R-vpn-server-14.*) |
| R-vpn-server-15.a–e | `scripts/verify-external.sh` (R-vpn-server-15.*) |
| R-vpn-server-17.a | `scripts/verify-external.sh`, `scripts/verify-vpn.sh` (R-vpn-server-17.a) |
| R-vpn-server-17.b | `scripts/verify-external.sh` (R-vpn-server-17.b) |

## Risks

- The cut-over drops the Reality link at once. It runs only after the names resolve to Cloudflare, and the deleted inbound is kept for a manual restore.
- Cloudflare's ranges change: a re-run refreshes them.
- XHTTP through nginx `grpc_pass` is the path Xray documents; the deploy script checks that the inbound answers through nginx before writing the link.
