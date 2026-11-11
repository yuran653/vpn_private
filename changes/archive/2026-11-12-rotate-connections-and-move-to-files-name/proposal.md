# Proposal: rotate-connections-and-move-to-files-name

## Why

`docs/censor-red-flags.md`, flag 3: each user holds connections for hours and moves gigabytes under one hostname, `status.casedigestai.com`. Gigabytes a day to a status page is implausible, and connections that live for half an hour or more do not look like a browser's.

## What changes

- The client link carries XHTTP connection settings: a connection to Cloudflare takes no new sessions after 2 to 5 minutes or after 32 to 64 sessions, whichever comes first, and every request is padded with 100 to 1000 random bytes. The server pads its responses the same way.
- Clients connect under a new cover name, `files.casedigestai.com`: case-file upload and sync, where long, heavy transfers in both directions are expected. The landing page describes that service.
- `status.casedigestai.com` stays a name of the site, so devices with the old link keep working until they import the new one.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-server | existing | `specs/vpn-server/spec.md` |

## Out of scope

- Split tunneling in the client (red flag 3, measure 3) and per-user names (measure 4).
- Flags 4, 5, 6, 8.
- Hiding the name with ECH: reported to be blocked in Russia and China.

## Decisions checked

- ADR-0013: every way in still passes through Cloudflare; no per-address limit on 443 is added.
- ADR-0012: the new name is proxied by Cloudflare and served by the same site container on loopback.

## Open questions

- [TODO-CLARIFY: does Happ apply the `extra` parameter (xmux, padding) from a vless:// link? If it ignores it, the client falls back to Xray's defaults: a connection is reused for 30 to 50 minutes.]
