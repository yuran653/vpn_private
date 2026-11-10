# Proposal: name-the-profile-in-the-link

## Why

The owner wants the VPN shown in Happ as `กรุงเทพฯ cloud.z.com` instead of `TH-Reality`. The subscription that was meant to carry names and a counter does not work with Happ (ADR-0011), so the name goes in the client link, and the subscription from the previous change is removed.

## What changes

- The client link's name, and the inbound's name, become `กรุงเทพฯ cloud.z.com`. The key is unchanged.
- The subscription service is off again, and the server has no outbound for it.
- The subscription address file is removed from the server.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-server | existing | `specs/vpn-server/spec.md` |

## Out of scope

- The group name in Happ and the main icon: set by the app, not by the server.
- A traffic counter in the app.

## Decisions checked

ADR-0002 (subscription off) and ADR-0008 (no extra outbound) hold again. ADR-0010 is superseded by ADR-0011.

## Open questions

- [TODO-CLARIFY: which icon does Happ show for the profile after the link is re-imported with the new name?]
