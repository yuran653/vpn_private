# Tasks: serve-own-cover-site

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

- [x] 1. Write ADR-0012, the proposal, the delta and this design (files: `docs/decisions/ADR-0012-own-domain-cover-site.md`, `changes/serve-own-cover-site/`)
  Check: the owner approves the proposal.
- [x] 2. Build the landing page and the container definition (files: `site/html/index.html`, `site/docker-compose.yml`, `site/nginx.conf`; criteria: R-vpn-server-15.c, .d)
  Check: the page opens locally in light and dark mode at phone width with no network request (done 2026-11-12); the owner approved the preview (2026-11-12).
- [x] 3. Add nginx, certbot, Docker and port 80 to the deploy script (files: `scripts/deploy-vpn.sh`; criteria: R-vpn-server-05, -06.b, -15, -16)
  Check: `bash -n` passes. `shellcheck` is not installed on the workstation; not run.
- [x] 4. Point Reality at the local web server and set the cover name (files: `scripts/deploy-vpn.sh`; criteria: R-vpn-server-04, -14)
  Check: `bash -n` passes; the loopback target is checked on the VPS by R-vpn-server-04.c.
- [x] 5. Update the verify scripts (files: `scripts/verify-external.sh`, `scripts/verify-vpn.sh`)
  Check: `bash -n` passes; every new criterion ID is found by `grep`.
- [x] 6. Deploy in the window the owner names; run both verify scripts (criteria: all)
  Check: both scripts exit 0; the tunnel exits through WARP in Bangkok. Done 2026-11-12: `verify-vpn.sh` and `verify-external.sh` passed every check after the third run. The first run stopped before the tunnel changed (the TLS check ran before nginx had reloaded); the second left R-vpn-server-06.b failing (the image's own access log line) and R-vpn-server-08.d failing (the check counted Docker's veth interface). A re-run left the client link unchanged, and the client ID, public key and short ID are the ones from before the change.
- [ ] 7. Hand over the new link; the owner confirms it on every device, on Wi-Fi and mobile data.
- [ ] 8. Update the docs (files: `docs/decisions/INDEX.md`, `docs/censor-red-flags.md`, `docs/vps-access.md`)
  Check: ADR-0003 reads "superseded by ADR-0012"; flags 1, 7 and 10 are marked fixed.
- [ ] Final: run every command in `AGENTS.md`; archive the change; pull request; merge.
