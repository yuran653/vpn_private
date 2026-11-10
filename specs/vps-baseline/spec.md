# Capability: vps-baseline

> Current behavior. Changed only by archiving a change. Do not edit directly.

## Purpose

Applies the baseline to the VPS through `scripts/harden-vps.sh`: SSH keepalive and login settings, fail2ban, ufw, SYN flood settings and per-address limits on SSH connections. Run by the operator as root through `sudo -n`.

## Requirements

### R-vps-baseline-01: SSH keepalive

An idle SSH session is probed by the server and dropped after repeated silence, and an invalid keepalive setting never reaches the running SSH service.

- **R-vps-baseline-01.a** [untested: no automated test; checked manually with `sshd -T` on the VPS] WHEN the script runs on a host with a valid sshd config THEN sshd sends a keepalive probe every 60 seconds and closes a session after 3 unanswered probes.
  Test: none
- **R-vps-baseline-01.b** [untested: the invalid-config branch has not been exercised, because it would break the live SSH config] WHEN the sshd config is invalid after the keepalive file is written THEN the script removes that file, does not reload sshd, and exits with an error.
  Test: none

### R-vps-baseline-02: Admin IP exemption

The administrator's IP is never banned by fail2ban, and the script refuses to run without a valid IP.

- **R-vps-baseline-02.a** [untested: exercised manually on the VPS, no automated test] WHEN the script runs without an IPv4 argument THEN it exits with an error before changing anything.
  Test: none
- **R-vps-baseline-02.b** [untested: checked manually with `fail2ban-client get sshd ignoreip`, no automated test] WHEN the script runs with an IPv4 argument THEN fail2ban ignores that address for the sshd jail.
  Test: none

### R-vps-baseline-03: Firewall before enable

The firewall never enables without first allowing the SSH port.

- **R-vps-baseline-03.a** [untested: checked manually with `ufw status verbose`, no automated test] WHEN the script enables ufw THEN the SSH port is already allowed and incoming traffic is denied by default.
  Test: none

### R-vps-baseline-04: Re-run safety

Running the script again on a configured host does not fail or duplicate rules.

- **R-vps-baseline-04.a** [untested: run twice on the VPS, the last run exit code 0; no automated test] WHEN the script runs a second time on the same host THEN it completes with exit code 0 and ufw lists each rule once.
  Test: none

### R-vps-baseline-05: SSH login surface

sshd accepts key login for non-root users only, and does not hold unauthenticated connections open.

- **R-vps-baseline-05.a** [verified] WHEN the effective sshd configuration is inspected THEN root login, password login, keyboard-interactive login and X11 forwarding are off, and a connection that has not authenticated is closed after 30 seconds.
  Test: `scripts/verify-baseline.sh` (R-vps-baseline-05.a)
- **R-vps-baseline-05.b** [untested: the invalid-config branch has not been exercised, because it would break the live SSH config] WHEN the sshd config is invalid after the login settings are written THEN the script removes those settings, does not reload sshd, and exits with an error.
  Test: none

### R-vps-baseline-06: SSH connection limits per address

One address cannot occupy the SSH service with connections.

- **R-vps-baseline-06.a** [verified] WHEN the loaded firewall rules are listed THEN new SSH connections from one address are dropped beyond 10 concurrent connections or 30 new connections per minute.
  Test: `scripts/verify-baseline.sh` (R-vps-baseline-06.a)
- **R-vps-baseline-06.b** [untested: tried once from the workstation with 16 simultaneous connections; they were completed by a local proxy and never reached the server, and no second outside host is available] WHEN one address opens 16 SSH connections at once THEN at most 10 are accepted.
  Test: none

### R-vps-baseline-07: SYN flood settings

The host keeps answering new connections while a SYN flood fills the backlog.

- **R-vps-baseline-07.a** [verified] WHEN the kernel settings are inspected THEN SYN cookies are on and the SYN backlog holds at least 4096 entries.
  Test: `scripts/verify-baseline.sh` (R-vps-baseline-07.a)
