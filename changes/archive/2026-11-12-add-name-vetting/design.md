# Design: add-name-vetting

## Approach

`docs/blocked-names.txt` holds one name per line with date and evidence. `scripts/verify-external.sh` reads it and compares every name in `SITE_NAMES` (the names the site and the link use) with the entries, exactly and by suffix. `scripts/check-name.sh <name> [address]` runs curl against the name: a control upload first, then GET over HTTP/1.1 and HTTP/2, then POSTs of 500, 5000 and 30000 bytes. The sizes and the HTTP/2 check come from the Beeline measurements of 2026-11-12: the flagged name answered a small GET, hung HTTP/2, and cut uploads from about 2 KB. The optional address pins the name to one address, so the script's failing path can be tested.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| tooling | `scripts/check-name.sh` (new), `docs/blocked-names.txt` (new) | the name check and the list |
| verify | `scripts/verify-external.sh` | checks for R-vpn-server-20.a, 21.a, 21.b |
| docs | `docs/decisions/`, `docs/vps-access.md`, `docs/censor-red-flags.md` | ADR-0017, runbook for replacing the domain, pointer to the check |

New modules or dependencies between modules: none.

## Contracts and data

No server change, no deploy. The name check needs only curl and head, so it runs in Termux.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| `deploy-vpn.sh` refuses to run with a listed name | It would block every deploy, including the ones that fix the problem, until the domain is replaced. |
| Keep the findings only in `docs/censor-red-flags.md` | A note does not stop the next deploy from using a blocked name; the list is checked by a script. |
| Check the name from Globalping probes | Its probes are mostly datacenters; the block was seen only from a phone on a mobile network, and the probes ran GETs only. |

Decision record needed: ADR-0017

## Verification

| Criterion | Test |
|---|---|
| R-vpn-server-20.a | `scripts/verify-external.sh` (R-vpn-server-20.a) |
| R-vpn-server-21.a | `scripts/verify-external.sh` (R-vpn-server-21.a) |
| R-vpn-server-21.b | `scripts/verify-external.sh` (R-vpn-server-21.b) |
| R-vpn-server-21.c | none: needs a network that cuts the control name |
| R-vpn-server-21.d | none: a process the owner follows |

## Risks

- R-vpn-server-20.a fails until the domain is replaced. This is the state of the world; the status is `drift` in the spec.
- A name that passes the check on one carrier can still be flagged later or elsewhere; the check says nothing about Iran or China.
