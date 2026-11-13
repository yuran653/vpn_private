# Delta: vpn-server

## ADDED

### R-vpn-server-28: A reserve path through Gcore

The server is reachable through a second CDN, Gcore, on a reserve name of the same domain, for networks that throttle Cloudflare (ADR-0025). The exit, the client ID and the tunnel path are the same as on the main path.

- **R-vpn-server-28.a** WHEN a client connects with the reserve link and requests Cloudflare's connection report THEN the report says the request came through WARP and places the client in Thailand.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-28.a), once the deploy writes the reserve link
- **R-vpn-server-28.b** WHEN a TLS client without the client ID connects to the reserve name through Gcore THEN it receives a publicly trusted certificate for that name and the landing page.
  Test: `scripts/verify-external.sh` (R-vpn-server-28.b)
- **R-vpn-server-28.c** WHEN the firewall rules are listed THEN the web ports are admitted from Cloudflare's and Gcore's published ranges only, and a probe sent straight to the server's address gets no answer.
  Test: `scripts/verify-vpn.sh` (R-vpn-server-28.c), `scripts/verify-external.sh` (R-vpn-server-17.b, unchanged)
- **R-vpn-server-28.d** WHEN a client on the reserve path downloads 30 MB, uploads 30 MB and then holds the connection idle for 60 seconds THEN both transfers complete and the connection still passes traffic afterwards.
  Test: none automated; run by hand through the reserve path, because Gcore's standard origin timeouts (5 s to connect, 30 s between reads) can cut an idle XHTTP connection
