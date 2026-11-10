# Delta: vpn-server

## MODIFIED

### R-vpn-server-12: Client traffic leaves through Cloudflare WARP

Everything a client sends through the tunnel leaves the server through Cloudflare WARP, enters Cloudflare at its Bangkok site, exits in Thailand, and never leaves from the server's own address.

- **R-vpn-server-12.a** WHEN a client requests Cloudflare's connection report through the tunnel THEN the report says the request came through WARP.
- **R-vpn-server-12.b** WHEN a client requests Cloudflare's connection report through the tunnel THEN the report places the client in Thailand.
- **R-vpn-server-12.c** WHEN the running proxy configuration is inspected THEN it has no outbound that sends traffic from the server's own address, so a request fails when WARP is unreachable.
- **R-vpn-server-12.d** WHEN a client opens YouTube Music through the tunnel THEN the page is not the "not available in your area" page.
- **R-vpn-server-12.e** WHEN the deploy script runs a second time on the same host THEN the WARP registration is kept, not made again.
- **R-vpn-server-12.f** WHEN a client requests Cloudflare's connection report through the tunnel THEN the report names Cloudflare's Bangkok site as the place the request reached Cloudflare.
