# AGENTS.md — VPS Access Guide

Instructions for coding agents (Kimi Code and similar) operating in this repo.

## Target

| Item | Value |
|---|---|
| VPS | Z.com Cloud, BKK4 zone (Bangkok), plan C2 (2 vCPU / 4 GB / 50 GB) |
| OS | Ubuntu 24.04 LTS, bare |
| Global IP | geolocation-verified Thailand (`curl ifconfig.co/country` → `TH`) |
| SSH | key-only, user `ubuntu`, alias `zcom-th`, private key `~/.ssh/zcom_th_vpn` |
| Root | SSH login as `root` is **blocked** by the provider image. `su root` works via console password (fallback only). Use `sudo` for privileged commands. |

## Connecting

```bash
ssh zcom-th            # alias in ~/.ssh/config: HostName <IP>, User ubuntu, IdentityFile ~/.ssh/zcom_th_vpn
```

First connect: accept the host key (`yes`). If the key prompt returns on every connect, the key may be unregistered — stop and report, do not fall back to password login.

## Rules for the agent

1. **Never** run `ssh -i ... root@...` — it fails and locks the session out of habits; use `zcom-th` and `sudo`.
2. **Never** commit `.env`, private keys, panel credentials, or `vless://` links. Real values live outside the repo.
3. State-changing or risky commands on the VPS (`ufw enable`, sshd edits, package installs, panel install) — show the command and purpose first, wait for explicit confirmation. Read-only checks (`curl ifconfig.co/country`, `systemctl status`, `ufw status`) run freely.
4. Keep the SSH session alive when editing sshd/ufw: open a second session and verify login works before closing the first.
5. All privileged operations via `sudo -n` — agent should not expect interactive password prompts; if a command asks for a password, stop and report.

## Post-connect sanity check (run before any work)

```bash
ssh zcom-th 'hostname && curl -s ifconfig.co/country && uname -r'
```

Expected: `ubuntu@...`, `TH`, kernel `6.x`. If country is not `TH`, stop and report (exit node invalid).
