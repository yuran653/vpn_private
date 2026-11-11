# Proposal: serve-own-cover-site

## Why

The server presents itself as `www.samsung.com` from a Thai hosting address. That mismatch (flag 1), the delay of relaying probes to Samsung (flag 7) and the odd route for Chinese users (flag 10) are listed in `docs/censor-red-flags.md`. Serving the owner's own domain from the VPS removes all three. See ADR-0012.

## What changes

- A visitor or probe that opens `https://casedigestai.com` or `https://status.casedigestai.com` gets a landing page for "CaseDigest AI" with a valid, publicly trusted certificate for that name.
- A TLS client without the VPN key that connects to port 443 gets that same site, answered by the VPS itself. Nothing is relayed to a third party.
- Port 80 answers and redirects to HTTPS. The firewall now admits SSH, 80/tcp and 443/tcp.
- The certificate renews without an operator.
- The client link names `status.casedigestai.com` instead of `www.samsung.com`. The old link stops working; the client ID and keys stay the same.
- The landing page: one static page, navy and white, a serif heading, light and dark modes, usable on a phone. It carries the name, the line "An AI assistant for lawyers working with multi-volume cases", three short benefits, a "Coming soon" note and the footer "© 2026 CaseDigest AI". It has no trackers, outside fonts or scripts, forms or contact email, and it makes no outbound calls.
- The web server keeps no access log.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-server | existing | `specs/vpn-server/spec.md` |

## Out of scope

- Flags 2, 3, 4, 5, 6, 8 and 9: the datacenter address, traffic shape, open SSH, a second transport, the client fingerprint and HTTP/3.
- The owner's real website. It replaces the landing page later, as its own change.
- DNS records. The owner sets them at the registrar; the scripts only check them.
- A spare address. The incident lessons call for one; this change does not provide it.

## Decisions checked

- ADR-0002: the panel and its ports stay on loopback. The new public port is 80 only; the site container is published on `127.0.0.1` only.
- ADR-0003: superseded by ADR-0012 in this change.
- ADR-0004: Docker must run with the kernel's IPv6 off. No IPv6 is enabled for it.
- ADR-0005: the per-address limits on 443 stay. Port 80 gets none. [TODO-CLARIFY: should port 80 get the same per-address limits as 443?]
- ADR-0008: the certificate client and Docker image pulls are the host's own traffic, not client traffic, so they leave from the server address as apt already does. No `freedom` outbound is added to Xray.

## Open questions

Neither blocks writing the scripts. Both must be answered before the deploy.

- [TODO-CLARIFY: is the server on a new address after the 2026-11-12 block, and do the A records of `casedigestai.com` and `status.casedigestai.com` point at it, as DNS-only records with no CDN proxy in front?]
- [TODO-CLARIFY: was `casedigestai.com` the domain linked on 2026-11-12? If yes, the same link may get the new address blocked again; the incident lessons say to test on a spare address first.]
