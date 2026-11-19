# ADR-0026: Dedicated Thai exit, no Reality fallback

- Status: accepted
- Date: 2026-11-19
- Supersedes: ADR-0008, ADR-0009, ADR-0018, ADR-0019
- Change: `changes/archive/2026-11-19-replace-warp-with-dedicated-thai-exit/`

## Context

The exit through Cloudflare WARP placed client traffic in Thailand, but WARP is a shared Cloudflare exit. It does not provide the stable dedicated Thai IPv4 identity required for the owner's Google AI, Claude and YouTube accounts. A dedicated static residential/ISP Thai IPv4 gives those services one stable address that is not shared with other Cloudflare users.

The separately deployed Reality fallback was designed to answer a block of the Cloudflare path, but it added a second server and exposed a hosting-provider address to a user's ISP. The owner removed that fallback on 2026-11-19. Entry resilience stays with the main Cloudflare path, its alternative HTTPS ports, the Gcore reserve path and vetted replacement domains.

## Decision

- All client traffic leaves the VPN server through one operator-provided dedicated static Thai residential/ISP IPv4 proxy. The settings and credentials live only in `/root/vpn/exit-proxy.env`, mode 600, owned by root, and are never committed or printed.
- The Xray default outbound is that proxy, tagged `thai-exit`. There is no `freedom` outbound, no WireGuard/WARP outbound and no automatic exit through the server's own address. When the configured proxy is unreachable, client requests fail.
- The deploy refuses to configure the tunnel until `/root/vpn/exit-proxy.env` exists and is valid. Verification compares the observed public IPv4 with `EXPECTED_EXIT_IPV4`, requires Thailand and rejects a WARP exit.
- The separate directly reached Reality fallback server is removed. The `relay` client, relay link, fallback deploy and verify scripts, and candidate-host check are not part of the architecture.
- The Cloudflare path remains the main entry. The Gcore path remains the hot reserve for Cloudflare throttling (ADR-0025). A blocked domain is replaced by a vetted domain (ADR-0017), not by a directly reached fallback server.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Keep Cloudflare WARP as the exit | It places traffic in Thailand but is shared and does not provide a stable dedicated identity. |
| Route only Google, Claude and YouTube through the dedicated exit | Two exits make an accidental identity split more likely and complicate fail-closed routing. |
| Keep the direct Reality fallback server | It exposes a hosting-provider address to the user's ISP, adds a second server and duplicates deployment and verification work. |
| Let the server fall back to direct egress | The server's address can be geolocated incorrectly and would reveal the VPS as the client exit. |
| Store the exit-proxy credentials in the repository | Credentials are secrets and must remain root-only on the VPS. |

## Consequences

- Google AI services, Claude and YouTube see one stable Thai IPv4 address chosen for the deployment, not the working machine's address and not a shared WARP address.
- The exit provider sees destinations and must be trusted as an upstream provider. The user's ISP still sees only the CDN entry.
- An exit-proxy outage stops client traffic. This fail-closed behavior is intentional.
- A blocked domain requires the redeploy/domain-replacement path. There is no directly reached server to hand out during that incident.
- Throughput and provider classification cannot be verified until a live VPS and real exit-proxy credentials exist. The affected criteria remain `untested` until then.

## Do not

- Do not use Cloudflare WARP, a `freedom` outbound or the server's own address as client egress: the only client exit is the configured dedicated static Thai residential/ISP IPv4. (ADR-0026)
- Do not build or hand out a directly reached Reality fallback server: entry resilience is Cloudflare's alternative ports, the Gcore reserve and vetted replacement domains. (ADR-0026)
