# Proposal: add-http1-tunnel

## Why

On 2026-11-12 a user on a Russian mobile network could not use the key, and the cover site did not load there. Tests from the phone (Termux, mobile data, no VPN) showed that HTTP/2 to `files.`, `casedigestai.com` and `status.` hangs after the TLS handshake in every run, while HTTP/1.1 to the same three names returns 200, and HTTP/2 to another Cloudflare name on the same address works. The client link offered `h2,http/1.1`, so clients used HTTP/2. Over HTTP/1.1 the tunnel did not work either: nginx's `grpc_pass` answers an HTTP/1.1 request with raw HTTP/2 frames, with or without Cloudflare in the path.

## What changes

- The client link offers HTTP/1.1 only, so a phone behind such a network connects the way that gets through.
- The web server passes tunnel requests of any HTTP version to the tunnel inbound, so a client on HTTP/1.1 gets a working tunnel. Devices with the earlier link, which negotiate HTTP/2, keep working.

## Capabilities affected

| Capability | New or existing | Delta |
|---|---|---|
| vpn-server | existing | `specs/vpn-server/spec.md` |

## Out of scope

- Moving to a new domain, a second transport outside Cloudflare, or HTTP/3.
- Finding out who blocks HTTP/2 to these names, or why. Only the effect was measured.

## Decisions checked

None of the "Do not" lines forbids this. "Do not give clients a link to the server's own address" and the Cloudflare-only firewall rule stay in force.

## Open questions

- [TODO-CLARIFY: do other carriers, and Iran and China, treat HTTP/2 to these names the same way? Only one Russian mobile network was tested.]
