# ADR-0015: Tunnel over HTTP/1.1, passed by proxy_pass

- Status: accepted
- Date: 2026-11-12
- Supersedes: none
- Change: `changes/archive/2026-11-12-add-http1-tunnel/`

## Context

A user on a Russian mobile network could not use the key (2026-11-12). From the phone, on mobile data with no VPN, HTTP/2 to `files.casedigestai.com`, `casedigestai.com` and `status.casedigestai.com` hung after the TLS handshake in every run, and HTTP/1.1 to the same names returned 200. HTTP/2 to `www.cloudflare.com` on the same address, and an 87 KB download from `cdnjs.cloudflare.com`, worked, so Cloudflare as a whole, the address, and a transfer-size cutoff are ruled out. The tunnel used HTTP/2 because the link offered `h2,http/1.1`. Over HTTP/1.1 the tunnel failed: the server answered an HTTP/1.1 tunnel client with raw HTTP/2 frames, with and without Cloudflare in the path. On the VPS, a temporary `proxy_pass` block on a plain listener passed, and the same block with `listen ... ssl http2` failed, so the `http2` flag on the listener is the cause. Who blocks HTTP/2 to these names, and why, is not known.

## Decision

The client link offers `http/1.1` only and sets `fp=android`: Xray's browser fingerprints put `h2` in the TLS hello whatever the ALPN says, which made Cloudflare answer HTTP/2 to an HTTP/1.1 client (measured: `chrome`, `firefox`, `safari`, `ios` and `edge` fail; `android`, `randomized` and `unsafe` pass). nginx listens without `http2` (only Cloudflare connects) and passes the tunnel path to Xray with `proxy_pass` over HTTP/1.1, which Xray's clear-text inbound accepts for HTTP/1.1 and HTTP/2 alike. The tunnel then runs as XHTTP `packet-up`.

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| New domain | Not shown to help; the block hit all three names alike and the cause is unknown. |
| Second transport outside Cloudflare | Reverses ADR-0013 and brings back the datacenter-address risk (flag 2); not needed while HTTP/1.1 passes. |
| `grpc_pass` for HTTP/2, `proxy_pass` for HTTP/1.1 | An `if` in a location is fragile; one `proxy_pass` serves both. |

## Consequences

Phones on networks that drop HTTP/2 to these names connect again. Throughput is lower than over HTTP/2. If HTTP/1.1 is blocked as well, the next step is a second transport. Every device must import the new link.

## Do not

- Do not enable `http2` on nginx's listener, put `h2` in the client link's `alpn`, or set a browser `fp` (`chrome`, `firefox`, `safari`, `ios`, `edge`) in it: Russian mobile networks hang HTTP/2 to our names, and an `http2` listener answers an HTTP/1.1 tunnel client with raw HTTP/2 frames, while a browser `fp` makes the client offer `h2` anyway. (ADR-0015)
