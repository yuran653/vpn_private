# Tasks: deploy-vless-reality

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

- [x] 1. Dry-run the panel API, the Xray template and a loopback client on a throwaway panel instance in `/tmp` on the VPS, then remove it. (files: none)
  Check: tunnel exit address is the server's IPv4; the throwaway instance is gone.
- [x] 2. Write the deploy script. (files: `scripts/deploy-vpn.sh`; criteria: all)
  Check: `bash -n scripts/deploy-vpn.sh` passes.
- [x] 3. Write the verify scripts. (files: `scripts/verify-vpn.sh`, `scripts/verify-external.sh`; criteria: all tested ones)
  Check: `bash -n` passes for both.
- [ ] 4. Run the deploy script on the VPS. (criteria: R-vpn-server-01 to 07, 09.a)
  Check: exit code 0; output holds no secret.
- [ ] 5. Run both verify scripts. (criteria: all tested ones)
  Check: both print `all checks passed`.
- [ ] 6. Run the deploy script a second time. (criteria: R-vpn-server-08.a)
  Check: exit code 0; checksum of the link file unchanged.
- [ ] 7. Reboot the VPS and run both verify scripts again. (criteria: R-vpn-server-08.c)
  Check: both print `all checks passed`.
- [ ] 8. Write ADR-0002 and ADR-0003; update `docs/vps-access.md`. (files: `docs/decisions/*`, `docs/vps-access.md`)
  Check: both rows are in `docs/decisions/INDEX.md`.
- [ ] Final: run every command in `AGENTS.md`; archive the change. The commands are still `[TODO-CLARIFY]`.
