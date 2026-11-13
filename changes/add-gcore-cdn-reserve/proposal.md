# Proposal: add-gcore-cdn-reserve

## Why

Russian ISPs throttle Cloudflare at the network level: only the first kilobytes of a connection to Cloudflare's addresses pass at full speed. No setting of ours answers that: connection rotation (ADR-0014), hello fragmentation (ADR-0021) and the alternative ports (ADR-0020) all change the client's behavior, not the network's. A paid Cloudflare plan does not help either, because every plan uses the same anycast network. When the main path is throttled on a user's network, that user is cut off (flag 6 in `docs/censor-red-flags.md`).

The owner chose on 2026-11-14: a reserve path through Gcore's CDN, in parallel with the Cloudflare path, switched by hand.

## What changes

- A second way in exists: client, Gcore (a node inside Russia), the same VPS, the same WARP exit in Thailand. The server's address stays hidden: Gcore pulls from it over HTTPS, and the firewall admits Gcore's published ranges as it admits Cloudflare's.
- The reserve path uses its own name on the same domain, a CNAME to Gcore, not proxied by Cloudflare. The main name and the main link are unchanged.
- The Gcore resource pulls with the origin Host header set to the main tunnel name, so the server's existing certificate covers the origin connection; Gcore issues the client-facing certificate for the reserve name.
- The user imports the reserve profile in advance and switches to it by hand when the Cloudflare path is throttled.
- Before the reserve profile is handed out, the reserve name passes the phone check (ADR-0017) and the reserve path passes the streaming checks of R-vpn-server-28.d.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-server | existing | `specs/vpn-server/spec.md` (R-vpn-server-28) |

## Out of scope

- A block of the name. The reserve path answers a network throttle of Cloudflare only; a flagged name is cut on any CDN (ADR-0018's reason for rejecting a second CDN still stands for that scenario).
- The fallback Reality server (`changes/add-fallback-reality-server/`). The reserve does not replace it: the fallback answers a name block as well, the reserve does not.
- Automatic switching between profiles in the client app.
- CDNs under Russian jurisdiction (Selectel, EdgeCenter, VK Cloud, Ngenix): their nodes answer the throttling problem, but the provider itself is obliged to enforce the censor's rules.
- A paid Cloudflare plan.

## Decisions checked

- ADR-0013 (the server's web ports admit Cloudflare's ranges only; the address answers nobody else): extended by ADR-0025 to Gcore's published ranges. The principle "the origin answers only the networks in front of it" is kept.
- ADR-0013 (no per-address limits on 443): unchanged; reserve clients also arrive from shared CDN addresses.
- ADR-0018 (rejected alternative "a second CDN in front of the same server"): superseded in part by ADR-0025 for the throttling scenario. The fallback server itself is unchanged.
- ADR-0017 (names vetted from a phone; blocked names not reused): applies to the reserve name.
- ADR-0015 (`alpn=http/1.1`, `fp=android`, no `http2` on the listener): the reserve link copies the main link's TLS settings; only the name changes.
- ADR-0021 (no ECH setting in a link, no sensitive words in a name): the reserve link carries no ECH setting; the reserve name follows the word list.
- ADR-0008, ADR-0019 (no second way out): the reserve path has no outbound of its own; it is the same server and the same WARP exit.

## Open questions

- [TODO-CLARIFY: does Gcore's free plan pass XHTTP without buffering, and does an idle XHTTP connection survive Gcore's origin read timeout (30 s between reads on standard plans)? This is what R-vpn-server-28.d tests.]
- [TODO-CLARIFY: which label carries the reserve name? It must contain no word from `docs/avoided-name-words.txt` and should present a plausible second service of the cover site.]
