# Proposal: enable-bbr-congestion-control

## Why

The owner wants the VPN to be quicker without moving the server. The path from the Bangkok VPS to the owner's devices is long and loses packets. The server sends with the kernel defaults: CUBIC congestion control, which halves its sending rate at each lost packet, the `fq_codel` queueing discipline, a 4 MB send buffer limit, and a restart from a low rate after every idle period. On such a path these keep download speed far below what the link carries.

## What changes

- New TCP connections from the server, including every connection that carries tunnel traffic to a client, use BBR congestion control.
- The interface that carries the default route paces outgoing packets with the `fq` queueing discipline.
- A TCP connection's send and receive buffers may each grow to 16 MB.
- A connection that was idle resumes at its previous sending rate.
- TCP probes for a smaller packet size when it detects that large packets are lost on the path.
- These settings survive a reboot.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-server | existing | `specs/vpn-server/spec.md` |

## Out of scope

- Client settings: blocking QUIC on the client, client version, Mux. They are not enforced by the server.
- A numeric speed target. Speed depends on the client's network, which no test on the server controls.
- A different provider or route in the same location.
- Changes to the Xray transport, the Reality settings or the DNS resolvers.

## Decisions checked

None of the "Do not" lines apply. ADR-0004 (IPv6 off in the kernel) is not touched: the new settings are IPv4 TCP and queueing settings in their own file.

## Open questions

None.
