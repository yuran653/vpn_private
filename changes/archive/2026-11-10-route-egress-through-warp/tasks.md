# Tasks: route-egress-through-warp

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

- [x] 1. Add the WARP registration step and the `warp` outbound to the deploy script; remove `direct`; DNS through routing (files: `scripts/deploy-vpn.sh`; criteria: R-vpn-server-12.a, 12.c, 12.e, 09.a)
  Check: `bash -n scripts/deploy-vpn.sh`; `shellcheck` if installed
- [x] 2. Add the R-vpn-server-12 checks and change the 01.a and 02.c checks (files: `scripts/verify-vpn.sh`; criteria: R-vpn-server-01.a, 02.c, 12.a to 12.d)
  Check: `bash -n scripts/verify-vpn.sh`; run before the deploy and see 12.a fail
- [x] 3. Run the deploy script on the VPS, then both verify scripts
  Check: every line `PASS`; second deploy run leaves the `warp.json` checksum unchanged; output holds no key or token
- [x] 4. Measure throughput through the tunnel and confirm Google places the exit in Thailand
  Check: numbers recorded in ADR-0008 (92 Mbit/s direct, 87 Mbit/s through WARP; Google: Thailand)
- [x] 5. Write ADR-0008, the "Do not" line, the WARP section in `docs/vps-access.md`, and the goal line in `AGENTS.md`
  Check: files read back
- [x] Final: run every command in `AGENTS.md`; archive the change.
  Note: the four commands in `AGENTS.md` are still `[TODO-CLARIFY]`. Run instead: `bash -n` on both scripts, `scripts/verify-vpn.sh` (all pass) and `scripts/verify-external.sh` (all pass).

Found while the change was open: the WARP tunnel's UDP socket counted as a public listener, so R-vpn-server-05.a and its check were amended in this change. The script edits reached `main` early inside PR #5, committed by another session working in the same folder.
