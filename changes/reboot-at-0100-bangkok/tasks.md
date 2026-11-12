# Tasks: reboot-at-0100-bangkok

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

- [ ] 1. Set the time zone and the reboot time, and check both (files: `scripts/lib/host-common.sh`, `scripts/verify-vpn.sh`, `scripts/verify-fallback.sh`; criteria: R-vpn-server-07.c)
  Check: after a deploy, `verify-vpn.sh` passes R-vpn-server-07.c, and `timedatectl` on the host shows Asia/Bangkok.
  Written 2026-11-12: `bash -n` passes. Not run on a server; none exists.
- [x] 2. State the new time in the docs (files: `docs/vps-access.md`, `docs/how-it-works.html`, `docs/decisions/ADR-0006-automatic-reboot-after-updates.md`)
  Check: no document outside the spec and the decision history says 04:00. Done 2026-11-12.
- [ ] Final: run every command in `AGENTS.md`; archive the change.
