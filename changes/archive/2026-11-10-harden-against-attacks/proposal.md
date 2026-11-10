# Proposal: harden-against-attacks

## Why

A security review of the live server on 2026-11-10 found it well closed to the internet but with gaps. 166 security updates were not installed, among them OpenSSH, sudo, libc and the kernel: unattended upgrades were enabled but had never run, and nothing reboots the host after a kernel update. sshd still had the provider image's `PermitRootLogin yes` and X11 forwarding on. Nothing limited how many connections one address may open to SSH or the VPN port, and the SYN backlog was the default 256.

## What changes

- After the deploy script runs, pending security updates are installed, not left for the nightly timer.
- When an installed update needs a reboot, the host reboots itself at 04:00 server time (Asia/Bangkok).
- sshd refuses root login, password login, keyboard-interactive login and X11 forwarding, and closes a connection that has not authenticated within 30 seconds.
- New SSH connections from one address are dropped beyond 10 at once or 30 per minute.
- New connections to the VPN port from one address are dropped beyond 1000 at once or 100 per second (burst 300).
- SYN cookies are on and the SYN backlog holds 4096 entries.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vps-baseline | existing | `specs/vps-baseline/spec.md` |
| vpn-server | existing | `specs/vpn-server/spec.md` |

## Out of scope

- Volumetric DDoS. A flood that fills the uplink never reaches the firewall; only the provider can absorb it, and Reality cannot sit behind a CDN. The limits here stop a single address or a small group of addresses from exhausting the host, nothing larger.
- Running Xray and the panel as a non-root user. 3x-ui installs and manages them as root.
- Restricting SSH to the operator's address. That address is dynamic.
- Non-security package updates. Only the security pocket installs automatically, as Ubuntu ships it.
- Passwordless sudo for `ubuntu`. The agent's access depends on it (`docs/vps-access.md`, rule 5).

## Decisions checked

- ADR-0002 (no public panel port): untouched. No port is opened.
- ADR-0004 (IPv6 off in the kernel): untouched. The new firewall rules are IPv4 only, which is all the host has.

## Open questions

None.
