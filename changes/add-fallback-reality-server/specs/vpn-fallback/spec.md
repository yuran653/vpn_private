# Delta: vpn-fallback

New capability: a second VPN server on its own VPS and address, reached directly, used when the link through Cloudflare fails (ADR-0018).

## ADDED

### R-vpn-fallback-01: Tunnel

A client holding the fallback link connects to the second server's address directly and reaches the internet from an IPv4 address that is not that server's.

- **R-vpn-fallback-01.a** WHEN a client connects with the fallback link and requests a web page THEN the page sees an IPv4 client address that is not the second server's address.
- **R-vpn-fallback-01.b** WHEN the fallback link is read THEN its address is the second server's IPv4 address on port 443, and no name or address of the first server appears in it.

### R-vpn-fallback-02: Probe resistance

A party without the link that connects to the second server sees a third-party website that belongs in that network.

- **R-vpn-fallback-02.a** WHEN a TLS client without the link connects to port 443 of the second server with the cover name THEN it receives that site's publicly trusted certificate and its page.
- **R-vpn-fallback-02.b** WHEN the cover name is resolved from the internet THEN it resolves to an address in the same provider network as the second server, and the name is not on `docs/blocked-names.txt` and is not one of the owner's.
- **R-vpn-fallback-02.c** WHEN a TLS client connects to port 443 with another name or with no name THEN it gets the cover site's answer, not a reset that differs from the cover site's own.

### R-vpn-fallback-03: Nothing else answers

The second server answers the internet on port 443 only, and its SSH port answers only the operator.

- **R-vpn-fallback-03.a** WHEN the host's listening sockets are listed THEN only SSH and port 443 listen on a public address, apart from the UDP socket the proxy holds open for its exit tunnel.
- **R-vpn-fallback-03.b** WHEN the firewall rules are listed THEN incoming traffic is denied except 443/tcp from anywhere and SSH from the operator's listed addresses.
- **R-vpn-fallback-03.c** WHEN a host on the internet connects to the panel port or to the usual panel and subscription ports THEN the connection is not accepted.
- **R-vpn-fallback-03.d** WHEN a host that is not on the operator's list connects to the SSH port THEN it gets no answer.

### R-vpn-fallback-04: Same protections as the first server

No traffic leaves the second server over IPv6, DNS stays inside it, it keeps no activity record, and nothing leaves from its own address.

- **R-vpn-fallback-04.a** WHEN the host is inspected THEN it has no global IPv6 address, and a client's request for an IPv6 destination through the tunnel fails.
- **R-vpn-fallback-04.b** WHEN a client sends a DNS query through the tunnel to port 53 of any address THEN the server answers it, and the server's own lookups for tunnel traffic use DNS-over-HTTPS only.
- **R-vpn-fallback-04.c** WHEN the running proxy configuration is inspected THEN the access log and the DNS log are off, and it has no outbound that sends traffic from the server's own address.
- **R-vpn-fallback-04.d** WHEN a client requests Cloudflare's connection report through the tunnel THEN [TODO-CLARIFY: the report places the client in Thailand, or in the second server's country? See the proposal's first open question.]

### R-vpn-fallback-05: Independent of the first server

Finding or blocking the second server tells nothing about the first one, and deploying it changes nothing there.

- **R-vpn-fallback-05.a** WHEN the fallback link and the first server's link are compared THEN they share no client ID, key, path or name.
- **R-vpn-fallback-05.b** WHEN the second server has been deployed THEN every criterion of `vpn-server` still holds on the first server.
- **R-vpn-fallback-05.c** WHEN the fallback link is read THEN its profile name differs from the first link's, so the user can tell the two apart in the app.

### R-vpn-fallback-06: An address is tried from a mobile network before the server is kept

A check, run on a phone on mobile data, shows whether an address can carry the fallback from the network it runs on.

- **R-vpn-fallback-06.a** WHEN the check runs against an address that completes a TLS handshake for the cover name, returns a page of more than 100 KB and takes an upload of 30000 bytes THEN it exits 0.
- **R-vpn-fallback-06.b** WHEN the check runs against an address that gives no answer, or whose transfer stops part-way, THEN it exits 1 and names each failing check.
- **R-vpn-fallback-06.c** WHEN the control name cannot take a 30 KB upload from the network the check runs on THEN the check exits 2 and judges nothing.
- **R-vpn-fallback-06.d** WHEN a candidate server is to be kept, or its link handed out, THEN the check has passed for its address from a mobile network in Russia.

### R-vpn-fallback-07: Updates, re-runs and secrets

The second server updates itself, survives a re-run and a reboot, and its secrets stay on it.

- **R-vpn-fallback-07.a** WHEN the host's update settings are inspected THEN unattended upgrades and the automatic reboot at 04:00 server time are on.
- **R-vpn-fallback-07.b** WHEN the deploy script runs a second time on the same host THEN it exits with code 0 and the fallback link is unchanged.
- **R-vpn-fallback-07.c** WHEN the host reboots THEN every other criterion of this capability still holds.
- **R-vpn-fallback-07.d** WHEN the deploy script runs THEN its output contains no credential, key or link, and the files holding them are readable by root only.
