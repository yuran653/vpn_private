# ADR-0014: Browser-like connection rotation and a cover name for heavy traffic

- Status: accepted
- Date: 2026-11-12
- Supersedes: none (amends ADR-0013's client link and ADR-0012's list of names)
- Change: `changes/archive/2026-11-12-rotate-connections-and-move-to-files-name/`

## Context

`docs/censor-red-flags.md`, flag 3: each user holds connections for hours and moves gigabytes to one hostname. Since ADR-0013 the address is Cloudflare's, so what is left is the name in the TLS hello (`status.casedigestai.com`, a status page) and the shape of the connections. Xray's default reuses one connection for 30 to 50 minutes.

## Decision

- The client link carries XHTTP `extra` settings: `xmux` with `maxConcurrency "16-32"`, `cMaxReuseTimes "32-64"`, `hMaxRequestTimes "600-900"`, `hMaxReusableSecs "120-300"`, and `xPaddingBytes "100-1000"`. A connection to Cloudflare takes no new sessions after 2 to 5 minutes or 32 to 64 sessions.
- The inbound pads its responses with `xPaddingBytes "100-1000"`, the same range as the client.
- Clients connect to `files.casedigestai.com`, presented as case-file upload and sync, where heavy transfers both ways are normal. The landing page says so.
- `status.casedigestai.com` stays a proxied name of the site, so old links keep working.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Xray's default xmux | Connections live 30 to 50 minutes. |
| Rotation under a minute | Many more handshakes and visible latency; browsers keep connections longer. |
| ECH | Hides the name, but is reported blocked in Russia and China, so it adds a flag where it matters. |
| `cdn.` as the name | Rarely carries uploads. |
| Retire `status.` at once | Every device loses the VPN until it imports the new link. |

## Consequences

- Flag 3 is weakened, not closed: a heavy user is still heavy. Split tunneling and per-user names are the remaining measures.
- Rotation is client behavior. A client that ignores `extra` falls back to Xray's defaults. [TODO-CLARIFY: does Happ apply `extra` from a vless:// link?]
- The link changes once; every device imports it again.
- The certificate now covers three names, all in certificate transparency logs.

## Do not

- Do not set `xPaddingBytes` on the server to a range the client link does not share: the server rejects requests whose padding is outside its range. (ADR-0014)
