# Design: deploy-vless-reality

## Approach

One bash script, `scripts/deploy-vpn.sh`, copied to the VPS with `scp` and run with `sudo -n`. It installs 3x-ui v3.11.0 with the project's own installer in non-interactive mode, binds the panel to 127.0.0.1, and then configures everything through the panel's HTTP API on loopback with the API token the installer wrote. Two verification scripts check the result from inside and from outside.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| (none in the repo's architecture) | `scripts/deploy-vpn.sh`, `scripts/verify-vpn.sh`, `scripts/verify-external.sh` | New scripts, outside the module map |
| VPS (not in the repo) | `/usr/local/x-ui/`, `/etc/x-ui/`, `/etc/default/grub.d/60-vpn-disable-ipv6.cfg`, `/etc/sysctl.d/60-vpn-disable-ipv6.conf`, `/etc/netplan/*.yaml`, `/etc/default/ufw`, `/etc/apt/apt.conf.d/20auto-upgrades`, `/root/vpn/`, ufw rules | Written or edited by the script |

New modules or dependencies between modules: none. `docs/architecture.md` is unchanged.

## Contracts and data

- CLI: `sudo -n bash deploy-vpn.sh`, no arguments. `sudo -n bash verify-vpn.sh`. `bash scripts/verify-external.sh [ssh-alias]`.
- Secrets on the VPS, root-only: panel credentials and API token in `/etc/x-ui/install-result.env` (written by the installer), the client link in `/root/vpn/vless-link.txt`, the installer's output in `/root/vpn/install.log`. None of these enter the repo or the script's output.
- The Xray template is owned by the script: each run rebuilds it from the panel's default plus the rules below. Edits made in the panel are overwritten.
- The inbound is created once. A re-run finds the inbound on port 443 and keeps its keys and client ID.

## How each leak is closed

| Leak | Measure |
|---|---|
| IPv6 egress | Kernel parameter `ipv6.disable=1`, IPv6 entries removed from netplan, ufw `IPV6=no` (ADR-0004); the `direct` outbound uses `ForceIPv4`; a routing rule sends `::/0` to `blocked`; DNS `queryStrategy` is `UseIPv4`. |
| DNS | Xray's DNS uses two DoH resolvers (`https+local://1.1.1.1`, `https+local://8.8.8.8`). A routing rule sends port 53 from clients to a `dns` outbound, so plaintext DNS never leaves the VPS. Sniffing (`http`, `tls`, `quic`) makes the server resolve the real name itself. |
| DPI fingerprinting | VLESS over TCP with Reality and the `xtls-rprx-vision` flow on 443. An unauthenticated handshake is forwarded to the cover site. |
| Panel discovery | Panel `listenIP` 127.0.0.1 on a random port with a random path; subscription service off; ufw opens only SSH and 443/tcp. |
| Activity records | `log.access` is `none`, `dnsLog` is `false`. |

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Run the installer interactively | Not reproducible, and it prints credentials to the terminal. |
| Unpack the release tarball by hand | Duplicates the installer's unit and sandbox setup; breaks on the next release. |
| Panel on a public port behind a secret path and TLS | Still answers a scanner. A loopback bind cannot be discovered. |
| Write the inbound straight into the panel's database | Depends on the schema; the API is documented by the panel's own OpenAPI file. |
| Leave IPv6 on and filter it in Xray only | One missed rule leaks. Disabling it on the host cannot be bypassed from Xray. |
| Disable IPv6 by sysctl only | Implemented first and replaced: undone by systemd-networkd at boot (ADR-0004). |
| Plain DNS to the VPS's default resolvers | The hosting network can read every lookup. |

Decision record needed: ADR-0002 (panel on loopback, pinned installer), ADR-0003 (Reality cover site), ADR-0004 (IPv6 off in the kernel; a reversal, with a "Do not" line).

## Verification

| Criterion | Test |
|---|---|
| R-vpn-server-01.a | `scripts/verify-vpn.sh` (R-vpn-server-01.a) |
| R-vpn-server-01.b | `scripts/verify-external.sh` (R-vpn-server-01.b) |
| R-vpn-server-02.a to 02.d | `scripts/verify-vpn.sh` (same IDs) |
| R-vpn-server-03.a, 03.b | `scripts/verify-vpn.sh` (same IDs) |
| R-vpn-server-04.a | `scripts/verify-external.sh` and `scripts/verify-vpn.sh` (R-vpn-server-04.a) |
| R-vpn-server-05.a, 05.c | `scripts/verify-vpn.sh` (same IDs) |
| R-vpn-server-05.b | `scripts/verify-external.sh` (R-vpn-server-05.b) |
| R-vpn-server-06.a, 07.a, 08.b | `scripts/verify-vpn.sh` (same IDs) |
| R-vpn-server-08.a | None automated. Second run on the VPS, link checksum compared before and after. |
| R-vpn-server-08.c | `scripts/verify-vpn.sh` (R-vpn-server-08.c) checks the boot parameter. The full criterion was checked by rebooting and running both verify scripts. |
| R-vpn-server-08.d | `scripts/verify-vpn.sh` (R-vpn-server-08.d) |
| R-vpn-server-09.a | None automated. Run output searched for secrets; file modes listed. |

The verify scripts use the live network, so they are not deterministic in the sense of the change cycle. They test a deployed server; there is no offline substitute.

## Risks

- A failed step could leave the VPN half-configured. Contained: SSH and its firewall rule are not touched, and the script is safe to re-run.
- The panel is a root process with a large code base. Contained by the loopback bind and the pinned, checksummed installer.
- The installer and the panel API may change in a later release. Contained by the version pin; a version bump is a new change.
- The cover site may change its TLS setup. The verify scripts fail when it no longer returns a valid certificate.
- The loopback client test does not prove the path from the owner's network. The external script checks reachability of 443; the first real connection is the owner's.

## Implementation notes from the first runs

The deploy script ran on the VPS with exit code 0 on the first attempt. Two checks were wrong and were fixed in this change; the server was not at fault in either case:

1. `verify-external.sh` used a bare TCP connect to decide whether a port was open. The workstation's network accepted every connect locally, including to unused ports, so every port looked open. The check now requires an HTTP or TLS answer from the server.
2. `verify-vpn.sh` piped `apt-config dump` into `grep -q` under `pipefail`. `grep -q` closed the pipe early and the pipeline failed. The output is now captured first.

The deploy script also sets `NEEDRESTART_SUSPEND=1`, so package installs do not print service-restart notices.

### Found by the reboot test

3. After the first reboot the VPS had its global IPv6 address again. systemd-networkd had set `disable_ipv6 = 0` on the interface, because the provider's netplan file carries an IPv6 default route. The sysctl approach was replaced by the kernel parameter `ipv6.disable=1`, with ufw set to `IPV6=no` (ADR-0004).
4. After the second reboot IPv6 stayed off, but the boot took 2 min 16 s: networkd stayed in "configuring" on the IPv6 route and `systemd-networkd-wait-online` timed out. The deploy script now removes IPv6 entries from netplan, keeping the originals in `/root/vpn/netplan-backup/`. The third reboot took 17 s and both verify scripts passed.

The client link had the same checksum after all four deploy runs and three reboots.
