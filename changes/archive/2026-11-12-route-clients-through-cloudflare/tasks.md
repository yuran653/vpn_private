# Tasks: route-clients-through-cloudflare

- [x] 1. Decision record and index (files: `docs/decisions/ADR-0013-*.md`, `docs/decisions/INDEX.md`, ADR-0005, ADR-0012 status lines)
  Check: index lists ADR-0013 and its three "Do not" lines.
- [x] 2. Deploy script: Cloudflare ranges, DNS check, XHTTP inbound, cut-over, firewall, link (files: `scripts/deploy-vpn.sh`; criteria: R-vpn-server-04, 05, 14, 17)
  Check: `bash -n`; a run on the VPS exits 0 after Cloudflare is active.
- [x] 3. Verify scripts (files: `scripts/verify-vpn.sh`, `scripts/verify-external.sh`; criteria: all in the delta)
  Check: `bash -n`; both pass against the VPS.
- [x] 4. Docs (files: `AGENTS.md`, `docs/vps-access.md`, `docs/censor-red-flags.md`)
  Check: no remaining claim that clients connect to the server's address.
- [x] 5. Owner: domain on Cloudflare, both names proxied, SSL "Full (strict)", nameservers changed at Onamae.com
  Check: `dig NS casedigestai.com` names Cloudflare; both names resolve to Cloudflare ranges.
- [x] 6. Deploy, run both verify scripts, owner re-imports the link in Happ.
- [x] Final: run every command in `AGENTS.md`; archive the change.

## Found during implementation

- 3x-ui v3 keeps clients in their own table. Deleting the Reality inbound left the client `owner` behind, and the new inbound was refused ("Duplicate email"). The deploy script now deletes the leftover client and reuses its ID. The first run stopped at that point with the VPN down for about two minutes; the fixed script completed the cut-over.
- Cloudflare's ranges file has no newline after the last range; `verify-vpn.sh` skipped it until fixed. The firewall itself was right.
- Cloudflare's "JavaScript Detections" injects a script into the landing page (R-vpn-server-15.c set to `drift`).
- The commands in `AGENTS.md` are still `[TODO-CLARIFY]`; the checks run were `bash -n` on every script, `scripts/verify-vpn.sh` on the VPS and `scripts/verify-external.sh` from the workstation.
