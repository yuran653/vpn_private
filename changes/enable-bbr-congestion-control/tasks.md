# Tasks: enable-bbr-congestion-control

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

- [x] 1. Add the TCP step to the deploy script and the checks to the verify script (files: `scripts/deploy-vpn.sh`, `scripts/verify-vpn.sh`; criteria: R-vpn-server-11.a to 11.f)
  Check: `bash -n` passes on both.
- [ ] 2. Run the deploy script and the verify scripts on the VPS (criteria: R-vpn-server-11.a to 11.f)
  Check: the deploy script exits 0; `verify-vpn.sh` and `verify-external.sh` print "all checks passed"; the client link checksum is unchanged.
- [ ] 3. Record the decision and update the access guide (files: `docs/decisions/ADR-0007-bbr-congestion-control.md`, `docs/decisions/INDEX.md`, `docs/vps-access.md`)
  Check: the index lists ADR-0007.
- [ ] Final: run every command in `AGENTS.md`; archive the change. The commands are still `[TODO-CLARIFY]`.
