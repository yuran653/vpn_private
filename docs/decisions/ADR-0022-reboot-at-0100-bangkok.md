# ADR-0022: Reboot at 01:00 Bangkok time, with the time zone set by the deploy

- Status: accepted
- Date: 2026-11-12
- Supersedes: ADR-0006 in part (the reboot time, and the assumption that the host's time zone is Asia/Bangkok)
- Change: `changes/reboot-at-0100-bangkok/` (open)

## Context

ADR-0006 reboots the host after an update that needs it, "at 04:00 server time (Asia/Bangkok)". The reboot time that unattended-upgrades takes is local time, and no script set the host's time zone. On a provider image that runs on UTC, 04:00 is 11:00 in Bangkok, in the middle of the day. The documentation review of 2026-11-12 found the gap. The owner then chose the time: 01:00 Bangkok time.

## Decision

- The deploy sets the host's time zone to Asia/Bangkok, on the server behind Cloudflare and on the fallback server alike. Both run the same shared host steps.
- The automatic reboot after an update that needs one is at 01:00 in that zone.
- The verify scripts check the time and the zone together.
- Everything else in ADR-0006 stands.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Keep 04:00 and only set the time zone | The owner chose 01:00. |
| State the time in UTC and leave the zone alone | 18:00 UTC is 01:00 in Bangkok, but every log on the host would then be read in two zones. One zone on every server is simpler. |
| The fallback server in its own local zone | Its users and the operator think in Bangkok time, wherever it is hosted. |

## Consequences

- VPN connections drop for about a minute at 01:00 Bangkok time on days when an update needs a reboot. That is 21:00 in Moscow and 21:30 in Tehran the evening before, and 02:00 in China: users in Russia and Iran are cut in the evening.
- Both servers reboot at the same minute. The fallback depends on the first server anyway (ADR-0019), so it gives no cover during that minute.
- Log times on the hosts are Bangkok time from the first deploy on.
- Not yet run on a server (2026-11-12).

## Do not

- Do not leave the reboot time to the time zone of the provider's image: the time is local, so an image on UTC reboots the host at 08:00 in Bangkok. The deploy sets the zone. (ADR-0022)
