# Delta: vpn-server

## MODIFIED

### R-vpn-server-07: Unattended security updates

Security updates install and take effect without an operator.

- **R-vpn-server-07.a** WHEN the host's update settings are inspected THEN unattended upgrades are enabled.
- **R-vpn-server-07.b** WHEN the host is inspected THEN a security-update run has completed within the last 48 hours.
- **R-vpn-server-07.c** WHEN the host's update settings are inspected THEN an automatic reboot after an update that needs one is on, set for 04:00 server time.

## ADDED

### R-vpn-server-10: VPN port connection limits per address

One address cannot occupy the VPN port with connections.

- **R-vpn-server-10.a** WHEN the loaded firewall rules are listed THEN new connections to port 443 from one address are dropped beyond 1000 concurrent connections or 100 new connections per second with a burst of 300.
