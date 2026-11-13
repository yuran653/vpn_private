# ADR-0025: A reserve path through Gcore for Cloudflare throttling

- Status: accepted
- Date: 2026-11-14
- Supersedes: ADR-0018 in part (the rejected alternative "a second CDN in front of the same server", for the throttling scenario only)
- Change: `changes/add-gcore-cdn-reserve/` (open)

## Context

Russian ISPs throttle Cloudflare at the network level: a connection to Cloudflare's addresses passes only its first kilobytes at full speed. The main path (ADR-0013) dies on such a network, and none of the existing measures answer it: rotation, fragmentation and alternative ports all change the client, not the network. The fallback Reality server (ADR-0018, ADR-0019) answers a name block as well, but returns flag 2 (the user's ISP sees a hosting provider's address) and is not built.

The owner chose on 2026-11-14: Gcore as a hot reserve, in parallel with Cloudflare.

## Decision

- The Cloudflare path stays the default and is unchanged. The Gcore path is an addition, not a replacement.
- The reserve path is: client, Gcore (a node inside Russia), the same VPS over HTTPS, the same WARP exit in Thailand. The server's address answers only Cloudflare's and Gcore's published ranges.
- The reserve uses its own name on the same domain, a CNAME to Gcore, not proxied by Cloudflare. Gcore pulls from the origin with the Host header set to the main tunnel name, so the server's existing certificate covers the origin connection; Gcore issues the client-facing certificate.
- Gcore's ranges are fetched from its public API (`/cdn/public-ip-list` or `/cdn/public-net-list`, no authentication) and refreshed on each deploy run, like Cloudflare's.
- The reserve link is the main link with the reserve name in the address, `sni` and `host`; every other setting is copied. It is imported in advance and switched by hand.
- The reserve profile is handed out only after the reserve name passes the phone check (ADR-0017) and the streaming checks of R-vpn-server-28.d pass on the live path.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| A paid Cloudflare plan | Every plan uses the same anycast network. The throttle is applied by Russian ISPs to that network, not to the account, so money buys features, not an unthrottled path. |
| Move the only path to Gcore | Cloudflare is verified where it is not throttled; one network in front is flag 6 again. |
| A cold reserve (switch DNS during an incident) | Propagation delay during an outage, and an untested path. The hot reserve is tested before it is needed. |
| CDNs under Russian jurisdiction (Selectel, EdgeCenter, VK Cloud, Ngenix) | Their nodes answer the throttle, but the provider itself must enforce the censor's rules and can be made to cut the name. |
| Fastly, CloudFront, Bunny | No nodes inside Russia; the same network-level throttle can reach them later. Candidates if Gcore fails R-vpn-server-28.d. |

## Consequences

- A network that throttles Cloudflare no longer cuts the user off: the reserve's first hop stays inside Russia on Gcore's nodes, and the leg to Thailand is not Cloudflare's network.
- The reserve answers throttling only. A block of the domain cuts both paths; that scenario remains the fallback server's job (ADR-0018).
- Two names on one domain are in use, and two networks see the traffic's metadata. Neither sees the VLESS contents.
- Gcore's origin timeouts (5 s to connect, 30 s between reads on standard plans) may not fit XHTTP. R-vpn-server-28.d is the gate: if it fails, the reserve is not handed out.
- One more allowlist to keep fresh; a stale list drops requests from Gcore's new ranges until the deploy re-runs.
- Nothing is built yet (2026-11-14). The scripts and the live test are tasks 3 and 4 of the change.

## Do not

- Do not respond to Cloudflare throttling with a paid Cloudflare plan or by moving the only path to another CDN: the throttle is applied by Russian ISPs to Cloudflare's network, not to the account, and the Gcore path is an addition to the Cloudflare path, not a replacement. (ADR-0025)
