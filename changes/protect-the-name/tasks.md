# Tasks: protect-the-name

Ordered. Each task touches one to three files and has its own check. Tick a task only after its check passes.

Tasks 1 to 3 need the first server to pass their checks; it does not exist on 2026-11-12. What was checked off a server is noted under each. The jq code could not be run: the workstation has no jq.

- [ ] 1. Serve the site and the tunnel on the alternative ports (files: `scripts/deploy-vpn.sh`; criteria: R-vpn-server-05.a, 05.c, 23.a to 23.d, 26.a)
  Check: the deploy ends with `[deploy] done` and logs the alternative ports.
  Written 2026-11-12: `bash -n` passes.
- [ ] 2. Check the ports, the links and ECH from the inside (files: `scripts/verify-vpn.sh`; criteria: R-vpn-server-05.a, 05.c, 23.a, 23.b, 23.d, 24.a, 26.a)
  Check: every check passes on the server.
  Written 2026-11-12: `bash -n` passes; the comparison of the alternative links with the main one was run against invented links (a good set passed, a set with another client ID failed).
- [ ] 3. Check the ports, ECH and the name words from outside (files: `scripts/verify-external.sh`; criteria: R-vpn-server-23.a, 23.c, 24.b, 25.a)
  Check: every check passes from the workstation.
  Written 2026-11-12: `bash -n` passes; the DNS record reader was run against text and raw sample records and against a live name that offers ECH; the word check flagged `my-vpn.example.org` and passed the others.
- [x] 4. Write the word list and the client guide (files: `docs/avoided-name-words.txt`, `docs/client-setup.md`; criteria: R-vpn-server-25.a, 27.a)
  Check: the word check reads the list. Done 2026-11-12. The guide's menu names are not checked on a device.
- [x] 5. Put ECH off and the word rule into the order of steps (files: `docs/redeploy.md`, `docs/vps-access.md`, `docs/censor-red-flags.md`)
  Check: the runbook names both. Done 2026-11-12.
- [ ] Final: run every command in `AGENTS.md`; archive the change.
