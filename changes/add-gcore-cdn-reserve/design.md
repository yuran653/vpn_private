# Design: add-gcore-cdn-reserve

## Approach

Nothing new runs on the server. The reserve is a second CDN resource in front of the existing nginx, plus firewall rules for Gcore's ranges, plus one more client link. The deploy script already has every piece of the pattern: it fetches Cloudflare's ranges into a root-only file and admits them, and it writes alternative links from the main one (ADR-0020). The reserve reuses both.

The Gcore resource is configured once per domain by the operator, not by the deploy script: Gcore's API token would otherwise sit on the VPS, the same reason ADR-0021's ECH setting is an operator step.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| scripts | `scripts/deploy-vpn.sh` | Fetch Gcore's published ranges into `/root/vpn/gcore-ips.txt`; admit them to the same ports as Cloudflare's; write the reserve link to `/root/vpn/vless-link-reserve.txt`. |
| scripts | `scripts/verify-vpn.sh` | Firewall and link checks for R-vpn-server-28.a and 28.c. |
| scripts | `scripts/verify-external.sh` | Probe and certificate checks for R-vpn-server-28.b; the reserve name in the word and blocked-name checks. |
| docs | `docs/redeploy.md`, `docs/vps-access.md`, `AGENTS.md` | The order for the reserve path (this change, done). |
| docs | `docs/decisions/` | ADR-0025 and the index (this change, done). |

New modules or dependencies between modules: none. `docs/architecture.md` lists no modules yet.

## Contracts and data

- Gcore CDN resource, set by the operator: origin is the VPS address over HTTPS on 443; the origin Host header is the main tunnel name (so the origin certificate is the existing one); caching off; the client-facing certificate for the reserve name is issued by Gcore.
- Gcore's ranges come from the public API without authentication: `https://api.gcore.com/cdn/public-ip-list` (individual addresses) or `https://api.gcore.com/cdn/public-net-list` (networks, fewer rules). Gcore states that the list changes over time and asks consumers to refresh it on a schedule; the deploy refreshes it on each run, like the Cloudflare ranges.
- New root-only state on the server: `/root/vpn/gcore-ips.txt` and `/root/vpn/vless-link-reserve.txt`.
- The reserve link is the main link with the address, `sni` and `host` set to the reserve name. The client ID, path, ALPN, fingerprint, padding and fragmentation settings are unchanged, so the reserve and main links stay interchangeable for the server.
- No Gcore API token on the VPS or in the repo. The public IP list needs none.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| A paid Cloudflare plan | Every plan uses the same anycast network; the throttle is applied by Russian ISPs to that network, not to the account. |
| Move the only path from Cloudflare to Gcore | Cloudflare is the verified path where it is not throttled; one network in front is flag 6 again, only with a different name. |
| A cold reserve: switch DNS to Gcore only when Cloudflare is throttled | The switch happens during an incident, takes DNS propagation time, and the name's behavior on Gcore is unknown until then. A hot reserve is imported and tested in advance. |
| CDNs under Russian jurisdiction | Their nodes answer the throttle, but the provider itself must enforce the censor's rules and can be made to cut the name. |
| Fastly, CloudFront or Bunny as the reserve | No nodes inside Russia; the same network-level throttle can reach them later. Candidates if Gcore fails the streaming checks. |
| An origin certificate for the reserve name on the VPS | The reserve name resolves to Gcore, so an HTTP-01 challenge for it does not reach the server. Reusing the main tunnel name as the origin Host header avoids a second certificate and a DNS-01 token. |
| A Gcore API token on the server, to manage the resource from the deploy | The token would sit on the VPS; the resource is a one-time operator step per domain. |

Decision record needed: ADR-0025 (written), which supersedes ADR-0018's rejection of a second CDN for the throttling scenario.

## Verification

| Criterion | Test |
|---|---|
| R-vpn-server-28.a | `scripts/verify-vpn.sh` (a temporary client built from the reserve link, as for the main link) |
| R-vpn-server-28.b | `scripts/verify-external.sh` |
| R-vpn-server-28.c | `scripts/verify-vpn.sh` |
| R-vpn-server-28.d | Run by hand through the reserve path on a live server; no automated test until the path exists |

## Risks

- **Gcore buffers or cuts XHTTP.** Standard origin timeouts are 5 s to connect and 30 s between reads, and raising them needs the Enterprise plan. If R-vpn-server-28.d fails, the reserve is not handed out and the alternatives above come back.
- **The allowlist goes stale.** Gcore changes its ranges; a re-run of the deploy refreshes them, as for Cloudflare. Until a re-run, a request from a new range is dropped.
- **The reserve name shares the domain's fate.** A block of the domain cuts both paths. Accepted: the reserve is for throttling, not for name blocks.
- **Two networks see the traffic's metadata.** Gcore, like Cloudflare, sees timing, volume and the client's address, not the VLESS contents.
- **No server to test on.** Nothing here has run on a VPS; no criterion is marked verified before a live run.
