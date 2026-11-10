# Delta: vpn-server

## ADDED

### R-vpn-server-01: Tunnel

A client holding the issued link connects to the server and reaches the internet from the server's IPv4 address.

- **R-vpn-server-01.a** WHEN a client connects with the issued link and requests a web page THEN the page sees the server's IPv4 address as the client address.
- **R-vpn-server-01.b** WHEN a host on the internet opens a TCP connection to port 443 of the server THEN the connection is accepted.

### R-vpn-server-02: No IPv6 egress

No traffic leaves the server over IPv6, from the host or from a client.

- **R-vpn-server-02.a** WHEN the host is inspected THEN it has no global IPv6 address and cannot reach an IPv6 destination.
- **R-vpn-server-02.b** WHEN a client requests an IPv6 destination through the tunnel THEN the request fails.
- **R-vpn-server-02.c** WHEN a client requests a dual-stack site through the tunnel THEN the site sees the server's IPv4 address.
- **R-vpn-server-02.d** WHEN a client sends an AAAA query through the tunnel THEN the answer contains no address.

### R-vpn-server-03: DNS stays inside the server

DNS queries arriving through the tunnel are answered by the server, and the server's lookups for tunnel traffic leave it encrypted.

- **R-vpn-server-03.a** WHEN a client sends a DNS query through the tunnel to port 53 of any address, including one where no resolver exists, THEN the server answers it.
- **R-vpn-server-03.b** WHEN the server resolves a name for tunnel traffic THEN it uses DNS-over-HTTPS resolvers only.

### R-vpn-server-04: Probe resistance

A party without the client key cannot tell the VPN port from an ordinary HTTPS site.

- **R-vpn-server-04.a** WHEN a TLS client without the key connects to port 443 with the cover site's name THEN it receives the cover site's valid certificate and an HTTP answer from that site.

### R-vpn-server-05: Panel not discoverable

The management panel and its subscription service cannot be found or reached from the internet.

- **R-vpn-server-05.a** WHEN the host's listening sockets are listed THEN only SSH and port 443 listen on a public address.
- **R-vpn-server-05.b** WHEN a host on the internet connects to the panel port, or to the usual panel and subscription ports, THEN the connection is not accepted.
- **R-vpn-server-05.c** WHEN the firewall rules are listed THEN incoming traffic is denied except SSH and 443/tcp.

### R-vpn-server-06: No client activity record

The server keeps no record of which client connected to which destination.

- **R-vpn-server-06.a** WHEN the running proxy configuration is inspected THEN the access log and the DNS log are off.

### R-vpn-server-07: Unattended security updates

- **R-vpn-server-07.a** WHEN the host's update settings are inspected THEN unattended upgrades are enabled.

### R-vpn-server-08: Re-run and reboot safety

- **R-vpn-server-08.a** WHEN the deploy script runs a second time on the same host THEN it exits with code 0 and the client link is unchanged.
- **R-vpn-server-08.b** WHEN the host is inspected THEN the panel service is running and enabled at boot.
- **R-vpn-server-08.c** WHEN the host reboots THEN every other criterion in this spec still holds.

### R-vpn-server-09: Secrets stay on the server

- **R-vpn-server-09.a** WHEN the deploy script runs THEN its output contains no panel credential, API token, private key or client link, and the files holding them are readable by root only.
