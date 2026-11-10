#!/usr/bin/env bash
# deploy-vpn.sh - VLESS + XTLS-Reality server on the Thailand VPS (Ubuntu 22.04/24.04).
#
# Installs the 3x-ui panel (pinned release), binds it to loopback, and configures
# Xray through the panel API:
#   1. unattended security upgrades on
#   2. IPv6 disabled on the host
#   3. 3x-ui installed from the pinned release, panel on 127.0.0.1 only,
#      subscription service off
#   4. Xray template: encrypted DNS, IPv4-only egress, port-53 capture, no access log
#   5. one VLESS + Reality + Vision inbound on 443/tcp with one client
#   6. ufw: 443/tcp allowed
#   7. the client link written to /root/vpn/vless-link.txt (mode 600)
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
# Prints no secret. Panel credentials stay in /etc/x-ui/install-result.env and
# the client link in /root/vpn/vless-link.txt, both readable by root only.

set -euo pipefail

readonly XUI_VERSION=v3.11.0
readonly XUI_INSTALL_URL="https://raw.githubusercontent.com/MHSanaei/3x-ui/${XUI_VERSION}/install.sh"
readonly XUI_INSTALL_SHA256=9684bae4f769b2127fcceceb4f200045657381311867529e6ba76c6b58e2825d
readonly XUI_BIN=/usr/local/x-ui/x-ui
readonly XUI_RESULT=/etc/x-ui/install-result.env

readonly VPN_PORT=443
readonly REALITY_TARGET=www.samsung.com
readonly INBOUND_REMARK=th-reality
readonly CLIENT_EMAIL=owner

readonly STATE_DIR=/root/vpn
readonly LINK_FILE=$STATE_DIR/vless-link.txt
readonly INSTALL_LOG=$STATE_DIR/install.log
readonly SYSCTL_CONF=/etc/sysctl.d/60-vpn-disable-ipv6.conf
readonly AUTO_UPGRADES=/etc/apt/apt.conf.d/20auto-upgrades

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
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl jq openssl ca-certificates unattended-upgrades >/dev/null
cat > "$AUTO_UPGRADES" <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
chmod 644 "$AUTO_UPGRADES"
systemctl enable --now unattended-upgrades >/dev/null 2>&1
log "unattended upgrades enabled"

# 2. IPv6 off, now and after reboot.
cat > "$SYSCTL_CONF" <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
chmod 644 "$SYSCTL_CONF"
sysctl -q -p "$SYSCTL_CONF"
log "IPv6 disabled"

# 3. 3x-ui, pinned. The installer prints the panel credentials, so its output
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

# 4. Xray template: the panel's default plus this project's rules.
#    - dns: every lookup goes out over DoH, IPv4 answers only
#    - direct: destinations are resolved by that DNS and dialled over IPv4 only
#    - port 53 from clients is answered by that DNS, whatever resolver they asked
#    - IPv6 destinations are refused
#    - log.access stays "none": no record of who connected to what
api_ok "read default template" panel/api/xray/getDefaultJsonConfig | jq '.obj
    | .log.access = "none"
    | .log.dnsLog = false
    | .dns = {servers: ["https+local://1.1.1.1/dns-query", "https+local://8.8.8.8/dns-query"], queryStrategy: "UseIPv4"}
    | (.outbounds[] | select(.tag == "direct") | .settings.domainStrategy) = "ForceIPv4"
    | .outbounds += [{protocol: "dns", tag: "dns-out"}]
    | .routing.rules = [.routing.rules[0],
        {type: "field", port: "53", outboundTag: "dns-out"},
        {type: "field", ip: ["::/0"], outboundTag: "blocked"}] + .routing.rules[1:]' > "$work/template.json"
[ "$(jq -r '.routing.rules[0].outboundTag' "$work/template.json")" = api ] \
    || die "default template changed shape: first routing rule is not the api rule"
api_ok "save template" panel/api/xray/update -X POST \
    --data-urlencode "xraySetting@$work/template.json" >/dev/null
log "xray template applied"

# 5. Inbound. Created once; keys and the client ID are never regenerated.
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

# 6. Firewall, then restart Xray so the template and inbound are live.
ufw allow "${VPN_PORT}/tcp" comment 'VLESS Reality' >/dev/null
api_ok "restart xray" panel/api/server/restartXrayService -X POST >/dev/null
listening=""
for _ in $(seq 1 20); do
    if ss -Htln "sport = :$VPN_PORT" | grep -q .; then listening=yes; break; fi
    sleep 1
done
[ -n "$listening" ] || die "xray is not listening on ${VPN_PORT}/tcp: $(api panel/api/xray/getXrayResult | jq -r '.obj')"
log "xray listening on ${VPN_PORT}/tcp"

# 7. Client link, built from what the panel stores. Written to a root-only file.
public_ip=$(ip -4 route get 1.1.1.1 | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}')
printf '%s' "$public_ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || die "could not read the public IPv4 address"
api_ok "read inbound" "panel/api/inbounds/get/$id" | jq -r --arg ip "$public_ip" --arg email "$CLIENT_EMAIL" '
    .obj as $in
    | ($in.settings.clients[] | select(.email == $email)) as $c
    | $in.streamSettings.realitySettings as $r
    | "vless://\($c.id)@\($ip):\($in.port)?encryption=none&flow=\($c.flow)&type=tcp&headerType=none&security=reality&sni=\($r.serverNames[0])&fp=\($r.settings.fingerprint)&pbk=\($r.settings.publicKey)&sid=\($r.shortIds[0])&spx=%2F#TH-Reality"' \
    > "$LINK_FILE"
chmod 600 "$LINK_FILE"
grep -q '^vless://' "$LINK_FILE" || die "client link was not written"
log "client link written to $LINK_FILE"

log "final state:"
systemctl is-active x-ui
ufw status | sed -n '1,12p'
log "done"
