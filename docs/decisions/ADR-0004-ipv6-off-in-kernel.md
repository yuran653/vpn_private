# ADR-0004: IPv6 disabled in the kernel, not by sysctl

- Status: accepted
- Date: 2026-11-10
- Supersedes: none
- Change: `changes/archive/2026-11-10-deploy-vless-reality/`

## Context

The server must have no IPv6 egress. The first implementation wrote `net.ipv6.conf.{all,default}.disable_ipv6 = 1` to `/etc/sysctl.d/`. It held until the first reboot. After the reboot the interface had its global IPv6 address again: the provider's netplan file carries an IPv6 default route, and systemd-networkd sets `disable_ipv6 = 0` on any interface whose config has IPv6 entries.

## Decision

- IPv6 is disabled with the kernel parameter `ipv6.disable=1`, set through `/etc/default/grub.d/60-vpn-disable-ipv6.cfg`. It takes effect at the next boot; the deploy script reports when a reboot is needed.
- IPv6 addresses and routes are removed from `/etc/netplan/*.yaml`, with `accept-ra: false` and `link-local: []`. The originals are kept in `/root/vpn/netplan-backup/`.
- ufw runs with `IPV6=no`.
- The sysctl file stays as a second layer, with keys marked optional.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| sysctl `disable_ipv6` only | Implemented first. Undone by systemd-networkd at boot; the VPS regained a global IPv6 address. |
| Kernel parameter without the netplan edit | Tried second. IPv6 stayed off, but networkd stayed in "configuring" on the IPv6 route and every boot waited two minutes for the network. |
| Keep IPv6 and drop it in the firewall | The address stays on the interface; one changed rule leaks. |

## Consequences

The host cannot use IPv6 at all until this decision is reversed. A provider image that rewrites netplan with IPv6 entries will slow the boot again; `scripts/verify-vpn.sh` (R-vpn-server-08.c, 08.d) detects both failures.

## Do not

- Do not rely on sysctl `disable_ipv6` alone to turn IPv6 off: systemd-networkd re-enables it at boot on an interface with IPv6 config. Use the `ipv6.disable=1` kernel parameter. (ADR-0004)
