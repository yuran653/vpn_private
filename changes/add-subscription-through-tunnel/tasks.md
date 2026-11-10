# Tasks: add-subscription-through-tunnel

- [ ] 1. Deploy script: subscription settings, `sub` outbound and rule, inbound name, link name, address file (files: `scripts/deploy-vpn.sh`; criteria: R-vpn-server-13, R-vpn-server-12.c)
  Check: `bash -n scripts/deploy-vpn.sh`.
- [ ] 2. Verify scripts: R-vpn-server-13 checks, relaxed R-vpn-server-12.c (files: `scripts/verify-vpn.sh`; criteria: R-vpn-server-13.a to .f, R-vpn-server-12.c)
  Check: `bash -n scripts/verify-vpn.sh`; on the VPS before the deploy the new checks fail.
- [ ] 3. Run the deploy script on the VPS, detached, then both verify scripts (files: none)
  Check: every line of `verify-vpn.sh` and `verify-external.sh` is PASS.
- [ ] 4. Decision record, index, ADR-0002 note, operator note (files: `docs/decisions/ADR-0010-subscription-through-tunnel.md`, `docs/decisions/INDEX.md`, `docs/vps-access.md`)
  Check: the "Do not" line is the same text in the ADR and in the index.
- [ ] Final: run every command in `AGENTS.md` (still `[TODO-CLARIFY]`; run `bash -n` on the scripts, both verify scripts instead); archive the change.
