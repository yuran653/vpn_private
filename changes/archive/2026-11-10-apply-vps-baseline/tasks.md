# Tasks: apply-vps-baseline

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

- [x] 1. Write the script from the shell history (files: `scripts/harden-vps.sh`; criteria: R-vps-baseline-01.a, 02.a, 02.b, 03.a)
  Check: `bash -n scripts/harden-vps.sh` passes.
- [x] 2. Run the script on the VPS. The keepalive step applied; the run stopped at the port lookup (exit 141). (files: `scripts/harden-vps.sh`; criteria: R-vps-baseline-01.a)
  Check: keepalive file present on the VPS.
- [x] 3. Fix the broken pipe in the port lookup, then run again. The run stopped at the fail2ban check because the socket was not ready. (files: `scripts/harden-vps.sh`; criteria: R-vps-baseline-04.a)
  Check: the script reached the fail2ban step.
- [x] 4. Add the socket wait, then run again. Exit code 0. (files: `scripts/harden-vps.sh`; criteria: R-vps-baseline-02.b, 03.a, 04.a)
  Check: `fail2ban-client get sshd ignoreip` lists the admin IP; `ufw status verbose` shows 22/tcp ALLOW IN; a new `ssh zcom-th` login succeeds.
- [x] 5. Exercise the validation branches. Done for no argument and a bad IP (R-vps-baseline-02.a): both exit 1 before changing anything. Not done for the invalid-sshd-config branch (R-vps-baseline-01.b): it would break the live SSH config, so it stays `untested`.
  Check: script exits 1 with the error messages above.
- [x] 6. Approve the proposal. Approved by the owner on 2026-11-10.
- [ ] Final: run every command in `AGENTS.md`; archive the change. The commands are still `[TODO-CLARIFY]`.
