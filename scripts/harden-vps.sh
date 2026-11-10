#!/usr/bin/env bash
# harden-vps.sh - baseline setup for the Thailand VPS (Ubuntu 24.04).
#
# Reconstructed from the operator's shell history on 2026-11-10:
#   1. SSH keepalive (ClientAliveInterval 60, ClientAliveCountMax 3)
#   2. Hostname in /etc/hosts (silences "sudo: unable to resolve host")
#   3. fail2ban with the operator's IP in ignoreip
#   4. ufw: allow SSH, default deny incoming, enable
# Added by the change harden-against-attacks:
#   5. SSH login surface: no root login, no password login, no X11 forwarding,
#      unauthenticated connections closed after 30 seconds
#   6. SYN flood settings in the kernel
#   7. per-address limits on new SSH connections (ADR-0005)
#
# Usage, on the VPS as root or via sudo:
#   sudo -n bash harden-vps.sh <ADMIN_IP>
#
# ADMIN_IP is the operator's current public IPv4 address. It is passed on
# every run and never stored in this repository.
#
# Safe to re-run. Overwrites /etc/fail2ban/jail.local, the two sshd drop-in
# files and the sysctl file, and replaces its own marked block in
# /etc/ufw/before.rules.

set -euo pipefail

readonly KEEPALIVE_CONF=/etc/ssh/sshd_config.d/keepalive.conf
readonly SSH_HARDENING_CONF=/etc/ssh/sshd_config.d/10-hardening.conf
readonly JAIL_LOCAL=/etc/fail2ban/jail.local
readonly SYSCTL_CONF=/etc/sysctl.d/60-vps-syn-flood.conf
readonly UFW_BEFORE=/etc/ufw/before.rules
readonly LIMITS_MARKER='vps-baseline ssh limits'
# One address may hold this many SSH connections at once, and open this many
# new ones per minute. Generous on purpose: the operator's scripts open several
# sessions in a row (ADR-0005).
readonly SSH_MAX_CONCURRENT=10
readonly SSH_MAX_NEW_PER_MINUTE=30

log() { printf '[harden] %s\n' "$*"; }
die() { printf '[harden] error: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root: sudo -n bash $0 <ADMIN_IP>"

ADMIN_IP=${1:-}
[ -n "$ADMIN_IP" ] || die "ADMIN_IP argument is required"
printf '%s' "$ADMIN_IP" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' \
    || die "ADMIN_IP must be an IPv4 address"

# 1. Hostname resolution.
if ! grep -qw "$(hostname)" /etc/hosts; then
    echo "127.0.1.1 $(hostname)" >> /etc/hosts
    log "added hostname to /etc/hosts"
fi

# 2. SSH keepalive. Validate before reload; remove the file if the config is invalid.
cat > "$KEEPALIVE_CONF" <<'EOF'
ClientAliveInterval 60
ClientAliveCountMax 3
EOF
if ! sshd -t; then
    rm -f "$KEEPALIVE_CONF"
    die "sshd config invalid; keepalive file removed, SSH not reloaded"
fi

# 2b. SSH login surface. sshd takes the first value it reads for a keyword, and
#     the drop-in directory is included at the top of sshd_config, so this file
#     wins over the provider image's "PermitRootLogin yes". Running sessions
#     survive the reload; root stays reachable through sudo and the console.
cat > "$SSH_HARDENING_CONF" <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
X11Forwarding no
LoginGraceTime 30
EOF
chmod 644 "$SSH_HARDENING_CONF"
if ! sshd -t; then
    rm -f "$SSH_HARDENING_CONF"
    die "sshd config invalid; hardening file removed, SSH not reloaded"
fi
systemctl reload ssh
log "sshd keepalive and login hardening applied, ssh reloaded"

SSH_PORT=$(sshd -T | awk '$1 == "port" { print $2 }')
[ -n "$SSH_PORT" ] || die "could not read the SSH port from sshd -T"
log "SSH port is $SSH_PORT"

# 3. fail2ban, with the operator's IP exempt from bans.
DEBIAN_FRONTEND=noninteractive apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq fail2ban
cat > "$JAIL_LOCAL" <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 $ADMIN_IP

[sshd]
enabled = true
port = $SSH_PORT
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban
# The socket appears a moment after the unit starts; wait for it before querying.
for _ in $(seq 1 10); do
    fail2ban-client ping >/dev/null 2>&1 && break
    sleep 1
done
fail2ban-client status sshd >/dev/null
log "fail2ban running with sshd jail"

# 4. Firewall. SSH is allowed before ufw is enabled, so this cannot lock out the session.
ufw allow "${SSH_PORT}/tcp" comment 'SSH'
ufw default deny incoming
ufw default allow outgoing
ufw --force enable
log "ufw enabled"

# 5. SYN flood settings. Cookies keep the listener answering when the backlog
#    is full; the larger backlog and fewer SYN-ACK retries make it fill later
#    and drain sooner.
cat > "$SYSCTL_CONF" <<'EOF'
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_synack_retries = 3
EOF
chmod 644 "$SYSCTL_CONF"
sysctl -q -p "$SYSCTL_CONF"
log "SYN flood settings applied"

# 6. Per-address limits on new SSH connections, as one marked block at the end
#    of ufw's before-input chain, which runs ahead of the ALLOW rules. Not
#    "ufw limit": its fixed 6 connections in 30 seconds locks out the operator's
#    own script runs (ADR-0005).
#    The candidate file is tested against the live ruleset before it replaces
#    the current one, and the previous file comes back if the reload fails, so a
#    bad rule cannot leave the firewall half loaded.
set_before_rules_block() { # set_before_rules_block <marker> <file with rule lines>
    local marker=$1 block=$2 candidate backup
    candidate=$(mktemp)
    backup=$(mktemp)
    awk -v begin="# BEGIN $marker" -v end="# END $marker" -v block="$block" '
        $0 == begin { skip = 1 }
        $0 == "*filter" { in_filter = 1 }
        !skip && in_filter && $0 == "COMMIT" {
            print begin
            while ((getline line < block) > 0) print line
            print end
            in_filter = 0
        }
        !skip { print }
        $0 == end { skip = 0 }' "$UFW_BEFORE" > "$candidate"
    grep -qxF "# END $marker" "$candidate" || { rm -f "$candidate" "$backup"; die "no filter table found in $UFW_BEFORE"; }
    if cmp -s "$candidate" "$UFW_BEFORE"; then
        rm -f "$candidate" "$backup"
        return 0
    fi
    if ! iptables-restore --test --noflush < "$candidate"; then
        rm -f "$candidate" "$backup"
        die "new firewall rules for '$marker' did not validate; nothing changed"
    fi
    cp -p "$UFW_BEFORE" "$backup"
    cat "$candidate" > "$UFW_BEFORE"
    if ! ufw reload >/dev/null; then
        cat "$backup" > "$UFW_BEFORE"
        ufw reload >/dev/null
        rm -f "$candidate" "$backup"
        die "ufw did not reload with the rules for '$marker'; previous rules restored"
    fi
    rm -f "$candidate" "$backup"
}
limits=$(mktemp)
cat > "$limits" <<EOF
-A ufw-before-input -p tcp --syn --dport $SSH_PORT -m connlimit --connlimit-above $SSH_MAX_CONCURRENT --connlimit-mask 32 -j DROP
-A ufw-before-input -p tcp --syn --dport $SSH_PORT -m hashlimit --hashlimit-name ssh-new --hashlimit-mode srcip --hashlimit-above $SSH_MAX_NEW_PER_MINUTE/minute --hashlimit-burst $SSH_MAX_NEW_PER_MINUTE -j DROP
EOF
set_before_rules_block "$LIMITS_MARKER" "$limits"
rm -f "$limits"
log "per-address SSH connection limits applied"

log "final state:"
systemctl is-active ssh
ufw status verbose
fail2ban-client status sshd
