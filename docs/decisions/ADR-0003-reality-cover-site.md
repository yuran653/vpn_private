# ADR-0003: Reality cover site

- Status: superseded by ADR-0012
- Date: 2026-11-10
- Supersedes: none
- Change: `changes/archive/2026-11-10-deploy-vless-reality/`

## Context

Reality forwards any handshake without the client key to a real third-party site, so a probe sees that site. The site must support TLS 1.3, HTTP/2 and X25519, and its certificate must name the host that clients send as SNI.

## Decision

The cover site is `www.samsung.com:443`. It was chosen from the panel's own Reality target scan, run from the VPS on 2026-11-10: it passed every feasibility check, its certificate names the host exactly, and it answered in 167 ms. The value is the `REALITY_TARGET` constant in `scripts/deploy-vpn.sh`.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| `www.nvidia.com` (49 ms, fastest in the scan), `dl.google.com`, `www.intel.com` | All passed the scan, but the host is not listed by its exact name in the certificate (it is covered by a wildcard or the certificate's subject is another host). A certificate that names the host exactly was preferred. |
| `www.cloudflare.com` | A Cloudflare address range is expected behind that name; a Thai hosting address is not. |
| `www.microsoft.com`, `www.sony.com` | Passed, but roughly twice the latency from this VPS. |

[TODO-CLARIFY: is `www.samsung.com` reachable and unremarkable on the networks the owner connects from?]

## Consequences

If the cover site changes its TLS setup or blocks the VPS, the tunnel stops working; `scripts/verify-external.sh` fails when the site no longer returns a valid certificate. Changing the cover site changes the client link.

## Do not

None.
