# Delta: vpn-server

## ADDED

### R-vpn-server-20: Blocked names are not used

Names that a censor is known to block are recorded in `docs/blocked-names.txt`, and neither the site nor the client link uses a listed name or a name under a listed domain.

- **R-vpn-server-20.a** WHEN the names the site and the client link use are compared with the blocked-names list THEN none is on it, exactly or as a name under a listed domain.

### R-vpn-server-21: A name is tried from a mobile network before it carries the tunnel

A name check, run on a phone on mobile data, shows whether a name can carry the tunnel from the network it runs on, and a name goes into the client link only after it passes.

- **R-vpn-server-21.a** WHEN the name check runs against a name that answers GET over HTTP/1.1 and HTTP/2 and takes uploads of 500, 5000 and 30000 bytes THEN it exits 0.
- **R-vpn-server-21.b** WHEN the name check runs against a name that gets no answer THEN it exits 1 and names each failing check.
- **R-vpn-server-21.c** WHEN the control name cannot take a 30 KB upload from the network the check runs on THEN the check exits 2 and judges nothing.
- **R-vpn-server-21.d** WHEN a name is to be put in the client link THEN the name check has passed for it from a mobile network in each country the owner serves.
