# ADR-0008: Client traffic leaves through Cloudflare WARP

- Status: accepted; the "Do not" line is narrowed by ADR-0010
- Date: 2026-11-10
- Supersedes: none
- Change: `changes/archive/2026-11-10-route-egress-through-warp/`

## Context

Google places the server's IPv4 address in Myanmar. Through the VPN, YouTube Music and YouTube Premium answered "not available in this country". Other databases disagree about the same address: ipinfo, ip-api and Cloudflare say Thailand, ifconfig.co says Japan. The provider re-registered the address block to Thailand in August 2026; only the provider can get the databases corrected. The owner decided on 2026-11-10 to send all client traffic out through Cloudflare WARP and gave permission to register the server as a WARP device, which accepts Cloudflare's terms of service.

## Decision

- `scripts/deploy-vpn.sh` registers the server once as a free WARP device and keeps the registration in `/root/vpn/warp.json` (root only).
- The Xray template's first outbound is a WireGuard outbound to WARP, tag `warp`: IPv4 only, MTU 1280, endpoint given as an address literal, run inside Xray in user space (`noKernelTun`).
- The template has no `freedom` outbound. When WARP is unreachable, client requests fail; they never leave from the server's own address.
- The server's DNS-over-HTTPS lookups for client traffic go through the same outbound.
- Clients still connect to the server's own address on port 443. The Reality cover-site forwarding and the host's own traffic do not use WARP.

Checked by `scripts/verify-vpn.sh` (R-vpn-server-12).

Measured on 2026-11-10 with a client on the VPS, 100 MB from a Singapore test server: 92 Mbit/s directly from the host, 87 Mbit/s through the tunnel and WARP. Google placed the exit in Thailand; YouTube Music and Premium were available.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Route only YouTube and Google names through WARP | The owner asked for all traffic. Two exits give one device two countries at once. |
| Keep `direct` and add a catch-all rule to `warp` | A rule edit or a missed case would send traffic from the mislocated address without notice. |
| Kernel WireGuard interface or `warp-cli` with policy routing | Adds an interface and routing tables to a host whose firewall and boot checks assume one interface; a mistake cuts SSH. |
| The panel's WARP button | The registration would live only in the panel database, outside the deploy script. |
| Wait for the provider to correct the address, or ask for a new one | Slow and outside the repo. Still worth doing; WARP can be removed afterwards by a new decision. |

## Consequences

- Sites see a Cloudflare address placed in Thailand, not the server's address.
- Cloudflare carries all client traffic and sees its destinations, as the provider's network did before.
- A WARP outage stops client traffic until WARP returns.
- Throughput is about 5% lower than direct at the uplink's limit. Some sites show more captchas to WARP addresses.
- Xray holds one UDP socket open for the tunnel on a random port. The firewall admits no new incoming traffic to it; R-vpn-server-05.a names it as the one exception.
- The registration API is unofficial. A change to it affects only a first deploy on a new host.

## Do not

Do not add a `freedom` outbound to the Xray template that can reach anything but the subscription service on loopback, or route client traffic out from the server's own address: Google places that address in Myanmar, and a second way out leaks when WARP is down. (ADR-0008, ADR-0010)
