# Delta: vpn-server

## ADDED

### R-vpn-server-18: Connections rotate like a browser's

A client using the link spreads a long stretch of use over many short connections to Cloudflare, and the tunnel's requests and responses carry random padding.

- **R-vpn-server-18.a** WHEN the client link is read THEN its XHTTP settings stop a connection taking new sessions after at most 300 seconds and after at most 64 sessions, and pad every request with 100 to 1000 bytes.
- **R-vpn-server-18.b** WHEN a client using the link opens sessions over more than 300 seconds THEN it has used more than one connection to Cloudflare.
- **R-vpn-server-18.c** WHEN the running proxy configuration is inspected THEN the tunnel inbound pads its responses with 100 to 1000 bytes.

## MODIFIED

### R-vpn-server-04: Probe resistance

A party without the client ID who reaches the server's names gets the website, and the tunnel is reachable only through the web server on one path.

- **R-vpn-server-04.a** WHEN a TLS client without the client ID connects to port 443 with the name `files.casedigestai.com` THEN it receives a publicly trusted certificate for that name and the landing page.
- **R-vpn-server-04.b** WHEN a TLS client without the client ID connects to port 443 with the name `casedigestai.com` or `status.casedigestai.com`, or with no name, THEN it receives the same site's certificate, not a connection reset.
- **R-vpn-server-04.c** WHEN the running configuration is inspected THEN the tunnel inbound listens on loopback only, and port 443 is held by the web server.

### R-vpn-server-14: Client link names the server

The client link names the profile `กรุงเทพฯ cloud.z.com` and carries the tunnel over HTTPS to `files.casedigestai.com`.

- **R-vpn-server-14.a** WHEN the client link is read THEN the name after `#` is `กรุงเทพฯ cloud.z.com`.
- **R-vpn-server-14.b** WHEN the deploy script runs on a host that already has the link THEN the client ID and the path in the link are unchanged.
- **R-vpn-server-14.c** WHEN the client link is read THEN its transport is XHTTP over TLS, and its `sni` and `host` are `files.casedigestai.com`.

### R-vpn-server-15: Cover site on the owner's domain

The server is the website of `casedigestai.com`, `files.casedigestai.com` and `status.casedigestai.com`, published through Cloudflare: every name answers with a valid certificate and the landing page.

- **R-vpn-server-15.a** WHEN `casedigestai.com`, `files.casedigestai.com` and `status.casedigestai.com` are resolved from the internet THEN none resolves to the server's own address.
- **R-vpn-server-15.b** WHEN a browser opens `https://` on any of the three names THEN it receives a publicly trusted certificate that names that host and a page containing "CaseDigest AI".
- **R-vpn-server-15.c** WHEN the landing page and everything it loads are inspected THEN no URL points to another host, and the page has no form and no script.
- **R-vpn-server-15.d** WHEN the landing page is read THEN it mentions neither a VPN nor Thailand.
- **R-vpn-server-15.e** WHEN a client requests `http://` on port 80 for any of the three names THEN it is redirected to the same path on `https://` of that name.
- **R-vpn-server-15.f** WHEN the landing page is read THEN it describes case-file upload and sync at `files.casedigestai.com`.

### R-vpn-server-17: Server address hidden behind Cloudflare

Clients reach the server only through Cloudflare, and the server's own address answers nobody else on its web ports.

- **R-vpn-server-17.a** WHEN the client link is read THEN its address is `files.casedigestai.com`, not an IP address, and that name resolves from the internet only to addresses in Cloudflare's published IPv4 ranges.
- **R-vpn-server-17.b** WHEN a host outside Cloudflare's ranges connects to port 80 or 443 of the server's own address THEN it gets no answer.
