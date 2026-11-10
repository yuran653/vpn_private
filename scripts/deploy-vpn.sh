#!/usr/bin/env bash
# deploy-vpn.sh - VLESS + XTLS-Reality server on the Thailand VPS (Ubuntu 22.04/24.04).
#
# Installs the 3x-ui panel (pinned release), binds it to loopback, and configures
# Xray through the panel API:
#   1. unattended security upgrades on, pending ones installed now, and an
#      automatic reboot at 04:00 server time when an update needs one (ADR-0006)
#   2. IPv6 disabled on the host (kernel parameter; needs one reboot after the first run)
#   3. TCP sending tuned for the long-distance path to the clients: BBR
#      congestion control, fq pacing, larger buffers (ADR-0007)
#   4. 3x-ui installed from the pinned release, panel on 127.0.0.1 only,
#      subscription service on 127.0.0.1 only (ADR-0010)
#   5. Xray template: all client traffic out through Cloudflare WARP (the server
#      is registered once as a free WARP device, ADR-0008), encrypted DNS,
#      IPv4-only egress, port-53 capture, no access log
#   6. one VLESS + Reality + Vision inbound on 443/tcp with one client
#   7. ufw: 443/tcp allowed, with per-address limits on new connections (ADR-0005)
#   8. the client link written to /root/vpn/vless-link.txt (mode 600) and the
#      subscription address to /root/vpn/subscription-url.txt (mode 600)
#
# Usage, on the VPS as root or via sudo:
#   sudo -n bash deploy-vpn.sh
#
# Run scripts/harden-vps.sh first: this script expects ufw to be active.
#
# Safe to re-run. Keys, the client ID and panel credentials are generated once
# and kept; a re-run reapplies the settings and leaves the client link unchanged.
# The Xray template is owned by this script: edits made to it in the panel are
# overwritten on the next run.
#
# Prints no secret. Panel credentials stay in /etc/x-ui/install-result.env, the
# client link in /root/vpn/vless-link.txt, the subscription address in
# /root/vpn/subscription-url.txt and the WARP registration in
# /root/vpn/warp.json, all readable by root only.

set -euo pipefail

readonly XUI_VERSION=v3.11.0
readonly XUI_INSTALL_URL="https://raw.githubusercontent.com/MHSanaei/3x-ui/${XUI_VERSION}/install.sh"
readonly XUI_INSTALL_SHA256=9684bae4f769b2127fcceceb4f200045657381311867529e6ba76c6b58e2825d
readonly XUI_BIN=/usr/local/x-ui/x-ui
readonly XUI_RESULT=/etc/x-ui/install-result.env

readonly VPN_PORT=443
readonly REALITY_TARGET=www.samsung.com
# The inbound's name is the profile name the client app shows (ADR-0010).
readonly INBOUND_REMARK='กรุงเทพฯ cloud.z.com'
readonly CLIENT_EMAIL=owner

# Subscription (ADR-0010). The service listens on loopback; a connected client
# reaches it through the tunnel at SUB_ADDRESS, a TEST-NET-1 address that no host
# answers and that client apps do not treat as a private network.
readonly SUB_TITLE='VPN ไทย'
readonly SUB_ADDRESS=192.0.2.1
readonly SUB_PORT=2096

readonly STATE_DIR=/root/vpn
readonly LINK_FILE=$STATE_DIR/vless-link.txt
readonly SUB_URL_FILE=$STATE_DIR/subscription-url.txt
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
readonly LIMITS_MARKER='vpn-server port limits'
# One address may hold this many connections to the VPN port at once, and open
# this many new ones per second. Every stream a client opens through the tunnel
# is its own connection to this port, so the numbers sit far above normal use,
# including several devices behind one home address (ADR-0005).
readonly VPN_MAX_CONCURRENT=1000
readonly VPN_MAX_NEW_PER_SECOND=100
readonly VPN_NEW_BURST=300

log() { printf '[deploy] %s\n' "$*"; }
die() { printf '[deploy] error: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root: sudo -n bash $0"
[ "$(uname -m)" = x86_64 ] || die "only x86_64 is supported"
# shellcheck disable=SC1091
. /etc/os-release
[ "${ID:-}" = ubuntu ] || die "only Ubuntu is supported"
ufw status | grep -q '^Status: active' || die "ufw is not active; run scripts/harden-vps.sh first"

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

# Subscription service (ADR-0010): on, loopback only. The link it writes carries
# the host's public address, not the Host header of the request, which is the
# reserved address a client uses to reach the service through the tunnel.
public_ip=$(ip -4 route get 1.1.1.1 | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}')
printf '%s' "$public_ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || die "could not read the public IPv4 address"
api_ok "read settings" panel/api/setting/all -X POST | jq '.obj' > "$work/settings.json"
jq --arg ip "$public_ip" --arg title "$SUB_TITLE" --argjson port "$SUB_PORT" '
    .subEnable = true | .subListen = "127.0.0.1" | .subPort = $port | .subDomain = $ip
    | .subTitle = $title | .subUpdates = 1 | .remarkTemplate = "{{INBOUND}}"
    | .subJsonEnable = false | .subClashEnable = false' "$work/settings.json" > "$work/settings.new.json"
if [ "$(jq -S . "$work/settings.json")" != "$(jq -S . "$work/settings.new.json")" ]; then
    api_ok "update settings" panel/api/setting/update -X POST \
        -H 'Content-Type: application/json' -d @"$work/settings.new.json" >/dev/null
    systemctl restart x-ui
    wait_api
    log "subscription service enabled on 127.0.0.1:$SUB_PORT"
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
#    - sub: a request for the reserved subscription address is redirected to the
#      subscription service on loopback. It is the only other outbound, it can
#      reach nothing but loopback, and it is not the default (ADR-0010)
#    - log.access stays "none": no record of who connected to what
api_ok "read default template" panel/api/xray/getDefaultJsonConfig | jq \
    --slurpfile warp "$WARP_FILE" --arg endpoint "$WARP_ENDPOINT" --argjson mtu "$WARP_MTU" \
    --arg sub_address "$SUB_ADDRESS" --arg sub_port "$SUB_PORT" '.obj
    | .log.access = "none"
    | .log.dnsLog = false
    | .dns = {servers: ["https://1.1.1.1/dns-query", "https://8.8.8.8/dns-query"], queryStrategy: "UseIPv4"}
    | .outbounds = [{protocol: "wireguard", tag: "warp", settings: {
            secretKey: $warp[0].private_key, address: [$warp[0].address + "/32"],
            peers: [{publicKey: $warp[0].peer_public_key, endpoint: $endpoint, allowedIPs: ["0.0.0.0/0"]}],
            reserved: $warp[0].reserved, mtu: $mtu, domainStrategy: "ForceIPv4", noKernelTun: true}}]
        + [.outbounds[] | select(.protocol != "freedom")]
        + [{protocol: "dns", tag: "dns-out"},
           {protocol: "freedom", tag: "sub", settings: {redirect: ("127.0.0.1:" + $sub_port)}}]
    | .routing.rules = [.routing.rules[0],
        {type: "field", ip: [$sub_address], port: "80", outboundTag: "sub"},
        {type: "field", port: "53", outboundTag: "dns-out"},
        {type: "field", ip: ["::/0"], outboundTag: "blocked"}] + .routing.rules[1:]' > "$work/template.json"
[ "$(jq -r '.routing.rules[0].outboundTag' "$work/template.json")" = api ] \
    || die "default template changed shape: first routing rule is not the api rule"
[ "$(jq -r '[.outbounds[0].tag, ([.outbounds[] | select(.protocol == "freedom" and ((.settings.redirect // "") | startswith("127.0.0.1:") | not))] | length)] | join(" ")' "$work/template.json")" = "warp 0" ] \
    || die "template still has a way out that is not WARP"
api_ok "save template" panel/api/xray/update -X POST \
    --data-urlencode "xraySetting@$work/template.json" >/dev/null
log "xray template applied"

# 6. Inbound. Created once; keys and the client ID are never regenerated.
inbound_id() {
    api_ok "list inbounds" panel/api/inbounds/list \
        | jq -r --argjson p "$VPN_PORT" '[.obj[] | select(.port == $p)][0].id // empty'
}
id=$(inbound_id)
if [ -z "$id" ]; then
    api_ok "new keypair" panel/api/server/getNewX25519Cert > "$work/keys.json"
    uuid=$(api_ok "new uuid" panel/api/server/getNewUUID | jq -r '.obj.uuid // .obj')
    printf '%s' "$uuid" | grep -Eq '^[0-9a-f-]{36}$' || die "panel returned no UUID"
    short_id=$(openssl rand -hex 8)
    jq -n --arg uuid "$uuid" --arg sid "$short_id" --arg target "$REALITY_TARGET" \
        --arg remark "$INBOUND_REMARK" --arg email "$CLIENT_EMAIL" --argjson port "$VPN_PORT" \
        --slurpfile keys "$work/keys.json" '{
        enable: true, remark: $remark, listen: "", port: $port, protocol: "vless",
        expiryTime: 0, total: 0,
        settings: {
            clients: [{id: $uuid, email: $email, flow: "xtls-rprx-vision", enable: true,
                       limitIp: 0, totalGB: 0, expiryTime: 0}],
            decryption: "none", fallbacks: []},
        streamSettings: {
            network: "tcp", security: "reality", externalProxy: [],
            tcpSettings: {acceptProxyProtocol: false, header: {type: "none"}},
            realitySettings: {
                show: false, xver: 0, target: ($target + ":443"), serverNames: [$target],
                privateKey: $keys[0].obj.privateKey, minClientVer: "", maxClientVer: "",
                maxTimediff: 0, shortIds: [$sid],
                settings: {publicKey: $keys[0].obj.publicKey, fingerprint: "chrome",
                           serverName: "", spiderX: "/"}}},
        sniffing: {enabled: true, destOverride: ["http", "tls", "quic"],
                   metadataOnly: false, routeOnly: false}}' > "$work/inbound.json"
    api_ok "add inbound" panel/api/inbounds/add -X POST \
        -H 'Content-Type: application/json' -d @"$work/inbound.json" >/dev/null
    id=$(inbound_id)
    [ -n "$id" ] || die "inbound was not created"
    log "inbound created on ${VPN_PORT}/tcp"
else
    log "inbound on ${VPN_PORT}/tcp already exists; keys kept"
fi
# The inbound's name is the profile name in the client app. Only the name changes.
if [ "$(api_ok "read inbound" "panel/api/inbounds/get/$id" | jq -r '.obj.remark')" != "$INBOUND_REMARK" ]; then
    api_ok "read inbound" "panel/api/inbounds/get/$id" \
        | jq --arg remark "$INBOUND_REMARK" '.obj | del(.clientStats) | .remark = $remark' > "$work/inbound-rename.json"
    api_ok "rename inbound" "panel/api/inbounds/update/$id" -X POST \
        -H 'Content-Type: application/json' -d @"$work/inbound-rename.json" >/dev/null
    log "inbound renamed to its profile name"
fi

# 7. Firewall, then restart Xray so the template and inbound are live.
ufw allow "${VPN_PORT}/tcp" comment 'VLESS Reality' >/dev/null

# Per-address limits on new connections to the VPN port, as one marked block at
# the end of ufw's before-input chain, which runs ahead of the ALLOW rules. The
# candidate file is tested against the live ruleset before it replaces the
# current one, and the previous file comes back if the reload fails. Same
# mechanism as the SSH limits in harden-vps.sh, with its own marker.
set_before_rules_block() { # set_before_rules_block <marker> <file with rule lines>
    local marker=$1 block=$2
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
        $0 == end { skip = 0 }' "$UFW_BEFORE" > "$work/before.rules"
    grep -qxF "# END $marker" "$work/before.rules" || die "no filter table found in $UFW_BEFORE"
    cmp -s "$work/before.rules" "$UFW_BEFORE" && return 0
    iptables-restore --test --noflush < "$work/before.rules" \
        || die "new firewall rules for '$marker' did not validate; nothing changed"
    cp -p "$UFW_BEFORE" "$work/before.rules.bak"
    cat "$work/before.rules" > "$UFW_BEFORE"
    if ! ufw reload >/dev/null; then
        cat "$work/before.rules.bak" > "$UFW_BEFORE"
        ufw reload >/dev/null
        die "ufw did not reload with the rules for '$marker'; previous rules restored"
    fi
}
cat > "$work/limits" <<EOF
-A ufw-before-input -p tcp --syn --dport $VPN_PORT -m connlimit --connlimit-above $VPN_MAX_CONCURRENT --connlimit-mask 32 -j DROP
-A ufw-before-input -p tcp --syn --dport $VPN_PORT -m hashlimit --hashlimit-name vpn-new --hashlimit-mode srcip --hashlimit-above $VPN_MAX_NEW_PER_SECOND/second --hashlimit-burst $VPN_NEW_BURST -j DROP
EOF
set_before_rules_block "$LIMITS_MARKER" "$work/limits"
log "per-address connection limits applied on ${VPN_PORT}/tcp"

api_ok "restart xray" panel/api/server/restartXrayService -X POST >/dev/null
listening=""
for _ in $(seq 1 20); do
    if ss -Htln "sport = :$VPN_PORT" | grep -q .; then listening=yes; break; fi
    sleep 1
done
[ -n "$listening" ] || die "xray is not listening on ${VPN_PORT}/tcp: $(api panel/api/xray/getXrayResult | jq -r '.obj')"
log "xray listening on ${VPN_PORT}/tcp"

# 8. Client link, built from what the panel stores. Written to a root-only file.
api_ok "read inbound" "panel/api/inbounds/get/$id" | jq -r --arg ip "$public_ip" --arg email "$CLIENT_EMAIL" --arg name "$INBOUND_REMARK" '
    .obj as $in
    | ($in.settings.clients[] | select(.email == $email)) as $c
    | $in.streamSettings.realitySettings as $r
    | "vless://\($c.id)@\($ip):\($in.port)?encryption=none&flow=\($c.flow)&type=tcp&headerType=none&security=reality&sni=\($r.serverNames[0])&fp=\($r.settings.fingerprint)&pbk=\($r.settings.publicKey)&sid=\($r.shortIds[0])&spx=%2F#\($name | @uri)"' \
    > "$LINK_FILE"
chmod 600 "$LINK_FILE"
grep -q '^vless://' "$LINK_FILE" || die "client link was not written"
log "client link written to $LINK_FILE"

# Subscription address: the reserved address a connected client requests, the
# panel's subscription path and the client's subscription ID.
sub_path=$(api_ok "read settings" panel/api/setting/all -X POST | jq -r '.obj.subPath')
sub_id=$(api_ok "read inbound" "panel/api/inbounds/get/$id" \
    | jq -r --arg email "$CLIENT_EMAIL" '.obj.settings.clients[] | select(.email == $email) | .subId')
[ -n "$sub_path" ] && [ -n "$sub_id" ] && [ "$sub_id" != null ] || die "subscription path or client subscription ID is missing"
printf 'http://%s%s%s\n' "$SUB_ADDRESS" "$sub_path" "$sub_id" > "$SUB_URL_FILE"
chmod 600 "$SUB_URL_FILE"
log "subscription address written to $SUB_URL_FILE"

log "final state:"
systemctl is-active x-ui
ufw status | sed -n '1,12p'
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
