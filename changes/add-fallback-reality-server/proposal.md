# Proposal: add-fallback-reality-server

## Why

The only way in, through Cloudflare on one domain, failed on a Russian mobile network on 2026-11-12, and a block of the name or of Cloudflare cuts every user off at once (flag 6 in `docs/censor-red-flags.md`). ADR-0018 decided a second transport on a separate server, for Russia first.

## What changes

- A second server exists, on its own VPS and address. A client holding its link connects to that address directly on 443/tcp (VLESS with Reality and Vision) and reaches the internet through the first server: the second server is an entry only and forwards everything to the first one through Cloudflare, so the exit is the first server's, in Thailand, with its protections (ADR-0019).
- The first server issues a second client ID, `relay`, for the second server.
- A party without the link that connects to 443 on that address gets the certificate and pages of a third-party site hosted in the same provider network.
- That server's SSH port answers only the operator's known addresses.
- A check run from a phone on mobile data tells whether a candidate address can carry the fallback from that network, before the server is kept.
- The first server's own link is unchanged.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-fallback | new | `specs/vpn-fallback/spec.md` |
| vps-baseline | existing | `specs/vps-baseline/spec.md` |
| vpn-server | existing | `specs/vpn-server/spec.md` |

## Out of scope

- An entry relay inside Russia, a host with a premium route to China, and a QUIC transport: later steps, each with its own decision (ADR-0018).
- Restricting SSH on the first server. The baseline gains the option; using it there is a separate change.
- Automatic switching between the two links in the client app. The user picks the fallback profile by hand.
- Per-user client IDs. One client, as on the first server.
- Replacing the blocked domain of the first server (`docs/redeploy.md`).

## Decisions checked

- ADR-0013's two other lines (80 and 443 from Cloudflare's ranges only, no per-address limits on 443) are scoped to the server behind Cloudflare since 2026-11-12; the second server admits 443 from anywhere.
- ADR-0013, reworded by ADR-0018 (no way in on the server behind Cloudflare; a way in outside Cloudflare runs on a separate server, as a fallback): followed. The first server opens no port; the relay arrives through Cloudflare like any client.
- ADR-0012, reworded by ADR-0018 (Reality cover site in the VPS's provider network; no own domain on a VPS address): followed, and checked by R-vpn-fallback-02.b.
- ADR-0018 (the direct link is not the default; no clients while SSH is open to everyone): R-vpn-fallback-03.b and R-vps-baseline-08.
- ADR-0002 (panel on loopback, no port opened for it): followed.
- ADR-0004 (IPv6 off by kernel parameter), ADR-0005 (no `ufw limit` on SSH), ADR-0008 (no `freedom` outbound): followed on both servers.
- ADR-0019 (the fallback has no way out of its own): R-vpn-fallback-04.c and 04.e.
- ADR-0009 (WARP endpoint): does not apply to the second server, which has no WARP tunnel.
- ADR-0015 (no `h2` and no browser `fp` in a client link that goes through Cloudflare): does not apply to the direct Reality link, as the line says since it was reworded on 2026-11-12. A Reality link borrows a real site's name and sends a browser's hello.
- ADR-0017 (names vetted from a mobile network; blocked names not reused): the fallback link carries a borrowed name, not one of ours. The same idea is applied to the address by R-vpn-fallback-06.

## Open questions

- [TODO-CLARIFY: which candidate providers and locations are tried from a phone in Russia? (ADR-0018)]
- [TODO-CLARIFY: which addresses may reach SSH on the second server? A home address that changes locks the operator out until the provider's console is used.]
