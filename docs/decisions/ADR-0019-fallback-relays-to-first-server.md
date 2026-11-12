# ADR-0019: The fallback server is an entry only and relays to the first server

- Status: accepted
- Date: 2026-11-12
- Supersedes: ADR-0018 in part (the line that the second server's client traffic leaves through its own WARP tunnel)
- Change: `changes/add-fallback-reality-server/` (open)

## Context

ADR-0018 adds a second server on its own VPS, reached directly with Reality. It said that server's client traffic leaves through WARP. WARP exits in the country of the server it runs on. The second server is chosen for being reachable from Russian mobile networks, which may put it outside Thailand, and then users on the fallback would exit in another country. The project is a Thai exit.

## Decision

The owner chose on 2026-11-12:

- The second server is an entry only. Everything a client sends through it is forwarded to the first server and leaves from there, through the first server's WARP tunnel, in Thailand.
- The second server reaches the first one the way a client does: through Cloudflare, with a link of its own. The first server issues a second client ID for it, named `relay`. No port is opened on the first server and its address stays unused (ADR-0013).
- The second server has no WARP registration and no outbound of its own to the internet. When the first server cannot be reached, a request through the fallback fails; it never leaves from the second server's own address.
- The relay link is a secret like the client link: root-only on both servers, moved from one to the other without being printed, never in the repo.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Exit where the second server stands, through its own WARP | Simpler and independent of the first server, but users on the fallback appear in another country. |
| Host the second server in Thailand at another provider | Keeps the Thai exit without a relay, but narrows the choice of hosts that Russian mobile networks can reach; the first Thai address was blocked on 2026-11-12. |
| Relay straight to the first server's address on a port opened for the second server | A second way in on the server behind Cloudflare, against ADR-0013. |
| Reuse the owner's client ID for the relay | Removing the relay would then mean a new link for every device. |

## Consequences

- The exit is the same on both links: Thailand, through WARP.
- One more hop: client, second server, Cloudflare, first server, WARP. Slower than either server alone.
- The fallback answers a censor that blocks the way in. It does not answer a failure of the first server: when the first server is down, both links are down.
- The second server holds the first server's name and a client ID. Whoever takes over the second server learns that name; its provider sees TLS to Cloudflare with that name. The first server's own address is not revealed.
- When the first server's domain is replaced, the relay link changes and the second server needs it again. The users' fallback link does not change.
- The first server gets a second client. Its traffic counter in the panel separates relay traffic from the owner's.

## Do not

- Do not give the fallback server a way out of its own (a `freedom` outbound, or its own WARP tunnel): its users would exit outside Thailand, and a second way out leaks when the first server is unreachable. It forwards to the first server only. (ADR-0019)
