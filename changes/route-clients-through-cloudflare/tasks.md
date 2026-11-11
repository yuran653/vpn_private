# Tasks: route-clients-through-cloudflare

- [x] 1. Decision record and index (files: `docs/decisions/ADR-0013-*.md`, `docs/decisions/INDEX.md`, ADR-0005, ADR-0012 status lines)
  Check: index lists ADR-0013 and its three "Do not" lines.
- [x] 2. Deploy script: Cloudflare ranges, DNS check, XHTTP inbound, cut-over, firewall, link (files: `scripts/deploy-vpn.sh`; criteria: R-vpn-server-04, 05, 14, 17)
  Check: `bash -n`; a run on the VPS exits 0 after Cloudflare is active.
- [x] 3. Verify scripts (files: `scripts/verify-vpn.sh`, `scripts/verify-external.sh`; criteria: all in the delta)
  Check: `bash -n`; both pass against the VPS.
- [x] 4. Docs (files: `AGENTS.md`, `docs/vps-access.md`, `docs/censor-red-flags.md`)
  Check: no remaining claim that clients connect to the server's address.
- [ ] 5. Owner: domain on Cloudflare, both names proxied, SSL "Full (strict)", nameservers changed at Onamae.com
  Check: `dig NS casedigestai.com` names Cloudflare; both names resolve to Cloudflare ranges.
- [ ] 6. Deploy, run both verify scripts, owner re-imports the link in Happ.
- [ ] Final: run every command in `AGENTS.md`; archive the change.
