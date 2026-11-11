# Capability: vpn-server

> Current behavior. Changed only by archiving a change. Do not edit directly.

## Purpose

A VLESS VPN server on the VPS for the owner's devices, reached only through Cloudflare (VLESS over XHTTP inside HTTPS, ADR-0013) and deployed by `scripts/deploy-vpn.sh` together with the website that covers it, that prevents the identity disclosures a server can enforce: IPv6 egress, DNS leaks, tunnel fingerprinting and panel discovery.

The verify scripts test the deployed server over the live network. `verified` means the named check fails when the criterion is violated on the VPS.

## Requirements

### R-vpn-server-01: Tunnel

A client holding the issued link connects to the server and reaches the internet from an IPv4 address that is not the server's.

- **R-vpn-server-01.a** [verified] WHEN a client connects with the issued link and requests a web page THEN the page sees an IPv4 client address that is not the server's address.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-01.a)

### R-vpn-server-02: No IPv6 egress

No traffic leaves the server over IPv6, from the host or from a client.

- **R-vpn-server-02.a** [verified] WHEN the host is inspected THEN it has no global IPv6 address and cannot reach an IPv6 destination.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-02.a)
- **R-vpn-server-02.b** [verified] WHEN a client requests an IPv6 destination through the tunnel THEN the request fails.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-02.b)
- **R-vpn-server-02.c** [verified] WHEN a client requests a dual-stack site through the tunnel THEN the site sees an IPv4 address.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-02.c)
- **R-vpn-server-02.d** [verified] WHEN a client sends an AAAA query through the tunnel THEN the answer contains no address.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-02.d)

### R-vpn-server-03: DNS stays inside the server

DNS queries arriving through the tunnel are answered by the server, and the server's lookups for tunnel traffic leave it encrypted.

- **R-vpn-server-03.a** [verified] WHEN a client sends a DNS query through the tunnel to port 53 of any address, including one where no resolver exists, THEN the server answers it.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-03.a)
- **R-vpn-server-03.b** [verified] WHEN the server resolves a name for tunnel traffic THEN it uses DNS-over-HTTPS resolvers only.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-03.b)

### R-vpn-server-04: Probe resistance

A party without the client ID who reaches the server's names gets the website, and the tunnel is reachable only through the web server on one path.

- **R-vpn-server-04.a** [verified] WHEN a TLS client without the client ID connects to port 443 with the name `status.casedigestai.com` THEN it receives a publicly trusted certificate for that name and the landing page.
  Test: `scripts/verify-external.sh` (R-vpn-server-04.a), `scripts/verify-vpn.sh` (R-vpn-server-04.a)
- **R-vpn-server-04.b** [verified] WHEN a TLS client without the client ID connects to port 443 with the name `casedigestai.com`, or with no name, THEN it receives the same site's certificate, not a connection reset.
  Test: `scripts/verify-external.sh` (R-vpn-server-04.b), `scripts/verify-vpn.sh` (R-vpn-server-04.b)
- **R-vpn-server-04.c** [verified] WHEN the running configuration is inspected THEN the tunnel inbound listens on loopback only, and port 443 is held by the web server.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-04.c)

### R-vpn-server-05: Panel not discoverable

The management panel, its subscription service, the tunnel inbound and the site's content server cannot be found or reached from the internet.

- **R-vpn-server-05.a** [verified] WHEN the host's listening sockets are listed THEN only SSH, port 80 and port 443 listen on a public address, apart from the UDP socket the proxy holds open to send its WARP tunnel traffic.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-05.a)
- **R-vpn-server-05.b** [verified] WHEN a host on the internet connects to the panel port, to the usual panel and subscription ports, or to the ports the tunnel inbound, the web server and the site container use on loopback, THEN the connection is not accepted.
  Test: `scripts/verify-external.sh` (R-vpn-server-05.b)
- **R-vpn-server-05.c** [verified] WHEN the firewall rules are listed THEN incoming traffic is denied except SSH from anywhere and 80/tcp and 443/tcp from Cloudflare's published IPv4 ranges only.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-05.c)

### R-vpn-server-06: No client activity record

The server keeps no record of which client connected to which destination, and none of who visited the site.

- **R-vpn-server-06.a** [verified] WHEN the running proxy configuration is inspected THEN the access log and the DNS log are off.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-06.a)
- **R-vpn-server-06.b** [verified] WHEN the web server and the site container are inspected THEN neither writes an access log.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-06.b)

### R-vpn-server-07: Unattended security updates

Security updates install and take effect without an operator.

- **R-vpn-server-07.a** [verified] WHEN the host's update settings are inspected THEN unattended upgrades are enabled.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-07.a)
- **R-vpn-server-07.b** [verified] WHEN the host is inspected THEN a security-update run has completed within the last 48 hours.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-07.b)
- **R-vpn-server-07.c** [verified] WHEN the host's update settings are inspected THEN an automatic reboot after an update that needs one is on, set for 04:00 server time.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-07.c)

### R-vpn-server-08: Re-run and reboot safety

- **R-vpn-server-08.a** [untested: no automated test; the script was run four times on the VPS with exit code 0 and the link checksum compared] WHEN the deploy script runs a second time on the same host THEN it exits with code 0 and the client link is unchanged.
  Test: none
- **R-vpn-server-08.b** [verified] WHEN the host is inspected THEN the panel service is running and enabled at boot.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-08.b)
- **R-vpn-server-08.c** [untested: only the boot parameter is tested, by `scripts/verify-vpn.sh` (R-vpn-server-08.c); the rest was checked by rebooting three times and running both verify scripts] WHEN the host reboots THEN every other criterion in this spec still holds, and IPv6 is off from the start of the boot.
  Test: none
- **R-vpn-server-08.d** [verified] WHEN the host has booted THEN its network interfaces are fully configured, so the boot is not held up waiting for the network.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-08.d)

### R-vpn-server-09: Secrets stay on the server

- **R-vpn-server-09.a** [untested: no automated test; the run output was searched for the WARP key, token and device id and the file modes were listed] WHEN the deploy script runs THEN its output contains no panel credential, API token, private key, WARP key or token, or client link, and the files holding them are readable by root only.
  Test: none

### R-vpn-server-11: TCP sending tuned for the long-distance path

The server sends tunnel traffic with a congestion control that keeps its rate when packets are lost, paces it, and allows buffers large enough for a fast long-distance path.

- **R-vpn-server-11.a** [verified] WHEN the kernel settings are inspected THEN the congestion control for new TCP connections is BBR.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-11.a)
- **R-vpn-server-11.b** [verified] WHEN tunnel traffic arrives on port 443 THEN the server's side of that connection uses BBR.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-11.b)
- **R-vpn-server-11.c** [verified] WHEN the queueing discipline of the interface that carries the default route is inspected THEN it is `fq`.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-11.c)
- **R-vpn-server-11.d** [verified] WHEN the kernel settings are inspected THEN a TCP connection's send buffer and receive buffer may each grow to at least 16 MB.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-11.d)
- **R-vpn-server-11.e** [verified] WHEN the kernel settings are inspected THEN a connection that was idle does not go back to slow start.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-11.e)
- **R-vpn-server-11.f** [verified] WHEN the kernel settings are inspected THEN TCP probes for a smaller packet size after it detects that large packets are lost on the path.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-11.f)

### R-vpn-server-12: Client traffic leaves through Cloudflare WARP

Everything a client sends through the tunnel leaves the server through Cloudflare WARP, enters Cloudflare at its Bangkok site, exits in Thailand, and never leaves from the server's own address.

- **R-vpn-server-12.a** [verified] WHEN a client requests Cloudflare's connection report through the tunnel THEN the report says the request came through WARP.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-12.a)
- **R-vpn-server-12.b** [verified] WHEN a client requests Cloudflare's connection report through the tunnel THEN the report places the client in Thailand.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-12.b)
- **R-vpn-server-12.c** [verified] WHEN the running proxy configuration is inspected THEN it has no outbound that sends traffic from the server's own address, so a request fails when WARP is unreachable.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-12.c)
- **R-vpn-server-12.d** [verified] WHEN a client opens YouTube Music through the tunnel THEN the page is not the "not available in your area" page.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-12.d)
- **R-vpn-server-12.e** [untested: no automated test; the script was run twice on the VPS and the checksum of the registration file compared] WHEN the deploy script runs a second time on the same host THEN the WARP registration is kept, not made again.
  Test: none
- **R-vpn-server-12.f** [verified] WHEN a client requests Cloudflare's connection report through the tunnel THEN the report names Cloudflare's Bangkok site as the place the request reached Cloudflare.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-12.f)

### R-vpn-server-14: Client link names the server

The client link names the profile `กรุงเทพฯ cloud.z.com` and carries the tunnel over HTTPS to `status.casedigestai.com`.

- **R-vpn-server-14.a** [verified] WHEN the client link is read THEN the name after `#` is `กรุงเทพฯ cloud.z.com`.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-14.a)
- **R-vpn-server-14.b** [untested: no automated test; on 2026-11-12 the deploy script was re-run after the cut-over and the link's checksum compared, and the client ID was compared with the removed Reality inbound's] WHEN the deploy script runs on a host that already has the link THEN the client ID and the path in the link are unchanged.
  Test: none
- **R-vpn-server-14.c** [verified] WHEN the client link is read THEN its transport is XHTTP over TLS, and its `sni` and `host` are `status.casedigestai.com`.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-14.c)

### R-vpn-server-15: Cover site on the owner's domain

The server is the website of `casedigestai.com` and `status.casedigestai.com`, published through Cloudflare: both names answer with a valid certificate and the landing page.

- **R-vpn-server-15.a** [verified] WHEN `casedigestai.com` and `status.casedigestai.com` are resolved from the internet THEN neither resolves to the server's own address.
  Test: `scripts/verify-external.sh` (R-vpn-server-15.a)
- **R-vpn-server-15.b** [verified] WHEN a browser opens `https://casedigestai.com` or `https://status.casedigestai.com` THEN it receives a publicly trusted certificate that names that host and a page containing "CaseDigest AI".
  Test: `scripts/verify-external.sh` (R-vpn-server-15.b)
- **R-vpn-server-15.c** [drift: Cloudflare's "JavaScript Detections" injects a script that loads /cdn-cgi/challenge-platform/ into the page; turning it off in the Cloudflare dashboard is pending with the owner] WHEN the landing page and everything it loads are inspected THEN no URL points to another host, and the page has no form and no script.
  Test: `scripts/verify-external.sh` (R-vpn-server-15.c)
- **R-vpn-server-15.d** [verified] WHEN the landing page is read THEN it mentions neither a VPN nor Thailand.
  Test: `scripts/verify-external.sh` (R-vpn-server-15.d)
- **R-vpn-server-15.e** [verified] WHEN a client requests `http://` on port 80 for either name THEN it is redirected to the same path on `https://` of that name.
  Test: `scripts/verify-external.sh` (R-vpn-server-15.e)

### R-vpn-server-16: Certificate renews unattended

The site certificate is renewed without an operator.

- **R-vpn-server-16.a** [verified] WHEN the host's timers are inspected THEN the certificate renewal timer is enabled and active.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-16.a)
- **R-vpn-server-16.b** [verified] WHEN a renewal is rehearsed against the certificate authority's staging service THEN it succeeds.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-16.b)
- **R-vpn-server-16.c** [verified] WHEN the served certificate is inspected THEN it is valid for more than 20 days.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-16.c)

### R-vpn-server-17: Server address hidden behind Cloudflare

Clients reach the server only through Cloudflare, and the server's own address answers nobody else on its web ports.

- **R-vpn-server-17.a** [verified] WHEN the client link is read THEN its address is `status.casedigestai.com`, not an IP address, and that name resolves from the internet only to addresses in Cloudflare's published IPv4 ranges.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-17.a), `scripts/verify-external.sh` (R-vpn-server-17.a)
- **R-vpn-server-17.b** [verified] WHEN a host outside Cloudflare's ranges connects to port 80 or 443 of the server's own address THEN it gets no answer.
  Test: `scripts/verify-external.sh` (R-vpn-server-17.b)
