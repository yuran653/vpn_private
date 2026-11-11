# Tasks: rotate-connections-and-move-to-files-name

- [x] 1. Decision record and index (files: `docs/decisions/ADR-0014-*.md`, `docs/decisions/INDEX.md`)
  Check: index lists ADR-0014.
- [x] 2. Deploy script: name list, padding, `extra` in the link (files: `scripts/deploy-vpn.sh`; criteria: R-vpn-server-14, 15, 17, 18.a, 18.c)
  Check: `bash -n`; a run on the VPS exits 0.
- [x] 3. Landing page section (files: `site/html/index.html`; criteria: R-vpn-server-15.c, .d, .f)
  Check: no script, form or other host; no "VPN" or "Thailand".
- [x] 4. Verify scripts (files: `scripts/verify-vpn.sh`, `scripts/verify-external.sh`; criteria: all in the delta)
  Check: `bash -n`; both pass against the VPS.
- [x] 5. Owner: `files.casedigestai.com` added in Cloudflare as a proxied record.
  Check: it resolves to Cloudflare ranges only.
- [x] 6. Deploy, run both verify scripts. Owner re-imports the link in Happ: outstanding; the old link keeps working meanwhile.
- [x] 7. Docs (files: `AGENTS.md`, `docs/vps-access.md`, `docs/censor-red-flags.md`)
  Check: no remaining claim that clients connect to `status.casedigestai.com`.
- [x] Final: run every command in `AGENTS.md`; archive the change.

## Found during implementation

- Xray 26.10.21 on the VPS accepts `extra.xmux` from the client config; the tunnel works through Cloudflare with it.
- A client whose padding range does not overlap the server's (`1-10` against `100-1000`) gets no connection through the tunnel. That is the reason for ADR-0014's "Do not" line.
- With Xray's default xmux, connections also turned over during a 330-second run (3 connections, against 2 with the new settings). The settings set a guaranteed bound; the run did not show how much they add on top of the defaults. R-vpn-server-18.b is `untested`.
- A single long download keeps its connection for as long as it runs, whatever xmux says: rotation applies to new sessions only.
- The old link (`status.casedigestai.com`) still connects.
- The re-run left the link's checksum unchanged and did not update the inbound again. The VPS was rebooted once for a pending update; both verify scripts passed afterwards.
- Not fixed (out of scope): `docs/how-it-works.html` still describes the Reality setup from before ADR-0013 (direct TCP 443 to the VPS, XTLS-Vision, the name `status.casedigestai.com`).
- The commands in `AGENTS.md` are still `[TODO-CLARIFY]`; the checks run were `bash -n` on every script, `scripts/verify-vpn.sh` on the VPS and `scripts/verify-external.sh` from the workstation.
