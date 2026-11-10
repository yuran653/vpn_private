# ADR-0011: No subscription; the profile name travels in the client link

- Status: accepted
- Date: 2026-11-11
- Supersedes: ADR-0010
- Change: `changes/archive/2026-11-11-name-the-profile-in-the-link/`

## Context

ADR-0010 served a subscription through the tunnel so that Happ would show a group name, a profile name and a traffic counter. It was deployed and passed every server-side check. On the owner's phone, adding it failed with "Request time out", and the panel showed no fetch from the phone while the phone was connected: Happ requests a subscription outside its own tunnel, where the reserved address `192.0.2.1` does not answer. Any other route needs a public address for the subscription, which ADR-0002 forbids.

The owner dropped the traffic counter and kept the names.

## Decision

- The subscription service stays off (ADR-0002 again), and the template has no outbound but WARP and the ones the default template has (ADR-0008 again).
- The inbound's name, and the name after `#` in the client link, is `กรุงเทพฯ cloud.z.com` (percent-encoded in the link). The key itself is unchanged.
- The group name in Happ ("Server-List") and the main icon are the app's own; nothing on the server sets them.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Subscription through the tunnel (ADR-0010) | Implemented and then replaced: Happ fetches it outside its tunnel and the request times out. |
| Subscription on a public port with TLS | Needs a domain or a short-lived IP certificate and a permanently open port; ADR-0002 forbids it, and the owner dropped the counter it was for. |

## Consequences

- The client app shows no traffic counter. The panel still counts the client's traffic; it is read over the SSH tunnel to the panel.
- The Thai profile name is only what the link says; Happ shows it after the link is imported again.

## Do not

- Do not serve a subscription to the client app through the tunnel at a reserved address, or otherwise expect Happ to fetch one through its own tunnel: the app fetches subscriptions outside it and the request times out. A subscription needs a public address, which ADR-0002 forbids. (ADR-0011)
