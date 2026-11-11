# Tasks: rotate-connections-and-move-to-files-name

- [ ] 1. Decision record and index (files: `docs/decisions/ADR-0014-*.md`, `docs/decisions/INDEX.md`)
  Check: index lists ADR-0014.
- [ ] 2. Deploy script: name list, padding, `extra` in the link (files: `scripts/deploy-vpn.sh`; criteria: R-vpn-server-14, 15, 17, 18.a, 18.c)
  Check: `bash -n`; a run on the VPS exits 0.
- [ ] 3. Landing page section (files: `site/html/index.html`; criteria: R-vpn-server-15.c, .d, .f)
  Check: no script, form or other host; no "VPN" or "Thailand".
- [ ] 4. Verify scripts (files: `scripts/verify-vpn.sh`, `scripts/verify-external.sh`; criteria: all in the delta)
  Check: `bash -n`; both pass against the VPS.
- [ ] 5. Owner: `files.casedigestai.com` added in Cloudflare as a proxied record.
  Check: it resolves to Cloudflare ranges only.
- [ ] 6. Deploy, run both verify scripts; owner re-imports the link in Happ.
- [ ] 7. Docs (files: `AGENTS.md`, `docs/vps-access.md`, `docs/censor-red-flags.md`)
  Check: no remaining claim that clients connect to `status.casedigestai.com`.
- [ ] Final: run every command in `AGENTS.md`; archive the change.
