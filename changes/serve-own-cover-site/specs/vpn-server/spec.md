# Delta: vpn-server

## ADDED

### R-vpn-server-15: Cover site on the owner's domain

The server is the website of `casedigestai.com` and `status.casedigestai.com`: both names resolve to it, and it answers both with a valid certificate and the landing page.

- **R-vpn-server-15.a** WHEN `casedigestai.com` and `status.casedigestai.com` are resolved from the internet THEN each resolves to the server's address and to no other.
- **R-vpn-server-15.b** WHEN a browser opens `https://casedigestai.com` or `https://status.casedigestai.com` THEN it receives a publicly trusted certificate that names that host and a page containing "CaseDigest AI".
- **R-vpn-server-15.c** WHEN the landing page and everything it loads are inspected THEN no URL points to another host, and the page has no form and no script.
- **R-vpn-server-15.d** WHEN the landing page is read THEN it mentions neither a VPN nor Thailand.
- **R-vpn-server-15.e** WHEN a client requests `http://` on port 80 for either name THEN it is redirected to the same path on `https://` of that name.

### R-vpn-server-16: Certificate renews unattended

The site certificate is renewed without an operator.

- **R-vpn-server-16.a** WHEN the host's timers are inspected THEN the certificate renewal timer is enabled and active.
- **R-vpn-server-16.b** WHEN a renewal is rehearsed against the certificate authority's staging service THEN it succeeds.
- **R-vpn-server-16.c** WHEN the served certificate is inspected THEN it is valid for more than 20 days.

## MODIFIED

### R-vpn-server-04: Probe resistance

A party without the client key cannot tell the VPN port from the website the server's name and address belong to, and the server answers that party itself.

- **R-vpn-server-04.a** WHEN a TLS client without the key connects to port 443 with the name `status.casedigestai.com` THEN it receives a publicly trusted certificate for that name and the landing page.
- **R-vpn-server-04.b** WHEN a TLS client without the key connects to port 443 with the name `casedigestai.com`, or with no name, THEN it receives the same site's certificate, not a connection reset.
- **R-vpn-server-04.c** WHEN the running proxy configuration is inspected THEN connections without the key are handed to a web server on the same host, so answering a probe opens no connection to another host.

### R-vpn-server-05: Panel not discoverable

The management panel, its subscription service and the site's content server cannot be found or reached from the internet.

- **R-vpn-server-05.a** WHEN the host's listening sockets are listed THEN only SSH, port 80 and port 443 listen on a public address, apart from the UDP socket the proxy holds open to send its WARP tunnel traffic.
- **R-vpn-server-05.b** WHEN a host on the internet connects to the panel port, to the usual panel and subscription ports, or to the ports the web server and the site container use on loopback, THEN the connection is not accepted.
- **R-vpn-server-05.c** WHEN the firewall rules are listed THEN incoming traffic is denied except SSH, 80/tcp and 443/tcp.

### R-vpn-server-06: No client activity record

The server keeps no record of which client connected to which destination, and none of who visited the site.

- **R-vpn-server-06.a** WHEN the running proxy configuration is inspected THEN the access log and the DNS log are off.
- **R-vpn-server-06.b** WHEN the web server and the site container are inspected THEN neither writes an access log.

### R-vpn-server-14: Client link names the server

The client link names the profile `กรุงเทพฯ cloud.z.com` and the cover name `status.casedigestai.com`.

- **R-vpn-server-14.a** WHEN the client link is read THEN the name after `#` is `กรุงเทพฯ cloud.z.com`.
- **R-vpn-server-14.b** WHEN the deploy script runs on a host that already has the link THEN the key in the link (client ID, public key, short ID) is unchanged.
- **R-vpn-server-14.c** WHEN the client link is read THEN its `sni` is `status.casedigestai.com`.
