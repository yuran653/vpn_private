# Proposal: reboot-at-0100-bangkok

## Why

The automatic reboot was set for "04:00 server time", and nothing set the host's time zone, so on a provider image that runs on UTC it would fall at 11:00 in Bangkok. The owner chose 01:00 Bangkok time on 2026-11-12 (ADR-0022).

## What changes

- A deployed host's time zone is Asia/Bangkok.
- A host that has installed an update needing a reboot restarts at 01:00 in that zone, not at 04:00.
- The same holds on the fallback server, which runs the same host steps.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-server | existing | `specs/vpn-server/spec.md` |

The fallback server's criterion is in the open change `changes/add-fallback-reality-server/` (R-vpn-fallback-07.a), updated there.

## Out of scope

- When updates are installed. Only the reboot time changes.
- Staggering the two servers' reboots.

## Decisions checked

- ADR-0006 (automatic reboot): superseded in the time and the zone by ADR-0022; the rest stands.
- ADR-0022 (the deploy sets the zone): this change implements it.

## Open questions

None.
