# Design: route-egress-through-warp

## Approach

`scripts/deploy-vpn.sh` registers the server once as a free WARP device with Cloudflare's client API, keeps the result in a root-only file, and writes an Xray WireGuard outbound from it. That outbound replaces the `direct` outbound in the Xray template, so it is the default route for everything the routing rules do not block. The server's DNS-over-HTTPS resolvers change from "sent by the host" to "sent through the routing", which puts lookups on the same exit as the traffic.

Details:

- **Registration.** A Curve25519 key pair is made with `openssl`. The public key is posted to `https://api.cloudflareclient.com/v0a2158/reg`. The answer gives the device's tunnel IPv4 address, the peer public key and the `client_id`, whose three bytes are the WireGuard `reserved` field. Registering accepts Cloudflare's terms of service for the owner (owner's permission, 2026-11-10). The private key, device id and token are stored in `/root/vpn/warp.json`, mode 600. The step is skipped when that file exists.
- **Outbound.** Protocol `wireguard`, tag `warp`, first in the list. IPv4 address only, `allowedIPs` `0.0.0.0/0`, MTU 1280, `domainStrategy` `ForceIPv4`, `noKernelTun` true. The endpoint is the address literal `162.159.192.1:2408`, so reaching WARP needs no name lookup.
- **No freedom outbound.** The template's `direct` outbound is deleted. Nothing can leave from the server's address through Xray routing, whatever rule matches.
- **DNS.** `https+local://` becomes `https://` for both resolvers. Xray then sends its lookups through the routing, which means through WARP. The resolvers are address literals, so there is no lookup loop.
- **Unchanged.** The rules for the API, port 53, IPv6 destinations, private addresses and BitTorrent. The inbound, its keys and the client link.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| deploy | `scripts/deploy-vpn.sh` | WARP registration step; template gets the `warp` outbound, loses `direct`, DNS goes through routing. |
| verify | `scripts/verify-vpn.sh` | Checks for R-vpn-server-12; R-vpn-server-01.a and 02.c compare against "not the server's address". |
| docs | `docs/vps-access.md`, `docs/decisions/ADR-0008-egress-through-warp.md`, `docs/decisions/INDEX.md`, `AGENTS.md` | WARP section, decision record, "Do not" line. |

New modules or dependencies between modules: none.

## Contracts and data

- New stored file `/root/vpn/warp.json` (root only): WARP private key, device id, token, tunnel address, peer key, reserved bytes.
- The Xray template now holds the WARP private key. It is stored in the panel database and `/usr/local/x-ui/bin/config.json`, both readable by root only.
- New outside dependency at run time: Cloudflare WARP. At first deploy: Cloudflare's registration API.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Route only YouTube and Google names through WARP | The owner asked for all traffic. Two exits also give one device two countries, which Google accounts flag. |
| Keep `direct` and add a catch-all rule to `warp` | A rule edit or a missed case would leak traffic from the server's address without notice. With no freedom outbound that cannot happen. |
| Kernel WireGuard interface (`wg-quick`, `warp-cli`) with policy routing | Adds a network interface and routing tables on a host whose firewall and boot checks assume one interface; a mistake there cuts SSH. Xray's user-space tunnel changes nothing on the host. |
| The panel's own WARP button | Its API is not part of what the script already checks, and the registration would live only in the panel database. |
| Ask the provider for another address | Still the right long-term fix, but slow and outside the repo. It can be done later and WARP removed. |

Decision record needed: ADR-0008.

## Verification

All checks are in `scripts/verify-vpn.sh`, run on the VPS, each labelled with its criterion.

| Criterion | Test |
|---|---|
| R-vpn-server-01.a | exit address through the tunnel is IPv4 and differs from the server's |
| R-vpn-server-02.c | dual-stack site sees an IPv4 address |
| R-vpn-server-05.a | public TCP listeners are SSH and 443; public UDP sockets belong to the proxy only |
| R-vpn-server-12.a | `cdn-cgi/trace` through the tunnel has `warp=on` |
| R-vpn-server-12.b | `cdn-cgi/trace` through the tunnel has `loc=TH` |
| R-vpn-server-12.c | running config has no `freedom` outbound and its first outbound is `warp` |
| R-vpn-server-12.d | `music.youtube.com` through the tunnel is not the "not available" page |
| R-vpn-server-12.e | untested by script; the deploy is run twice and the checksum of `warp.json` compared |
| R-vpn-server-09.a | untested by script, as before; the run output is searched for the key and token |

## Risks

- WARP outage: clients lose the internet until it returns. Accepted; the alternative is leaking from the mislocated address. Recovery is in `docs/vps-access.md`.
- Cloudflare changes the unofficial registration API: only a first deploy on a new host is affected; an existing `warp.json` keeps working.
- Throughput: the tunnel runs in user space on 2 vCPUs. Measured after the deploy and recorded in the ADR.
- Some sites show more captchas to WARP addresses.
- The user-space tunnel holds an unconnected UDP socket on a random port of every address (seen after the first deploy). It is the tunnel's sending socket. ufw denies new incoming traffic to it and admits only replies from the WARP endpoint. R-vpn-server-05.a is modified to name this one exception; its check now requires that the TCP listeners are exactly SSH and 443 and that every public UDP socket belongs to the proxy.
