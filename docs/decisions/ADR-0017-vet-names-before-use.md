# ADR-0017: Names are tried from a mobile network before use, and blocked names are listed

- Status: accepted
- Date: 2026-11-12
- Supersedes: none
- Change: `changes/archive/2026-11-12-add-name-vetting/`

## Context

The cover domain `casedigestai.com` is unusable on Russian mobile networks (2026-11-12). From a phone on Beeline in Moscow, a small GET to its names worked, HTTP/2 hung, and uploads of 2 KB or more hung; the same uploads to `www.cloudflare.com` passed, and sending another Cloudflare name to our address passed, so the trigger was the name and not the address. All three names under the domain failed alike, so names under one registered domain share its fate. The owner then found the landing page unreachable over https on mobile. Earlier, the VPS address was blocked right after this domain was linked to it (ADR-0012). Why the domain was flagged is not known: the direct link, tunnel traffic, or a rule that matches any new name. Datacenter probes (Globalping on MTS, Rostelecom and others) saw nothing wrong, because they ran GETs from networks the filter does not treat the same way.

## Decision

- Blocked names are listed in `docs/blocked-names.txt`. The site and the client link use no listed name and no name under a listed domain; `verify-external.sh` checks it.
- A name goes into the client link only after `scripts/check-name.sh` passes for it from a phone on mobile data in each country the owner serves. The check meets the name the way the Beeline measurements found it flagged: GET over HTTP/1.1 and HTTP/2, and uploads of 500, 5000 and 30000 bytes, with a control name to tell a bad name from a bad network.
- A tunnel name sits on a registered domain used for nothing else, so a block on it costs no other site.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Refuse to deploy with a listed name | It blocks every deploy, including the ones that fix the problem. |
| Notes only, no list | A note does not stop the next deploy using a blocked name. |
| Probe the name from cloud probe networks | They did not show the block; only a phone did. |

## Consequences

Replacing a blocked domain starts with the check on a phone, before DNS, certificate and link change. `R-vpn-server-20.a` fails until the deployed domain is replaced. A passing check does not guarantee that a name stays unflagged, and says nothing about Iran or China.

## Do not

- Do not put a name in the client link before `scripts/check-name.sh` passes for it from a mobile network in each target country, and do not reuse a name or a domain listed in `docs/blocked-names.txt`: a flagged domain made every uploaded request to its names hang on a Russian mobile network. (ADR-0017)
