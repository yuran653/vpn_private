# Tasks: move-warp-endpoint-to-bangkok

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

- [x] 1. Measure the baseline from the owner's Mac through the VPN: connection setup to ten sites, downloads from five servers, one upload (files: none)
  Check: the measurement prints `colo=SIN loc=TH warp=on` and a number for each site.
- [x] 2. Point `WARP_ENDPOINT` at `188.114.97.1:2408` and update its comment (files: `scripts/deploy-vpn.sh`)
  Check: `bash -n scripts/deploy-vpn.sh`; `grep -c '^readonly WARP_ENDPOINT=188.114.97.1:2408$' scripts/deploy-vpn.sh` prints 1.
- [x] 3. Add the check that Cloudflare's connection report names the Bangkok site (files: `scripts/verify-vpn.sh`; criteria: R-vpn-server-12.f)
  Check: run on the VPS before the switch, the check fails and names `SIN`.
- [x] 4. Re-run `deploy-vpn.sh` on the VPS, detached, then both verify scripts (files: none; criteria: R-vpn-server-12.a to 12.f)
  Check: every line of `verify-vpn.sh` and `verify-external.sh` is PASS.
- [ ] 5. Repeat the measurement of task 1 and decide: keep when setup is faster and downloads are not slower, otherwise restore `162.159.192.1` and re-run (files: `scripts/deploy-vpn.sh` only when restoring)
  Check: the measurement prints `colo=BKK loc=TH warp=on`; the comparison is written into ADR-0009.
- [ ] 6. Write ADR-0009, its row and "Do not" line in the index, and the operator note (files: `docs/decisions/ADR-0009-warp-endpoint-in-bangkok.md`, `docs/decisions/INDEX.md`, `docs/vps-access.md`)
  Check: the "Do not" line in the ADR and in the index are the same text.
- [ ] Final: run every command in `AGENTS.md`; archive the change.
