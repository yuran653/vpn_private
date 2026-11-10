# Tasks: enable-bbr-congestion-control

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

- [x] 1. Add the TCP step to the deploy script and the checks to the verify script (files: `scripts/deploy-vpn.sh`, `scripts/verify-vpn.sh`; criteria: R-vpn-server-11.a to 11.f)
  Check: `bash -n` passes on both.
- [x] 2. Run the deploy script and the verify scripts on the VPS (criteria: R-vpn-server-11.a to 11.f)
  Check: the deploy script exits 0; `verify-vpn.sh` and `verify-external.sh` print "all checks passed"; the client link checksum is unchanged. Done on 2026-11-10: 24 of 24 and 3 of 3 checks pass, checksum unchanged. With the congestion control set back to CUBIC for one run, the checks for 11.a and 11.b failed; BBR was then restored. The checks for 11.c to 11.f were not run against violating values. The host was rebooted afterwards (up again at 01:16 on 2026-11-11, Asia/Bangkok): `verify-vpn.sh` 24 of 24, `verify-baseline.sh` 3 of 3 and `verify-external.sh` 3 of 3 pass, `fq` is on `ens3`, both modules are loaded and the link checksum is unchanged. One 60 MB file copied from the VPS to the workstation over SSH took 175 s and 43 s before, and 26 s, 16 s and 23 s after; five samples on one route, not a benchmark.
- [x] 3. Record the decision and update the access guide (files: `docs/decisions/ADR-0007-bbr-congestion-control.md`, `docs/decisions/INDEX.md`, `docs/vps-access.md`)
  Check: the index lists ADR-0007.
- [ ] Final: run every command in `AGENTS.md`; archive the change. The commands are still `[TODO-CLARIFY]`.
