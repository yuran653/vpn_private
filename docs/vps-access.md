# vps-access.md — VPS Access Guide

Instructions for coding agents (Kimi Code and similar) operating in this repo.

## Target

| Item | Value |
|---|---|
| VPS | Z.com Cloud, BKK4 zone (Bangkok), plan C2 (2 vCPU / 4 GB / 50 GB) |
| OS | Ubuntu 24.04 LTS, bare |
| Global IP | registered to Thailand, but geo-IP databases disagree (2026-11-10): ipinfo, ip-api and Cloudflare say Thailand, ifconfig.co says Japan, Google says Myanmar. Client traffic therefore leaves through Cloudflare WARP (ADR-0008). |
| SSH | key-only, user `ubuntu`, alias `zcom-th`, private key `~/.ssh/zcom-th-vpn` (keep secret), public key `~/.ssh/zcom-th-vpn.pub` |
| Root | SSH login as `root` is **refused** by sshd (`PermitRootLogin no`, set by `scripts/harden-vps.sh`). `su root` works via console password (fallback only). Use `sudo` for privileged commands. |

## Connecting

```bash
ssh zcom-th            # alias in ~/.ssh/config: HostName <IP>, User ubuntu, IdentityFile ~/.ssh/zcom-th-vpn, IdentitiesOnly yes
```

First connect: accept the host key (`yes`). If the key prompt returns on every connect, the key may be unregistered — stop and report, do not fall back to password login.

## Rules for the agent

1. **Never** run `ssh -i ... root@...` — it fails and locks the session out of habits; use `zcom-th` and `sudo`.
2. **Never** commit `.env`, private keys, panel credentials, or `vless://` links. Real values live outside the repo.
3. The owner has decided that the agent runs scripts on the VPS over `ssh zcom-th` with `sudo -n` (decided 2026-11-10). Scripts come from this repo, are copied with `scp`, and are run as root with `sudo -n`. Report each script's name and result. Read-only checks (`curl ifconfig.co/country`, `systemctl status`, `ufw status`) run freely.
4. Keep the SSH session alive when editing sshd/ufw: open a second session and verify login works before closing the first.
5. All privileged operations via `sudo -n` — agent should not expect interactive password prompts; if a command asks for a password, stop and report.

## Baseline script

`scripts/harden-vps.sh` applies the baseline: SSH keepalive and login settings (no root, no passwords, no X11), fail2ban, ufw, SYN flood settings and per-address limits on SSH connections. Run it on the VPS with your current IP, which is passed as an argument and not stored in the repo, then check the result:

```bash
scp scripts/harden-vps.sh scripts/verify-baseline.sh zcom-th:/tmp/
ssh zcom-th 'sudo -n bash /tmp/harden-vps.sh <YOUR_IP>'
ssh zcom-th 'sudo -n bash /tmp/verify-baseline.sh; rm -f /tmp/harden-vps.sh /tmp/verify-baseline.sh'
```

After the script reloads sshd and ufw, the second `ssh` above is the login check that rule 4 asks for.

One address may hold 10 SSH connections at once and open 30 per minute (ADR-0005). A loop that opens more than that from your own address is dropped until the rate falls; wait a minute and retry.

The change records are in `changes/archive/2026-11-10-apply-vps-baseline/` and `changes/archive/2026-11-10-harden-against-attacks/`.

## VPN deployment

`scripts/deploy-vpn.sh` installs 3x-ui and configures the VLESS server, reached by clients only through Cloudflare (ADR-0013). Every site name must be proxied by Cloudflare before it runs. Run the baseline script first. It takes no arguments and prints no secret:

```bash
scp -r scripts/deploy-vpn.sh scripts/verify-vpn.sh site zcom-th:/tmp/
ssh zcom-th 'sudo -n bash /tmp/deploy-vpn.sh'
ssh zcom-th 'sudo -n bash /tmp/verify-vpn.sh; sudo -n rm -rf /tmp/deploy-vpn.sh /tmp/verify-vpn.sh /tmp/site'
bash scripts/verify-external.sh
```

After ADR-0015 the client link carries `alpn=http/1.1` and `fp=android` and nginx passes the tunnel path with `proxy_pass`. A re-run of the deploy script rewrites the link file; every device must import the new link. The earlier link (`h2,http/1.1`) keeps working where HTTP/2 is not blocked.

If the deploy script prints `REBOOT NEEDED`, reboot the VPS once and run both verify scripts again.

The deploy script also installs pending security updates, which takes several minutes on a fresh image. Start it detached, so a dropped SSH session cannot interrupt it. The script restarts Xray, which drops an SSH session that itself travels through this VPN:

```bash
ssh zcom-th 'sudo -n sh -c "nohup bash /tmp/deploy-vpn.sh > /root/vpn/deploy-run.log 2>&1 &"'
ssh zcom-th 'sudo -n tail /root/vpn/deploy-run.log'      # repeat until it prints "[deploy] done"
```

## Cover site

The server is the website of `casedigestai.com`, `files.casedigestai.com` and `status.casedigestai.com` (ADR-0012, ADR-0014), published through Cloudflare (ADR-0013). Clients connect to `files.casedigestai.com`, which the page presents as case-file sync, so heavy transfers have a reason. `status.casedigestai.com` is kept for links issued before ADR-0014; once every device has the new link it can go.

- Cloudflare holds the domain's DNS and proxies every name (orange cloud, SSL mode "Full (strict)"). Clients and visitors connect to Cloudflare; Cloudflare connects to the server.
- nginx on the host answers on port 80 (certificate challenge, redirect to HTTPS) and on port 443 with the Let's Encrypt certificate. One random path on 443 goes to the Xray XHTTP inbound on `127.0.0.1:10443`; every other path is the site. Its config, `/etc/nginx/conf.d/cover-site.conf`, is written by `deploy-vpn.sh`.
- ufw admits 80 and 443 only from Cloudflare's IPv4 ranges, fetched by the deploy script into `/root/vpn/cloudflare-ips-v4.txt`. Re-run the script when Cloudflare changes its ranges.
- The pages come from a Docker container in `/opt/cover-site`, published on `127.0.0.1:8080` only. The source is the repo's `site/` folder; change the page there and re-run the deploy script.
- The certificate renews through `certbot.timer`. `scripts/verify-vpn.sh` rehearses a renewal (R-vpn-server-16.b).
- The removed Reality inbound is in `/root/vpn/inbound-previous.json`, root-only.
- Neither nginx nor the container keeps an access log.

## Updates and reboots

Security updates install every night without an operator. When one needs a reboot, the host reboots itself at 04:00 Asia/Bangkok (ADR-0006); VPN connections drop for about a minute. Port 443 has no per-address limits: every client arrives from a Cloudflare address (ADR-0013).

## TCP tuning

The deploy script sets BBR congestion control, `fq` pacing and 16 MB TCP buffer limits for the long path to the clients (ADR-0007), in `/etc/sysctl.d/60-vpn-tcp.conf` and `/etc/modules-load.d/vpn-tcp.conf`. Connections that were open during the run keep the old congestion control until they close; reconnect the client to get the new one.

## Exit through Cloudflare WARP

Client traffic does not leave from the server's own address. The deploy script registers the server once as a free WARP device and Xray sends everything through that tunnel (ADR-0008). Sites see a Cloudflare address placed in Thailand. `scripts/verify-vpn.sh` checks it (R-vpn-server-12).

- The registration is in `/root/vpn/warp.json`. A re-run of the deploy script keeps it.
- When WARP is unreachable, clients connect but no site loads. Nothing falls back to the server's own address. Check with `ssh zcom-th 'sudo -n bash /tmp/verify-vpn.sh'` (copy the script first): R-vpn-server-12.a fails while WARP is down.
- If Cloudflare has dropped the registration, move `/root/vpn/warp.json` aside and re-run the deploy script; it registers a new device. Registering accepts Cloudflare's terms of service.
- Clients keep the same link.
- The tunnel goes to `188.114.97.1`, which Cloudflare's Bangkok site answers from this host (ADR-0009). If Cloudflare routes that address to another site, R-vpn-server-12.f fails and names the site. Traffic is then slower, but the exit is still valid while R-vpn-server-12.a to 12.d pass.

## What the server does not defend against

A flood aimed at the site names is absorbed by Cloudflare. A volumetric DDoS aimed at the server's own address, which is in DNS history and certificate logs from before ADR-0013, still fills the uplink before the firewall sees a packet. The practical recovery is a new IP address from the provider, then the two A records in Cloudflare changed to it (still proxied), then a re-run of `deploy-vpn.sh`. The client link names the host, not the address, so it does not change.

If Cloudflare is blocked or throttled where a user is, the VPN is unreachable there: there is no second way in (flag 6 in `docs/censor-red-flags.md`).

Secrets stay on the VPS, readable by root only:

| What | Where |
|---|---|
| Client link (`vless://...`) | `/root/vpn/vless-link.txt` |
| Tunnel path (also in the link and the nginx config) | `/root/vpn/xhttp-path` |
| Panel user, password, port, path and API token | `/etc/x-ui/install-result.env` |
| Installer output | `/root/vpn/install.log` |
| WARP registration (private key, device id, token) | `/root/vpn/warp.json` |
| Original netplan files | `/root/vpn/netplan-backup/` |

To show the client link: `ssh zcom-th 'sudo -n cat /root/vpn/vless-link.txt'`. Do not paste it into the repo (rule 2).

The link names the profile `กรุงเทพฯ cloud.z.com` (ADR-0011). Happ shows a new name only after the link is imported again; the group ("Server-List") and the main icon are the app's own, and there is no subscription or traffic counter in the app (ADR-0010 was tried and dropped). The panel's own counter shows the client's traffic.

The link's `extra` parameter carries XHTTP padding and connection rotation (ADR-0014): a connection to Cloudflare takes no new sessions after 2 to 5 minutes or 32 to 64 sessions. [TODO-CLARIFY: does Happ apply `extra` from a vless:// link?]

The panel listens on 127.0.0.1 only (ADR-0002). To open it, read the port and path from `install-result.env`, then tunnel:

```bash
ssh -L 8443:127.0.0.1:<PANEL_PORT> zcom-th     # then browse to http://127.0.0.1:8443/<PANEL_PATH>/
```

The Xray template is owned by `deploy-vpn.sh`; edits made to it in the panel are overwritten on the next run.

## Post-connect sanity check (run before any work)

```bash
ssh zcom-th 'hostname && curl -s ifconfig.co/country && uname -r'
```

Expected: the hostname, a country, kernel `6.x`. Since 2026-11-10 `ifconfig.co` answers `Japan` for this address; the owner knows (ADR-0008). The host's own country no longer decides whether the exit is valid: clients leave through WARP, and `scripts/verify-vpn.sh` (R-vpn-server-12.b) fails when that exit is not in Thailand. If that check fails, stop and report.

## Replacing the domain

`casedigestai.com` is on `docs/blocked-names.txt` (blocked on Russian mobile networks, 2026-11-12), so the site and the link have to move to a new domain (ADR-0017). Order:

1. Choose a domain used for nothing else.
2. From a phone on mobile data in each target country, with no VPN, run `bash scripts/check-name.sh <name>` for the name that will carry the tunnel. Only a pass (exit 0) lets it go on; exit 2 means that network cannot judge it. The name must resolve through Cloudflare for the check to mean anything, so put the zone on Cloudflare (proxied, "Full (strict)") first.
3. Change the names in `scripts/deploy-vpn.sh`, `scripts/verify-vpn.sh`, `scripts/verify-external.sh`, `site/docker-compose.yml`, `site/html/index.html`, `docs/how-it-works.html` and the spec, then run the deploy and both verify scripts. Every device imports the new link.

