# ADR-0013: Clients reach the server only through Cloudflare

- Status: accepted; the "CDN only" choice and the first "Do not" line superseded by ADR-0018
- Date: 2026-11-12
- Supersedes: ADR-0012 in part (the Reality inbound and the direct client link; the cover site itself stays), ADR-0005 in part (the per-address limits on port 443; the SSH limits stay)
- Change: `changes/archive/2026-11-12-route-clients-through-cloudflare/`

## Context

`docs/censor-red-flags.md`, flag 2: home users sending gigabytes to an address in a hosting provider's block is the basic proxy pattern, whatever name the TLS hello carries. Russia is reported to throttle TLS to foreign hosting networks. Configuration on the VPS cannot change the kind of address it has. Only putting another network in front of it can.

The owner chose on 2026-11-12:

- Cloudflare as that network (free plan; the domain `casedigestai.com` moves its DNS to Cloudflare).
- CDN only: no direct link to the server's address is kept as a fallback.

## Decision

- Clients connect to `status.casedigestai.com:443`, a name proxied by Cloudflare. Their ISP sees TLS to a Cloudflare address, the same addresses that serve millions of ordinary sites.
- The tunnel is VLESS over XHTTP inside ordinary HTTPS. Cloudflare terminates the client's TLS and opens its own TLS connection to the server (SSL mode "Full (strict)", validated against the server's Let's Encrypt certificate).
- On the server, nginx holds port 443. Requests for one random path (kept on the server, part of the client link) go to the Xray XHTTP inbound on loopback. Every other path is the cover site (ADR-0012).
- The VLESS + Reality inbound on 443 is removed. The old `vless://` link stops working.
- The firewall admits 80/tcp and 443/tcp only from Cloudflare's published IPv4 ranges, read from `https://www.cloudflare.com/ips-v4` at deploy time. A probe sent straight to the server's address gets no answer.
- Per-address connection limits on 443 are removed: every client now arrives from a Cloudflare address, so one address carries many users.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Keep the Reality link as a fallback | Recommended for Russia, where Cloudflare is reported to be throttled, but it keeps the server's own address in use, so flag 2 stays open for anyone on that link. The owner chose CDN only. |
| WebSocket instead of XHTTP | Equally well supported by Cloudflare, but a long-lived WebSocket upgrade is a known proxy shape. XHTTP looks like ordinary HTTP requests and is what Xray recommends behind a CDN. |
| gRPC transport | Works through Cloudflare, but needs gRPC switched on in the Cloudflare dashboard and is less common on small sites. |
| Gcore or another paid CDN | Reported to work better in Russia, but needs a paid account and billing. The owner chose Cloudflare. |
| A residential or mobile exit address | Expensive and unreliable, and the server would still be one address. |
| Keep the per-address limits on 443 | All clients share Cloudflare's addresses; a limit per address would throttle many users together. Cloudflare absorbs floods before they reach the server. |

## Consequences

- The ISP sees Cloudflare. Flag 2 is closed; flags 3 and 4 (one address, many users, heavy traffic) are weakened, because the address is shared with ordinary sites.
- Cloudflare sees the tunnel's metadata (timing, volume, the client's address) but not its contents, which are VLESS inside the HTTP body; it does see the path.
- Speed and reach depend on Cloudflare: Russia is reported to throttle Cloudflare since 2025, and Cloudflare's free plan has no nodes inside China. With one transport (flag 6), a Cloudflare block cuts every user off.
- The server's address is still in DNS history and certificate logs from before the move. With 80 and 443 closed to everyone but Cloudflare, that address no longer answers as a website.
- The client link uses the name, not the address. A new server address needs only a DNS change in Cloudflare and a re-run of `deploy-vpn.sh`, not a new link.
- Cloudflare's published ranges can change. A re-run of `deploy-vpn.sh` refreshes them; until then a request through a new range is dropped.
- SSH stays open to everyone (flag 5). That is not part of this decision.

## Do not

- Do not give clients a link to the server's own address, or any way in that does not pass through Cloudflare: the ISP then sees a hosting provider's address (flag 2). (ADR-0013)
- Do not admit 80/tcp or 443/tcp from outside Cloudflare's published ranges: the server's address must not answer probes directly. (ADR-0013)
- Do not limit connections per source address on port 443: every client arrives from a shared Cloudflare address. (ADR-0013)
