# Design: name-the-profile-in-the-link

## Approach

`scripts/deploy-vpn.sh` sets the inbound's remark to the name, resets the inbound's external proxy list (left over from the subscription) to empty, writes the name percent-encoded after `#` in the link, and removes `/root/vpn/subscription-url.txt`. The subscription service is disabled by the script's original block; the Xray template is rebuilt from the default each run, so the `sub` outbound and its rules disappear. `scripts/verify-vpn.sh` loses R-vpn-server-13 and gets R-vpn-server-14.a; R-vpn-server-12.c is back to "no freedom outbound".

The previous change (`changes/archive/2026-11-11-add-subscription-through-tunnel/`) stays as the record of what was tried.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| deploy | `scripts/deploy-vpn.sh` | Name, external proxy reset, link name, remove address file. |
| verify | `scripts/verify-vpn.sh` | R-vpn-server-14.a. |
| docs | `docs/decisions/ADR-0010-*.md`, `ADR-0011-*.md`, `INDEX.md`, `docs/vps-access.md` | Decision records, operator note. |

New modules or dependencies between modules: none.

## Contracts and data

The link's name changes; the client ID, keys and short ID do not (R-vpn-server-14.b), so the phone's profile keeps working.

## Alternatives rejected

See ADR-0011.

Decision record needed: ADR-0011.

## Verification

| Criterion | Test |
|---|---|
| R-vpn-server-14.a | `scripts/verify-vpn.sh` (R-vpn-server-14.a) |
| R-vpn-server-14.b | checked by hand: the client ID's hash before and after the run (as for R-vpn-server-08.a) |

## Risks

- The link file changes, so the phone must re-import it to show the new name. The old profile keeps working until then.
