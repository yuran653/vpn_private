# Tasks: add-fallback-reality-server

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

Blocked until the proposal's first open question is answered: tasks 4 to 6 (the exit).

- [ ] 1. Add the SSH address list to the baseline (files: `scripts/harden-vps.sh`, `scripts/verify-baseline.sh`; criteria: R-vps-baseline-08.a to 08.d)
  Check: `bash -n` on both; on a VPS, `verify-baseline.sh` passes with and without the list, and a list without the session's address is refused.
- [ ] 2. Write the phone check for an address (files: `scripts/check-host.sh`; criteria: R-vpn-fallback-06.a to 06.c)
  Check: exit 0 against a large public site's address and name, exit 1 against `192.0.2.1`.
- [ ] 3. Move the shared host steps into one file (files: `scripts/lib/host-common.sh`, `scripts/deploy-vpn.sh`; criteria: R-vpn-fallback-05.b)
  Check: the redeploy of the first server (`docs/redeploy.md`) ends with both verify scripts passing.
- [ ] 4. Write the fallback deploy (files: `scripts/deploy-fallback.sh`; criteria: R-vpn-fallback-01, 02.a, 02.c, 03.a to 03.c, 04, 07)
  Check: on the second VPS the script ends with `[deploy] done`; a second run leaves the link's checksum unchanged.
- [ ] 5. Write the inside checks (files: `scripts/verify-fallback.sh`; criteria: R-vpn-fallback-01, 03.a, 03.b, 04, 07.a)
  Check: every check passes on the second VPS, and one fails when its criterion is broken by hand.
- [ ] 6. Add the outside checks (files: `scripts/verify-external.sh`; criteria: R-vpn-fallback-02, 03.c, 05.a, 05.c, 06.a, 06.b)
  Check: passes from the workstation for both servers.
- [ ] 7. Try the candidate hosts from a phone in Russia and keep one (files: `docs/vps-access.md`; criteria: R-vpn-fallback-06.d)
  Check: `check-host.sh` exits 0 for the kept address on mobile data.
- [ ] 8. Describe the second server (files: `docs/vps-access.md`, `docs/redeploy.md`, `docs/censor-red-flags.md`)
  Check: the order for the second server can be followed from the docs alone.
- [ ] Final: run every command in `AGENTS.md`; archive the change.
