# Tasks: route-egress-through-warp

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

- [ ] 1. Add the WARP registration step and the `warp` outbound to the deploy script; remove `direct`; DNS through routing (files: `scripts/deploy-vpn.sh`; criteria: R-vpn-server-12.a, 12.c, 12.e, 09.a)
  Check: `bash -n scripts/deploy-vpn.sh`; `shellcheck` if installed
- [ ] 2. Add the R-vpn-server-12 checks and change the 01.a and 02.c checks (files: `scripts/verify-vpn.sh`; criteria: R-vpn-server-01.a, 02.c, 12.a to 12.d)
  Check: `bash -n scripts/verify-vpn.sh`; run before the deploy and see 12.a fail
- [ ] 3. Run the deploy script on the VPS, then both verify scripts
  Check: every line `PASS`; second deploy run leaves the `warp.json` checksum unchanged; output holds no key or token
- [ ] 4. Measure throughput through the tunnel and confirm Google places the exit in Thailand
  Check: numbers recorded in ADR-0008
- [ ] 5. Write ADR-0008, the "Do not" line, the WARP section in `docs/vps-access.md`, and the goal line in `AGENTS.md`
  Check: files read back
- [ ] Final: run every command in `AGENTS.md`; archive the change.
