# ADR-0018: A second transport that does not pass through Cloudflare

- Status: accepted
- Date: 2026-11-12
- Supersedes: ADR-0013 in part (the "CDN only" choice and its first "Do not" line) and ADR-0012 in part (its "Do not" line on a third-party Reality cover site, for the second server only)
- Change: none yet

## Context

ADR-0013 made Cloudflare the only way in. The owner chose "CDN only" on 2026-11-12 and rejected a Reality fallback, to keep the server's own address out of use (flag 2).

The same day the only way in failed. On Beeline mobile data in Moscow every upload over about 2 KB to any name under `casedigestai.com` hung, so the tunnel could not connect (`docs/censor-red-flags.md`, "Field observation"). The domain is on `docs/blocked-names.txt`. A new domain is the next try, but it is not known whether a fresh name stays unflagged once it carries tunnel traffic.

The assessment by country (`docs/censor-red-flags.md`, "Assessment by country") finds the same weak point in all three: one domain, one network in front, one transport (flag 6). A block of the name or of Cloudflare cuts every user off at once.

## Decision

The owner chose on 2026-11-12:

- The Cloudflare path of ADR-0013 stays as it is and stays the first link every user gets. Its server keeps admitting only Cloudflare to 80 and 443.
- A second transport is added on a **separate VPS with its own address**: VLESS with Reality and Vision on 443/tcp, reached directly. A block of that address, or its discovery, then tells nothing about the Cloudflare origin.
- **Russia comes first.** It is the only country where the current setup is measured to fail. An entry relay inside Russia and a host with a premium route to China are later steps, each with its own decision.
- **The host is decided by test.** Two or three candidate providers are tried from a phone on mobile data in Russia before one is kept. [TODO-CLARIFY: which candidate providers and locations?]
- **Reality borrows the name of a third-party site hosted in the same provider network as the VPS**, so the name and the address match. This answers the first reason ADR-0012 gave against a third-party site; the relay's extra round trip stays and is accepted for a fallback. The owner's own domain is not pointed at that address: that would repeat the 2026-11-12 incident.
- Before that server takes clients, SSH on it is closed to everyone but known addresses (flag 5), because its address is visible to every client's ISP.
- Its client traffic leaves through WARP, with the same DNS and IPv6 rules as the first server (ADR-0008, ADR-0004).
- Users get the second link only as a fallback, for networks where the first one fails.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Stay CDN only and replace the domain each time it is flagged | It is the current plan and stays the first step. Alone it leaves every user cut off between a block and the next redeploy, and Cloudflare itself is throttled in Russia and has no nodes in China on the free plan. |
| Reality on the first server, or on a second address of it | Opens 443 to everyone on the Cloudflare origin, against ADR-0013's second "Do not" line, and a fault or a block at the provider takes both transports. |
| A second CDN (Gcore, Fastly, CloudFront) in front of the same server | Still a name the censor can cut, as Beeline did. It answers a Cloudflare block but not a name block. |
| Domain fronting on Cloudflare | Cloudflare refuses a request whose TLS name and Host header belong to different zones. Its encrypted hello (ECH) is blocked in Russia and China. |
| A QUIC transport (Hysteria2, TUIC) as the second one | UDP is rate-limited or blocked on many networks in all three countries. A candidate for a third transport, not the second. |
| WireGuard or OpenVPN | Both have signatures that all three censors match. |

## Consequences

- A block of one name or of Cloudflare no longer cuts every user off (flag 6).
- Flag 2 returns for users on the second link: their ISP sees a hosting provider's address. That is why it is the fallback and not the default.
- Two servers to deploy, verify and pay for. `scripts/deploy-vpn.sh` needs a second mode or a second script, and the spec needs requirements for the second transport, through the change cycle.
- The first "Do not" line of ADR-0013 and the Reality line of ADR-0012 are reworded in `docs/decisions/INDEX.md`.
- Nothing is built yet. The second server is a behavior change of its own.

## Do not

- Do not give clients a link to the address of the server behind Cloudflare, or open a second way in on that server: its address must stay unused and unanswering. A way in outside Cloudflare runs on a separate server and is handed out only as a fallback. (ADR-0013, reworded by ADR-0018)
- Do not use as the Reality cover site a third-party site hosted outside the provider network of the VPS, or point the owner's own domain straight at a VPS address: the first does not match the address, the second ties a name to a hosting address. (ADR-0012, reworded by ADR-0018)
- Do not hand out the direct Reality link as the default link: the user's ISP then sees a hosting provider's address (flag 2). It is the fallback for networks where the Cloudflare link fails. (ADR-0018)
- Do not let the second server take clients while its SSH port is open to everyone: its address is visible to every client's ISP and to probes. (ADR-0018)
