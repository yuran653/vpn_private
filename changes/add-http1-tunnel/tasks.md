# Tasks: add-http1-tunnel

- [ ] 1. Tunnel location uses `proxy_pass`; link carries `alpn=http/1.1` (files: scripts/deploy-vpn.sh; criteria: R-vpn-server-19.a, .b, .c)
  Check: `bash -n scripts/deploy-vpn.sh`; nginx -t passes on the VPS after the run
- [ ] 2. Checks for R-vpn-server-19 (files: scripts/verify-vpn.sh; criteria: R-vpn-server-19.a, .b, .c)
  Check: `bash -n scripts/verify-vpn.sh`; the three checks print PASS on the VPS
- [ ] 3. Deploy and verify on the VPS, then from outside (files: none; criteria: all)
  Check: `verify-vpn.sh` and `verify-external.sh` have no FAIL
- [ ] 4. ADR-0015, index, docs (files: docs/decisions/*, docs/censor-red-flags.md, docs/vps-access.md)
  Check: links and the "Do not" line read correctly
- [ ] Final: run every command in `AGENTS.md`; archive the change.
