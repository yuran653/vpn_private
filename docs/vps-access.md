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

`scripts/deploy-vpn.sh` installs 3x-ui and configures the VLESS + Reality server. Run the baseline script first. It takes no arguments and prints no secret:

```bash
scp scripts/deploy-vpn.sh scripts/verify-vpn.sh zcom-th:/tmp/
ssh zcom-th 'sudo -n bash /tmp/deploy-vpn.sh'
ssh zcom-th 'sudo -n bash /tmp/verify-vpn.sh; sudo -n rm -f /tmp/deploy-vpn.sh /tmp/verify-vpn.sh'
bash scripts/verify-external.sh
```

If the deploy script prints `REBOOT NEEDED`, reboot the VPS once and run both verify scripts again.

The deploy script also installs pending security updates, which takes several minutes on a fresh image. Start it detached, so a dropped SSH session cannot interrupt it. The script restarts Xray, which drops an SSH session that itself travels through this VPN:

```bash
ssh zcom-th 'sudo -n sh -c "nohup bash /tmp/deploy-vpn.sh > /root/vpn/deploy-run.log 2>&1 &"'
ssh zcom-th 'sudo -n tail /root/vpn/deploy-run.log'      # repeat until it prints "[deploy] done"
```

## Updates and reboots

Security updates install every night without an operator. When one needs a reboot, the host reboots itself at 04:00 Asia/Bangkok (ADR-0006); VPN connections drop for about a minute. One address may hold 1000 connections to port 443 and open 100 per second (ADR-0005).

## TCP tuning

The deploy script sets BBR congestion control, `fq` pacing and 16 MB TCP buffer limits for the long path to the clients (ADR-0007), in `/etc/sysctl.d/60-vpn-tcp.conf` and `/etc/modules-load.d/vpn-tcp.conf`. Connections that were open during the run keep the old congestion control until they close; reconnect the client to get the new one.

## Exit through Cloudflare WARP

Client traffic does not leave from the server's own address. The deploy script registers the server once as a free WARP device and Xray sends everything through that tunnel (ADR-0008). Sites see a Cloudflare address placed in Thailand. `scripts/verify-vpn.sh` checks it (R-vpn-server-12).

- The registration is in `/root/vpn/warp.json`. A re-run of the deploy script keeps it.
- When WARP is unreachable, clients connect but no site loads. Nothing falls back to the server's own address. Check with `ssh zcom-th 'sudo -n bash /tmp/verify-vpn.sh'` (copy the script first): R-vpn-server-12.a fails while WARP is down.
- If Cloudflare has dropped the registration, move `/root/vpn/warp.json` aside and re-run the deploy script; it registers a new device. Registering accepts Cloudflare's terms of service.
- Clients keep the same link. They still connect to the server's own address on port 443.
- The tunnel goes to `188.114.97.1`, which Cloudflare's Bangkok site answers from this host (ADR-0009). If Cloudflare routes that address to another site, R-vpn-server-12.f fails and names the site. Traffic is then slower, but the exit is still valid while R-vpn-server-12.a to 12.d pass.

## What the server does not defend against

A volumetric DDoS fills the uplink before the firewall sees a packet. Only the provider can absorb it, and Reality cannot sit behind a CDN. The practical recovery is a new IP address from the provider, then a re-run of `deploy-vpn.sh` to rewrite the client link.

Secrets stay on the VPS, readable by root only:

| What | Where |
|---|---|
| Client link (`vless://...`) | `/root/vpn/vless-link.txt` |
| Panel user, password, port, path and API token | `/etc/x-ui/install-result.env` |
| Installer output | `/root/vpn/install.log` |
| WARP registration (private key, device id, token) | `/root/vpn/warp.json` |
| Original netplan files | `/root/vpn/netplan-backup/` |

To show the client link: `ssh zcom-th 'sudo -n cat /root/vpn/vless-link.txt'`. Do not paste it into the repo (rule 2).

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
