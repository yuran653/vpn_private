#!/usr/bin/env bash
# deploy-vpn.sh - VLESS over XHTTP behind Cloudflare, on the Thailand VPS (Ubuntu 22.04/24.04).
#
# Installs the 3x-ui panel (pinned release), binds it to loopback, and configures
# Xray through the panel API:
#   1. unattended security upgrades on, pending ones installed now, and an
#      automatic reboot at 04:00 server time when an update needs one (ADR-0006)
#   2. IPv6 disabled on the host (kernel parameter; needs one reboot after the first run)
#   3. TCP sending tuned for the long-distance path to the clients: BBR
#      congestion control, fq pacing, larger buffers (ADR-0007)
#   4. 3x-ui installed from the pinned release, panel on 127.0.0.1 only,
#      subscription service off
#   5. Xray template: all client traffic out through Cloudflare WARP (the server
#      is registered once as a free WARP device, ADR-0008), encrypted DNS,
#      IPv4-only egress, port-53 capture, no access log
#   6. the cover site (ADR-0012), published through Cloudflare (ADR-0013): the
#      owner's own website. nginx answers on 80/tcp and, with a Let's Encrypt
#      certificate, on 443/tcp; the pages come from a Docker container
#      published on loopback only. One random path on 443 is the tunnel
#   7. one VLESS + XHTTP inbound on loopback with one client, behind nginx; the
#      VLESS + Reality inbound that held 443 before is removed (cut-over)
#   8. ufw: 80/tcp and 443/tcp admitted from Cloudflare's IPv4 ranges only
#   9. the client link written to /root/vpn/vless-link.txt (mode 600); it
#      names status.casedigestai.com, not the server's address
#
# Usage, on the VPS as root or via sudo, with the repo's site/ folder next to
# this script (or its path in SITE_SRC):
#   sudo -n bash deploy-vpn.sh
#
# Run scripts/harden-vps.sh first: this script expects ufw to be active.
# Both cover names must be proxied by Cloudflare (orange cloud, SSL mode
# "Full (strict)") before the run; the script checks that they resolve to
# Cloudflare only and stops before it changes the tunnel if not.
#
# Safe to re-run. Keys, the client ID and panel credentials are generated once
# and kept; a re-run reapplies the settings and leaves the client link unchanged.
# The first run after ADR-0013 replaces the Reality link: every device imports
# the new one.
# The Xray template is owned by this script: edits made to it in the panel are
# overwritten on the next run.
#
# Prints no secret. Panel credentials stay in /etc/x-ui/install-result.env, the
# client link in /root/vpn/vless-link.txt and the WARP registration in
# /root/vpn/warp.json, all readable by root only.

set -euo pipefail

readonly XUI_VERSION=v3.11.0
readonly XUI_INSTALL_URL="https://raw.githubusercontent.com/MHSanaei/3x-ui/${XUI_VERSION}/install.sh"
readonly XUI_INSTALL_SHA256=9684bae4f769b2127fcceceb4f200045657381311867529e6ba76c6b58e2825d
readonly XUI_BIN=/usr/local/x-ui/x-ui
readonly XUI_RESULT=/etc/x-ui/install-result.env

readonly VPN_PORT=443
# Cover site (ADR-0012) behind Cloudflare (ADR-0013). Clients connect to
# COVER_NAME, which Cloudflare proxies to nginx on VPN_PORT. Both names are on
# one Let's Encrypt certificate. nginx takes the pages from the site container
# on COVER_SITE_PORT and hands the tunnel path to Xray on XHTTP_PORT. Before
# the cut-over nginx's TLS side waits on STAGING_TLS_PORT. All three are on
# loopback only.
readonly COVER_DOMAIN=casedigestai.com
readonly COVER_NAME=status.casedigestai.com
readonly STAGING_TLS_PORT=8443
readonly COVER_SITE_PORT=8080
readonly XHTTP_PORT=10443
readonly COVER_DIR=/opt/cover-site
readonly COVER_NGINX_CONF=/etc/nginx/conf.d/cover-site.conf
readonly COVER_CERT_DIR=/etc/letsencrypt/live/$COVER_DOMAIN
readonly COVER_PAGE_TEXT='CaseDigest AI'
readonly ACME_ROOT=/var/www/acme
readonly SITE_SRC=${SITE_SRC:-$(cd "$(dirname "$0")" && pwd)/site}
# The inbound's name is the profile name the client app shows (ADR-0011).
readonly INBOUND_REMARK='กรุงเทพฯ cloud.z.com'
readonly CLIENT_EMAIL=owner

readonly STATE_DIR=/root/vpn
readonly LINK_FILE=$STATE_DIR/vless-link.txt
readonly XHTTP_PATH_FILE=$STATE_DIR/xhttp-path
# Cloudflare's published IPv4 ranges; only they reach 80 and 443 (ADR-0013).
readonly CF_IPS_URL=https://www.cloudflare.com/ips-v4
readonly CF_IPS_FILE=$STATE_DIR/cloudflare-ips-v4.txt
readonly CF_RULE_COMMENT=cloudflare
readonly INSTALL_LOG=$STATE_DIR/install.log
# Cloudflare WARP (ADR-0008). The registration is made once and kept in
# WARP_FILE. The endpoint is an address literal, so reaching WARP needs no
# name lookup; 1280 is the packet size Cloudflare's own client uses.
# The endpoint is the address that Cloudflare's Bangkok site answers from this
# host, 1.4 ms away. The default one, 162.159.192.1, is answered in Singapore,
# 27 ms away (ADR-0009).
readonly WARP_FILE=$STATE_DIR/warp.json
readonly WARP_API=https://api.cloudflareclient.com/v0a2158
readonly WARP_ENDPOINT=188.114.97.1:2408
readonly WARP_MTU=1280
readonly SYSCTL_CONF=/etc/sysctl.d/60-vpn-disable-ipv6.conf
readonly GRUB_CONF=/etc/default/grub.d/60-vpn-disable-ipv6.cfg
readonly NETPLAN_BACKUP=$STATE_DIR/netplan-backup
readonly AUTO_UPGRADES=/etc/apt/apt.conf.d/20auto-upgrades
readonly AUTO_REBOOT=/etc/apt/apt.conf.d/52vpn-auto-reboot
readonly AUTO_REBOOT_TIME=04:00
readonly TCP_SYSCTL_CONF=/etc/sysctl.d/60-vpn-tcp.conf
readonly TCP_MODULES_CONF=/etc/modules-load.d/vpn-tcp.conf
# Upper limit of one TCP connection's send and receive buffer. The kernel grows
# a buffer towards it only while the connection needs it (ADR-0007).
readonly TCP_BUFFER_MAX=16777216
readonly UFW_BEFORE=/etc/ufw/before.rules
# The per-address limits on the VPN port (ADR-0005) are removed by this marker:
# every client now arrives from a shared Cloudflare address (ADR-0013).
readonly LIMITS_MARKER='vpn-server port limits'

log() { printf '[deploy] %s\n' "$*"; }
die() { printf '[deploy] error: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root: sudo -n bash $0"
[ "$(uname -m)" = x86_64 ] || die "only x86_64 is supported"
# shellcheck disable=SC1091
. /etc/os-release
[ "${ID:-}" = ubuntu ] || die "only Ubuntu is supported"
ufw status | grep -q '^Status: active' || die "ufw is not active; run scripts/harden-vps.sh first"
[ -s "$SITE_SRC/docker-compose.yml" ] && [ -s "$SITE_SRC/html/index.html" ] \
    || die "site folder not found at $SITE_SRC; copy the repo's site/ folder next to this script"

umask 077
install -d -m 700 "$STATE_DIR"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

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
cat > "$AUTO_REBOOT" <<EOF
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
Unattended-Upgrade::Automatic-Reboot-Time "$AUTO_REBOOT_TIME";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
EOF
chmod 644 "$AUTO_REBOOT"
systemctl enable --now unattended-upgrades >/dev/null 2>&1
log "unattended upgrades enabled, automatic reboot at $AUTO_REBOOT_TIME"
# Install what is pending now instead of waiting for the nightly timer: a fresh
# provider image is months behind. Quick when nothing is pending.
log "installing pending security updates (the first run can take several minutes)"
PYTHONWARNINGS=ignore unattended-upgrade || die "unattended-upgrade failed; see /var/log/unattended-upgrades/ on the VPS"
log "security updates installed"

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

# 5. WARP device, registered once (ADR-0008). Client traffic leaves through
#    Cloudflare WARP, because Google places this server's own address in a
#    country where some of its services are not offered. Registering accepts
#    Cloudflare's terms of service for the owner. The key pair is made here; the
#    answer carries the tunnel address, the peer key and the three "reserved"
#    bytes that Cloudflare expects in every packet. Nothing of it is printed.
if [ ! -s "$WARP_FILE" ]; then
    openssl genpkey -algorithm X25519 -outform DER -out "$work/warp.key"
    warp_private=$(tail -c 32 "$work/warp.key" | base64)
    warp_public=$(openssl pkey -inform DER -in "$work/warp.key" -pubout -outform DER | tail -c 32 | base64)
    jq -n --arg key "$warp_public" --arg tos "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" \
        '{key: $key, tos: $tos, type: "PC", model: "PC", locale: "en_US", install_id: "", fcm_token: ""}' \
        > "$work/warp-request.json"
    curl -fsS --retry 3 --max-time 30 -X POST "$WARP_API/reg" \
        -H 'CF-Client-Version: a-6.30-3596' -H 'User-Agent: okhttp/3.12.1' \
        -H 'Content-Type: application/json' -d @"$work/warp-request.json" \
        -o "$work/warp-answer.json" || die "WARP registration request failed"
    warp_reserved=$(jq -r '.config.client_id // empty' "$work/warp-answer.json" | base64 -d 2>/dev/null \
        | od -An -tu1 | xargs | tr ' ' ',')
    printf '%s' "$warp_reserved" | grep -Eq '^[0-9]+,[0-9]+,[0-9]+$' \
        || die "WARP registration answer has no usable client_id"
    jq -e --arg private "$warp_private" --argjson reserved "[$warp_reserved]" '{
        private_key: $private, device_id: .id, token: .token,
        address: .config.interface.addresses.v4,
        peer_public_key: .config.peers[0].public_key,
        reserved: $reserved}
        | select((.address | type) == "string" and (.peer_public_key | type) == "string")' \
        "$work/warp-answer.json" > "$work/warp.json" \
        || die "WARP registration answer is incomplete"
    jq -r '.address' "$work/warp.json" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' \
        || die "WARP registration gave no IPv4 tunnel address"
    install -m 600 "$work/warp.json" "$WARP_FILE"
    log "WARP device registered"
else
    log "WARP device already registered; kept"
fi
chmod 600 "$WARP_FILE"

#    Xray template: the panel's default plus this project's rules.
#    - warp: the only way out. It is the first outbound, so it carries whatever
#      the rules do not block, and the default "direct" outbound is removed:
#      when WARP is down a request fails, it never leaves from this server's
#      own address. IPv4 only; the tunnel runs inside Xray, not as a host interface
#    - dns: every lookup goes out over DoH through the same outbound, IPv4 answers only
#    - port 53 from clients is answered by that DNS, whatever resolver they asked
#    - IPv6 destinations are refused
#    - log.access stays "none": no record of who connected to what
api_ok "read default template" panel/api/xray/getDefaultJsonConfig | jq \
    --slurpfile warp "$WARP_FILE" --arg endpoint "$WARP_ENDPOINT" --argjson mtu "$WARP_MTU" '.obj
    | .log.access = "none"
    | .log.dnsLog = false
    | .dns = {servers: ["https://1.1.1.1/dns-query", "https://8.8.8.8/dns-query"], queryStrategy: "UseIPv4"}
    | .outbounds = [{protocol: "wireguard", tag: "warp", settings: {
            secretKey: $warp[0].private_key, address: [$warp[0].address + "/32"],
            peers: [{publicKey: $warp[0].peer_public_key, endpoint: $endpoint, allowedIPs: ["0.0.0.0/0"]}],
            reserved: $warp[0].reserved, mtu: $mtu, domainStrategy: "ForceIPv4", noKernelTun: true}}]
        + [.outbounds[] | select(.protocol != "freedom")]
        + [{protocol: "dns", tag: "dns-out"}]
    | .routing.rules = [.routing.rules[0],
        {type: "field", port: "53", outboundTag: "dns-out"},
        {type: "field", ip: ["::/0"], outboundTag: "blocked"}] + .routing.rules[1:]' > "$work/template.json"
[ "$(jq -r '.routing.rules[0].outboundTag' "$work/template.json")" = api ] \
    || die "default template changed shape: first routing rule is not the api rule"
[ "$(jq -r '[.outbounds[0].tag, ([.outbounds[] | select(.protocol == "freedom")] | length)] | join(" ")' "$work/template.json")" = "warp 0" ] \
    || die "template still has a way out that is not WARP"
api_ok "save template" panel/api/xray/update -X POST \
    --data-urlencode "xraySetting@$work/template.json" >/dev/null
log "xray template applied"


# 6. Cover site (ADR-0012), published through Cloudflare (ADR-0013). The
#    website of COVER_DOMAIN and COVER_NAME runs on this host; Cloudflare
#    proxies both names, and nginx on 443 hands the tunnel path to Xray.
#    Everything in this step is in place and tested before the cut-over in
#    step 7: a failure here leaves the tunnel as it was.
case "$XUI_PANEL_PORT" in
    "$STAGING_TLS_PORT"|"$COVER_SITE_PORT"|"$XHTTP_PORT") die "the panel port collides with a cover site or tunnel port" ;;
esac
public_ip=$(ip -4 route get 1.1.1.1 | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}')
printf '%s' "$public_ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || die "could not read the public IPv4 address"
# nginx's packaged default site listens on IPv6, which this host does not have,
# so the package's own first start fails and takes the install down with it.
# The start is held back during the install; nginx starts below, once this
# script's config is in place.
if ! dpkg -s nginx >/dev/null 2>&1; then
    printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
    chmod 755 /usr/sbin/policy-rc.d
    apt-get install -y -qq nginx >/dev/null || { rm -f /usr/sbin/policy-rc.d; die "nginx install failed"; }
    rm -f /usr/sbin/policy-rc.d
fi
apt-get install -y -qq certbot docker.io docker-compose-v2 >/dev/null

# Docker publishes ports past ufw, so its default bind address is loopback: a
# container started without an explicit address is still not reachable from
# outside. Containers keep no logs and get no IPv6.
install -d -m 755 /etc/docker
cat > "$work/daemon.json" <<'EOF'
{
  "ip": "127.0.0.1",
  "ipv6": false,
  "log-driver": "none"
}
EOF
if ! cmp -s "$work/daemon.json" /etc/docker/daemon.json; then
    install -m 644 "$work/daemon.json" /etc/docker/daemon.json
    systemctl restart docker
fi
systemctl enable --now docker >/dev/null 2>&1

# The site container. Its files are overwritten in place on every run: the
# container holds the folder and the config file open by inode, so replacing
# either with a new one would leave it serving the old copy.
install -d -m 755 "$COVER_DIR" "$COVER_DIR/html"
cp -R "$SITE_SRC/html/." "$COVER_DIR/html/"
cat "$SITE_SRC/nginx.conf" > "$COVER_DIR/nginx.conf"
install -m 644 "$SITE_SRC/docker-compose.yml" "$COVER_DIR/docker-compose.yml"
chmod -R a+rX "$COVER_DIR"
docker compose --project-directory "$COVER_DIR" up -d --quiet-pull >/dev/null 2>"$work/compose.err" \
    || die "the site container did not start: $(tail -n 3 "$work/compose.err")"
docker compose --project-directory "$COVER_DIR" exec -T site nginx -s reload >/dev/null 2>&1 || true
# Waits until a URL returns the landing page. The page is captured first: with
# pipefail, grep -q closing the pipe early would fail the pipeline. A reload of
# nginx returns before the new listener is up, hence the retries.
serves_page() { # serves_page <curl args...>
    local body _
    for _ in $(seq 1 20); do
        body=$(curl -fsS --max-time 5 "$@" 2>/dev/null) || body=""
        case "$body" in *"$COVER_PAGE_TEXT"*) return 0 ;; esac
        sleep 1
    done
    return 1
}
serves_page "http://127.0.0.1:$COVER_SITE_PORT/" \
    || die "the site container does not serve the landing page on loopback"
if ss -Htln "sport = :$COVER_SITE_PORT" | awk '{print $4}' | grep -qv '^127\.'; then
    die "the site container listens on a public address"
fi
log "site container running on loopback"

# Cloudflare's published IPv4 ranges (ADR-0013). Only these may reach 80 and
# 443. Fetched on every run; the last good copy is used when the fetch fails.
if curl -fsS --retry 3 --max-time 20 "$CF_IPS_URL" -o "$work/cf-ips" \
    && [ "$(grep -Ecx '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}' "$work/cf-ips")" -ge 5 ] \
    && ! grep -Evqx '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}' "$work/cf-ips"; then
    install -m 600 "$work/cf-ips" "$CF_IPS_FILE"
elif [ -s "$CF_IPS_FILE" ]; then
    log "could not fetch Cloudflare's ranges; using the copy from the last run"
else
    die "could not fetch Cloudflare's IPv4 ranges from $CF_IPS_URL"
fi
mapfile -t cf_ranges < "$CF_IPS_FILE"

# Both names must resolve to Cloudflare only: the domain is on Cloudflare and
# both records are proxied. Checked before a certificate is requested and
# before the cut-over, so the tunnel never moves to a name that does not lead
# through Cloudflare.
names_on_cloudflare() {
    local name resolved
    for name in "$COVER_DOMAIN" "$COVER_NAME"; do
        resolved=$(getent ahostsv4 "$name" | awk '{print $1}' | sort -u | tr '\n' ' ')
        [ -n "$resolved" ] || die "$name does not resolve; add it in Cloudflare as a proxied record (the tunnel is unchanged)"
        # shellcheck disable=SC2086
        python3 -I - "$CF_IPS_FILE" $resolved <<'PY' \
            || die "$name resolves to '$resolved', not only to Cloudflare; switch the record to Proxied in Cloudflare and run again (the tunnel is unchanged)"
import ipaddress, sys
nets = [ipaddress.ip_network(l.strip()) for l in open(sys.argv[1]) if l.strip()]
sys.exit(0 if all(any(ipaddress.ip_address(a) in n for n in nets) for a in sys.argv[2:]) else 1)
PY
    done
}
names_on_cloudflare
log "both names resolve to Cloudflare only"

# Firewall: 80 and 443 from Cloudflare's ranges. Rules for ranges Cloudflare
# no longer lists are deleted. The rules that admit everyone are deleted at the
# cut-over, in step 7.
for range in "${cf_ranges[@]}"; do
    for port in 80 "$VPN_PORT"; do
        ufw allow proto tcp from "$range" to any port "$port" comment "$CF_RULE_COMMENT" >/dev/null
    done
done
ufw status | awk -v c="# $CF_RULE_COMMENT" 'index($0, c) {print $1 " " $3}' | sort -u > "$work/cf-rules"
while read -r portspec range; do
    printf '%s\n' "${cf_ranges[@]}" | grep -qxF "$range" && continue
    ufw delete allow proto tcp from "$range" to any port "${portspec%/tcp}" >/dev/null || true
done < "$work/cf-rules"
log "80/tcp and ${VPN_PORT}/tcp admitted from Cloudflare's ${#cf_ranges[@]} ranges"

# The tunnel path: made once, kept in the inbound once that exists. A copy is
# kept root-only so the web server config can be written before the inbound.
inbound_id() { # inbound_id <port>
    api_ok "list inbounds" panel/api/inbounds/list \
        | jq -r --argjson p "$1" '[.obj[] | select(.port == $p)][0].id // empty'
}
xhttp_id=$(inbound_id "$XHTTP_PORT")
if [ -n "$xhttp_id" ]; then
    api_ok "read inbound" "panel/api/inbounds/get/$xhttp_id" \
        | jq -r '.obj.streamSettings | (if type == "string" then fromjson else . end) | .xhttpSettings.path' > "$XHTTP_PATH_FILE"
elif [ ! -s "$XHTTP_PATH_FILE" ]; then
    printf '/%s\n' "$(openssl rand -hex 12)" > "$XHTTP_PATH_FILE"
fi
chmod 600 "$XHTTP_PATH_FILE"
xhttp_path=$(cat "$XHTTP_PATH_FILE")
printf '%s' "$xhttp_path" | grep -Eqx '/[0-9a-f]{24}' || die "the tunnel path in $XHTTP_PATH_FILE is malformed"

# nginx on the host. Port 80 serves the certificate challenge and redirects the
# rest to HTTPS. The TLS side serves the site and the tunnel path. Until the
# cut-over it listens on loopback, because Reality still holds 443; after it,
# it holds 443. No access log is kept (R-vpn-server-06.b).
rm -f /etc/nginx/sites-enabled/default
sed -i -E 's|^([[:space:]]*)access_log[[:space:]].*;|\1access_log off;|' /etc/nginx/nginx.conf
install -d -m 755 "$ACME_ROOT"
cover_domain_re=${COVER_DOMAIN//./\\.}
cover_name_re=${COVER_NAME//./\\.}
write_nginx_conf() { # write_nginx_conf [<tls listen address>]
    cat > "$work/cover-site.conf" <<EOF
# Written by deploy-vpn.sh (ADR-0012, ADR-0013). Edits are overwritten on the next run.
server {
    listen 80 default_server;
    server_name $COVER_DOMAIN $COVER_NAME;
    server_tokens off;
    access_log off;
    set \$cover_host $COVER_DOMAIN;
    if (\$host ~ ^($cover_domain_re|$cover_name_re)\$) { set \$cover_host \$host; }
    location ^~ /.well-known/acme-challenge/ { root $ACME_ROOT; default_type text/plain; }
    location / { return 301 https://\$cover_host\$request_uri; }
}
EOF
    if [ -n "${1:-}" ]; then
        cat >> "$work/cover-site.conf" <<EOF
server {
    listen $1 ssl http2 default_server;
    server_name $COVER_DOMAIN $COVER_NAME;
    server_tokens off;
    access_log off;
    ssl_certificate $COVER_CERT_DIR/fullchain.pem;
    ssl_certificate_key $COVER_CERT_DIR/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_tickets off;
    location ^~ /.well-known/acme-challenge/ { root $ACME_ROOT; default_type text/plain; }
    # The tunnel (ADR-0013): VLESS over XHTTP, to Xray on loopback.
    location ^~ $xhttp_path {
        client_max_body_size 0;
        client_body_timeout 5m;
        grpc_pass grpc://127.0.0.1:$XHTTP_PORT;
        grpc_read_timeout 5m;
        grpc_send_timeout 5m;
        grpc_socket_keepalive on;
    }
    location / {
        proxy_pass http://127.0.0.1:$COVER_SITE_PORT;
        proxy_set_header Host \$host;
        # Cloudflare injects its bot-detection script into HTML unless the
        # response forbids changes; the free plan has no switch for it
        # (R-vpn-server-15.c).
        add_header Cache-Control "no-transform" always;
    }
}
EOF
    fi
    if ! cmp -s "$work/cover-site.conf" "$COVER_NGINX_CONF"; then
        [ -e "$COVER_NGINX_CONF" ] && cp -p "$COVER_NGINX_CONF" "$work/cover-site.conf.bak"
        install -m 644 "$work/cover-site.conf" "$COVER_NGINX_CONF"
        if ! nginx -t >/dev/null 2>"$work/nginx.err"; then
            if [ -e "$work/cover-site.conf.bak" ]; then
                cp -p "$work/cover-site.conf.bak" "$COVER_NGINX_CONF"
            else
                rm -f "$COVER_NGINX_CONF"
            fi
            die "nginx rejected the cover site config: $(tail -n 2 "$work/nginx.err")"
        fi
    fi
    systemctl enable nginx >/dev/null 2>&1
    systemctl reload-or-restart nginx
}
cert_covers_names() {
    [ -s "$COVER_CERT_DIR/fullchain.pem" ] \
        && openssl x509 -in "$COVER_CERT_DIR/fullchain.pem" -noout -checkend 0 >/dev/null \
        && openssl x509 -in "$COVER_CERT_DIR/fullchain.pem" -noout -checkhost "$COVER_DOMAIN" | grep -q 'does match' \
        && openssl x509 -in "$COVER_CERT_DIR/fullchain.pem" -noout -checkhost "$COVER_NAME" | grep -q 'does match'
}
reality_id=$(api_ok "list inbounds" panel/api/inbounds/list \
    | jq -r --argjson p "$VPN_PORT" '[.obj[] | select(.port == $p and .protocol == "vless")][0].id // empty')
# Until Xray lets go of 443, nginx's TLS side waits on loopback. Decided by who
# holds the port, not by the inbound list: a deleted inbound keeps its port
# until Xray restarts.
if [ -n "$reality_id" ] || ss -Htlnp "sport = :$VPN_PORT" | grep -q '"xray'; then
    tls_port=$STAGING_TLS_PORT; tls_listen=127.0.0.1:$STAGING_TLS_PORT
else
    tls_port=$VPN_PORT; tls_listen=$VPN_PORT
fi
if cert_covers_names; then write_nginx_conf "$tls_listen"; else write_nginx_conf; fi

# Certificate for both names from Let's Encrypt, by a challenge file served on
# port 80; Cloudflare passes the challenge through to this host. Requested only
# when no valid certificate covers both names. Requesting accepts Let's
# Encrypt's subscriber agreement for the owner; no email address is registered.
install -d -m 755 /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh <<'EOF'
#!/bin/sh
systemctl reload nginx
EOF
chmod 755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
if ! cert_covers_names; then
    certbot certonly --webroot -w "$ACME_ROOT" --cert-name "$COVER_DOMAIN" \
        -d "$COVER_DOMAIN" -d "$COVER_NAME" --non-interactive --agree-tos \
        --register-unsafely-without-email > "$STATE_DIR/certbot.log" 2>&1 \
        || die "the certificate was not issued; see $STATE_DIR/certbot.log on the VPS (the tunnel is unchanged)"
    cert_covers_names || die "the issued certificate does not cover both names"
    write_nginx_conf "$tls_listen"
    log "certificate issued for $COVER_DOMAIN and $COVER_NAME"
else
    log "certificate for $COVER_DOMAIN and $COVER_NAME is valid; kept"
fi
systemctl enable --now certbot.timer >/dev/null 2>&1
# The site must answer over TLS on loopback, with a certificate that validates
# for each name, before the cut-over.
for name in "$COVER_DOMAIN" "$COVER_NAME"; do
    serves_page --http2 --resolve "$name:$tls_port:127.0.0.1" "https://$name:$tls_port/" \
        || die "the cover site does not answer for $name on loopback (the tunnel is unchanged)"
done
log "cover site answers for both names on loopback"

# 7. Cut-over (ADR-0013). The Reality inbound on 443 is deleted and the XHTTP
#    inbound takes its client ID; the inbound as it was is kept, root-only, so
#    the change can be undone by hand. A client email is unique across the
#    panel, so the old inbound goes first. Then nginx takes 443 and the rules
#    that admitted everyone to 80 and 443 go.
if [ -n "$reality_id" ]; then
    api_ok "read inbound" "panel/api/inbounds/get/$reality_id" | jq '.obj | del(.clientStats)' > "$work/reality.json"
    install -m 600 "$work/reality.json" "$STATE_DIR/inbound-previous.json"
    api_ok "delete Reality inbound" "panel/api/inbounds/del/$reality_id" -X POST >/dev/null
    log "Reality inbound removed; kept in $STATE_DIR/inbound-previous.json"
fi
if [ -z "$xhttp_id" ]; then
    uuid=""
    [ -s "$STATE_DIR/inbound-previous.json" ] && uuid=$(jq -r --arg email "$CLIENT_EMAIL" \
        '.settings | (if type == "string" then fromjson else . end) | .clients[] | select(.email == $email) | .id' \
        "$STATE_DIR/inbound-previous.json" 2>/dev/null | head -n1)
    printf '%s' "$uuid" | grep -Eq '^[0-9a-f-]{36}$' \
        || uuid=$(api_ok "new uuid" panel/api/server/getNewUUID | jq -r '.obj.uuid // .obj')
    printf '%s' "$uuid" | grep -Eq '^[0-9a-f-]{36}$' || die "panel returned no UUID"
    # 3x-ui keeps clients in their own table: deleting an inbound leaves its
    # client behind, and a new inbound may not reuse that email. The leftover
    # client, attached to no inbound, is deleted; its ID is reused above.
    if api panel/api/clients/get/"$CLIENT_EMAIL" 2>/dev/null | jq -e '.success == true' >/dev/null; then
        api_ok "delete leftover client" panel/api/clients/del/"$CLIENT_EMAIL" -X POST >/dev/null
        log "leftover client '$CLIENT_EMAIL' from the removed inbound deleted"
    fi
    jq -n --arg uuid "$uuid" --arg path "$xhttp_path" --arg remark "$INBOUND_REMARK" \
        --arg email "$CLIENT_EMAIL" --argjson port "$XHTTP_PORT" '{
        enable: true, remark: $remark, listen: "127.0.0.1", port: $port, protocol: "vless",
        expiryTime: 0, total: 0,
        settings: {
            clients: [{id: $uuid, email: $email, flow: "", enable: true,
                       limitIp: 0, totalGB: 0, expiryTime: 0}],
            decryption: "none", fallbacks: []},
        streamSettings: {
            network: "xhttp", security: "none", externalProxy: [],
            xhttpSettings: {path: $path, host: "", headers: {}, mode: "auto"}},
        sniffing: {enabled: true, destOverride: ["http", "tls", "quic"],
                   metadataOnly: false, routeOnly: false}}' > "$work/inbound.json"
    api_ok "add inbound" panel/api/inbounds/add -X POST \
        -H 'Content-Type: application/json' -d @"$work/inbound.json" >/dev/null
    xhttp_id=$(inbound_id "$XHTTP_PORT")
    [ -n "$xhttp_id" ] || die "the XHTTP inbound was not created"
    log "XHTTP inbound created on 127.0.0.1:$XHTTP_PORT"
else
    log "XHTTP inbound already exists; client ID and path kept"
fi
# The inbound's name is the profile name in the client app (ADR-0011).
api_ok "read inbound" "panel/api/inbounds/get/$xhttp_id" | jq '.obj | del(.clientStats)' > "$work/inbound-now.json"
jq --arg remark "$INBOUND_REMARK" '.remark = $remark | .listen = "127.0.0.1"' \
    "$work/inbound-now.json" > "$work/inbound-want.json"
if [ "$(jq -S . "$work/inbound-now.json")" != "$(jq -S . "$work/inbound-want.json")" ]; then
    api_ok "update inbound" "panel/api/inbounds/update/$xhttp_id" -X POST \
        -H 'Content-Type: application/json' -d @"$work/inbound-want.json" >/dev/null
    log "XHTTP inbound updated: profile name, loopback only"
fi

api_ok "restart xray" panel/api/server/restartXrayService -X POST >/dev/null
listening=""
for _ in $(seq 1 20); do
    if ss -Htln "sport = :$XHTTP_PORT" | grep -q . \
        && ! ss -Htlnp "sport = :$VPN_PORT" | grep -q '"xray'; then listening=yes; break; fi
    sleep 1
done
[ -n "$listening" ] || die "xray is not listening on 127.0.0.1:$XHTTP_PORT or still holds ${VPN_PORT}: $(api panel/api/xray/getXrayResult | jq -r '.obj')"
if ss -Htln "sport = :$XHTTP_PORT" | awk '{print $4}' | grep -qv '^127\.'; then
    die "the XHTTP inbound listens on a public address"
fi
log "xray listening on 127.0.0.1:$XHTTP_PORT"

write_nginx_conf "$VPN_PORT"
for name in "$COVER_DOMAIN" "$COVER_NAME"; do
    serves_page --http2 --resolve "$name:$VPN_PORT:127.0.0.1" "https://$name:$VPN_PORT/" \
        || die "nginx does not answer for $name on ${VPN_PORT}"
done
log "nginx holds ${VPN_PORT}/tcp: site and tunnel path"

# 8. Firewall: only Cloudflare reaches 80 and 443 (added in step 6). The rules
#    that admitted everyone, and the per-address limits on 443 (ADR-0005,
#    superseded by ADR-0013), are removed.
for rule in "${VPN_PORT}/tcp" 80/tcp; do
    for _ in 1 2 3; do
        ufw status | grep -Eq "^$rule[[:space:]]+ALLOW[[:space:]]+Anywhere" || break
        ufw --force delete allow "$rule" >/dev/null || die "could not delete the ufw rule that admits everyone to $rule"
    done
    ! ufw status | grep -Eq "^$rule[[:space:]]+ALLOW[[:space:]]+Anywhere" \
        || die "the ufw rule that admits everyone to $rule is still there"
done
if grep -qxF "# BEGIN $LIMITS_MARKER" "$UFW_BEFORE"; then
    awk -v begin="# BEGIN $LIMITS_MARKER" -v end="# END $LIMITS_MARKER" '
        $0 == begin { skip = 1 } !skip { print } $0 == end { skip = 0 }' "$UFW_BEFORE" > "$work/before.rules"
    iptables-restore --test --noflush < "$work/before.rules" \
        || die "firewall rules without the port-443 limits did not validate; nothing changed"
    cp -p "$UFW_BEFORE" "$work/before.rules.bak"
    cat "$work/before.rules" > "$UFW_BEFORE"
    if ! ufw reload >/dev/null; then
        cat "$work/before.rules.bak" > "$UFW_BEFORE"
        ufw reload >/dev/null
        die "ufw did not reload without the port-443 limits; previous rules restored"
    fi
    log "per-address limits on ${VPN_PORT}/tcp removed"
fi
log "80/tcp and ${VPN_PORT}/tcp closed to everyone but Cloudflare"

# 9. Client link, built from what the panel stores. It names the host, not the
#    address: the client reaches Cloudflare, which reaches this server.
#    Written to a root-only file.
api_ok "read inbound" "panel/api/inbounds/get/$xhttp_id" | jq -r \
    --arg host "$COVER_NAME" --argjson port "$VPN_PORT" --arg email "$CLIENT_EMAIL" --arg name "$INBOUND_REMARK" '
    .obj as $in
    | ($in.settings | if type == "string" then fromjson else . end) as $s
    | ($in.streamSettings | if type == "string" then fromjson else . end) as $st
    | ($s.clients[] | select(.email == $email)) as $c
    | "vless://\($c.id)@\($host):\($port)?encryption=none&security=tls&sni=\($host)&fp=chrome&alpn=h2%2Chttp%2F1.1&type=xhttp&host=\($host)&path=\($st.xhttpSettings.path | @uri)&mode=auto#\($name | @uri)"' \
    > "$LINK_FILE"
chmod 600 "$LINK_FILE"
grep -q '^vless://' "$LINK_FILE" || die "client link was not written"
log "client link written to $LINK_FILE"
rm -f "$STATE_DIR/subscription-url.txt"

log "final state:"
systemctl is-active x-ui
ufw status | grep -v "# $CF_RULE_COMMENT" | sed -n '1,12p'
log "plus $(ufw status | grep -c "# $CF_RULE_COMMENT") rules admitting Cloudflare's ranges to 80 and ${VPN_PORT}"
if [ -n "$reboot_needed" ]; then
    log "REBOOT NEEDED: IPv6 is off now, but stays off across restarts only after one reboot"
fi
if [ -n "${reboot_needed_qdisc:-}" ]; then
    log "REBOOT NEEDED: fq pacing on the network interface starts only after a reboot"
fi
if [ -e /var/run/reboot-required ]; then
    log "REBOOT NEEDED: an installed update takes effect only after a reboot (automatic at $AUTO_REBOOT_TIME otherwise)"
fi
log "done"
