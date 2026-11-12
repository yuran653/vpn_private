#!/usr/bin/env bash
# verify-baseline.sh - checks the VPS baseline from the inside.
#
# Runs on the VPS as root. Reads the effective SSH, kernel and firewall state
# that scripts/harden-vps.sh sets. Each check names the acceptance criterion it
# verifies (specs/vps-baseline/spec.md). Changes nothing on the host.
#
# Usage:
#   sudo -n bash verify-baseline.sh [--ssh-from <addr>[,<addr>...]]
#
# Pass --ssh-from with the same list as harden-vps.sh got; without it the SSH
# port is expected to be admitted from anywhere.
#
# Exit code 0 only when every check passes. Prints no secret.

set -uo pipefail

fails=0
pass() { printf 'PASS  %-20s %s\n' "$1" "$2"; }
fail() { printf 'FAIL  %-20s %s\n' "$1" "$2"; fails=$((fails + 1)); }

[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo -n bash $0" >&2; exit 2; }

sshd_settings=$(sshd -T 2>/dev/null)
ssh_port=$(printf '%s\n' "$sshd_settings" | awk '$1 == "port" {print $2}')
setting() { printf '%s\n' "$sshd_settings" | awk -v k="$1" '$1 == k {print $2}'; }

# R-vps-baseline-05.a: no root login, no password or keyboard-interactive login,
# no X11 forwarding, and an unauthenticated connection is closed after 30 seconds.
wrong=""
for pair in permitrootlogin=no passwordauthentication=no kbdinteractiveauthentication=no \
            x11forwarding=no logingracetime=30; do
    [ "$(setting "${pair%%=*}")" = "${pair#*=}" ] || wrong="$wrong ${pair%%=*}"
done
[ -z "$wrong" ] \
    && pass R-vps-baseline-05.a "sshd refuses root, passwords and X11; login window is 30 s" \
    || fail R-vps-baseline-05.a "sshd settings differ:$wrong"

# R-vps-baseline-06.a: one address cannot hold more than 10 SSH connections or
# open more than 30 new ones per minute.
ssh_rules=$(iptables -S ufw-before-input 2>/dev/null | grep -- "--dport $ssh_port " | grep -- '-j DROP')
if printf '%s\n' "$ssh_rules" | grep -q -- '--connlimit-above 10 --connlimit-mask 32' \
    && printf '%s\n' "$ssh_rules" | grep -- '--hashlimit-mode srcip' \
        | grep -- '--hashlimit-above 30/min' | grep -q -- '--hashlimit-burst 30'; then
    pass R-vps-baseline-06.a "per-address connection limits are loaded on ${ssh_port}/tcp"
else
    fail R-vps-baseline-06.a "per-address connection limits are missing on ${ssh_port}/tcp"
fi

# R-vps-baseline-08.a, .c and .d: the SSH port is admitted from exactly the
# listed sources, or from anywhere when no list was asked for.
ssh_sources=$(ufw status | awk -v p="${ssh_port}/tcp" '$1 == p && $2 == "ALLOW" {print $3}' | sort -u | tr '\n' ' ')
if [ "${1:-}" = --ssh-from ]; then
    want=$(python3 -I -c '
import ipaddress, sys
out = []
for item in sys.argv[1].split(","):
    net = ipaddress.IPv4Network(item.strip(), strict=True)
    out.append(str(net.network_address) if net.prefixlen == 32 else str(net))
print(" ".join(sorted(set(out))) + " ")
' "${2:-}" 2>/dev/null)
    if [ -n "$want" ] && [ "$ssh_sources" = "$want" ]; then
        pass R-vps-baseline-08.a "${ssh_port}/tcp is admitted from the listed sources only"
    else
        fail R-vps-baseline-08.a "${ssh_port}/tcp is admitted from '${ssh_sources% }', not exactly the list"
    fi
elif [ "$ssh_sources" = "Anywhere " ]; then
    pass R-vps-baseline-08.c "${ssh_port}/tcp is admitted from anywhere (no list asked for)"
else
    fail R-vps-baseline-08.c "${ssh_port}/tcp is admitted from '${ssh_sources% }', expected anywhere"
fi

# R-vps-baseline-07.a: SYN cookies are on and the SYN backlog holds at least 4096.
if [ "$(sysctl -n net.ipv4.tcp_syncookies)" = 1 ] \
    && [ "$(sysctl -n net.ipv4.tcp_max_syn_backlog)" -ge 4096 ]; then
    pass R-vps-baseline-07.a "SYN cookies on, SYN backlog at least 4096"
else
    fail R-vps-baseline-07.a "SYN cookies off or SYN backlog below 4096"
fi

echo
if [ "$fails" -eq 0 ]; then
    echo "all checks passed"
else
    echo "$fails check(s) failed"
    exit 1
fi
