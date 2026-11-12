# Delta: vpn-server

## ADDED

### R-vpn-server-22: A client of its own for the fallback server

The first server issues a second client ID, used only by the fallback server to forward its users' traffic (ADR-0019).

- **R-vpn-server-22.a** WHEN the tunnel inbound's clients are listed THEN there are two: the owner's and one named `relay`, with different IDs.
- **R-vpn-server-22.b** WHEN a client connects with the relay link and requests Cloudflare's connection report THEN the report says the request came through WARP and places the client in Thailand.
- **R-vpn-server-22.c** WHEN the deploy script runs on a host that already has both clients THEN the owner's link and the relay link are unchanged.
- **R-vpn-server-22.d** WHEN the deploy script runs THEN the relay link is written to a file readable by root only and does not appear in the output.
