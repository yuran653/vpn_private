#!/usr/bin/env bash
# deploy-fallback.sh - the fallback VPN server (ADR-0018, ADR-0019), on its own
# VPS and address (Ubuntu 22.04/24.04). NOT the server behind Cloudflare.
#
# Clients reach this server directly on 443/tcp with VLESS + Reality + Vision.
# It is an entry only: everything a client sends is forwarded to the first
# server through Cloudflare, with the relay link that server issued, and leaves
# from there. This host has no way out of its own (ADR-0019).
#
#   1-4. the host steps shared with the first server (lib/host-common.sh):
#        security updates, IPv6 off, TCP tuning, the pinned 3x-ui on loopback
#   5. Xray template: the relay to the first server is the only outbound that
#      carries traffic; no access log; IPv6 destinations refused
#   6. one VLESS + Reality + Vision inbound on 443/tcp with one client. A
#      connection without the key is handed to the cover site, a third-party
#      site hosted in the same provider network as this VPS (ADR-0012 as
#      reworded by ADR-0018)
#   7. ufw: 443/tcp admitted from anywhere
#   8. the client link written to /root/vpn/vless-link.txt (mode 600)
#
# Usage, on the VPS as root or via sudo, with the repo's scripts/lib/ folder
# next to this script:
#   sudo -n bash deploy-fallback.sh [<cover name>]
#
# <cover name> is required on the first run and kept in the inbound after it.
# Passing a different one later changes the cover site and the client link.
# The name is not stored in the repo and not printed.
#
# Before the first run:
#   - scripts/harden-vps.sh with --ssh-from: this script refuses to run while
#     the SSH port is open to everyone (ADR-0018)
#   - the relay link from the first server in /root/vpn/relay-link.txt, mode
#     600, moved without being printed (docs/vps-access.md)
#
# Safe to re-run. Keys and the client ID are generated once and kept; a re-run
# leaves the client link unchanged unless the cover name or the address changed.
# The Xray template is owned by this script.
#
# Prints no secret. Not yet run on a server (written 2026-11-12).

set -euo pipefail

readonly LOG_TAG=fallback
readonly LIB=$(cd "$(dirname "$0")" && pwd)/lib/host-common.sh
[ -r "$LIB" ] || { echo "[fallback] error: $LIB not found; copy the repo's scripts/lib folder next to this script" >&2; exit 1; }
# shellcheck source=lib/host-common.sh
. "$LIB"

readonly VPN_PORT=443
readonly LINK_FILE=$STATE_DIR/vless-link.txt
readonly RELAY_LINK_FILE=$STATE_DIR/relay-link.txt
# The profile name the client app shows (ADR-0011). It differs from the first
# server's, so the user can tell the two links apart (R-vpn-fallback-05.c).
readonly INBOUND_REMARK='กรุงเทพฯ fallback'
readonly CLIENT_EMAIL=owner
readonly CLIENT_FLOW=xtls-rprx-vision
# A Reality link borrows a real site's name, so it sends a browser's hello.
# ADR-0015's rule against browser fingerprints covers links that go through
# Cloudflare, not this one (reworded 2026-11-12).
readonly LINK_FP=chrome
readonly COVER_ARG=${1:-}

host_preflight

# This script and deploy-vpn.sh must never run on the same host: the first
# server's address stays unused and unanswering (ADR-0013).
if [ -e /etc/nginx/conf.d/cover-site.conf ] || [ -e "$STATE_DIR/xhttp-path" ]; then
    die "this host is the server behind Cloudflare; the fallback runs on a separate VPS (ADR-0018)"
fi
# No clients while SSH answers everyone (ADR-0018).
ssh_port=$(sshd -T 2>/dev/null | awk '$1 == "port" { print $2 }')
[ -n "$ssh_port" ] || die "could not read the SSH port from sshd -T"
# The status is captured first: with pipefail, grep -q closing the pipe early
# would fail the pipeline and let this guard pass.
ufw_now=$(ufw status)
if grep -Eq "^${ssh_port}/tcp[[:space:]]+ALLOW[[:space:]]+Anywhere" <<<"$ufw_now"; then
    die "the SSH port is open to everyone; run harden-vps.sh with --ssh-from first (ADR-0018)"
fi
[ -s "$RELAY_LINK_FILE" ] || die "no relay link at $RELAY_LINK_FILE; move it here from the first server first (docs/vps-access.md)"

host_begin
chmod 600 "$RELAY_LINK_FILE"
host_updates          # 1
host_ipv6_off         # 2
host_tcp_tuning       # 3
host_panel            # 4

# 5. Xray template. The relay outbound is built from the relay link, the same
#    way a client app reads a link. It is the first outbound, so it carries
#    whatever the rules do not block, and the default "direct" outbound is
#    removed: when the first server cannot be reached a request fails, it never
#    leaves from this server's own address (ADR-0019).
#    - no DNS of its own: a client's port-53 query travels through the relay
#      and is answered by the first server; names are not resolved here
#    - IPv6 destinations are refused
#    - log.access stays "none"
python3 -I - "$RELAY_LINK_FILE" > "$work/relay-outbound.json" <<'PY' || die "the relay link is not a VLESS link over XHTTP and TLS to a host name"
import ipaddress, json, sys, urllib.parse
u = urllib.parse.urlsplit(open(sys.argv[1]).read().strip())
q = dict(urllib.parse.parse_qsl(u.query))
if u.scheme != "vless" or q.get("type") != "xhttp" or q.get("security") != "tls" or not u.hostname or not u.username:
    sys.exit(1)
try:
    ipaddress.ip_address(u.hostname)
    sys.exit(1)             # the relay goes to a name behind Cloudflare, never to an address
except ValueError:
    pass
print(json.dumps({
    "protocol": "vless", "tag": "relay",
    "settings": {"vnext": [{"address": u.hostname, "port": u.port or 443, "users": [
        {"id": u.username, "encryption": "none"}]}]},
    "streamSettings": {"network": "xhttp", "security": "tls",
        "tlsSettings": {"serverName": q["sni"], "fingerprint": q["fp"], "alpn": q["alpn"].split(",")},
        "xhttpSettings": {"host": q["host"], "path": q["path"], "mode": q.get("mode", "auto"),
            "extra": json.loads(q.get("extra", "{}"))}}}))
PY
api_ok "read default template" panel/api/xray/getDefaultJsonConfig | jq \
    --slurpfile relay "$work/relay-outbound.json" '.obj
    | .log.access = "none"
    | .log.dnsLog = false
    | del(.dns)
    | .outbounds = [$relay[0]] + [.outbounds[] | select(.protocol != "freedom")]
    | .routing.domainStrategy = "AsIs"
    | .routing.rules = [.routing.rules[0],
        {type: "field", ip: ["::/0"], outboundTag: "blocked"}] + .routing.rules[1:]' > "$work/template.json"
[ "$(jq -r '.routing.rules[0].outboundTag' "$work/template.json")" = api ] \
    || die "default template changed shape: first routing rule is not the api rule"
[ "$(jq -r '[.outbounds[0].tag, ([.outbounds[] | select(.protocol == "freedom" or .protocol == "wireguard")] | length)] | join(" ")' "$work/template.json")" = "relay 0" ] \
    || die "template has a way out that is not the relay"
jq -e '[.outbounds[] | select(.tag == "blocked")] | length == 1' "$work/template.json" >/dev/null \
    || die "default template changed shape: no 'blocked' outbound"
api_ok "save template" panel/api/xray/update -X POST \
    --data-urlencode "xraySetting@$work/template.json" >/dev/null
log "xray template applied: the relay is the only way out"

# 6. Inbound. Created once; keys and the client ID are never regenerated.
#    The cover site must answer TLS 1.3 from this host, since Reality hands it
#    every connection that lacks the key.
check_cover() { # check_cover <name>
    printf '%s' "$1" | grep -Eq '^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$' \
        || die "the cover name must be a host name in lower case"
    getent ahostsv4 "$1" >/dev/null || die "the cover name does not resolve from this host"
    curl -sS -o /dev/null --tlsv1.3 --max-time 15 "https://$1/" 2>/dev/null \
        || die "the cover site does not answer over TLS 1.3 from this host"
}
inbound_id() {
    api_ok "list inbounds" panel/api/inbounds/list \
        | jq -r --argjson p "$VPN_PORT" '[.obj[] | select(.port == $p)][0].id // empty'
}
id=$(inbound_id)
if [ -z "$id" ]; then
    [ -n "$COVER_ARG" ] || die "the first run needs the cover name: sudo -n bash $0 <cover name>"
    check_cover "$COVER_ARG"
    cover=$COVER_ARG
    api_ok "new keypair" panel/api/server/getNewX25519Cert > "$work/keys.json"
    uuid=$(api_ok "new uuid" panel/api/server/getNewUUID | jq -r '.obj.uuid // .obj')
    printf '%s' "$uuid" | grep -Eq '^[0-9a-f-]{36}$' || die "panel returned no UUID"
    short_id=$(openssl rand -hex 8)
    jq -n --arg uuid "$uuid" --arg sid "$short_id" --arg target "$cover" --arg flow "$CLIENT_FLOW" \
        --arg remark "$INBOUND_REMARK" --arg email "$CLIENT_EMAIL" --argjson port "$VPN_PORT" \
        --arg fp "$LINK_FP" --slurpfile keys "$work/keys.json" '{
        enable: true, remark: $remark, listen: "", port: $port, protocol: "vless",
        expiryTime: 0, total: 0,
        settings: {
            clients: [{id: $uuid, email: $email, flow: $flow, enable: true,
                       limitIp: 0, totalGB: 0, expiryTime: 0}],
            decryption: "none", fallbacks: []},
        streamSettings: {
            network: "tcp", security: "reality", externalProxy: [],
            tcpSettings: {acceptProxyProtocol: false, header: {type: "none"}},
            realitySettings: {
                show: false, xver: 0, target: ($target + ":443"), serverNames: [$target],
                privateKey: $keys[0].obj.privateKey, minClientVer: "", maxClientVer: "",
                maxTimediff: 0, shortIds: [$sid],
                settings: {publicKey: $keys[0].obj.publicKey, fingerprint: $fp,
                           serverName: "", spiderX: "/"}}},
        sniffing: {enabled: true, destOverride: ["http", "tls", "quic"],
                   metadataOnly: false, routeOnly: false}}' > "$work/inbound.json"
    api_ok "add inbound" panel/api/inbounds/add -X POST \
        -H 'Content-Type: application/json' -d @"$work/inbound.json" >/dev/null
    id=$(inbound_id)
    [ -n "$id" ] || die "the inbound was not created"
    log "Reality inbound created on ${VPN_PORT}/tcp"
else
    api_ok "read inbound" "panel/api/inbounds/get/$id" | jq '.obj | del(.clientStats)' > "$work/inbound-now.json"
    cover=$(jq -r '.streamSettings | (if type == "string" then fromjson else . end) | .realitySettings.serverNames[0] // empty' "$work/inbound-now.json")
    [ -n "$cover" ] || die "the inbound on ${VPN_PORT}/tcp is not a Reality inbound"
    if [ -n "$COVER_ARG" ] && [ "$COVER_ARG" != "$cover" ]; then
        check_cover "$COVER_ARG"
        cover=$COVER_ARG
        jq --arg target "$cover" '
            .streamSettings |= ((if type == "string" then fromjson else . end)
                | .realitySettings.target = ($target + ":443")
                | .realitySettings.serverNames = [$target])' \
            "$work/inbound-now.json" > "$work/inbound-want.json"
        # The panel may hand streamSettings back as a JSON string; send the same form.
        if [ "$(jq -r '.streamSettings | type' "$work/inbound-now.json")" = string ]; then
            jq '.streamSettings |= tojson' "$work/inbound-want.json" > "$work/inbound-send.json"
        else
            cp "$work/inbound-want.json" "$work/inbound-send.json"
        fi
        api_ok "update inbound" "panel/api/inbounds/update/$id" -X POST \
            -H 'Content-Type: application/json' -d @"$work/inbound-send.json" >/dev/null
        log "cover site changed; the client link changes with it"
    else
        log "Reality inbound on ${VPN_PORT}/tcp already exists; keys, client ID and cover site kept"
    fi
fi

api_ok "restart xray" panel/api/server/restartXrayService -X POST >/dev/null
listening=""
for _ in $(seq 1 20); do
    if ss -Htlnp "sport = :$VPN_PORT" | grep -q '"xray'; then listening=yes; break; fi
    sleep 1
done
[ -n "$listening" ] || die "xray is not listening on ${VPN_PORT}/tcp: $(api panel/api/xray/getXrayResult | jq -r '.obj')"
log "xray listening on ${VPN_PORT}/tcp"

# A connection without the key must get the cover site's own certificate, before
# the port is opened to the internet.
probe_ok=""
for _ in $(seq 1 10); do
    if curl -sS -o /dev/null --max-time 15 --resolve "$cover:$VPN_PORT:127.0.0.1" "https://$cover/" 2>/dev/null; then
        probe_ok=yes; break
    fi
    sleep 1
done
[ -n "$probe_ok" ] || die "a connection without the key does not get the cover site's certificate; ${VPN_PORT}/tcp stays closed"
log "a connection without the key gets the cover site"

# 7. Firewall.
ufw allow "${VPN_PORT}/tcp" comment 'fallback' >/dev/null
log "${VPN_PORT}/tcp admitted from anywhere"

# 8. Client link, built from what the panel stores. It names this server's
#    address: there is no name of ours on this host. Written to a root-only file.
public_ip=$(ip -4 route get 1.1.1.1 | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}')
printf '%s' "$public_ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || die "could not read the public IPv4 address"
api_ok "read inbound" "panel/api/inbounds/get/$id" | jq -r --arg ip "$public_ip" --arg email "$CLIENT_EMAIL" \
    --arg name "$INBOUND_REMARK" --arg flow "$CLIENT_FLOW" --arg fp "$LINK_FP" '
    .obj as $in
    | ($in.settings | if type == "string" then fromjson else . end) as $s
    | ($in.streamSettings | if type == "string" then fromjson else . end) as $st
    | ($s.clients[] | select(.email == $email)) as $c
    | $st.realitySettings as $r
    | "vless://\($c.id)@\($ip):\($in.port)?encryption=none&flow=\($flow)&type=tcp&headerType=none&security=reality&sni=\($r.serverNames[0])&fp=\($fp)&pbk=\($r.settings.publicKey)&sid=\($r.shortIds[0])&spx=%2F#\($name | @uri)"' \
    > "$LINK_FILE"
chmod 600 "$LINK_FILE"
grep -q '^vless://' "$LINK_FILE" || die "client link was not written"
log "client link written to $LINK_FILE"

log "final state:"
systemctl is-active x-ui
log "$(ufw status | grep -c ' ALLOW ') firewall rules admit traffic: ${VPN_PORT}/tcp from anywhere, SSH from the listed sources"
host_reboot_notes
log "done"
