# Design: add-fallback-reality-server

## Approach

The second server gets its own deploy and verify scripts. The host steps both servers share (updates, IPv6 off, TCP tuning, the pinned 3x-ui install on loopback) move out of `deploy-vpn.sh` into one sourced file, so the two servers cannot drift apart. The first server has to be redeployed on a fresh VPS anyway (`docs/redeploy.md`), and that run is what verifies the move.

On the second server Xray itself holds 443/tcp with a VLESS inbound using Reality and the Vision flow. Reality hands every connection that lacks the key to the cover site, a third-party site in the same provider network, chosen after the provider is known and kept in the panel's inbound on the server, not in the repo. No nginx, no certificate, no Docker and no WARP on this host.

The second server's only outbound is the relay (ADR-0019): VLESS over XHTTP to the first server's name through Cloudflare, built from a relay link that the first server issues for a second client, `relay`. Port 53 from clients goes into the relay too, so the first server answers it. The operator moves the relay link from one server to the other through a pipe between two SSH sessions, so it is never printed or stored on the workstation.

The baseline script takes an optional list of addresses for SSH. The second server is always hardened with it.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| scripts | `scripts/lib/host-common.sh` (new) | Steps 1 to 4 of today's `deploy-vpn.sh` as functions. |
| scripts | `scripts/deploy-vpn.sh`, `scripts/verify-vpn.sh` | Sources the shared file; adds the `relay` client and its link file (R-vpn-server-22). |
| scripts | `scripts/deploy-fallback.sh` (new) | Shared steps, Reality inbound, relay outbound, firewall, link file. Takes the cover name as an argument on the first run and expects the relay link in `/root/vpn/relay-link.txt`. |
| scripts | `scripts/verify-fallback.sh` (new) | Inside checks, with a temporary client built from the link. |
| scripts | `scripts/verify-external.sh` | Optional second alias: outside checks of the fallback server. |
| scripts | `scripts/check-host.sh` (new) | The phone check of R-vpn-fallback-06. Needs only curl. |
| scripts | `scripts/harden-vps.sh`, `scripts/verify-baseline.sh` | The SSH address list (R-vps-baseline-08). |
| docs | `docs/vps-access.md`, `docs/redeploy.md`, `docs/censor-red-flags.md` | Second alias, the order for the second server, flag status. |

New modules or dependencies between modules: none. `docs/architecture.md` lists no modules yet.

## Contracts and data

- `harden-vps.sh <ADMIN_IP> [--ssh-from <addr>[,<addr>...]]`. Without the option nothing changes for existing use.
- State on the second server, root-only, in `/root/vpn/`: `vless-link.txt` and `relay-link.txt`. The Reality key pair, the short ID and the cover name live in the panel's inbound, as on the first deployment; there is no separate file for them.
- State added on the first server, root-only: `/root/vpn/relay-link.txt`.
- The second server's address and cover name are not written into the repo: the address identifies the server to anyone who reads the repo's history. The scripts read them from the SSH alias and from the server.
- The fallback link: `vless://<id>@<address>:443?security=reality&sni=<cover>&pbk=<key>&sid=<short id>&flow=xtls-rprx-vision&type=tcp&fp=<fp>#<profile>`.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| A `--transport` mode inside `deploy-vpn.sh` | Steps 6 to 9 of that script (site, certificate, nginx, Cloudflare firewall) do not apply; a mode switch would run through most of 400 lines. |
| A separate script with its own copy of the host steps | Two copies of the IPv6 and panel rules, the ones that protect identity, would drift. |
| Cover name as a constant in the repo | It names the provider network and so narrows down the server. |
| `ufw limit` or fail2ban alone instead of an address list for SSH | The port still answers probes (flag 5), and ADR-0005 forbids `ufw limit`. |
| Moving SSH to another port | A probe still finds the banner. |

Decision record needed: ADR-0019 (written: the fallback relays to the first server); and a reworded ADR-0015 line if the owner confirms it.

## Verification

| Criterion | Test |
|---|---|
| R-vpn-fallback-01.a, 01.b | `scripts/verify-fallback.sh` |
| R-vpn-fallback-02.a, 02.c | `scripts/verify-external.sh` |
| R-vpn-fallback-02.b | `scripts/verify-external.sh`, comparing the network (AS number) of the cover name's address and the server's |
| R-vpn-fallback-03.a, 03.b | `scripts/verify-fallback.sh` |
| R-vpn-fallback-03.c | `scripts/verify-external.sh` |
| R-vpn-fallback-03.d | untested from the workstation, which is on the list; checked once by hand from another network |
| R-vpn-fallback-04.a to 04.d | `scripts/verify-fallback.sh` |
| R-vpn-fallback-04.e | untested: it needs the first server stopped; checked once by hand |
| R-vpn-server-22.a, 22.b, 22.d | `scripts/verify-vpn.sh` |
| R-vpn-server-22.c | untested: by hand, comparing checksums, as R-vpn-server-14.b |
| R-vpn-fallback-05.a, 05.c | `scripts/verify-external.sh`, reading both links over SSH and comparing without printing them |
| R-vpn-fallback-05.b | `scripts/verify-vpn.sh` and `scripts/verify-external.sh` on the first server |
| R-vpn-fallback-06.a, 06.b | `scripts/verify-external.sh`, as for R-vpn-server-21.a and 21.b |
| R-vpn-fallback-06.c, 06.d | untested: a network that fails the control, and a process on a phone |
| R-vpn-fallback-07.a | `scripts/verify-fallback.sh` |
| R-vpn-fallback-07.b, 07.c, 07.d | untested: by hand, as R-vpn-server-08.a, 08.c and 09.a |
| R-vps-baseline-08.a, 08.c, 08.d | `scripts/verify-baseline.sh` |
| R-vps-baseline-08.b | untested: by hand, with a list that leaves out the session's address |

## Risks

- **Lockout.** An SSH list without the operator's current address closes the server. Contained by R-vps-baseline-08.b and the provider's console.
- **The move of shared steps breaks the first server.** Contained by doing it before the first server's redeploy and running both verify scripts there.
- **No server to test on.** Neither VPS exists today. Scripts are written first and marked not deployed; no criterion is called verified before a run on a real host.
- **The cover site changes or leaves the network.** R-vpn-fallback-02.b then fails and names it; a new cover name needs a re-run and a new link.
- **Both links depend on the first server.** Accepted by ADR-0019: the fallback answers a block, not an outage.
- **The second server knows the first server's name.** Accepted by ADR-0019; the first server's address is not on it.
- **Foreign hosting ranges are throttled in Russia.** That is what R-vpn-fallback-06 measures before a server is kept; it can fail for every candidate.
- **The user's ISP sees a hosting address** (flag 2). Accepted by ADR-0018 for a fallback.
