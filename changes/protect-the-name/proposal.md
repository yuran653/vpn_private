# Proposal: protect-the-name

## Why

The name is what a censor cuts, and a cut costs a new domain and a new link on every device (`docs/censor-red-flags.md`). The owner chose five measures on 2026-11-12 to make a name last longer and to give a user more ways in: split tunneling, ECH off, hello fragmentation, Cloudflare's other HTTPS ports, and no sensitive words in the name.

## What changes

- The site and the tunnel answer on 2053, 2083, 2087, 2096 and 8443 as on 443, through Cloudflare only. The server keeps one link per port for users whose network cuts 443.
- No link carries an ECH setting, and the names' DNS records offer no ECH configuration.
- The owner's links ask the client app to fragment the TLS hello.
- A site name that contains a word from `docs/avoided-name-words.txt` fails the outside check.
- A setup guide, `docs/client-setup.md`, tells each user to turn on split tunneling and how to use the other ports.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-server | existing | `specs/vpn-server/spec.md` |

## Out of scope

- Per-user names and spare domains (flags 3 and 4): separate steps.
- A routing profile delivered to the app automatically: a plain link carries none, and a subscription is ruled out by ADR-0011.
- The fallback server (`changes/add-fallback-reality-server/`). Its link gets no fragmentation setting in this change.
- Putting a working Cloudflare address into the link for Iran: described in the guide, not automated.

## Decisions checked

- ADR-0013 (80 and 443 from Cloudflare's ranges only; no way in outside Cloudflare): the new ports are admitted from the same ranges only. ADR-0020 adds the matching line.
- ADR-0002 (no port for the panel): the panel stays on loopback; the deploy stops if its port is one of the five.
- ADR-0012 (no container port on a public address): unchanged.
- ADR-0014 (the server's padding range equals the link's): unchanged; the new links copy the main one.
- ADR-0015 (no `http2` on the listener, `alpn=http/1.1`, `fp=android`): the new listeners have no `http2`, and the new links copy the main one.
- ADR-0011 (no subscription): the client settings are a written guide, not a profile served by the server.
- ADR-0017 (names vetted from a phone; blocked names not reused): unchanged; the word rule is added next to it by ADR-0021.

## Open questions

- [TODO-CLARIFY: confirm that Cloudflare's API turns ECH off for a free zone. If it does not, R-vpn-server-24.b cannot pass on the free plan.]
- [TODO-CLARIFY: try the link with and without `fragment` from a phone in each country; the values are Happ's documented example, not tuned.]
- [TODO-CLARIFY: is a ready-made routing profile per country to be handed out, and in which form does Happ import it?]
