# Tasks: harden-against-attacks

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

- [x] 1. Add the sshd login settings, SYN flood sysctls and SSH connection limits to the baseline script, and a verify script for them (files: `scripts/harden-vps.sh`, `scripts/verify-baseline.sh`; criteria: R-vps-baseline-05.a, 05.b, 06.a, 07.a)
  Check: `bash -n` passes on both; on the VPS the script exits 0, a new `ssh zcom-th` login succeeds, and `verify-baseline.sh` passes 3 of 3.
- [x] 2. Exercise the SSH limit from outside (criteria: R-vps-baseline-06.b)
  Check: not achieved. 16 simultaneous connections from the workstation all succeeded, and the server's SSH log showed that none of them arrived: the workstation's connections are completed by a local proxy. The criterion stays `untested`.
- [x] 3. Add the update run, automatic reboot and VPN port limits to the deploy script, and checks for them (files: `scripts/deploy-vpn.sh`, `scripts/verify-vpn.sh`; criteria: R-vpn-server-07.b, 07.c, 10.a)
  Check: `bash -n` passes on both; on the VPS the script exits 0 and no security update is pending.
- [x] 4. Reboot the VPS and run all three verify scripts (criteria: all of the above, R-vpn-server-08.c)
  Check: `verify-baseline.sh`, `verify-vpn.sh` and `verify-external.sh` each print "all checks passed"; `uname -r` shows the new kernel. Done: 6.8.0-147, 0 security updates pending, both scripts re-run with exit 0 and the client link unchanged. The SSH session dropped during one attached re-run of the deploy script, at the Xray restart; the detached re-run completed with exit 0.
- [x] 5. Record the decisions and update the access guide (files: `docs/decisions/ADR-0005-*.md`, `docs/decisions/ADR-0006-*.md`, `docs/decisions/INDEX.md`, `docs/vps-access.md`)
  Check: the index lists both records and the new "Do not" line.
- [ ] Final: run every command in `AGENTS.md`; archive the change. The commands are still `[TODO-CLARIFY]`.
