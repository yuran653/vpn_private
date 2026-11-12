# Specs

One row per capability. Each spec at `specs/<capability>/spec.md` states what that capability does now.

A capability is a coherent slice of behavior that a user or caller can name, such as `auth` or `export`. It is not a class, an endpoint, a task or a ticket. A new piece of work usually changes an existing capability; it gets a new row only when no existing capability covers the behavior.

Specs change only when a change is archived (see `.agents/skills/sdd-change/SKILL.md`). Do not edit them directly, with one exception: a criterion's status and test reference, which the change cycle updates for a bug fix or for drift without a change folder.

| Capability | Spec | Summary |
|---|---|---|
| vps-baseline | `specs/vps-baseline/spec.md` | Applies the SSH keepalive and login settings, fail2ban, ufw, SYN flood settings and per-address SSH connection limits to the VPS through `scripts/harden-vps.sh`. |
| vpn-server | `specs/vpn-server/spec.md` | VLESS server reached only through Cloudflare (XHTTP inside HTTPS), whose client traffic leaves through Cloudflare WARP, with no IPv6 egress, server-side encrypted DNS, the owner's own website as the cover site for probes, a loopback-only panel, self-installing security updates, a firewall that admits only Cloudflare to the web ports, browser-like connection rotation and padding in the client link, a client link that offers HTTP/1.1 only, since a Russian mobile network hangs HTTP/2 to the site names, a list of blocked names the site and link must not use, a name check run from a phone before a name carries the tunnel, and TCP sending tuned for the long path (BBR), deployed by `scripts/deploy-vpn.sh`. |
