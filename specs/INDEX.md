# Specs

One row per capability. Each spec at `specs/<capability>/spec.md` states what that capability does now.

A capability is a coherent slice of behavior that a user or caller can name, such as `auth` or `export`. It is not a class, an endpoint, a task or a ticket. A new piece of work usually changes an existing capability; it gets a new row only when no existing capability covers the behavior.

Specs change only when a change is archived (see `.agents/skills/sdd-change/SKILL.md`). Do not edit them directly.

| Capability | Spec | Summary |
|---|---|---|
| vps-baseline | `specs/vps-baseline/spec.md` | Applies the SSH keepalive and login settings, fail2ban, ufw, SYN flood settings and per-address SSH connection limits to the VPS through `scripts/harden-vps.sh`. |
| vpn-server | `specs/vpn-server/spec.md` | VLESS + Reality server whose client traffic leaves through Cloudflare WARP, with no IPv6 egress, server-side encrypted DNS, a cover site for probes, a loopback-only panel, self-installing security updates, per-address connection limits and TCP sending tuned for the long path (BBR), deployed by `scripts/deploy-vpn.sh`. |
