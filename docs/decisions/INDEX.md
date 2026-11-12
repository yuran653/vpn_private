# Decisions

Read this before planning any change.

## Do not

Approaches that were tried or considered and rejected. Each line is binding until a newer decision supersedes it. To go against one, propose a new decision first.

Format: `- Do not <approach>: <one-line reason>. (ADR-NNNN)`

- Do not open a firewall port for the 3x-ui panel or its subscription service, or bind either to a public address: a reachable panel can be discovered and attacked. (ADR-0002)
- Do not rely on sysctl `disable_ipv6` alone to turn IPv6 off: systemd-networkd re-enables it at boot on an interface with IPv6 config. Use the `ipv6.disable=1` kernel parameter. (ADR-0004)
- Do not use `ufw limit` on the SSH port: its fixed 6 connections in 30 seconds locks out the operator's own scp and ssh script runs. Use the per-address limits in `before.rules`. (ADR-0005)
- Do not add a `freedom` outbound to the Xray template or route client traffic out from the server's own address: Google places that address in Myanmar, and a second way out leaks when WARP is down. (ADR-0008)
- Do not serve a subscription to the client app through the tunnel at a reserved address, or otherwise expect Happ to fetch one through its own tunnel: the app fetches subscriptions outside it and the request times out. A subscription needs a public address, which ADR-0002 forbids. (ADR-0011)
- Do not point the WARP tunnel at `162.159.192.1` (`engage.cloudflareclient.com`) or at `162.159.193.1`: from this host the first is answered in Singapore, 27 ms away, and the second passes no traffic. (ADR-0009)
- Do not use a third-party site as the Reality cover site: its name does not match the VPS address, and relaying probes to it adds a round trip that gives the relay away. (ADR-0012)
- Do not publish a Docker container port on a public address: Docker's firewall rules bypass ufw. Publish on `127.0.0.1` and put the host web server in front. (ADR-0012)
- Do not give clients a link to the server's own address, or any way in that does not pass through Cloudflare: the ISP then sees a hosting provider's address (flag 2). (ADR-0013)
- Do not admit 80/tcp or 443/tcp from outside Cloudflare's published ranges: the server's address must not answer probes directly. (ADR-0013)
- Do not limit connections per source address on port 443: every client arrives from a shared Cloudflare address. (ADR-0013)
- Do not set `xPaddingBytes` on the server to a range the client link does not share: the server rejects requests whose padding is outside its range. (ADR-0014)
- Do not use `grpc_pass` for the tunnel path or put `h2` in the client link's `alpn`: Russian mobile networks hang HTTP/2 to our names, and `grpc_pass` answers HTTP/1.1 requests with raw HTTP/2 frames. (ADR-0015)

## Log

One row per decision record in this folder. Files are named `ADR-NNNN-<slug>.md`, numbered in sequence.

| ADR | Title | Status | Date |
|---|---|---|---|
| [ADR-0001](ADR-0001-stack.md) | Stack | accepted | 2026-11-10 |
| [ADR-0002](ADR-0002-panel-on-loopback.md) | Panel on loopback, installed from a pinned release | accepted | 2026-11-10 |
| [ADR-0003](ADR-0003-reality-cover-site.md) | Reality cover site | superseded by ADR-0012 | 2026-11-10 |
| [ADR-0004](ADR-0004-ipv6-off-in-kernel.md) | IPv6 disabled in the kernel, not by sysctl | accepted | 2026-11-10 |
| [ADR-0005](ADR-0005-per-address-connection-limits.md) | Per-address connection limits in ufw's before-input chain | accepted; the port-443 limits superseded by ADR-0013 | 2026-11-10 |
| [ADR-0006](ADR-0006-automatic-reboot-after-updates.md) | Automatic reboot after updates that need one | accepted | 2026-11-10 |
| [ADR-0007](ADR-0007-bbr-congestion-control.md) | BBR congestion control with fq pacing | accepted | 2026-11-10 |
| [ADR-0008](ADR-0008-egress-through-warp.md) | Client traffic leaves through Cloudflare WARP | accepted | 2026-11-10 |
| [ADR-0009](ADR-0009-warp-endpoint-in-bangkok.md) | WARP endpoint answered in Bangkok | accepted | 2026-11-10 |
| [ADR-0010](ADR-0010-subscription-through-tunnel.md) | Subscription served through the tunnel | superseded by ADR-0011 | 2026-11-11 |
| [ADR-0011](ADR-0011-no-subscription-name-in-the-link.md) | No subscription; the profile name travels in the client link | accepted | 2026-11-11 |
| [ADR-0012](ADR-0012-own-domain-cover-site.md) | Cover site on the owner's own domain, served from the VPS | accepted; the Reality inbound superseded by ADR-0013 | 2026-11-12 |
| [ADR-0013](ADR-0013-clients-only-through-cloudflare.md) | Clients reach the server only through Cloudflare | accepted | 2026-11-12 |
| [ADR-0014](ADR-0014-browser-like-connections-files-name.md) | Browser-like connection rotation and a cover name for heavy traffic | accepted | 2026-11-12 |
| [ADR-0015](ADR-0015-tunnel-over-http1.md) | Tunnel over HTTP/1.1, passed by proxy_pass | accepted | 2026-11-12 |
