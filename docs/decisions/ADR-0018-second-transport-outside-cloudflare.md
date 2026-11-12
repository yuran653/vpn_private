# ADR-0018: A second transport that does not pass through Cloudflare

- Status: proposed (drafted 2026-11-12; not binding until the owner accepts it)
- Date: 2026-11-12
- Supersedes: if accepted, ADR-0013 in part (the "CDN only" choice and its first "Do not" line) and ADR-0012 in part (its "Do not" line on a third-party Reality cover site, for the second server only)
- Change: none yet

## Context

ADR-0013 made Cloudflare the only way in. The owner chose "CDN only" on 2026-11-12 and rejected a Reality fallback, to keep the server's own address out of use (flag 2).

The same day the only way in failed. On Beeline mobile data in Moscow every upload over about 2 KB to any name under `casedigestai.com` hung, so the tunnel could not connect (`docs/censor-red-flags.md`, "Field observation"). The domain is on `docs/blocked-names.txt`. A new domain is the next try, but it is not known whether a fresh name stays unflagged once it carries tunnel traffic.

The assessment by country (`docs/censor-red-flags.md`, "Assessment by country") finds the same weak point in all three: one domain, one network in front, one transport (flag 6). A block of the name or of Cloudflare cuts every user off at once.

## Decision

Proposed, in this order:

- The Cloudflare path of ADR-0013 stays as it is and stays the first link every user gets. Its server keeps admitting only Cloudflare to 80 and 443.
- A second transport is added on a **separate VPS with its own address**: VLESS with Reality and Vision on 443/tcp, reached directly. A block of that address, or its discovery, then tells nothing about the Cloudflare origin.
- Before that server takes clients, SSH on it is closed to everyone but known addresses (flag 5), because its address is visible to every client's ISP.
- Its client traffic leaves through WARP, with the same DNS and IPv6 rules as the first server (ADR-0008, ADR-0004).
- Users get the second link only as a fallback, for networks where the first one fails.

Open, to be answered by the owner before this is accepted:

- [TODO-CLARIFY: is a second VPS acceptable, or must the second transport run on the first server with a second address?]
- [TODO-CLARIFY: where is the second VPS? A host with a good route to China and one reachable from Russian mobile networks are different hosts.]
- [TODO-CLARIFY: which site does Reality borrow its name from? ADR-0012 rejected a third-party site because the name did not match the address and the relay added a round trip. A site hosted in the same provider network as the VPS answers the first reason; the round trip stays. The owner's own domain on that address repeats the 2026-11-12 incident.]
- [TODO-CLARIFY: which country comes first? Russia needs this most today; an entry relay inside Russia and a host with a premium route to China are later steps, each with its own decision.]

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Stay CDN only and replace the domain each time it is flagged | It is the current plan and stays the first step. Alone it leaves every user cut off between a block and the next redeploy, and Cloudflare itself is throttled in Russia and has no nodes in China on the free plan. |
| Reality on the first server's address | Opens 443 to everyone on the Cloudflare origin, against ADR-0013's second "Do not" line, and one block then takes both transports. |
| A second CDN (Gcore, Fastly, CloudFront) in front of the same server | Still a name the censor can cut, as Beeline did. It answers a Cloudflare block but not a name block. |
| Domain fronting on Cloudflare | Cloudflare refuses a request whose TLS name and Host header belong to different zones. Its encrypted hello (ECH) is blocked in Russia and China. |
| A QUIC transport (Hysteria2, TUIC) as the second one | UDP is rate-limited or blocked on many networks in all three countries. A candidate for a third transport, not the second. |
| WireGuard or OpenVPN | Both have signatures that all three censors match. |

## Consequences

If accepted:

- A block of one name or of Cloudflare no longer cuts every user off (flag 6).
- Flag 2 returns for users on the second link: their ISP sees a hosting provider's address. That is why it is the fallback and not the default.
- Two servers to deploy, verify and pay for. `scripts/deploy-vpn.sh` needs a second mode or a second script, and the spec needs requirements for the second transport, through the change cycle.
- The "Do not" lines of ADR-0013 and ADR-0012 must be reworded when this is accepted, not before.

## Do not

None until accepted. The lines of ADR-0012 and ADR-0013 stay binding.
