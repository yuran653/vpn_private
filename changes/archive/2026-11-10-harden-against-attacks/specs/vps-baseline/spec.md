# Delta: vps-baseline

## ADDED

### R-vps-baseline-05: SSH login surface

sshd accepts key login for non-root users only, and does not hold unauthenticated connections open.

- **R-vps-baseline-05.a** WHEN the effective sshd configuration is inspected THEN root login, password login, keyboard-interactive login and X11 forwarding are off, and a connection that has not authenticated is closed after 30 seconds.
- **R-vps-baseline-05.b** WHEN the sshd config is invalid after the login settings are written THEN the script removes those settings, does not reload sshd, and exits with an error.

### R-vps-baseline-06: SSH connection limits per address

One address cannot occupy the SSH service with connections.

- **R-vps-baseline-06.a** WHEN the loaded firewall rules are listed THEN new SSH connections from one address are dropped beyond 10 concurrent connections or 30 new connections per minute.
- **R-vps-baseline-06.b** WHEN one address opens 16 SSH connections at once THEN at most 10 are accepted.

### R-vps-baseline-07: SYN flood settings

The host keeps answering new connections while a SYN flood fills the backlog.

- **R-vps-baseline-07.a** WHEN the kernel settings are inspected THEN SYN cookies are on and the SYN backlog holds at least 4096 entries.
