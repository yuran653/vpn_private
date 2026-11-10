# Design: harden-against-attacks

## Approach

Each script keeps what it already owns. `scripts/harden-vps.sh` owns SSH and the base firewall, so it gets the sshd login settings, the SYN flood sysctls and the SSH connection limits. `scripts/deploy-vpn.sh` owns the update settings and the 443 rule, so it gets the automatic reboot, the immediate update run and the VPN port limits.

The connection limits are iptables `connlimit` and `hashlimit` rules in one marked block per script at the end of the `ufw-before-input` chain in `/etc/ufw/before.rules`. That chain runs before ufw's ALLOW rules. A script rewrites only its own block, tests the candidate file with `iptables-restore --test --noflush` against the live ruleset, and restores the previous file if `ufw reload` fails.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| baseline | `scripts/harden-vps.sh` | `/etc/ssh/sshd_config.d/10-hardening.conf`, `/etc/sysctl.d/60-vps-syn-flood.conf`, the block `vps-baseline ssh limits` in `before.rules` |
| vpn | `scripts/deploy-vpn.sh` | `/etc/apt/apt.conf.d/52vpn-auto-reboot`, one `unattended-upgrade` run, the block `vpn-server port limits` in `before.rules`, a second `REBOOT NEEDED` message |
| verification | `scripts/verify-baseline.sh` (new), `scripts/verify-vpn.sh` | checks for the new criteria |
| docs | `docs/vps-access.md`, `docs/decisions/` | new verify script, reboot window, ADR-0005, ADR-0006 |

New modules or dependencies between modules: none.

## Contracts and data

- `harden-vps.sh` and `deploy-vpn.sh` keep their arguments and exit codes.
- `deploy-vpn.sh` now takes minutes on a host with pending updates, and can print a second `REBOOT NEEDED` line.
- Root can no longer log in over SSH with any key. Root access is `sudo` from `ubuntu`, or the provider console.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| `ufw limit 22/tcp` | Fixed at 6 connections in 30 seconds per address. One run of the operator's scp and ssh sequence exceeds it. ADR-0005. |
| fail2ban for connection floods | It reacts to log lines after the fact, and a flood of bare connections writes few. |
| One shared limits script called by both | A third file to copy to the VPS for 20 lines; the two blocks have different owners and markers. |
| Reboot by hand after updates | The review found exactly this state: kernel 6.8.0-85 running with 6.8.0-147 in the security pocket. ADR-0006. |
| `apt-get dist-upgrade` in the deploy script | Installs non-security updates too, outside what unattended upgrades maintain afterwards. |

Decision record needed: ADR-0005 (connection limits), ADR-0006 (automatic reboot).

## Verification

| Criterion | Test |
|---|---|
| R-vps-baseline-05.a | `scripts/verify-baseline.sh` (R-vps-baseline-05.a) |
| R-vps-baseline-05.b | none: would break the live SSH config, as R-vps-baseline-01.b |
| R-vps-baseline-06.a | `scripts/verify-baseline.sh` (R-vps-baseline-06.a) |
| R-vps-baseline-06.b | none: the workstation's connections are completed by a local proxy, so the 16 test connections never reached the server; no second outside host is available |
| R-vps-baseline-07.a | `scripts/verify-baseline.sh` (R-vps-baseline-07.a) |
| R-vpn-server-07.b | `scripts/verify-vpn.sh` (R-vpn-server-07.b) |
| R-vpn-server-07.c | `scripts/verify-vpn.sh` (R-vpn-server-07.c) |
| R-vpn-server-10.a | `scripts/verify-vpn.sh` (R-vpn-server-10.a) |

## Risks

- A bad firewall rule could cut SSH. Contained by the dry-run test before the file is replaced and the rollback on a failed reload; established sessions survive a reload.
- A bad sshd setting could cut SSH. Contained by `sshd -t` before the reload and a new login checked before the old session closes.
- The VPN limits could throttle a heavy client. 1000 concurrent connections from one address is well above several devices; the numbers are constants at the top of `deploy-vpn.sh`.
- An automatic reboot drops VPN connections for about a minute, at 04:00 Bangkok time, only on days an update needs it.
