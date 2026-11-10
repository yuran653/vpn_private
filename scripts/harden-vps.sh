#!/usr/bin/env bash
# harden-vps.sh - baseline setup for the Thailand VPS (Ubuntu 24.04).
#
# Reconstructed from the operator's shell history on 2026-11-10:
#   1. SSH keepalive (ClientAliveInterval 60, ClientAliveCountMax 3)
#   2. Hostname in /etc/hosts (silences "sudo: unable to resolve host")
#   3. fail2ban with the operator's IP in ignoreip
#   4. ufw: allow SSH, default deny incoming, enable
#
# Usage, on the VPS as root or via sudo:
#   sudo -n bash harden-vps.sh <ADMIN_IP>
#
# ADMIN_IP is the operator's current public IPv4 address. It is passed on
# every run and never stored in this repository.
#
# Safe to re-run. Overwrites /etc/fail2ban/jail.local and the keepalive file.

set -euo pipefail

readonly KEEPALIVE_CONF=/etc/ssh/sshd_config.d/keepalive.conf
readonly JAIL_LOCAL=/etc/fail2ban/jail.local

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
systemctl reload ssh
log "sshd keepalive applied and ssh reloaded"

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

log "final state:"
systemctl is-active ssh
ufw status verbose
fail2ban-client status sshd
