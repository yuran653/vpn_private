# Design: reboot-at-0100-bangkok

## Approach

The shared host steps set the time zone before they write the reboot setting, and the reboot time constant changes from 04:00 to 01:00. Both verify scripts check the time and the zone in one criterion.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| scripts | `scripts/lib/host-common.sh` | `HOST_TIMEZONE=Asia/Bangkok`, set with `timedatectl` when it differs; `AUTO_REBOOT_TIME=01:00`. |
| scripts | `scripts/verify-vpn.sh`, `scripts/verify-fallback.sh` | R-vpn-server-07.c and R-vpn-fallback-07.a check 01:00 and the zone. |
| docs | `docs/vps-access.md`, `docs/how-it-works.html`, ADR-0006, ADR-0022 | The new time. |

New modules or dependencies between modules: none.

## Contracts and data

None. A re-run on a host deployed before this change sets the zone and rewrites the reboot setting.

## Alternatives rejected

See ADR-0022.

Decision record needed: ADR-0022 (written).

## Verification

| Criterion | Test |
|---|---|
| R-vpn-server-07.a, 07.b | `scripts/verify-vpn.sh`, unchanged |
| R-vpn-server-07.c | `scripts/verify-vpn.sh` (R-vpn-server-07.c) |

## Risks

- **Log times on a host change zone at the first deploy.** Accepted; no host exists yet.
- **No server to test on.** Written and syntax-checked only.
