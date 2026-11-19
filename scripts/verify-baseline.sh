#!/usr/bin/env bash
# verify-baseline.sh - checks the VPS baseline from the inside.
#
# Runs on the VPS as root. Reads the effective SSH, kernel and firewall state
# that scripts/harden-vps.sh sets. Each check names the acceptance criterion it
# verifies (specs/vps-baseline/spec.md). Changes nothing on the host.
#
# Usage:
#   sudo -n bash verify-baseline.sh
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
