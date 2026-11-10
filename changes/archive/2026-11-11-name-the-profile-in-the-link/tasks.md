# Tasks: name-the-profile-in-the-link

- [x] 1. Deploy script: name, external proxy reset, link name, remove address file (files: `scripts/deploy-vpn.sh`; criteria: R-vpn-server-14)
  Check: `bash -n scripts/deploy-vpn.sh`.
- [x] 2. Verify script: R-vpn-server-14.a (files: `scripts/verify-vpn.sh`)
  Check: `bash -n scripts/verify-vpn.sh`.
- [x] 3. Run the deploy script on the VPS, then both verify scripts (files: none)
  Check: every line PASS; the client ID's hash is the same before and after.
- [x] 4. Operator note (files: `docs/vps-access.md`)
  Check: it says how to show the link and that the group name and icon are the app's.
- [x] Final: run every command in `AGENTS.md` (still `[TODO-CLARIFY]`; run `bash -n` on the scripts and both verify scripts instead); archive the change.
