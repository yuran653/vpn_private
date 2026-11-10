# Design: apply-vps-baseline

## Approach

One bash script, `scripts/harden-vps.sh`, run on the VPS over `scp` and `sudo -n`. It applies four steps in order: hostname, sshd keepalive, fail2ban, ufw. Each step checks its own state, so a re-run changes nothing that is already in place.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| (none in the repo's architecture) | `scripts/harden-vps.sh` | New script, outside the module map |
| VPS (not in the repo) | `/etc/ssh/sshd_config.d/keepalive.conf`, `/etc/hosts`, `/etc/fail2ban/jail.local`, ufw rules | Written by the script |

New modules or dependencies between modules: none. `docs/architecture.md` is unchanged.

## Contracts and data

- CLI: `sudo -n bash harden-vps.sh <ADMIN_IP>`. The IP is an argument and is never stored in the repo.
- `/etc/fail2ban/jail.local` is overwritten on each run. This is the only existing file the script replaces. Its previous content is not backed up.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Keep the commands in shell history only | Not reproducible. Lost on a rebuild. |
| Hard-code the admin IP in the script | The IP changes. Passed as an argument instead. |
| Enable ufw before allowing SSH | Risks locking out the session. The allow rule comes first. |

Decision record needed: no. Limiting the SSH rule to one IP is an open question in the proposal.

## Implementation notes from the first runs

The script was run on the VPS twice before it passed. Both fixes are part of this change:

1. `sshd -T | awk ... exit` broke the pipe under `pipefail` (exit 141). Fixed by reading the full output.
2. `fail2ban-client status` ran before fail2ban created its socket. Fixed by waiting for `fail2ban-client ping`.

The keepalive step ran on the first attempt. Later runs rewrote the same content.

## Verification

Criteria have no automated tests yet. The repo has no test runner, and `AGENTS.md` lists no test command. Each criterion is checked by the script's final-state output.

| Criterion | Test |
|---|---|
| R-vps-baseline-01.a | None. Checked by `sshd -T` and the keepalive file. |
| R-vps-baseline-01.b | None. The validation branch has not been exercised. |
| R-vps-baseline-02.a | None. Not run. |
| R-vps-baseline-02.b | None. Checked by `fail2ban-client get sshd ignoreip` on the VPS. |
| R-vps-baseline-03.a | None. Checked by `ufw status verbose` on the VPS. |
| R-vps-baseline-04.a | None. The script has been run twice, with exit code 0 on the last run. |

## Risks

- ufw allows SSH from any address, which is weaker than an IP-limited rule. Contained by key-only SSH, and tracked as an open question in the proposal.
- The script overwrites `jail.local`. Re-run on a host with custom jail settings will discard them.
- A new SSH session must be tested before the old one closes. The script does not check this; the operator does.
