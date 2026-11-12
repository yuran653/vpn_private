# Design: add-http1-tunnel

## Approach

Take `http2` off nginx's listen directive and replace `grpc_pass` in the tunnel location of the nginx config that `scripts/deploy-vpn.sh` writes with `proxy_pass` over HTTP/1.1, with response and request buffering off and the 5-minute timeouts kept. Xray's inbound on loopback accepts HTTP/1.1 and HTTP/2 in clear text, so nginx no longer needs to speak HTTP/2 to it. The client link gets `alpn=http/1.1` and `fp=android`: Xray's browser fingerprints (`chrome`, `firefox`, `safari`, `ios`, `edge`) put `h2` in the TLS hello whatever `alpn` says, so Cloudflare chose HTTP/2 and the client, speaking HTTP/1.1, failed (measured through Cloudflare: only `android`, `randomized` and `unsafe` passed). `verify-vpn.sh` already builds its test client from the link, so its existing checks then run over HTTP/1.1; it gains a second client that offers HTTP/2 only.

Measured on the VPS, with the client built from the link: with the old config, HTTP/1.1 fails with malformed responses (raw HTTP/2 frames), directly and through Cloudflare. A temporary `proxy_pass` block on a listener without `http2` passes three requests and an 87 KB download; the same block with `listen ... ssl http2` fails like the old config. So the `http2` flag on the listener is what breaks an HTTP/1.1 tunnel client, and `proxy_pass` is needed because nginx's `grpc_pass` is for gRPC. Only Cloudflare connects to this listener, so dropping HTTP/2 there costs nothing for visitors or HTTP/2 clients.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| deploy | `scripts/deploy-vpn.sh` | listener without `http2`; tunnel location uses `proxy_pass`; link carries `alpn=http%2F1.1` and `fp=android` |
| verify | `scripts/verify-vpn.sh` | checks for R-vpn-server-19.a, .b, .c |
| docs | `docs/decisions/`, `docs/censor-red-flags.md`, `docs/vps-access.md` | ADR-0015, "Do not" line, flag 6, link re-import note |

New modules or dependencies between modules: none.

## Contracts and data

The client link changes (`alpn`). The client ID and path do not. Every device must import the new link; the earlier link keeps working over HTTP/2 where HTTP/2 is not blocked. The nginx config changes on the next deploy run.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| `fp=randomized` or `unsafe` | Also respect `alpn`, but a randomized hello is itself unusual; `android` is a real client's hello. |
| Keep `grpc_pass` and only drop `http2` | Not tested alone; `proxy_pass` on a plain listener is the setup measured to work. |
| `grpc_pass` for HTTP/2 and `proxy_pass` for HTTP/1.1 through `if` | `if` in a location is fragile; one `proxy_pass` serves both, which criterion .c checks. |
| New domain | Not shown to help: all three names behave alike, and HTTP/2 to another Cloudflare name works, so the cause is not known. |

Decision record needed: ADR-0015

## Verification

| Criterion | Test |
|---|---|
| R-vpn-server-19.a | `scripts/verify-vpn.sh` (R-vpn-server-19.a) |
| R-vpn-server-19.b | `scripts/verify-vpn.sh` (R-vpn-server-19.b) |
| R-vpn-server-19.c | `scripts/verify-vpn.sh` (R-vpn-server-19.c) |

## Risks

- Throughput over HTTP/1.1 is lower: more connections, and the upload goes in many small POSTs (`packet-up`). Contained by keeping the HTTP/2 path working, so an owner on an unblocked network can go back by editing `alpn` in the app.
- The `android` fingerprint on an iPhone does not match the device (flag 8 already notes the `chrome` mismatch).
- A client that cannot pin ALPN would still offer HTTP/2. Apps that read the link's `alpn` parameter are unaffected.
