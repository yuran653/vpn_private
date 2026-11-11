# Delta: vpn-server

## ADDED

### R-vpn-server-17: Server address hidden behind Cloudflare

Clients reach the server only through Cloudflare, and the server's own address answers nobody else on its web ports.

- **R-vpn-server-17.a** WHEN the client link is read THEN its address is `status.casedigestai.com`, not an IP address, and that name resolves from the internet only to addresses in Cloudflare's published IPv4 ranges.
- **R-vpn-server-17.b** WHEN a host outside Cloudflare's ranges connects to port 80 or 443 of the server's own address THEN it gets no answer.

## MODIFIED

### R-vpn-server-04: Probe resistance

A party without the client ID who reaches the server's names gets the website, and the tunnel is reachable only through the web server on one path.

- **R-vpn-server-04.a** WHEN a TLS client without the client ID connects to port 443 with the name `status.casedigestai.com` THEN it receives a publicly trusted certificate for that name and the landing page.
- **R-vpn-server-04.b** WHEN a TLS client without the client ID connects to port 443 with the name `casedigestai.com`, or with no name, THEN it receives the same site's certificate, not a connection reset.
- **R-vpn-server-04.c** WHEN the running configuration is inspected THEN the tunnel inbound listens on loopback only, and port 443 is held by the web server.

### R-vpn-server-05: Panel not discoverable

The management panel, its subscription service, the tunnel inbound and the site's content server cannot be found or reached from the internet.

- **R-vpn-server-05.a** WHEN the host's listening sockets are listed THEN only SSH, port 80 and port 443 listen on a public address, apart from the UDP socket the proxy holds open to send its WARP tunnel traffic.
- **R-vpn-server-05.b** WHEN a host on the internet connects to the panel port, to the usual panel and subscription ports, or to the ports the tunnel inbound, the web server and the site container use on loopback, THEN the connection is not accepted.
- **R-vpn-server-05.c** WHEN the firewall rules are listed THEN incoming traffic is denied except SSH from anywhere and 80/tcp and 443/tcp from Cloudflare's published IPv4 ranges only.

### R-vpn-server-11: TCP sending tuned for the long-distance path

The server sends tunnel traffic with a congestion control that keeps its rate when packets are lost, paces it, and allows buffers large enough for a fast long-distance path.

- **R-vpn-server-11.a** WHEN the kernel settings are inspected THEN the congestion control for new TCP connections is BBR.
- **R-vpn-server-11.b** WHEN tunnel traffic arrives on port 443 THEN the server's side of that connection uses BBR.
- **R-vpn-server-11.c** WHEN the queueing discipline of the interface that carries the default route is inspected THEN it is `fq`.
- **R-vpn-server-11.d** WHEN the kernel settings are inspected THEN a TCP connection's send buffer and receive buffer may each grow to at least 16 MB.
- **R-vpn-server-11.e** WHEN the kernel settings are inspected THEN a connection that was idle does not go back to slow start.
- **R-vpn-server-11.f** WHEN the kernel settings are inspected THEN TCP probes for a smaller packet size after it detects that large packets are lost on the path.

### R-vpn-server-14: Client link names the server

The client link names the profile `กรุงเทพฯ cloud.z.com` and carries the tunnel over HTTPS to `status.casedigestai.com`.

- **R-vpn-server-14.a** WHEN the client link is read THEN the name after `#` is `กรุงเทพฯ cloud.z.com`.
- **R-vpn-server-14.b** WHEN the deploy script runs on a host that already has the link THEN the client ID and the path in the link are unchanged.
- **R-vpn-server-14.c** WHEN the client link is read THEN its transport is XHTTP over TLS, and its `sni` and `host` are `status.casedigestai.com`.

### R-vpn-server-15: Cover site on the owner's domain

The server is the website of `casedigestai.com` and `status.casedigestai.com`, published through Cloudflare: both names answer with a valid certificate and the landing page.

- **R-vpn-server-15.a** WHEN `casedigestai.com` and `status.casedigestai.com` are resolved from the internet THEN neither resolves to the server's own address.
- **R-vpn-server-15.b** WHEN a browser opens `https://casedigestai.com` or `https://status.casedigestai.com` THEN it receives a publicly trusted certificate that names that host and a page containing "CaseDigest AI".
- **R-vpn-server-15.c** WHEN the landing page and everything it loads are inspected THEN no URL points to another host, and the page has no form and no script.
- **R-vpn-server-15.d** WHEN the landing page is read THEN it mentions neither a VPN nor Thailand.
- **R-vpn-server-15.e** WHEN a client requests `http://` on port 80 for either name THEN it is redirected to the same path on `https://` of that name.

## REMOVED

- R-vpn-server-01.b: port 443 no longer accepts every internet host; R-vpn-server-17 states who reaches it.
- R-vpn-server-10: every client now arrives from a shared Cloudflare address, so per-address limits on 443 would throttle many users together (ADR-0013).
