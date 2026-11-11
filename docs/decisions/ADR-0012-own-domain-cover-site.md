# ADR-0012: Cover site on the owner's own domain, served from the VPS

- Status: accepted
- Date: 2026-11-12
- Supersedes: ADR-0003
- Change: `changes/archive/2026-11-12-serve-own-cover-site/`

## Context

ADR-0003 made `www.samsung.com` the Reality cover site. `docs/censor-red-flags.md` lists what that gives away:

- Flag 1: the TLS hello names Samsung, but the address belongs to Z.com, a Thai hosting provider.
- Flag 7: a probe without the key is relayed to the real samsung.com, so the TLS reply arrives a round trip late.
- Flag 10: in China samsung.com is served from local CDN nodes, so reaching it through a Thai address is unusual.

The owner holds the domain `casedigestai.com`. On 2026-11-12 the server address was blocked right after a domain was linked to it; the lesson recorded then is that a domain is linked to the VPS only with a decision record. This is that record.

## Decision

The cover site is the owner's own site, served by the VPS itself.

- The cover name, sent by clients as SNI and listed in Reality's `serverNames`, is `status.casedigestai.com`.
- `casedigestai.com` and `status.casedigestai.com` both resolve to the VPS address and both show the same landing page.
- A web server on the VPS holds a Let's Encrypt certificate for both names, renewed automatically. Reality relays every handshake without the client key to that local web server, not to a third party.
- Port 80/tcp is open for certificate issuance and redirects everything else to HTTPS.
- The site content runs in a Docker container published on `127.0.0.1` only. The host web server is the only thing that reaches it.
- The landing page loads nothing from another host and names neither the VPN nor Thailand.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Keep `www.samsung.com` (ADR-0003) | Flags 1, 7 and 10 stay. This was implemented and is replaced. |
| Another third-party cover site | Fixes none of the three flags: the name still doesn't match the address, and the relay still adds a round trip. |
| VLESS over XHTTP or WebSocket behind Cloudflare | Hides the VPS address and fixes flag 2 as well, but it is a different transport with a different client link and its own throughput limits. It stays open as a second transport (flag 6), not as this change. |
| The bare `casedigestai.com` as the cover name | Works equally well on the wire. `status.` was chosen by the owner; a status page is a plausible reason for long-lived connections to a small site. |
| Certificate by DNS-01, with port 80 closed | Needs a DNS provider API token on the server. An ordinary small site answers on port 80, so a closed port 80 is itself unusual. |
| Site content served by the host web server, without Docker | Simpler, but the owner's real website will replace the landing page later and arrives as a container. |

## Consequences

- The name, the address, the certificate and the page now agree. A probe sees an ordinary small site answered locally, with no relay delay.
- The names are public: DNS and the certificate transparency log tie `casedigestai.com` to the VPS address. If the address is blocked, the domain is known to the censor too, and a new address needs new DNS records.
- The 2026-11-12 block followed a domain link. If that link was the cause, this change can trigger the same block. Both names resolved to the server address before the deploy, and the VPN worked on Wi-Fi and mobile data after it. [TODO-CLARIFY: was `casedigestai.com` the domain linked on 2026-11-12, and is the server on a new address since then?]
- The server now runs a web server, certbot and Docker, which are more software to keep patched. Port 80 is a second public TCP port besides SSH and 443.
- If certificate renewal fails for 90 days, probes see an expired certificate. The tunnel itself keeps working, because Reality clients do not validate that certificate.
- Changing the cover name changes the client link once. Every device imports the new link.

## Do not

- Do not use a third-party site as the Reality cover site: its name does not match the VPS address, and relaying probes to it adds a round trip that gives the relay away. (ADR-0012)
- Do not publish a Docker container port on a public address: Docker's firewall rules bypass ufw. Publish on `127.0.0.1` and put the host web server in front. (ADR-0012)
