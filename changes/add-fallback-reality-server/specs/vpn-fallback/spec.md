# Delta: vpn-fallback

New capability: a second VPN server on its own VPS and address, reached directly, used when the link through Cloudflare fails (ADR-0018).

## ADDED

### R-vpn-fallback-01: Tunnel

A client holding the fallback link connects to the second server's address directly and reaches the internet through the first server.

- **R-vpn-fallback-01.a** WHEN a client connects with the fallback link and requests a web page THEN the page sees an IPv4 client address that is neither the second server's nor the first server's.
- **R-vpn-fallback-01.b** WHEN the fallback link is read THEN its address is the second server's IPv4 address on port 443, and no name or address of the first server appears in it.

### R-vpn-fallback-02: Probe resistance

A party without the link that connects to the second server sees a third-party website that belongs in that network.

- **R-vpn-fallback-02.a** WHEN a TLS client without the link connects to port 443 of the second server with the cover name THEN it receives that site's publicly trusted certificate and its page.
- **R-vpn-fallback-02.b** WHEN the cover name is resolved from the internet THEN it resolves only to addresses announced by the same AS number as the second server's address, and the name is not on `docs/blocked-names.txt` and is not one of the owner's.
- **R-vpn-fallback-02.c** WHEN a TLS client connects to port 443 with another name or with no name THEN it gets the cover site's answer, not a reset that differs from the cover site's own.

### R-vpn-fallback-03: Nothing else answers

The second server answers the internet on port 443 only, and its SSH port answers only the operator.

- **R-vpn-fallback-03.a** WHEN the host's listening sockets are listed THEN only SSH and port 443 listen on a public address, and no UDP socket.
- **R-vpn-fallback-03.b** WHEN the firewall rules are listed THEN incoming traffic is denied except 443/tcp from anywhere and SSH from the operator's listed addresses.
- **R-vpn-fallback-03.c** WHEN a host on the internet connects to the panel port or to the usual panel and subscription ports THEN the connection is not accepted.
- **R-vpn-fallback-03.d** WHEN a host that is not on the operator's list connects to the SSH port THEN it gets no answer.

### R-vpn-fallback-04: An entry only, with the first server's exit

Everything a client sends through the second server is forwarded to the first server and leaves from there; nothing leaves from the second server's own address, and it keeps no activity record.

- **R-vpn-fallback-04.a** WHEN the host is inspected THEN it has no global IPv6 address, and a client's request for an IPv6 destination through the tunnel fails.
- **R-vpn-fallback-04.b** WHEN a client sends a DNS query through the tunnel to port 53 of any address THEN it is answered, and the second server itself sends no DNS query for a destination a client asked for.
- **R-vpn-fallback-04.c** WHEN the running proxy configuration is inspected THEN the access log and the DNS log are off, and its only outbound that carries traffic is the relay to the first server's name: no outbound sends from the server's own address to a destination, and none is a WARP tunnel.
- **R-vpn-fallback-04.d** WHEN a client requests Cloudflare's connection report through the tunnel THEN the report says the request came through WARP and places the client in Thailand.
- **R-vpn-fallback-04.e** WHEN the first server cannot be reached THEN a client's request through the second server fails.

### R-vpn-fallback-05: Independent of the first server

Blocking the second server does not touch the first one, and the users' two links share nothing.

- **R-vpn-fallback-05.a** WHEN the fallback link and the first server's link are compared THEN they share no client ID, key, path or name.
- **R-vpn-fallback-05.b** WHEN the second server has been deployed THEN every criterion of `vpn-server` still holds on the first server, and its own address still answers nobody but Cloudflare on 80 and 443.
- **R-vpn-fallback-05.c** WHEN the fallback link is read THEN its profile name differs from the first link's, so the user can tell the two apart in the app.

### R-vpn-fallback-06: An address is tried from a mobile network before the server is kept

A check, run on a phone on mobile data, shows whether an address can carry the fallback from the network it runs on.

- **R-vpn-fallback-06.a** WHEN the check runs against an address that completes a TLS handshake for the cover name, completes a download of more than 64 KB and takes an upload of 30000 bytes THEN it exits 0.
- **R-vpn-fallback-06.b** WHEN the check runs against an address that gives no answer, or whose transfer stops part-way, THEN it exits 1 and names each failing check.
- **R-vpn-fallback-06.c** WHEN the control name cannot take a 30 KB upload from the network the check runs on, or the object fetched is too small to judge, THEN the check exits 2 and judges nothing.
- **R-vpn-fallback-06.d** WHEN a candidate server is to be kept, or its link handed out, THEN the check has passed for its address from a mobile network in Russia.

### R-vpn-fallback-07: Updates, re-runs and secrets

The second server updates itself, survives a re-run and a reboot, and its secrets stay on it.

- **R-vpn-fallback-07.a** WHEN the host's update settings are inspected THEN unattended upgrades are on, the automatic reboot is set for 01:00, and the host's time zone is Asia/Bangkok.
- **R-vpn-fallback-07.b** WHEN the deploy script runs a second time on the same host THEN it exits with code 0 and the fallback link is unchanged.
- **R-vpn-fallback-07.c** WHEN the host reboots THEN every other criterion of this capability still holds.
- **R-vpn-fallback-07.d** WHEN the deploy script runs THEN its output contains no credential, key or link, and the files holding them are readable by root only.
