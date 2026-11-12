# ADR-0020: The tunnel answers on Cloudflare's other HTTPS ports too

- Status: accepted
- Date: 2026-11-12
- Supersedes: none
- Change: `changes/protect-the-name/` (open)

## Context

Clients reach the server only through Cloudflare, on port 443 of one name (ADR-0013). A network that interferes with 443 to that name, or with the Cloudflare address a user is given on 443, cuts the user off; there is one transport and one port (flag 6). Iranian networks in particular throttle some Cloudflare addresses and ports and leave others alone.

Cloudflare proxies HTTPS on five more ports: 2053, 2083, 2087, 2096 and 8443. It connects to the server on the port the visitor used. On the free plan these ports are proxied without caching, which the tunnel does not use anyway.

The owner asked for these ports on 2026-11-12.

## Decision

- nginx on the server answers on 2053, 2083, 2087, 2096 and 8443 exactly as on 443: the same certificate, the site, and the tunnel path.
- The firewall admits those ports from Cloudflare's published ranges only, like 80 and 443.
- The main client link stays on 443. One link per other port is written to `/root/vpn/vless-links-alt.txt`, root-only; each is the main link with the port and the profile name changed. A user gets one only when 443 fails on their network.
- nginx's loopback staging port moves from 8443 to 18443.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Stay on 443 only | One port is one more thing a network can cut. |
| Move the main link to another port | Most HTTPS on the internet is on 443; the other ports are rarer and stand out more. They are the fallback, not the default. |
| A separate nginx server block or certificate per port | The same site on every port is what a real site behind Cloudflare looks like, and one block cannot drift from another. |
| Ports Cloudflare proxies for plain HTTP (8080, 8880 and others) | The tunnel would travel unencrypted between the user and Cloudflare. |

## Consequences

- A user on a network that cuts 443 to the name can try five more ports without a new domain. It does not help when the name itself is cut, as on Beeline on 2026-11-12: the cut followed the name, not the port.
- Seen from outside Cloudflare nothing changes: the server's own address still answers nobody on these ports.
- 2053 and 2096 are the 3x-ui panel's usual ports. The panel stays on loopback on its own random port; if that port is one of the five, the deploy script stops and says so.
- Six ports on one name is itself unusual for a small site. Only the port in use is visible to a user's network.
- Not yet run on a server (2026-11-12).

## Do not

- Do not admit 2053, 2083, 2087, 2096 or 8443 from outside Cloudflare's published ranges, and do not put the panel or any other service on them: nginx holds them for the site and the tunnel. (ADR-0020)
