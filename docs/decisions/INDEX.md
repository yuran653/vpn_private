# Decisions

Read this before planning any change.

## Do not

Approaches that were tried or considered and rejected. Each line is binding until a newer decision supersedes it. To go against one, propose a new decision first.

Format: `- Do not <approach>: <one-line reason>. (ADR-NNNN)`

- Do not open a firewall port for the 3x-ui panel or its subscription service, or bind either to a public address: a reachable panel can be discovered and attacked. (ADR-0002)
- Do not rely on sysctl `disable_ipv6` alone to turn IPv6 off: systemd-networkd re-enables it at boot on an interface with IPv6 config. Use the `ipv6.disable=1` kernel parameter. (ADR-0004)
- Do not use `ufw limit` on the SSH port: its fixed 6 connections in 30 seconds locks out the operator's own scp and ssh script runs. Use the per-address limits in `before.rules`. (ADR-0005)
- Do not add a `freedom` outbound to the Xray template or send client traffic to its destination from a server's own address: Google places the first server's address in Myanmar, and a second way out leaks when WARP is down. (ADR-0008)
- Do not serve a subscription to the client app through the tunnel at a reserved address, or otherwise expect Happ to fetch one through its own tunnel: the app fetches subscriptions outside it and the request times out. A subscription needs a public address, which ADR-0002 forbids. (ADR-0011)
- Do not point the WARP tunnel at `162.159.192.1` (`engage.cloudflareclient.com`) or at `162.159.193.1`: from this host the first is answered in Singapore, 27 ms away, and the second passes no traffic. (ADR-0009)
- Do not use as the Reality cover site a third-party site whose addresses are not announced by the same AS number as the VPS's address, or point the owner's own domain straight at a VPS address: the first does not match the address, the second ties a name to a hosting address. (ADR-0012, reworded by ADR-0018)
- Do not publish a Docker container port on a public address: Docker's firewall rules bypass ufw. Publish on `127.0.0.1` and put the host web server in front. (ADR-0012)
- Do not give clients a link to the address of the server behind Cloudflare, or open a second way in on that server: its address must stay unused and unanswering. A way in outside Cloudflare runs on a separate server and is handed out only as a fallback. (ADR-0013, reworded by ADR-0018)
- On the server behind Cloudflare, do not admit 80/tcp or 443/tcp from outside Cloudflare's published ranges: that server's address must not answer probes directly. The fallback server admits 443/tcp from anywhere and answers as its cover site (ADR-0018). (ADR-0013)
- On the server behind Cloudflare, do not limit connections per source address on port 443: every client arrives from a shared Cloudflare address. (ADR-0013)
- Do not set `xPaddingBytes` on the server to a range the client link does not share: the server rejects requests whose padding is outside its range. (ADR-0014)
- Do not enable `http2` on nginx's listener, and in a client link that goes through Cloudflare do not put `h2` in `alpn` or set a browser `fp` (`chrome`, `firefox`, `safari`, `ios`, `edge`): Russian mobile networks hang HTTP/2 to our names, and an `http2` listener answers an HTTP/1.1 tunnel client with raw HTTP/2 frames, while a browser `fp` makes the client offer `h2` anyway. The fallback's direct Reality link is not such a link. (ADR-0015)
- Do not give any device a link that carries a name before `scripts/check-name.sh` passes for it from a mobile network in each target country (`docs/vps-access.md`, "Target countries"), and do not reuse a name or a domain listed in `docs/blocked-names.txt`: a flagged domain made every uploaded request to its names hang on a Russian mobile network. (ADR-0017)
- Do not hand out the direct Reality link as the default link: the user's ISP then sees a hosting provider's address (flag 2). Give a user the fallback link only after the main link and the links for the other ports have failed on that user's network. (ADR-0018)
- Do not let the second server take clients while its SSH port is open to any address the operator did not list when the baseline was last applied: its address is visible to every client's ISP and to probes. (ADR-0018)
- Do not give the fallback server a way out of its own (a `freedom` outbound, or its own WARP tunnel): its users would exit outside Thailand, and a second way out leaks when the first server is unreachable. It forwards to the first server only. (ADR-0019)
- Do not admit 2053, 2083, 2087, 2096 or 8443 from outside Cloudflare's published ranges, and do not put the panel or any other service on them: nginx holds them for the site and the tunnel. (ADR-0020)
- Do not turn ECH on for the zone or put an ECH setting in a client link: Cloudflare's ECH is blocked in Russia, and encrypted server names are blocked in China. (ADR-0021)
- Do not use a site name that contains a word from `docs/avoided-name-words.txt`: censors match names by keyword. (ADR-0021)
- Do not leave the reboot time to the time zone of the provider's image: the time is local, so an image on UTC reboots the host at 08:00 in Bangkok. The deploy sets the zone. (ADR-0022)
- Do not commit directly to `main`: every change arrives through a pull request, so it has a record. (ADR-0023)

## Log

One row per decision record in this folder. Files are named `ADR-NNNN-<slug>.md`, numbered in sequence. ADR-0016 is not used: it was drafted on 2026-11-12 for a change that made port 80 answer 404 instead of redirecting to HTTPS, and the owner dropped it on 2026-11-13 before it was merged. The redirect stays (R-vpn-server-15.e).

| ADR | Title | Status | Date |
|---|---|---|---|
| [ADR-0001](ADR-0001-stack.md) | Stack | accepted | 2026-11-10 |
| [ADR-0002](ADR-0002-panel-on-loopback.md) | Panel on loopback, installed from a pinned release | accepted | 2026-11-10 |
| [ADR-0003](ADR-0003-reality-cover-site.md) | Reality cover site | superseded by ADR-0012 | 2026-11-10 |
| [ADR-0004](ADR-0004-ipv6-off-in-kernel.md) | IPv6 disabled in the kernel, not by sysctl | accepted | 2026-11-10 |
| [ADR-0005](ADR-0005-per-address-connection-limits.md) | Per-address connection limits in ufw's before-input chain | accepted; the port-443 limits superseded by ADR-0013 | 2026-11-10 |
| [ADR-0006](ADR-0006-automatic-reboot-after-updates.md) | Automatic reboot after updates that need one | accepted; the reboot time and the time zone superseded by ADR-0022 | 2026-11-10 |
| [ADR-0007](ADR-0007-bbr-congestion-control.md) | BBR congestion control with fq pacing | accepted | 2026-11-10 |
| [ADR-0008](ADR-0008-egress-through-warp.md) | Client traffic leaves through Cloudflare WARP | accepted | 2026-11-10 |
| [ADR-0009](ADR-0009-warp-endpoint-in-bangkok.md) | WARP endpoint answered in Bangkok | accepted | 2026-11-10 |
| [ADR-0010](ADR-0010-subscription-through-tunnel.md) | Subscription served through the tunnel | superseded by ADR-0011 | 2026-11-11 |
| [ADR-0011](ADR-0011-no-subscription-name-in-the-link.md) | No subscription; the profile name travels in the client link | accepted | 2026-11-11 |
| [ADR-0012](ADR-0012-own-domain-cover-site.md) | Cover site on the owner's own domain, served from the VPS | accepted; the Reality inbound superseded by ADR-0013, the cover-site "Do not" line reworded by ADR-0018 | 2026-11-12 |
| [ADR-0013](ADR-0013-clients-only-through-cloudflare.md) | Clients reach the server only through Cloudflare | accepted; "CDN only" superseded by ADR-0018 | 2026-11-12 |
| [ADR-0014](ADR-0014-browser-like-connections-files-name.md) | Browser-like connection rotation and a cover name for heavy traffic | accepted | 2026-11-12 |
| [ADR-0015](ADR-0015-tunnel-over-http1.md) | Tunnel over HTTP/1.1, passed by proxy_pass | accepted | 2026-11-12 |
| [ADR-0017](ADR-0017-vet-names-before-use.md) | Names are tried from a mobile network before use, and blocked names are listed | accepted | 2026-11-12 |
| [ADR-0018](ADR-0018-second-transport-outside-cloudflare.md) | A second transport that does not pass through Cloudflare | accepted; the second server's own WARP exit superseded by ADR-0019 | 2026-11-12 |
| [ADR-0019](ADR-0019-fallback-relays-to-first-server.md) | The fallback server is an entry only and relays to the first server | accepted | 2026-11-12 |
| [ADR-0020](ADR-0020-alternative-cloudflare-ports.md) | The tunnel answers on Cloudflare's other HTTPS ports too | accepted | 2026-11-12 |
| [ADR-0021](ADR-0021-protect-the-name.md) | Measures that keep the name from being flagged | accepted | 2026-11-12 |
| [ADR-0022](ADR-0022-reboot-at-0100-bangkok.md) | Reboot at 01:00 Bangkok time, with the time zone set by the deploy | accepted | 2026-11-12 |
| [ADR-0023](ADR-0023-agent-merges-its-own-pull-requests.md) | The agent opens, pushes and merges its own pull requests | accepted | 2026-11-12 |
