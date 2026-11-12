# Redeploying on a new VPS

The order of steps for moving the VPN to a bare VPS: after the old one is lost, its IP is blocked, or the provider changes. Follow it top to bottom every time. Details for each step are in `docs/vps-access.md`.

Two questions decide where to start:

- **Is the current domain still usable?** If it, or any name above it, is in `docs/blocked-names.txt`, start at step 1. Otherwise skip steps 1 to 3 and step 10, and keep the domain.
- **Is the client link changing?** The link names the host, not the address. A new IP with the same domain keeps the same link, as long as `/root/vpn/` is restored. A fresh VPS issues a new client ID, so every device imports the new link (step 11).

## Before the VPS

1. **Choose a new domain** that is used for nothing else and is not under a name in `docs/blocked-names.txt` (ADR-0017). It needs three names: the apex, the tunnel name (now `files.`) and `status.`. `status.` is kept only for links from before ADR-0014, so it can be dropped from the scripts on a new domain.
2. **Put the zone on Cloudflare.** Set SSL mode to "Full (strict)". Add no records yet. [TODO-CLARIFY: must "Always Use HTTPS" be off until the first certificate is issued? The certificate challenge arrives on port 80 through Cloudflare.]
3. **Change the names in the repo** (task branch and PR, merged before the deploy): `scripts/deploy-vpn.sh`, `scripts/verify-vpn.sh`, `scripts/verify-external.sh`, `site/docker-compose.yml`, `site/html/index.html`, `docs/how-it-works.html` and `specs/vpn-server/spec.md`.

## The VPS

4. **Order the VPS**: Ubuntu 24.04 LTS, x86_64, key login for `ubuntu`, in Bangkok. The WARP endpoint in ADR-0009 was chosen for that location.
5. **Point the `zcom-th` alias at the new IP** in `~/.ssh/config`, and remove the old host key with `ssh-keygen -R <old IP>`. Log in once and run the post-connect sanity check. Record what the geo-IP services say about the new address in the Target table of `docs/vps-access.md`.
6. **Run the baseline**: `harden-vps.sh <YOUR_IP>`, then `verify-baseline.sh`. From this step on, keep one SSH session open while another one tests login.

## Cloudflare to the server

7. **Add an A record for every site name**, pointing to the new IP, **proxied (orange cloud) from the first second**. A record left on "DNS only" even briefly puts the IP into DNS history and ties the name to a hosting address (flag 1 and the 2026-11-12 incident in `docs/censor-red-flags.md`). Delete the records that point to the old IP.
8. **Deploy**: run `deploy-vpn.sh` detached and wait for `[deploy] done`. If it prints `REBOOT NEEDED`, reboot once. A fresh host always needs that reboot, because IPv6 is turned off in the kernel.
9. **Verify**: `verify-vpn.sh` on the VPS and `verify-external.sh` from the workstation. Check R-vpn-server-12.f. If the WARP endpoint `188.114.97.1` is not answered in Bangkok from the new host, report it: ADR-0009 was decided on an earlier host.

## Before any device gets the link

10. **Check the names**: from a phone on mobile data in each target country, with no VPN, run `bash scripts/check-name.sh <tunnel name>` (ADR-0017). This comes after the deploy because the check needs the site to answer. Only a pass (exit 0) lets the name go out. On a fail, add the domain to `docs/blocked-names.txt` and go back to step 1. The VPS stays.
11. **Hand out the link**: read it with `ssh zcom-th 'sudo -n cat /root/vpn/vless-link.txt'` and import it on each device. Never paste the link into the repo or into a chat that keeps it.

## Record

12. Update `docs/vps-access.md` (the Target table: IP geo results, zone), `docs/censor-red-flags.md` (incident and flag status for the new host) and the spec, through a change with a PR. Add a line to the log below.

## Open

- Flag 5 (SSH open to everyone). A new IP has no scan history, so closing SSH to the internet before the deploy keeps it clean. No option has been decided. [TODO-CLARIFY: SSH through a Cloudflare Tunnel or only from known addresses?]
- When a step proves wrong or missing during a redeploy, fix this file in the same PR as the record in step 12.

## Log

| Date | Why | New domain? | Notes |
|---|---|---|---|
| 2026-11-12 | The old VPS was killed after its IP was blocked; `casedigestai.com` is blocked on Russian mobile networks | yes | Order written; redeploy not done yet |
