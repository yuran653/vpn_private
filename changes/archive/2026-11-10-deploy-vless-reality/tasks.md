# Tasks: deploy-vless-reality

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

- [x] 1. Dry-run the panel API, the Xray template and a loopback client on a throwaway panel instance in `/tmp` on the VPS, then remove it. (files: none)
  Check: tunnel exit address is the server's IPv4; the throwaway instance is gone.
- [x] 2. Write the deploy script. (files: `scripts/deploy-vpn.sh`; criteria: all)
  Check: `bash -n scripts/deploy-vpn.sh` passes.
- [x] 3. Write the verify scripts. (files: `scripts/verify-vpn.sh`, `scripts/verify-external.sh`; criteria: all tested ones)
  Check: `bash -n` passes for both.
- [x] 4. Run the deploy script on the VPS. (criteria: R-vpn-server-01 to 07, 09.a)
  Check: exit code 0; output holds no secret.
- [x] 5. Run both verify scripts. (criteria: all tested ones)
  Check: both print `all checks passed`.
- [x] 6. Run the deploy script a second time. (criteria: R-vpn-server-08.a)
  Check: exit code 0; checksum of the link file unchanged.
- [x] 7. Reboot the VPS and run both verify scripts again. (criteria: R-vpn-server-08.c)
  Check: both print `all checks passed`.
- [x] 8. Write ADR-0002 and ADR-0003; update `docs/vps-access.md`. (files: `docs/decisions/*`, `docs/vps-access.md`)
  Check: both rows are in `docs/decisions/INDEX.md`.
- [x] 9. Fix found by task 7: IPv6 returned after reboot. Disable it with the kernel parameter, close ufw's IPv6 side, remove IPv6 from netplan. (files: `scripts/deploy-vpn.sh`, `scripts/verify-vpn.sh`; criteria: R-vpn-server-02.a, 08.c, 08.d)
  Check: after a reboot, both verify scripts print `all checks passed` and the boot takes under 30 s.
- [x] Final (partly): archive the change. The commands in `AGENTS.md` are still `[TODO-CLARIFY]`, so none could be run; both verify scripts were run instead.
