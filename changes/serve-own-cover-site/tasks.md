# Tasks: serve-own-cover-site

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

- [x] 1. Write ADR-0012, the proposal, the delta and this design (files: `docs/decisions/ADR-0012-own-domain-cover-site.md`, `changes/serve-own-cover-site/`)
  Check: the owner approves the proposal.
- [ ] 2. Build the landing page and the container definition (files: `site/index.html`, `site/docker-compose.yml`; criteria: R-vpn-server-15.c, .d)
  Check: the page opens locally in light and dark mode at phone width with no network request; the owner approves the preview.
- [ ] 3. Add nginx, certbot, Docker and port 80 to the deploy script (files: `scripts/deploy-vpn.sh`, `site/nginx-host.conf`; criteria: R-vpn-server-05, -06.b, -15, -16)
  Check: `bash -n` and `shellcheck` pass.
- [ ] 4. Point Reality at the local web server and set the cover name (files: `scripts/deploy-vpn.sh`; criteria: R-vpn-server-04, -14)
  Check: `bash -n` and `shellcheck` pass; the generated inbound JSON has the loopback target.
- [ ] 5. Update the verify scripts (files: `scripts/verify-external.sh`, `scripts/verify-vpn.sh`)
  Check: `bash -n` and `shellcheck` pass; every new criterion ID is found by `grep`.
- [ ] 6. Deploy in the window the owner names; run both verify scripts (criteria: all)
  Check: both scripts exit 0; the tunnel exits through WARP in Bangkok.
- [ ] 7. Hand over the new link; the owner confirms it on every device, on Wi-Fi and mobile data.
- [ ] 8. Update the docs (files: `docs/decisions/INDEX.md`, `docs/censor-red-flags.md`, `docs/vps-access.md`)
  Check: ADR-0003 reads "superseded by ADR-0012"; flags 1, 7 and 10 are marked fixed.
- [ ] Final: run every command in `AGENTS.md`; archive the change; pull request; merge.
