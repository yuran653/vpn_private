#!/usr/bin/env bash
# host-common.sh - the host steps that every VPN server of this project shares.
#
# Sourced by scripts/deploy-vpn.sh (the server behind Cloudflare) and
# scripts/deploy-fallback.sh (the fallback server, ADR-0018). Kept in one place
# so the rules that protect identity (IPv6 off, panel on loopback, updates)
# cannot drift apart between the two servers.
#
# The function bodies were moved here unchanged from deploy-vpn.sh and are not
# indented, so the move can be compared line by line. They set globals that
# the callers use: work, reboot_needed, reboot_needed_qdisc, BASE and the
# panel API helpers api, api_ok and wait_api.
#
# The caller sets LOG_TAG (the word in the log prefix) before sourcing, and
# runs under `set -euo pipefail`. Prints no secret.

# shellcheck shell=bash

readonly XUI_VERSION=v3.11.0
readonly XUI_INSTALL_URL="https://raw.githubusercontent.com/MHSanaei/3x-ui/${XUI_VERSION}/install.sh"
readonly XUI_INSTALL_SHA256=9684bae4f769b2127fcceceb4f200045657381311867529e6ba76c6b58e2825d
readonly XUI_BIN=/usr/local/x-ui/x-ui
readonly XUI_RESULT=/etc/x-ui/install-result.env
readonly STATE_DIR=/root/vpn
readonly INSTALL_LOG=$STATE_DIR/install.log
readonly SYSCTL_CONF=/etc/sysctl.d/60-vpn-disable-ipv6.conf
readonly GRUB_CONF=/etc/default/grub.d/60-vpn-disable-ipv6.cfg
readonly NETPLAN_BACKUP=$STATE_DIR/netplan-backup
readonly AUTO_UPGRADES=/etc/apt/apt.conf.d/20auto-upgrades
readonly AUTO_REBOOT=/etc/apt/apt.conf.d/52vpn-auto-reboot
# The reboot time is local time, so the deploy sets the host's time zone itself
# and does not leave it to the provider's image (ADR-0022).
readonly HOST_TIMEZONE=Asia/Bangkok
readonly AUTO_REBOOT_TIME=01:00
readonly TCP_SYSCTL_CONF=/etc/sysctl.d/60-vpn-tcp.conf
readonly TCP_MODULES_CONF=/etc/modules-load.d/vpn-tcp.conf
# Upper limit of one TCP connection's send and receive buffer. The kernel grows
# a buffer towards it only while the connection needs it (ADR-0007).
readonly TCP_BUFFER_MAX=16777216

log() { printf '[%s] %s\n' "${LOG_TAG:-deploy}" "$*"; }
die() { printf '[%s] error: %s\n' "${LOG_TAG:-deploy}" "$*" >&2; exit 1; }

# Root, x86_64, Ubuntu, and the baseline's firewall already on.
host_preflight() {
[ "$(id -u)" -eq 0 ] || die "run as root: sudo -n bash $0"
[ "$(uname -m)" = x86_64 ] || die "only x86_64 is supported"
# shellcheck disable=SC1091
. /etc/os-release
[ "${ID:-}" = ubuntu ] || die "only Ubuntu is supported"
ufw status | grep -q '^Status: active' || die "ufw is not active; run scripts/harden-vps.sh first"
}

# Root-only state folder and a work folder that is removed on exit.
host_begin() {
umask 077
install -d -m 700 "$STATE_DIR"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
}

# Step 1.
host_updates() {
# 1. Packages and unattended upgrades.
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1
apt-get update -qq
apt-get install -y -qq curl jq openssl ca-certificates unattended-upgrades >/dev/null
cat > "$AUTO_UPGRADES" <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
chmod 644 "$AUTO_UPGRADES"
# An update that needs a reboot (kernel, libc) is not in effect until the host
# restarts, so the host restarts itself in the quiet hours (ADR-0006).
if [ "$(timedatectl show -p Timezone --value 2>/dev/null)" != "$HOST_TIMEZONE" ]; then
    timedatectl set-timezone "$HOST_TIMEZONE" || die "could not set the time zone to $HOST_TIMEZONE"
    log "time zone set to $HOST_TIMEZONE"
fi
cat > "$AUTO_REBOOT" <<EOF
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
Unattended-Upgrade::Automatic-Reboot-Time "$AUTO_REBOOT_TIME";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
EOF
chmod 644 "$AUTO_REBOOT"
systemctl enable --now unattended-upgrades >/dev/null 2>&1
log "unattended upgrades enabled, automatic reboot at $AUTO_REBOOT_TIME $HOST_TIMEZONE"
# Install what is pending now instead of waiting for the nightly timer: a fresh
# provider image is months behind. Quick when nothing is pending.
log "installing pending security updates (the first run can take several minutes)"
PYTHONWARNINGS=ignore unattended-upgrade || die "unattended-upgrade failed; see /var/log/unattended-upgrades/ on the VPS"
log "security updates installed"
}

# Step 2. Sets reboot_needed when the kernel has not booted with IPv6 off yet.
host_ipv6_off() {
# 2. IPv6 off.
#    At boot: the kernel parameter ipv6.disable=1. A sysctl alone does not hold,
#    because systemd-networkd turns IPv6 back on for an interface whose network
#    config carries an IPv6 route (ADR-0004).
#    Until the next reboot: the per-interface switches, and ufw's IPv6 side
#    closed (with IPV6=no ufw drops all IPv6 except loopback).
cat > "$GRUB_CONF" <<'EOF'
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX ipv6.disable=1"
EOF
chmod 644 "$GRUB_CONF"
if ! grep -q 'ipv6\.disable=1' /boot/grub/grub.cfg; then
    update-grub >/dev/null 2>&1 || die "update-grub failed"
    grep -q 'ipv6\.disable=1' /boot/grub/grub.cfg || die "ipv6.disable=1 did not reach grub.cfg"
fi
# The leading "-" makes sysctl skip these keys once the kernel has no IPv6 at all.
cat > "$SYSCTL_CONF" <<'EOF'
-net.ipv6.conf.all.disable_ipv6 = 1
-net.ipv6.conf.default.disable_ipv6 = 1
EOF
chmod 644 "$SYSCTL_CONF"
for f in /proc/sys/net/ipv6/conf/*/disable_ipv6; do
    [ -e "$f" ] && echo 1 > "$f"
done
if ! grep -q '^IPV6=no' /etc/default/ufw; then
    sed -i 's/^IPV6=.*/IPV6=no/' /etc/default/ufw
    grep -q '^IPV6=no' /etc/default/ufw || echo 'IPV6=no' >> /etc/default/ufw
    ufw reload >/dev/null
fi
# The network config must not ask for IPv6 either. With IPv6 off in the kernel,
# an IPv6 route in netplan can never be applied: systemd-networkd stays in
# "configuring" and every boot waits two minutes for the network to come online.
# The original files are kept in $NETPLAN_BACKUP. A config that does not
# validate is rolled back before anything is applied.
install -d -m 700 "$NETPLAN_BACKUP"
netplan_changed=$(python3 - "$NETPLAN_BACKUP" <<'PY'
import glob, os, shutil, sys, yaml

backup_dir = sys.argv[1]
is_v6 = lambda value: ":" in str(value)
changed = []
for path in sorted(glob.glob("/etc/netplan/*.yaml")):
    doc = yaml.safe_load(open(path)) or {}
    touched = False
    for cfg in ((doc.get("network") or {}).get("ethernets") or {}).values():
        if not isinstance(cfg, dict):
            continue
        for key, fields in (("routes", ("to", "via")), ("addresses", ())):
            items = cfg.get(key)
            if not items:
                continue
            keep = [i for i in items
                    if not (any(is_v6(i.get(f, "")) for f in fields) if isinstance(i, dict) else is_v6(i))]
            if len(keep) != len(items):
                touched = True
                if keep:
                    cfg[key] = keep
                else:
                    del cfg[key]
        if cfg.get("accept-ra") is not False:
            cfg["accept-ra"] = False
            touched = True
        if cfg.get("link-local") != []:
            cfg["link-local"] = []
            touched = True
    if touched:
        backup = os.path.join(backup_dir, os.path.basename(path))
        if not os.path.exists(backup):
            shutil.copy2(path, backup)
        tmp = path + ".tmp"
        with open(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as f:
            yaml.safe_dump(doc, f, default_flow_style=False, sort_keys=False)
        os.replace(tmp, path)
        changed.append(os.path.basename(path))
print(" ".join(changed))
PY
)
if [ -n "$netplan_changed" ]; then
    if ! netplan generate 2>"$work/netplan.err"; then
        for f in $netplan_changed; do cp -p "$NETPLAN_BACKUP/$f" "/etc/netplan/$f"; done
        netplan generate
        die "edited netplan did not validate; originals restored: $(cat "$work/netplan.err")"
    fi
    netplan apply
    log "IPv6 entries removed from netplan: $netplan_changed"
fi
reboot_needed=""
grep -qw 'ipv6.disable=1' /proc/cmdline || reboot_needed=yes
log "IPv6 disabled"
}

# Step 3. Sets reboot_needed_qdisc when fq pacing starts only after a reboot.
host_tcp_tuning() {
# 3. TCP sending tuned for the long-distance path to the clients (ADR-0007).
#    - BBR sets the sending rate from measured bandwidth and round-trip time,
#      so a lost packet does not halve it the way the default (CUBIC) does
#    - fq paces the packets BBR sends
#    - buffers may grow to 16 MB, enough to fill a fast link at a 200 ms round trip
#    - a connection that was idle resumes at its previous rate
#    - when large packets vanish on the path, TCP tries smaller ones
#    The modules are listed for boot, so the settings file finds them loaded.
printf 'tcp_bbr\nsch_fq\n' > "$TCP_MODULES_CONF"
chmod 644 "$TCP_MODULES_CONF"
modprobe tcp_bbr || die "kernel module tcp_bbr is not available"
modprobe sch_fq || die "kernel module sch_fq is not available"
cat > "$TCP_SYSCTL_CONF" <<EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_rmem = 4096 131072 $TCP_BUFFER_MAX
net.ipv4.tcp_wmem = 4096 16384 $TCP_BUFFER_MAX
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
EOF
chmod 644 "$TCP_SYSCTL_CONF"
sysctl -q -p "$TCP_SYSCTL_CONF"
[ "$(sysctl -n net.ipv4.tcp_congestion_control)" = bbr ] || die "BBR congestion control did not take effect"
# The default queueing discipline applies only to queues created from now on.
# The interface that carries the default route gets it now; replacing the root
# of a multi-queue interface recreates its per-queue children with the default.
wan_dev=$(ip -4 route show default | awk '{for (i = 1; i < NF; i++) if ($i == "dev") {print $(i + 1); exit}}')
[ -n "$wan_dev" ] || die "could not find the interface of the default route"
qdisc_is_fq() { ! tc qdisc show dev "$wan_dev" | grep -qv -e '^qdisc mq ' -e '^qdisc fq '; }
if ! qdisc_is_fq; then
    if [ "$(find "/sys/class/net/$wan_dev/queues" -maxdepth 1 -name 'tx-*' | wc -l)" -gt 1 ]; then
        tc qdisc replace dev "$wan_dev" root mq
    else
        tc qdisc replace dev "$wan_dev" root fq
    fi
fi
if qdisc_is_fq; then
    log "TCP tuned: BBR congestion control, fq pacing on $wan_dev"
else
    reboot_needed_qdisc=yes
    log "TCP tuned: BBR congestion control; fq pacing on $wan_dev starts at the next reboot"
fi
}

# Step 4. Leaves the panel on loopback, the subscription service off, and the
# API helpers defined.
host_panel() {
# 4. 3x-ui, pinned. The installer prints the panel credentials, so its output
#    goes to a root-only log, never to this script's output.
installed_version=""
[ -x "$XUI_BIN" ] && installed_version=$("$XUI_BIN" -v 2>/dev/null | head -n1 || true)
if [ "v$installed_version" != "$XUI_VERSION" ]; then
    curl -fsSL --retry 3 -o "$work/install.sh" "$XUI_INSTALL_URL"
    echo "$XUI_INSTALL_SHA256  $work/install.sh" | sha256sum -c --quiet - \
        || die "3x-ui install script checksum mismatch"
    log "installing 3x-ui $XUI_VERSION"
    XUI_NONINTERACTIVE=1 XUI_SSL_MODE=none XUI_ENABLE_FAIL2BAN=false \
        bash "$work/install.sh" "$XUI_VERSION" > "$INSTALL_LOG" 2>&1 \
        || die "3x-ui install failed; see $INSTALL_LOG on the VPS"
    chmod 600 "$INSTALL_LOG"
else
    log "3x-ui $XUI_VERSION already installed"
fi
[ -x "$XUI_BIN" ] || die "3x-ui binary missing after install"
[ -r "$XUI_RESULT" ] || die "$XUI_RESULT missing; the panel API token is unknown"

# Panel on loopback only. Reached through an SSH tunnel, never from the internet.
if ! "$XUI_BIN" setting -getListen 2>/dev/null | grep -q '127\.0\.0\.1'; then
    "$XUI_BIN" setting -listenIP 127.0.0.1 >/dev/null
    systemctl restart x-ui
    log "panel bound to 127.0.0.1"
fi
systemctl enable x-ui >/dev/null 2>&1
systemctl is-active --quiet x-ui || systemctl start x-ui

# shellcheck disable=SC1090
. "$XUI_RESULT"
[ -n "${XUI_PANEL_PORT:-}" ] && [ -n "${XUI_API_TOKEN:-}" ] || die "$XUI_RESULT is incomplete"
readonly BASE="http://127.0.0.1:${XUI_PANEL_PORT}/${XUI_WEB_BASE_PATH:-}"

# The token goes through a curl config file, so it never shows in the process list.
printf 'header = "Authorization: Bearer %s"\n' "$XUI_API_TOKEN" > "$work/curlrc"
api() { # api <path> [curl args...]  -> response body
    local path=$1; shift
    curl -sS --fail --max-time 60 -K "$work/curlrc" "$@" "${BASE%/}/$path"
}
api_ok() { # api_ok <what> <path> [curl args...]  -> dies unless success:true
    local what=$1; shift
    local out
    out=$(api "$@") || die "$what: request failed"
    [ "$(printf '%s' "$out" | jq -r '.success')" = true ] \
        || die "$what: $(printf '%s' "$out" | jq -r '.msg')"
    printf '%s' "$out"
}
wait_api() {
    local _
    for _ in $(seq 1 30); do
        api panel/api/inbounds/list >/dev/null 2>&1 && return 0
        sleep 1
    done
    die "panel API did not answer on loopback"
}
wait_api

# Subscription service off: it listens on every interface and is not used.
api_ok "read settings" panel/api/setting/all -X POST | jq '.obj' > "$work/settings.json"
if [ "$(jq -r '[.subEnable, .subJsonEnable, .subClashEnable] | any' "$work/settings.json")" = true ]; then
    jq '.subEnable=false | .subJsonEnable=false | .subClashEnable=false' "$work/settings.json" > "$work/settings.new.json"
    api_ok "update settings" panel/api/setting/update -X POST \
        -H 'Content-Type: application/json' -d @"$work/settings.new.json" >/dev/null
    systemctl restart x-ui
    wait_api
    log "subscription service disabled"
fi
}

# The closing notes about a reboot that is still needed.
host_reboot_notes() {
if [ -n "$reboot_needed" ]; then
    log "REBOOT NEEDED: IPv6 is off now, but stays off across restarts only after one reboot"
fi
if [ -n "${reboot_needed_qdisc:-}" ]; then
    log "REBOOT NEEDED: fq pacing on the network interface starts only after a reboot"
fi
if [ -e /var/run/reboot-required ]; then
    log "REBOOT NEEDED: an installed update takes effect only after a reboot (automatic at $AUTO_REBOOT_TIME $HOST_TIMEZONE otherwise)"
fi
return 0
}
