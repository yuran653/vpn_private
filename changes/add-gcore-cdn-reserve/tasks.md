# Tasks: add-gcore-cdn-reserve

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

- [x] 1. Record the decision and the spec delta (files: `docs/decisions/ADR-0025-gcore-cdn-reserve.md`, `docs/decisions/INDEX.md`, `docs/decisions/ADR-0018-second-transport-outside-cloudflare.md`, `changes/add-gcore-cdn-reserve/`)
  Check: the ADR follows the template, the index has its row and its "Do not" line, and the delta holds ADDED requirements only. Done 2026-11-14.
- [x] 2. Put the reserve path into the deploy order and the access guide (files: `docs/redeploy.md`, `docs/vps-access.md`, `AGENTS.md`)
  Check: the order for the reserve can be followed from the docs alone. Done 2026-11-14.
- [ ] 3. Extend the deploy and the verify scripts (files: `scripts/deploy-vpn.sh`, `scripts/verify-vpn.sh`, `scripts/verify-external.sh`; criteria: R-vpn-server-28.a to 28.c)
  Check: `bash -n` on all three; on the VPS the deploy ends with `[deploy] done`, both verify scripts pass, and a second run leaves both links' checksums unchanged.
- [ ] 4. Set up the Gcore resource and test XHTTP through it (criteria: R-vpn-server-28.a, 28.b, 28.d)
  Check: R-vpn-server-28.d passes on the live path (30 MB down, 30 MB up, 60 s idle, then usable). If it fails, report and do not hand out the reserve profile.
- [ ] 5. Vet the reserve name and hand out the profile (criteria: R-vpn-server-21.d applied to the reserve name)
  Check: `scripts/check-name.sh` exits 0 for the reserve name from a phone on mobile data in each target country.
- [ ] Final: run every command in `AGENTS.md`; archive the change.
