# Redeploying on a new VPS

The order of steps for moving the VPN to a bare VPS: after the old one is lost, its IP is blocked, or the provider changes. Follow it top to bottom every time. The commands for each step are in `docs/vps-access.md`.

Two questions decide where to start:

- **Is the current domain still usable?** If it, or any name above it, is in `docs/blocked-names.txt`, start at step 1. Otherwise keep the domain and skip steps 1, 3 and 11; in step 2 only confirm the three settings (SSL mode, "Always Use HTTPS" off, ECH off).
- **Is the client link changing?** The link names the host, not the address. A new domain always means a new link. With the same domain the link stays the same only if a copy of `/root/vpn/` from the old VPS is restored in step 7. Without that copy the new VPS issues a new client ID and tunnel path, so every device imports the new link (step 12).

## Before the VPS

1. **Register a new domain** that is used for nothing else and is not under a name in `docs/blocked-names.txt` (ADR-0017), and contains no word from `docs/avoided-name-words.txt` (ADR-0021): nothing that says what the service is, nothing politically sensitive. The scripts expect three names: the apex, the tunnel name (now `files.`) and `status.`. `status.` only serves links from before ADR-0014, so a new domain does not need it. Dropping it removes checks from both verify scripts and criteria from the spec, so it is a change of its own; the short path is to rename all three.
2. **Put the zone on Cloudflare.** Add the zone, set Cloudflare's two nameservers at the registrar, and wait until Cloudflare shows the zone as active. Set SSL mode to "Full (strict)" and leave "Always Use HTTPS" off: the first certificate is issued by a challenge on port 80, and a redirect at Cloudflare would send that challenge to port 443 before the server has a certificate. nginx on the server does the redirect itself. Turn ECH off for the zone (ADR-0021): free zones have it on by default and no switch in the dashboard, so it is done through Cloudflare's API, `PATCH /zones/<zone id>/settings/ech` with the value `off`, using an API token of your own that never goes into the repo or onto the VPS. [TODO-CLARIFY: confirm that this call is accepted for a free zone.] The DNS record that offers ECH can take 15 minutes to go; `verify-external.sh` checks it in step 10 (R-vpn-server-24.b). Add no records yet.
3. **Change the names in the repo**, through the change cycle (`.agents/skills/sdd-change/SKILL.md`), merged before the deploy, because the scripts are copied from the repo:
   - `scripts/deploy-vpn.sh`, `scripts/verify-vpn.sh` and `scripts/verify-external.sh`: the name constants, and `COVER_PAGE_TEXT` if the page's brand changes. The three scripts must agree.
   - `site/docker-compose.yml`, `site/html/index.html`: the page must still present case-file sync at the tunnel name (R-vpn-server-15.f).
   - `docs/how-it-works.html`, the "Cover site" section of `docs/vps-access.md`, and `specs/vpn-server/spec.md` (through the change's delta, not edited directly).

## The VPS

4. **Order the VPS**: Ubuntu 24.04 LTS, x86_64, key login for `ubuntu` with `~/.ssh/zcom-th-vpn.pub`, in Bangkok. The WARP endpoint in ADR-0009 was chosen for that location.
5. **Point the `zcom-th` alias at the new IP** in `~/.ssh/config`, and remove the old host key with `ssh-keygen -R <old IP>`. Log in once and run the post-connect sanity check. Note what the geo-IP services say about the new address; it is recorded in step 14.
6. **Run the baseline**: `harden-vps.sh <YOUR_IP>`, then `verify-baseline.sh`. From this step on, keep one SSH session open while another one tests login.
7. **Restore `/root/vpn/`**, only when the domain is kept and a copy from the old VPS exists: put it back as a root-only folder (mode 700) before the deploy. The deploy script then keeps the tunnel path and the WARP registration. It keeps the client ID only if `inbound-previous.json` is in the copy. This path has not been tried; compare the link in step 12 with the old one. [TODO-CLARIFY: is a copy of `/root/vpn/` kept anywhere off the VPS? The old VPS was killed on 2026-11-12 without one.]

## Cloudflare to the server

8. **Set an A record for every site name** to the new IP, **proxied (orange cloud) from the first second**. On a kept domain, change the existing records and leave none on the old IP. A record left on "DNS only" even briefly puts the IP into DNS history and ties the name to a hosting address (flag 1 and the 2026-11-12 incident in `docs/censor-red-flags.md`). Wait until `dig +short A <name> @1.1.1.1` returns Cloudflare addresses for every name; the deploy script stops if one does not.
9. **Deploy**: copy the scripts, `scripts/lib/` and `site/`, run `deploy-vpn.sh` detached and wait for `[deploy] done`. On a fresh host the folder for the run log does not exist yet; the command in `docs/vps-access.md` creates it. If the script prints `REBOOT NEEDED`, reboot once. A fresh host always needs that reboot, because IPv6 is turned off in the kernel. The script is safe to re-run: after a failure, fix the cause and run it again.
10. **Verify**, after the reboot: `verify-vpn.sh` on the VPS and `verify-external.sh` from the workstation. The reboot empties `/tmp`, so copy `verify-vpn.sh` again. Every check must pass. If R-vpn-server-12.f fails, the WARP endpoint `188.114.97.1` is not answered in Bangkok from the new host: report it, because ADR-0009 was decided on an earlier host. The exit is still valid while R-vpn-server-12.a to 12.d pass.

## Before any device gets the link

11. **Check the names**: from a phone on mobile data in each target country (`docs/vps-access.md`, "Target countries"), with no VPN, run `bash scripts/check-name.sh <tunnel name>` (ADR-0017). This comes after the deploy because the check needs the site to answer: a name with no server behind it fails the first GET. Only a pass (exit 0) lets the name go out. Exit 2 means that network cannot judge the name; try another network, it is not a pass. On a fail (exit 1), add the domain to `docs/blocked-names.txt`, delete its records in Cloudflare, and go back to step 1. The VPS stays: skip steps 4 to 7 on that round.
12. **Hand out the link**: read it with `ssh zcom-th 'sudo -n cat /root/vpn/vless-link.txt'`. Import it on one device first and load a page through it on mobile data; then import it on the others. Give every user `docs/client-setup.md` with the link: split tunneling, fragmentation, ECH off (ADR-0021). A user whose network cuts 443 gets a link for another port from `/root/vpn/vless-links-alt.txt` (ADR-0020). Never paste the link into the repo or into a chat that keeps it.

## After

13. **Remove what is left of the old setup**, once every device is on the new link: destroy the old VPS if it still exists (it holds the old keys in `/root/vpn/`), and delete the DNS records of a domain that was replaced.
14. **Record**: update `docs/vps-access.md` (the Target table: IP geo results, zone), `docs/censor-red-flags.md` (incident and flag status for the new host) and the spec, through a change with a PR. Add a line to the log below.

## The fallback server

The second server (ADR-0018, ADR-0019) is deployed after step 10, because it needs the first server's relay link. Its order is in `docs/vps-access.md`, "Fallback server": try the candidate address from a phone, baseline with `--ssh-from`, move the relay link, deploy, verify. Its link is not handed out with the main one in step 12: a user gets it only after the main link and the links for the other ports have failed on that user's network (ADR-0018). After the first server's domain is replaced, move the new relay link over and run `deploy-fallback.sh` again.

## Open

- Flag 5 (SSH open to everyone). A new IP has no scan history, so closing SSH to the internet before the deploy keeps it clean. No option has been decided. [TODO-CLARIFY: SSH through a Cloudflare Tunnel or only from known addresses?]
- A blocked name is found only in step 11, after the whole deploy. An earlier check would need the name to answer before the server exists; none has been designed.
- When a step proves wrong or missing during a redeploy, fix this file in the same PR as the record in step 14.

## Log

| Date | Why | New domain? | Notes |
|---|---|---|---|
| 2026-11-12 | The old VPS was killed after its IP was blocked; `casedigestai.com` is blocked on Russian mobile networks | yes | Order written; redeploy not done yet |
