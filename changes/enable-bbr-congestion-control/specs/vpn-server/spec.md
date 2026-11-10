# Delta: vpn-server

## ADDED

### R-vpn-server-11: TCP sending tuned for the long-distance path

The server sends tunnel traffic with a congestion control that keeps its rate when packets are lost, paces it, and allows buffers large enough for a fast long-distance path.

- **R-vpn-server-11.a** WHEN the kernel settings are inspected THEN the congestion control for new TCP connections is BBR.
- **R-vpn-server-11.b** WHEN a client connects to port 443 THEN the server's side of that connection uses BBR.
- **R-vpn-server-11.c** WHEN the queueing discipline of the interface that carries the default route is inspected THEN it is `fq`.
- **R-vpn-server-11.d** WHEN the kernel settings are inspected THEN a TCP connection's send buffer and receive buffer may each grow to at least 16 MB.
- **R-vpn-server-11.e** WHEN the kernel settings are inspected THEN a connection that was idle does not go back to slow start.
- **R-vpn-server-11.f** WHEN the kernel settings are inspected THEN TCP probes for a smaller packet size after it detects that large packets are lost on the path.
