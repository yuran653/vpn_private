# ADR-0007: BBR congestion control with fq pacing

- Status: accepted
- Date: 2026-11-10
- Supersedes: none
- Change: `changes/archive/2026-11-10-enable-bbr-congestion-control/`

## Context

The owner asked for a quicker VPN without moving the server. The path from the Bangkok VPS to the owner's devices is long and loses packets. The server sent with the kernel defaults: CUBIC, which halves its sending rate at each lost packet, `fq_codel`, a 4 MB send buffer limit, and slow start after every idle period.

## Decision

`scripts/deploy-vpn.sh` writes `/etc/sysctl.d/60-vpn-tcp.conf` and `/etc/modules-load.d/vpn-tcp.conf`:

- congestion control `bbr`, from the stock Ubuntu kernel;
- default queueing discipline `fq`, also set at once on the interface of the default route;
- `tcp_rmem` and `tcp_wmem` upper limits of 16 MB, lower and default values unchanged;
- `tcp_slow_start_after_idle = 0` and `tcp_mtu_probing = 1`.

The settings belong to the `vpn-server` capability and are checked by `scripts/verify-vpn.sh` (R-vpn-server-11).

## Rejected alternatives

| Alternative | Why rejected |
|---|---|
| Keep CUBIC and only raise the buffers | CUBIC still halves its rate at each loss, the main limit on this path. |
| A third-party BBR variant or kernel | Leaves Ubuntu's security updates, against R-vpn-server-07. |
| Settings in `harden-vps.sh` | That script is the security baseline; these settings are VPN performance. |
| `tcp_notsent_lowat`, `tcp_fastopen`, larger `net.core.*mem_max` | Not needed for throughput here; Xray does not set socket buffer sizes, so the `net.core` limits do not apply to it. |

## Consequences

Download speed through the tunnel no longer collapses at each lost packet. BBR takes a larger share of a shared link than CUBIC flows next to it. A buffer may use up to 16 MB while a connection needs it; the kernel's global `tcp_mem` limit is unchanged and caps the total. The two files must stay in place for the settings to hold after a reboot.

## Do not

None.
