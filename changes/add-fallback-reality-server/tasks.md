# Tasks: add-fallback-reality-server

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

Tasks 1 and 3 to 8 need a VPS to pass their checks; neither server exists on 2026-11-12. Their scripts are written and marked "not yet run on a server". What was checked off a server is noted under each task. The jq filters in the new code could not be run: the workstation has no jq.

- [ ] 1. Add the SSH address list to the baseline (files: `scripts/harden-vps.sh`, `scripts/verify-baseline.sh`; criteria: R-vps-baseline-08.a to 08.d)
  Check: `bash -n` on both; on a VPS, `verify-baseline.sh` passes with and without the list, and a list without the session's address is refused.
  Written 2026-11-12: `bash -n` passes, and the list parsing and the lockout guard were run by hand off a server. Not run on a VPS yet, so not ticked.
- [x] 2. Write the phone check for an address (files: `scripts/check-host.sh`; criteria: R-vpn-fallback-06.a to 06.c)
  Check: exit 0 against a large public site's address and name, exit 1 against `192.0.2.1`. Done 2026-11-12 from the workstation.
- [ ] 3. Move the shared host steps into one file and add the `relay` client (files: `scripts/lib/host-common.sh`, `scripts/deploy-vpn.sh`, `scripts/verify-vpn.sh`; criteria: R-vpn-fallback-05.b, R-vpn-server-22)
  Check: the redeploy of the first server (`docs/redeploy.md`) ends with both verify scripts passing, including the R-vpn-server-22 checks.
  Written 2026-11-12: the moved lines were copied by line range and the old script compared with the two new files line by line; `bash -n` passes. The `relay` client uses `POST panel/api/clients/add` with `{client, inboundIds}`, read from the source of the pinned 3x-ui v3.11.0, not tried against a panel. To confirm on the first run: the new client shows up in the inbound's `settings.clients`, which the link is built from.
- [ ] 4. Write the fallback deploy (files: `scripts/deploy-fallback.sh`; criteria: R-vpn-fallback-01, 02.a, 02.c, 03.a to 03.c, 04, 07)
  Check: on the second VPS the script ends with `[fallback] done`; a second run leaves the link's checksum unchanged.
  Written 2026-11-12: `bash -n` passes; the relay-link parser was run against invented links (a good one accepted; an address instead of a name, a non-XHTTP link and a non-link refused). The Reality inbound has the shape that worked on the first deployment (2026-11-10). To confirm on the first run: the panel keeps the client's `flow`, and the generated Xray config has no `dns` block.
- [ ] 5. Write the inside checks (files: `scripts/verify-fallback.sh`; criteria: R-vpn-fallback-01, 02.a, 02.c, 03.a, 03.b, 04, 05.a, 05.c, 07.a, 07.c, 07.d)
  Check: every check passes on the second VPS, and one fails when its criterion is broken by hand.
  Written 2026-11-12: `bash -n` passes. Nothing else could be run off a server.
- [ ] 6. Add the outside checks (files: `scripts/verify-external.sh`; criteria: R-vpn-fallback-02, 03.c, 05.a, 05.c, 06.a, 06.b)
  Check: passes from the workstation for both servers.
  Written 2026-11-12: `bash -n` passes; the link comparison was run against invented links (no overlap and a shared ID both reported correctly) and the network lookup against two public addresses.
- [ ] 7. Try the candidate hosts from a phone in Russia and keep one (files: `docs/vps-access.md`; criteria: R-vpn-fallback-06.d)
  Check: `check-host.sh` exits 0 for the kept address on mobile data.
- [ ] 8. Describe the second server (files: `docs/vps-access.md`, `docs/redeploy.md`, `docs/censor-red-flags.md`)
  Check: the order for the second server can be followed from the docs alone.
  Written 2026-11-12 in `docs/vps-access.md` ("Fallback server") and `docs/redeploy.md`. Not ticked: nobody has followed it yet, and `docs/censor-red-flags.md` changes only once the server exists.
- [ ] Final: run every command in `AGENTS.md`; archive the change.
