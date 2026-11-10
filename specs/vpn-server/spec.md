# Capability: vpn-server

> Current behavior. Changed only by archiving a change. Do not edit directly.

## Purpose

A VLESS + XTLS-Reality VPN server on the VPS for the owner's devices, deployed by `scripts/deploy-vpn.sh`, that prevents the identity disclosures a server can enforce: IPv6 egress, DNS leaks, tunnel fingerprinting and panel discovery.

The verify scripts test the deployed server over the live network. `verified` means the named check fails when the criterion is violated on the VPS.

## Requirements

### R-vpn-server-01: Tunnel

A client holding the issued link connects to the server and reaches the internet from an IPv4 address that is not the server's.

- **R-vpn-server-01.a** [verified] WHEN a client connects with the issued link and requests a web page THEN the page sees an IPv4 client address that is not the server's address.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-01.a)
- **R-vpn-server-01.b** [verified] WHEN a host on the internet opens a TCP connection to port 443 of the server THEN the connection is accepted.
  Test: `scripts/verify-external.sh` (R-vpn-server-01.b)

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

A party without the client key cannot tell the VPN port from an ordinary HTTPS site.

- **R-vpn-server-04.a** [verified] WHEN a TLS client without the key connects to port 443 with the cover site's name THEN it receives the cover site's valid certificate and an HTTP answer from that site.
  Test: `scripts/verify-external.sh` (R-vpn-server-04.a), `scripts/verify-vpn.sh` (R-vpn-server-04.a)

### R-vpn-server-05: Panel not discoverable

The management panel and its subscription service cannot be found or reached from the internet.

- **R-vpn-server-05.a** [verified] WHEN the host's listening sockets are listed THEN only SSH and port 443 listen on a public address, apart from the UDP socket the proxy holds open to send its WARP tunnel traffic.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-05.a)
- **R-vpn-server-05.b** [verified] WHEN a host on the internet connects to the panel port, or to the usual panel and subscription ports, THEN the connection is not accepted.
  Test: `scripts/verify-external.sh` (R-vpn-server-05.b)
- **R-vpn-server-05.c** [verified] WHEN the firewall rules are listed THEN incoming traffic is denied except SSH and 443/tcp.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-05.c)

### R-vpn-server-06: No client activity record

The server keeps no record of which client connected to which destination.

- **R-vpn-server-06.a** [verified] WHEN the running proxy configuration is inspected THEN the access log and the DNS log are off.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-06.a)

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

### R-vpn-server-10: VPN port connection limits per address

One address cannot occupy the VPN port with connections.

- **R-vpn-server-10.a** [verified] WHEN the loaded firewall rules are listed THEN new connections to port 443 from one address are dropped beyond 1000 concurrent connections or 100 new connections per second with a burst of 300.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-10.a)

### R-vpn-server-11: TCP sending tuned for the long-distance path

The server sends tunnel traffic with a congestion control that keeps its rate when packets are lost, paces it, and allows buffers large enough for a fast long-distance path.

- **R-vpn-server-11.a** [verified] WHEN the kernel settings are inspected THEN the congestion control for new TCP connections is BBR.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-11.a)
- **R-vpn-server-11.b** [verified] WHEN a client connects to port 443 THEN the server's side of that connection uses BBR.
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

The client link names the profile `กรุงเทพฯ cloud.z.com`.

- **R-vpn-server-14.a** [verified] WHEN the client link is read THEN the name after `#` is `กรุงเทพฯ cloud.z.com`.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-14.a)
- **R-vpn-server-14.b** [untested: no automated test; the hash of the client ID in the link was compared before and after the run] WHEN the deploy script runs on a host that already has the link THEN the key in the link (client ID, public key, short ID) is unchanged.
  Test: none
