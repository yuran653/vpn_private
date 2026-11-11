# ADR-0005: Per-address connection limits in ufw's before-input chain

- Status: accepted; the limits on port 443 superseded by ADR-0013
- Date: 2026-11-10
- Supersedes: none
- Change: `changes/archive/2026-11-10-harden-against-attacks/`

## Context

Nothing limited how many connections one address could open to SSH or to the VPN port, so a single host could exhaust the 2-vCPU server. The operator and the agent reach the server by running several `scp` and `ssh` commands in a row from one address, and every stream a VPN client opens is its own TCP connection to port 443.

## Decision

- Limits are iptables `connlimit` (concurrent) and `hashlimit` (rate of new connections) rules on SYN packets, per source address.
- They live in `/etc/ufw/before.rules`, at the end of `ufw-before-input`, in one marked block per owning script: `vps-baseline ssh limits` (`harden-vps.sh`) and `vpn-server port limits` (`deploy-vpn.sh`).
- SSH: 10 concurrent, 30 new per minute. VPN port: 1000 concurrent, 100 new per second with a burst of 300.
- A script tests the new file with `iptables-restore --test --noflush` before replacing the old one, and restores the old one if `ufw reload` fails.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| `ufw limit` | Fixed at 6 connections in 30 seconds. The deploy and verify sequence opens more than that from the operator's address, so the operator would be locked out by their own scripts. |
| fail2ban jail for floods | Works from log lines after the fact; bare connections that never authenticate write few. |
| Allow SSH from the operator's address only | The address is dynamic; a change would lock the operator out, with the console as the only way back. |

## Consequences

One address, or a handful, can no longer occupy SSH or the VPN port. This does not stop a distributed or volumetric flood: that traffic must be absorbed upstream by the provider. Anything that rewrites `/etc/ufw/before.rules` must keep the two marked blocks; `scripts/verify-baseline.sh` (R-vps-baseline-06.a) and `scripts/verify-vpn.sh` (R-vpn-server-10.a) detect their loss.

## Do not

- Do not use `ufw limit` on the SSH port: its fixed 6 connections in 30 seconds locks out the operator's own scp and ssh script runs. Use the per-address limits in `before.rules`. (ADR-0005)
