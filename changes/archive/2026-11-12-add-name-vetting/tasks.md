# Tasks: add-name-vetting

- [x] 1. The name check (files: scripts/check-name.sh; criteria: R-vpn-server-21.a, .b, .c)
  Check: run against the live name (exit 0) and against a pinned unreachable address (exit 1)
- [x] 2. The blocked-names list and its check (files: docs/blocked-names.txt, scripts/verify-external.sh; criteria: R-vpn-server-20.a, 21.a, 21.b)
  Check: `bash scripts/verify-external.sh` prints the three results
- [x] 3. ADR-0017 and docs (files: docs/decisions/*, docs/vps-access.md, docs/censor-red-flags.md)
  Check: the index row and the "Do not" line read correctly
- [x] Final: archive the change.
