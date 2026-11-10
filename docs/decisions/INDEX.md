# Decisions

Read this before planning any change.

## Do not

Approaches that were tried or considered and rejected. Each line is binding until a newer decision supersedes it. To go against one, propose a new decision first.

Format: `- Do not <approach>: <one-line reason>. (ADR-NNNN)`

- Do not open a firewall port for the 3x-ui panel or its subscription service, or bind either to a public address: a reachable panel can be discovered and attacked. (ADR-0002)
- Do not rely on sysctl `disable_ipv6` alone to turn IPv6 off: systemd-networkd re-enables it at boot on an interface with IPv6 config. Use the `ipv6.disable=1` kernel parameter. (ADR-0004)
- Do not use `ufw limit` on the SSH port: its fixed 6 connections in 30 seconds locks out the operator's own scp and ssh script runs. Use the per-address limits in `before.rules`. (ADR-0005)

## Log

One row per decision record in this folder. Files are named `ADR-NNNN-<slug>.md`, numbered in sequence.

| ADR | Title | Status | Date |
|---|---|---|---|
| [ADR-0001](ADR-0001-stack.md) | Stack | accepted | 2026-11-10 |
| [ADR-0002](ADR-0002-panel-on-loopback.md) | Panel on loopback, installed from a pinned release | accepted | 2026-11-10 |
| [ADR-0003](ADR-0003-reality-cover-site.md) | Reality cover site | accepted | 2026-11-10 |
| [ADR-0004](ADR-0004-ipv6-off-in-kernel.md) | IPv6 disabled in the kernel, not by sysctl | accepted | 2026-11-10 |
| [ADR-0005](ADR-0005-per-address-connection-limits.md) | Per-address connection limits in ufw's before-input chain | accepted | 2026-11-10 |
| [ADR-0006](ADR-0006-automatic-reboot-after-updates.md) | Automatic reboot after updates that need one | accepted | 2026-11-10 |
