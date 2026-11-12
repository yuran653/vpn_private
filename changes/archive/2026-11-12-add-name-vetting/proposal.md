# Proposal: add-name-vetting

## Why

On 2026-11-12 the cover domain `casedigestai.com` turned out to be unusable on Russian mobile networks. From a phone on Beeline (Moscow), uploads of about 2 KB or more to every name under it hang, HTTP/2 to them hangs, and the owner found the page unreachable over https; the address was ruled out (docs/censor-red-flags.md). The same domain had been linked to the VPS address earlier, and that address was blocked soon after (ADR-0012). The spec says nothing about which names the server may use, and no step catches a bad name before it carries the tunnel. The owner asked that the findings be captured so that a blocked name is not used again.

## What changes

- A list of blocked names, `docs/blocked-names.txt`, with the domain found blocked. The verify script fails while the site or the link uses a listed name or a name under a listed domain.
- A name check, `scripts/check-name.sh`, run on a phone on mobile data. It reports whether a name still answers GET over HTTP/1.1 and HTTP/2 and takes uploads of 500, 5000 and 30000 bytes, using a control name to tell a bad name from a bad network.
- A rule that a name goes into the client link only after that check passes from a mobile network in each country served.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-server | existing | `specs/vpn-server/spec.md` |

## Out of scope

- Replacing the domain. The deployed server keeps using `casedigestai.com`, so R-vpn-server-20.a is `drift` until the owner chooses a new domain.
- Finding out why the domain was blocked: the earlier direct link to the VPS address, tunnel traffic, or a rule that matches any new name is not known.
- Iran and China: no measurements.

## Decisions checked

None of the "Do not" lines applies. ADR-0012's rule that a domain is linked to the VPS only with a decision record stays in force.

## Open questions

- [TODO-CLARIFY: which new domain replaces `casedigestai.com`, and from which carriers must it pass before it is used?]
