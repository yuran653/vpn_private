# Delta: vpn-server

## ADDED

### R-vpn-server-19: The tunnel works over HTTP/1.1

The client link offers HTTP/1.1 only, and the tunnel carries traffic whether the client speaks HTTP/1.1 or HTTP/2.

- **R-vpn-server-19.a** WHEN the client link is read THEN its ALPN is `http/1.1` alone.
- **R-vpn-server-19.b** WHEN a client that offers only HTTP/1.1 opens a connection through the tunnel THEN traffic passes and the exit is Cloudflare WARP.
- **R-vpn-server-19.c** WHEN a client that offers only HTTP/2 opens a connection through the tunnel THEN traffic passes.
