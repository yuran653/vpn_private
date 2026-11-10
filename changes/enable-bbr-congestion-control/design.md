# Design: enable-bbr-congestion-control

## Approach

`scripts/deploy-vpn.sh` gets a new step 3 after the IPv6 step. It writes `/etc/modules-load.d/vpn-tcp.conf` (modules `tcp_bbr`, `sch_fq`) and `/etc/sysctl.d/60-vpn-tcp.conf`, loads both, and replaces the queueing discipline on the interface of the default route, because `net.core.default_qdisc` applies only to queues created later. `scripts/verify-vpn.sh` gets one check per criterion.

State found on the VPS on 2026-11-10 (kernel 6.8.0-147): `cubic`, `fq_codel` on `ens3` (one transmit queue), `tcp_rmem` max 6291456, `tcp_wmem` max 4194304, `tcp_slow_start_after_idle = 1`, `tcp_mtu_probing = 0`. The modules `tcp_bbr` and `sch_fq` are present and not loaded.

Settings written:

| Key | Value | Kernel default found |
|---|---|---|
| `net.core.default_qdisc` | `fq` | `fq_codel` |
| `net.ipv4.tcp_congestion_control` | `bbr` | `cubic` |
| `net.ipv4.tcp_rmem` | `4096 131072 16777216` | `4096 131072 6291456` |
| `net.ipv4.tcp_wmem` | `4096 16384 16777216` | `4096 16384 4194304` |
| `net.ipv4.tcp_slow_start_after_idle` | `0` | `1` |
| `net.ipv4.tcp_mtu_probing` | `1` | `0` |

The settings live in the deploy script and not in `harden-vps.sh`, because they exist for the VPN's traffic and the `vpn-server` spec owns the requirement.

## Modules and files touched

| Module | Files | Change |
|---|---|---|
| vpn-server | `scripts/deploy-vpn.sh` | New step 3; later steps renumbered 4 to 8. |
| vpn-server | `scripts/verify-vpn.sh` | Checks for R-vpn-server-11.a to 11.f. |
| docs | `docs/decisions/ADR-0007-bbr-congestion-control.md`, `docs/decisions/INDEX.md`, `docs/vps-access.md` | Decision record; a note in the access guide. |

New modules or dependencies between modules: none.

## Contracts and data

New files on the VPS: `/etc/sysctl.d/60-vpn-tcp.conf` and `/etc/modules-load.d/vpn-tcp.conf`, both owned by the deploy script and overwritten on each run. Connections open when the script runs keep their old congestion control until they close; new connections use BBR. The client link does not change.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Keep CUBIC and only raise the buffers | CUBIC still halves its rate at each loss, which is the main limit on a long path with loss. |
| A third-party BBR variant (BBRv3 or "BBR plus" kernels) | Needs a kernel outside Ubuntu's security updates, against R-vpn-server-07. |
| `tcp_notsent_lowat`, `tcp_fastopen`, larger `net.core.*mem_max` | Not needed for throughput: Xray does not set socket buffer sizes, so the `net.core` limits do not apply to it; the others change latency or handshake behavior and were not asked for. |
| Put the settings in `harden-vps.sh` | That script is the security baseline; these settings are VPN performance. |

Decision record needed: ADR-0007.

## Verification

| Criterion | Test |
|---|---|
| R-vpn-server-11.a | `scripts/verify-vpn.sh` (R-vpn-server-11.a) |
| R-vpn-server-11.b | `scripts/verify-vpn.sh` (R-vpn-server-11.b) |
| R-vpn-server-11.c | `scripts/verify-vpn.sh` (R-vpn-server-11.c) |
| R-vpn-server-11.d | `scripts/verify-vpn.sh` (R-vpn-server-11.d) |
| R-vpn-server-11.e | `scripts/verify-vpn.sh` (R-vpn-server-11.e) |
| R-vpn-server-11.f | `scripts/verify-vpn.sh` (R-vpn-server-11.f) |

## Risks

- Memory: a 16 MB limit per buffer with up to 1000 connections per address. The kernel's global `tcp_mem` limit (about 354 MB on this host) is unchanged and caps the total.
- Fingerprinting: congestion control changes packet timing only. It adds nothing to the TLS handshake a probe sees, so R-vpn-server-04 is not affected.
- Replacing the queueing discipline drops the packets queued at that moment; TCP retransmits them.
- Survival across a reboot rests on the two files in `/etc`. It is covered by R-vpn-server-08.c, which stays `untested` until the host is rebooted and the verify script is run again.
