# ADR-0021: Measures that keep the name from being flagged

- Status: accepted
- Date: 2026-11-12
- Supersedes: none
- Change: `changes/protect-the-name/` (open)

## Context

The name is what the censor sees and cuts (`docs/censor-red-flags.md`, field observation of 2026-11-12). A cut costs a new domain and a new link on every device, so the name has to last. The owner chose four measures on 2026-11-12:

- split tunneling in the client;
- the encrypted hello (ECH) left off;
- TLS hello fragmentation in the client;
- no politically sensitive words in the name.

Two of them are settings of the client app, which the server cannot enforce.

## Decision

**ECH off.** Cloudflare's ECH is blocked in Russia, and China blocks encrypted server names, so a hello that uses ECH is cut where a plain one passes. No link carries an ECH setting, and ECH is turned off for the Cloudflare zone, so the names' DNS records do not offer it to browsers either. Free zones have it on by default and no switch in the dashboard; it is turned off through Cloudflare's API. `scripts/verify-external.sh` reads the DNS records to check it.

**Fragmentation in the link.** The owner's links carry `fragment=1-10,5-20,tlshello`, a parameter the Happ app reads: the TLS hello is sent in pieces, so a filter that matches the name in one packet does not see it. The relay link carries none: it is used by a server, outside the censor's network.

**Split tunneling is recommended to every user, not enforced.** `docs/client-setup.md` tells users to send only foreign or blocked sites through the tunnel. Less traffic on the name makes it stand out less (flag 3).

**Words.** A site name contains no word from `docs/avoided-name-words.txt`: words that say what the service is, and politically sensitive ones. `scripts/verify-external.sh` checks it.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| ECH on, to hide the name | It is the hello that is blocked in Russia and China, not the name inside it. |
| Fragmentation only for users in Iran, where it is known to help | The owner asked for it in the client. One link for everyone is simpler to hand out; a user for whom it breaks the connection turns it off in the app. |
| Enforce split tunneling on the server | The server cannot tell which sites a user could have reached directly. |
| A routing profile delivered with the link | A plain `vless://` link carries no routing rules, and a subscription needs a public address (ADR-0011). |

## Consequences

- With split tunneling, sites reached directly see the user's real address and the user's ISP sees them, as without a VPN. That is the point of it, and a user who wants everything hidden leaves it off.
- Fragmentation applies only while Happ's own global fragmentation setting is off; the app's setting wins otherwise. Whether it helps or hurts on a given network is not known until tried there. [TODO-CLARIFY: try the link with and without `fragment` from a phone in each country.]
- Turning ECH off on a free zone depends on an API call that Cloudflare's documentation does not describe. [TODO-CLARIFY: confirm that `PATCH /zones/<id>/settings/ech` with the value `off` is accepted for a free zone.] If it is not, R-vpn-server-24.b cannot pass on the free plan.
- The word list is a guess at what filters match; it grows as names are lost.
- Not yet run on a server (2026-11-12).

## Do not

- Do not turn ECH on for the zone or put an ECH setting in a client link: Cloudflare's ECH is blocked in Russia, and encrypted server names are blocked in China. (ADR-0021)
- Do not use a site name that contains a word from `docs/avoided-name-words.txt`: censors match names by keyword. (ADR-0021)
