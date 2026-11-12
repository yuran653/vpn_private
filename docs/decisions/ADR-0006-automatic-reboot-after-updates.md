# ADR-0006: Automatic reboot after updates that need one

- Status: accepted; the reboot time and the time zone superseded by ADR-0022
- Date: 2026-11-10
- Supersedes: none
- Change: `changes/archive/2026-11-10-harden-against-attacks/`
- Note (2026-11-12): nothing set the host's time zone, so "server time" was Asia/Bangkok only if the provider's image was. ADR-0022 sets the zone and moves the reboot to 01:00.

## Context

Unattended upgrades install security updates, but a new kernel or libc is not in effect until the host restarts. The server has one operator and no monitoring. On 2026-11-10 it ran kernel 6.8.0-85 while 6.8.0-147 was in the security pocket.

## Decision

- unattended-upgrades reboots the host when an installed update requires it, at 04:00 server time (Asia/Bangkok), also when a user is logged in. Set in `/etc/apt/apt.conf.d/52vpn-auto-reboot` by `scripts/deploy-vpn.sh`.
- Unused kernel packages are removed automatically, so `/boot` does not fill.
- The deploy script runs `unattended-upgrade` once itself, so a freshly installed host is patched before it is used.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Reboot by hand | Depends on the operator noticing; the host stays on a vulnerable kernel in the meantime. |
| Kernel livepatch | Needs an Ubuntu Pro subscription token on the host, and still does not cover libc or systemd. |

## Consequences

VPN connections drop for about a minute at 04:00 Bangkok time on days when an update needs a reboot. Every setting must survive a reboot unattended; R-vpn-server-08 already requires that.

## Do not

None.
