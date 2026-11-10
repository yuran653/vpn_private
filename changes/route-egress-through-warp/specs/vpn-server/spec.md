# Delta: vpn-server

## ADDED

### R-vpn-server-12: Client traffic leaves through Cloudflare WARP

Everything a client sends through the tunnel leaves the server through Cloudflare WARP, exits in Thailand, and never leaves from the server's own address.

- **R-vpn-server-12.a** WHEN a client requests Cloudflare's connection report through the tunnel THEN the report says the request came through WARP.
- **R-vpn-server-12.b** WHEN a client requests Cloudflare's connection report through the tunnel THEN the report places the client in Thailand.
- **R-vpn-server-12.c** WHEN the running proxy configuration is inspected THEN it has no outbound that sends traffic from the server's own address, so a request fails when WARP is unreachable.
- **R-vpn-server-12.d** WHEN a client opens YouTube Music through the tunnel THEN the page is not the "not available in your area" page.
- **R-vpn-server-12.e** WHEN the deploy script runs a second time on the same host THEN the WARP registration is kept, not made again.

## MODIFIED

### R-vpn-server-01: Tunnel

A client holding the issued link connects to the server and reaches the internet from an IPv4 address that is not the server's.

- **R-vpn-server-01.a** WHEN a client connects with the issued link and requests a web page THEN the page sees an IPv4 client address that is not the server's address.
- **R-vpn-server-01.b** WHEN a host on the internet opens a TCP connection to port 443 of the server THEN the connection is accepted.

### R-vpn-server-02: No IPv6 egress

No traffic leaves the server over IPv6, from the host or from a client.

- **R-vpn-server-02.a** WHEN the host is inspected THEN it has no global IPv6 address and cannot reach an IPv6 destination.
- **R-vpn-server-02.b** WHEN a client requests an IPv6 destination through the tunnel THEN the request fails.
- **R-vpn-server-02.c** WHEN a client requests a dual-stack site through the tunnel THEN the site sees an IPv4 address.
- **R-vpn-server-02.d** WHEN a client sends an AAAA query through the tunnel THEN the answer contains no address.

### R-vpn-server-09: Secrets stay on the server

- **R-vpn-server-09.a** WHEN the deploy script runs THEN its output contains no panel credential, API token, private key, WARP key or token, or client link, and the files holding them are readable by root only.
