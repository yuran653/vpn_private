# Design: protect-the-name

## Approach

The extra ports are more `listen` lines on the one TLS server block nginx already has, more firewall rules in the loop that already admits Cloudflare's ranges, and more links from the function that already writes the main one. Nothing new runs on the server.

ECH is a setting of the Cloudflare zone, turned off by the operator when the zone is set up; the project checks the result in DNS. Fragmentation is one more parameter in the owner's links. Split tunneling is a written guide. The word rule is a list and a check.

Amended 2026-11-15: the routing rules are no longer only a written guide. The client guide hands them out as a ready-made Happ routing profile — a `happ://routing/onadd/{base64}` deeplink or a `.json`/`.happ` file — so the user imports rules instead of typing them. The profile also carries the DNS split: Russian names resolve locally, the rest through the server's resolver, so Russian destinations are not leaked to the foreign exit through DNS. This needs no subscription and no public address; ADR-0011 is unaffected, and ADR-0021's rejected alternative is amended accordingly.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| scripts | `scripts/deploy-vpn.sh` | `ALT_PORTS`; nginx listens on them once it holds 443; firewall rules for them and removal of rules for ports no longer wanted; staging port 8443 to 18443; stop if the panel port is one of them; `fragment` in the owner's links; `/root/vpn/vless-links-alt.txt`. |
| scripts | `scripts/verify-vpn.sh` | R-vpn-server-05.a and 05.c with the new ports; checks for 23.a, 23.b, 23.d, 24.a, 26.a. |
| scripts | `scripts/verify-external.sh` | Checks for 23.a, 23.c, 24.b, 25.a; 18443 in the closed-ports list. |
| docs | `docs/avoided-name-words.txt` (new), `docs/client-setup.md` (new) | The word list; the user's guide, including the ordered routing rules, the DNS split and the routing-profile delivery (amended 2026-11-15). |
| docs | `docs/redeploy.md`, `docs/vps-access.md`, `docs/censor-red-flags.md` | The word rule and ECH in the order of steps; the new files and ports. |

New modules or dependencies between modules: none. `docs/architecture.md` lists no modules yet.

## Contracts and data

- New root-only state on the server: `/root/vpn/vless-links-alt.txt`, one link per line.
- The main link gains `&fragment=1-10,5-20,tlshello`. Every device imports the new link; none is deployed today.
- The relay link is unchanged, so the fallback server's parser is not affected.
- Firewall: five more rules per Cloudflare range.
- The routing profile is handed out with the link as a deeplink or a file; it is not a secret (it contains no keys), but it is not published either: it names the tunnel names indirectly through the rules it ships with.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| A Cloudflare API token on the server to turn ECH off from the deploy script | A token that can change the zone would sit on the VPS; the operator does it once per zone instead. |
| Reading the ECH state from Cloudflare's API in the verify script | Needs the same token on the workstation; the DNS record is what a browser acts on, and anyone can read it. |
| One link file with all six links | The main link's file is read by both verify scripts and the runbook; it stays one link. |
| Words matched as whole labels only | Filters match substrings; `my-vpn` must fail. Short words that occur inside ordinary ones are kept off the list instead. |
| A full Xray JSON config as the carrier of the routing rules | Happ passes such a config to the core as-is, and its routing profiles and interface settings do not apply. The carrier is the link plus a Happ routing profile. |
| Routing through a subscription that serves the profile | Needs a public address, which ADR-0011 forbids. Deeplinks and files need neither. |

Decision record needed: ADR-0020 (alternative ports), ADR-0021 (ECH off, fragmentation, split tunneling, words; routing-profile delivery note added 2026-11-15). Both written.

## Verification

| Criterion | Test |
|---|---|
| R-vpn-server-05.a, 05.c | `scripts/verify-vpn.sh` (on loopback), `scripts/verify-external.sh` (through Cloudflare) |
| R-vpn-server-05.b | `scripts/verify-external.sh` |
| R-vpn-server-23.a | `scripts/verify-vpn.sh` (on loopback), `scripts/verify-external.sh` (through Cloudflare) |
| R-vpn-server-23.b, 23.d | `scripts/verify-vpn.sh` |
| R-vpn-server-23.c | `scripts/verify-external.sh` |
| R-vpn-server-24.a | `scripts/verify-vpn.sh` |
| R-vpn-server-24.b | `scripts/verify-external.sh` |
| R-vpn-server-25.a | `scripts/verify-external.sh` |
| R-vpn-server-26.a | `scripts/verify-vpn.sh` |
| R-vpn-server-26.b | untested: it needs a packet capture on a phone running Happ |
| R-vpn-server-27.a | untested: a process the owner follows; amended 2026-11-15 to include verifying the routing deeplink/file and the DNS fields on an iPhone and an Android phone |

## Risks

- **The panel's random port is one of the five.** The deploy stops with a message; the operator moves the panel.
- **Fragmentation breaks the connection on some network.** The user turns it off in the app (`docs/client-setup.md`); the values are untuned.
- **ECH cannot be turned off on the free plan.** Then R-vpn-server-24.b stays failing and the choice is a paid plan or accepting it.
- **Six open ports mark the name as unusual** to anyone who scans it through Cloudflare. Accepted in ADR-0020.
- **The routing profile behaves differently on a device than its documentation says.** Contained by the on-device verification in R-vpn-server-27.a before the profile is handed out.
- **No server to test on.** Nothing here has run on a VPS.
