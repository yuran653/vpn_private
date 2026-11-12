# Delta: vpn-server

## MODIFIED

### R-vpn-server-07: Unattended security updates

Security updates install and take effect without an operator.

- **R-vpn-server-07.a** WHEN the host's update settings are inspected THEN unattended upgrades are enabled.
- **R-vpn-server-07.b** WHEN the host is inspected THEN a security-update run has completed within the last 48 hours.
- **R-vpn-server-07.c** WHEN the host's update settings and clock settings are inspected THEN an automatic reboot after an update that needs one is on, set for 01:00, and the host's time zone is Asia/Bangkok.
