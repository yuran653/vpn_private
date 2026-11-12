# Proposal: add-fallback-reality-server

## Why

The only way in, through Cloudflare on one domain, failed on a Russian mobile network on 2026-11-12, and a block of the name or of Cloudflare cuts every user off at once (flag 6 in `docs/censor-red-flags.md`). ADR-0018 decided a second transport on a separate server, for Russia first.

## What changes

- A second server exists, on its own VPS and address. A client holding its link connects to that address directly on 443/tcp (VLESS with Reality and Vision) and reaches the internet with the same protections as on the first server: no IPv6, DNS kept inside, no activity record, no exit from the server's own address.
- A party without the link that connects to 443 on that address gets the certificate and pages of a third-party site hosted in the same provider network.
- That server's SSH port answers only the operator's known addresses.
- A check run from a phone on mobile data tells whether a candidate address can carry the fallback from that network, before the server is kept.
- The first server and its link are unchanged.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-fallback | new | `specs/vpn-fallback/spec.md` |
| vps-baseline | existing | `specs/vps-baseline/spec.md` |

## Out of scope

- An entry relay inside Russia, a host with a premium route to China, and a QUIC transport: later steps, each with its own decision (ADR-0018).
- Restricting SSH on the first server. The baseline gains the option; using it there is a separate change.
- Automatic switching between the two links in the client app. The user picks the fallback profile by hand.
- Per-user client IDs. One client, as on the first server.
- Replacing the blocked domain of the first server (`docs/redeploy.md`).

## Decisions checked

- ADR-0013, reworded by ADR-0018 (no way in on the server behind Cloudflare; a way in outside Cloudflare runs on a separate server, as a fallback): followed. Nothing changes on the first server.
- ADR-0012, reworded by ADR-0018 (Reality cover site in the VPS's provider network; no own domain on a VPS address): followed, and checked by R-vpn-fallback-02.b.
- ADR-0018 (the direct link is not the default; no clients while SSH is open to everyone): R-vpn-fallback-03.b and R-vps-baseline-08.
- ADR-0002 (panel on loopback, no port opened for it): followed.
- ADR-0004 (IPv6 off by kernel parameter), ADR-0005 (no `ufw limit` on SSH), ADR-0008 (no `freedom` outbound): followed.
- ADR-0009 (WARP endpoint): its measurements are for the Bangkok host. The endpoint for the second host is measured at deploy time and recorded.
- ADR-0015 (no browser `fp` and no `h2` in the client link): written for the HTTP/1.1 link through Cloudflare. A Reality link has to send a hello like a browser's, since it borrows a real site's name. The line needs wording that limits it to the Cloudflare link; proposed as part of this change. [TODO-CLARIFY: confirm that ADR-0015's line applies to the Cloudflare link only.]
- ADR-0017 (names vetted from a mobile network; blocked names not reused): the fallback link carries a borrowed name, not one of ours. The same idea is applied to the address by R-vpn-fallback-06.

## Open questions

- [TODO-CLARIFY: must traffic through the fallback exit in Thailand, like the first server? WARP exits in the country of the server it runs on, so a second server outside Thailand exits elsewhere. Options: (a) host the second server in Thailand at another provider; (b) let it exit where it stands; (c) make it an entry only, which forwards to the first server through that server's own Cloudflare link, so the exit stays in Thailand at the price of one more hop and a dependency on the first server. This decides R-vpn-fallback-04.d and the design of the exit.]
- [TODO-CLARIFY: which candidate providers and locations are tried from a phone in Russia? (ADR-0018)]
- [TODO-CLARIFY: which addresses may reach SSH on the second server? A home address that changes locks the operator out until the provider's console is used.]
