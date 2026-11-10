# Proposal: add-subscription-through-tunnel

## Why

The owner's Happ app shows the VPN as a bare profile in a local "Server-List" group, with the key's name `TH-Reality`, a globe icon and no traffic counter. Happ shows a group name, a profile name and a used-traffic counter only for a subscription. The owner wants the group `VPN ไทย`, the profile `กรุงเทพฯ cloud.z.com` and a counter of all traffic the client sends through the server, without a quota or an expiry date.

## What changes

- The server offers a subscription for the one client: the VLESS link, the group title `VPN ไทย`, the profile name `กรุงเทพฯ cloud.z.com` and the traffic used, with no quota and no expiry.
- The subscription is reachable only through the tunnel. A client that is connected requests it at a reserved test address (`192.0.2.1`, port 80). The server answers that request itself; the address is not routed anywhere. No new port is open to the internet.
- The inbound's name, and the name at the end of the client link, change from `th-reality` / `TH-Reality` to `กรุงเทพฯ cloud.z.com`. The key itself (UUID, Reality keys) is unchanged.
- The deploy script writes the subscription address to `/root/vpn/subscription-url.txt`, readable by root only.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-server | existing | `specs/vpn-server/spec.md` |

## Out of scope

- Setting the main icon (flag) in Happ. Happ documents no header for it (checked 2026-11-10); whether it follows the server address is tested on the owner's phone after the deploy and reported.
- A quota, an expiry date, more clients.
- Serving the subscription to a client that is not connected: it is not reachable from the internet by design.

## Decisions checked

- ADR-0002 "Do not open a firewall port for the 3x-ui panel or its subscription service, or bind either to a public address": followed. The service listens on 127.0.0.1 and the firewall is unchanged. ADR-0002's decision "the subscription service is off" is superseded (ADR-0010).
- ADR-0008 "Do not add a `freedom` outbound ... or route client traffic out from the server's own address": the design needs one `freedom` outbound that redirects to loopback only. ADR-0010 narrows the line; see design.

## Open questions

- [TODO-CLARIFY: does Happ fetch a subscription through its own tunnel while it is connected, and does it show a Thai flag as the main icon? Both are checked on the owner's phone after the deploy.]
- Found on the way: 3x-ui answered 403 to the reserved Host while `subDomain` was set, and Xray's freedom outbound blocked the loopback target. Both are in the design.
