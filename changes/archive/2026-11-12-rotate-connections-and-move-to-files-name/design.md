# Design: rotate-connections-and-move-to-files-name

## Approach

- Connection rotation is client behavior. Xray reads it from `xhttpSettings.extra.xmux`, which a share link carries as the URL-encoded JSON parameter `extra`. The deploy script writes it into the link; nothing on the server changes for it.
- Padding is set on both ends: `xPaddingBytes: "100-1000"` in the inbound's `xhttpSettings` and in the link's `extra`. That is Xray's default range, now stated, so the server and every client agree on it.
- Values: `maxConcurrency "16-32"` (Xray's default), `cMaxReuseTimes "32-64"`, `hMaxRequestTimes "600-900"` (default), `hMaxReusableSecs "120-300"` (default 1800-3000). A browser keeps an HTTP/2 connection for minutes, not most of an hour.
- The cover names become a list: `casedigestai.com`, `files.casedigestai.com` (the link's name) and `status.casedigestai.com` (kept for old links). The DNS check, nginx `server_name`, the certificate and the loopback checks loop over the list. The certificate is reissued once, for three names.
- The landing page gains a section on case-file upload and sync at `files.casedigestai.com`.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| deploy | `scripts/deploy-vpn.sh` | name list, `COVER_NAME=files.casedigestai.com`, padding in the inbound (also applied to an existing inbound), `extra` in the link |
| site | `site/html/index.html` | case-file sync section |
| verify | `scripts/verify-vpn.sh`, `scripts/verify-external.sh` | new name, three names, `extra` in the test client, R-18 checks |
| docs | `docs/vps-access.md`, `docs/censor-red-flags.md`, `AGENTS.md` | new name, flag 3 status |

New modules or dependencies between modules: none.

## Contracts and data

- The client link changes once (host, sni, `extra`). Client ID and path are kept. The old link keeps working while `status.casedigestai.com` stays proxied.
- The existing inbound is updated in place with `xPaddingBytes`.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Keep Xray's xmux defaults | A connection is reused for 30 to 50 minutes; flag 3 names exactly that. |
| `hMaxReusableSecs` under a minute | Many more TLS handshakes through Cloudflare and visible latency, and browsers keep connections longer than that. |
| `cdn.` as the name | Plausible for volume, but a CDN name rarely carries uploads; `files.` fits heavy traffic both ways. |
| Drop `status.casedigestai.com` | Every device would lose the VPN until it imports the new link. |
| ECH to hide the name | Reported blocked in Russia and China. |

Decision record needed: ADR-0014.

## Verification

| Criterion | Test |
|---|---|
| R-vpn-server-18.a | `scripts/verify-vpn.sh` (R-vpn-server-18.a) |
| R-vpn-server-18.b | untested: needs more than 5 minutes; run by hand on 2026-11-12 |
| R-vpn-server-18.c | `scripts/verify-vpn.sh` (R-vpn-server-18.c) |
| R-vpn-server-04.a, .b | `scripts/verify-external.sh`, `scripts/verify-vpn.sh` |
| R-vpn-server-14.c, 17.a | `scripts/verify-vpn.sh`, `scripts/verify-external.sh` |
| R-vpn-server-15.a, .b, .e, .f | `scripts/verify-external.sh` |
| R-vpn-server-01.a (test client now uses `extra`) | `scripts/verify-vpn.sh` |

## Risks

- The new name must be a proxied record in Cloudflare before the run; the script stops before it changes anything if not.
- If Happ ignores `extra`, the link still works with Xray's defaults; R-18.a holds for the link, not for that client.
- Server and client padding ranges must overlap, or the server rejects requests. Both are set to the same range.
