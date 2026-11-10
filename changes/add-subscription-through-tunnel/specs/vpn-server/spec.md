# Delta: vpn-server

## ADDED

### R-vpn-server-13: Subscription through the tunnel

The client app can import the server as a named subscription that carries the client link and the traffic used, and only a connected client can fetch it.

- **R-vpn-server-13.a** WHEN a client requests the subscription address through the tunnel THEN it receives a client link for the server's own address on the VPN port.
- **R-vpn-server-13.b** WHEN a client requests the subscription address through the tunnel THEN the response names the group `VPN ไทย`.
- **R-vpn-server-13.c** WHEN a client requests the subscription address through the tunnel THEN the traffic information in the response has no quota and no expiry date.
- **R-vpn-server-13.d** WHEN a host on the internet requests the subscription address on the server's public address, on the subscription service's port THEN the connection is not accepted.
- **R-vpn-server-13.e** WHEN a client requests the subscription address through the tunnel THEN the profile in the link is named `กรุงเทพฯ cloud.z.com`.
- **R-vpn-server-13.f** WHEN a client requests any other reserved or private address through the tunnel THEN the request fails.

## MODIFIED

### R-vpn-server-05: Panel not discoverable

The management panel cannot be found or reached from the internet, and its subscription service is reachable only through the tunnel.

- **R-vpn-server-05.a** WHEN the host's listening sockets are listed THEN only SSH and port 443 listen on a public address, apart from the UDP socket the proxy holds open to send its WARP tunnel traffic.
- **R-vpn-server-05.b** WHEN a host on the internet connects to the panel port, or to the usual panel and subscription ports, THEN the connection is not accepted.
- **R-vpn-server-05.c** WHEN the firewall rules are listed THEN incoming traffic is denied except SSH and 443/tcp.

### R-vpn-server-12: Client traffic leaves through Cloudflare WARP

Everything a client sends through the tunnel leaves the server through Cloudflare WARP, enters Cloudflare at its Bangkok site, exits in Thailand, and never leaves from the server's own address. The one exception is the client's request for its subscription, which the server answers itself.

- **R-vpn-server-12.a** WHEN a client requests Cloudflare's connection report through the tunnel THEN the report says the request came through WARP.
- **R-vpn-server-12.b** WHEN a client requests Cloudflare's connection report through the tunnel THEN the report places the client in Thailand.
- **R-vpn-server-12.c** WHEN the running proxy configuration is inspected THEN WARP is its default outbound, and no outbound can send traffic anywhere but the server's own loopback address, so a request fails when WARP is unreachable.
- **R-vpn-server-12.d** WHEN a client opens YouTube Music through the tunnel THEN the page is not the "not available in your area" page.
- **R-vpn-server-12.e** WHEN the deploy script runs a second time on the same host THEN the WARP registration is kept, not made again.
- **R-vpn-server-12.f** WHEN a client requests Cloudflare's connection report through the tunnel THEN the report names Cloudflare's Bangkok site as the place the request reached Cloudflare.
