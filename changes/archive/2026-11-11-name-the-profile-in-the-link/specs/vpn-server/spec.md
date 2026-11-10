# Delta: vpn-server

## ADDED

### R-vpn-server-14: Client link names the server

The client link names the profile `กรุงเทพฯ cloud.z.com`.

- **R-vpn-server-14.a** WHEN the client link is read THEN the name after `#` is `กรุงเทพฯ cloud.z.com`.
- **R-vpn-server-14.b** WHEN the deploy script runs on a host that already has the link THEN the key in the link (client ID, public key, short ID) is unchanged.
