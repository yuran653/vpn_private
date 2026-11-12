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
#      names files.casedigestai.com, not the server's address, and carries
#      the connection rotation settings (ADR-0014)
#
#  11. the same site and tunnel on the other HTTPS ports Cloudflare proxies
#      (2053, 2083, 2087, 2096, 8443), from Cloudflare's ranges only, with one
#      link per port in /root/vpn/vless-links-alt.txt (ADR-0020)
#  12. the owner's links ask the client app to fragment the TLS hello, and
#      carry no ECH setting (ADR-0021)
#  10. a second client, `relay`, for the fallback server (ADR-0019); its link is
#      written to /root/vpn/relay-link.txt (mode 600)
#
# Usage, on the VPS as root or via sudo, with the repo's site/ folder and
# scripts/lib/ folder next to this script (site/ may also be given in SITE_SRC):
#   sudo -n bash deploy-vpn.sh
#
# Run scripts/harden-vps.sh first: this script expects ufw to be active.
# Every site name must be proxied by Cloudflare (orange cloud, SSL mode
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

# The host steps shared with the fallback server live in lib/host-common.sh.
readonly LOG_TAG=deploy
readonly LIB=$(cd "$(dirname "$0")" && pwd)/lib/host-common.sh
[ -r "$LIB" ] || { echo "[deploy] error: $LIB not found; copy the repo's scripts/lib folder next to this script" >&2; exit 1; }
# shellcheck source=lib/host-common.sh
. "$LIB"

readonly VPN_PORT=443
# The other HTTPS ports Cloudflare proxies (ADR-0020). nginx answers on each as
# on VPN_PORT, admitted from Cloudflare's ranges only. A link per port is kept
# for networks where 443 to the name is cut.
readonly ALT_PORTS=(2053 2083 2087 2096 8443)
# Cover site (ADR-0012) behind Cloudflare (ADR-0013). Clients connect to
# COVER_NAME, which Cloudflare proxies to nginx on VPN_PORT (ADR-0014: a
# case-file sync name, where heavy transfers are normal). SITE_NAMES are all
# the site's names, on one Let's Encrypt certificate; status. is kept so
# devices with the link from before ADR-0014 keep working. nginx takes the pages from the site container
# on COVER_SITE_PORT and hands the tunnel path to Xray on XHTTP_PORT. Before
# the cut-over nginx's TLS side waits on STAGING_TLS_PORT. All three are on
# loopback only.
readonly COVER_DOMAIN=casedigestai.com
readonly COVER_NAME=files.casedigestai.com
readonly SITE_NAMES=("$COVER_DOMAIN" "$COVER_NAME" status.casedigestai.com)
# XHTTP padding and connection rotation (ADR-0014). The server and the link use
# the same padding range: the server refuses padding outside its own range.
# XMUX is client behavior and travels in the link's `extra` parameter: a
# connection takes no new sessions after 2-5 minutes or 32-64 sessions.
readonly XHTTP_PADDING=100-1000
readonly XHTTP_XMUX='{"maxConcurrency":"16-32","cMaxReuseTimes":"32-64","hMaxRequestTimes":"600-900","hMaxReusableSecs":"120-300"}'
# 18443, not 8443: 8443 is one of the alternative ports now (ADR-0020).
readonly STAGING_TLS_PORT=18443
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

readonly LINK_FILE=$STATE_DIR/vless-link.txt
readonly XHTTP_PATH_FILE=$STATE_DIR/xhttp-path
# Cloudflare's published IPv4 ranges; only they reach 80 and 443 (ADR-0013).
readonly CF_IPS_URL=https://www.cloudflare.com/ips-v4
readonly CF_IPS_FILE=$STATE_DIR/cloudflare-ips-v4.txt
readonly CF_RULE_COMMENT=cloudflare
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
readonly UFW_BEFORE=/etc/ufw/before.rules
# The per-address limits on the VPN port (ADR-0005) are removed by this marker:
# every client now arrives from a shared Cloudflare address (ADR-0013).
readonly LIMITS_MARKER='vpn-server port limits'
# The fallback server forwards its users' traffic to this one as a client of
# its own (ADR-0019). Its link is kept apart from the owner's.
readonly RELAY_EMAIL=relay
readonly RELAY_LINK_FILE=$STATE_DIR/relay-link.txt
# One link per alternative port (ADR-0020), one per line.
readonly ALT_LINKS_FILE=$STATE_DIR/vless-links-alt.txt
# TLS hello fragmentation (ADR-0021): a parameter the Happ app reads from the
# link, as length,interval,what-to-split. It applies only while the app's own
# global fragmentation setting is off. Xray itself ignores it in a link.
readonly LINK_FRAGMENT=1-10,5-20,tlshello

host_preflight
[ -s "$SITE_SRC/docker-compose.yml" ] && [ -s "$SITE_SRC/html/index.html" ] \
    || die "site folder not found at $SITE_SRC; copy the repo's site/ folder next to this script"

host_begin
host_updates          # 1
host_ipv6_off         # 2
host_tcp_tuning       # 3
host_panel            # 4

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
#    website of SITE_NAMES runs on this host; Cloudflare
#    proxies every name, and nginx on 443 hands the tunnel path to Xray.
#    Everything in this step is in place and tested before the cut-over in
#    step 7: a failure here leaves the tunnel as it was.
case "$XUI_PANEL_PORT" in
    "$STAGING_TLS_PORT"|"$COVER_SITE_PORT"|"$XHTTP_PORT") die "the panel port collides with a cover site or tunnel port" ;;
esac
for p in "${ALT_PORTS[@]}"; do
    [ "$XUI_PANEL_PORT" != "$p" ] \
        || die "the panel port is one of the alternative tunnel ports (ADR-0020); move the panel to another port and run again"
done
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

# Every name must resolve to Cloudflare only: the domain is on Cloudflare and
# every record is proxied. Checked before a certificate is requested and
# before the cut-over, so the tunnel never moves to a name that does not lead
# through Cloudflare.
names_on_cloudflare() {
    local name resolved
    for name in "${SITE_NAMES[@]}"; do
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
log "all site names resolve to Cloudflare only"

# Firewall: 80 and 443 from Cloudflare's ranges. Rules for ranges Cloudflare
# no longer lists are deleted. The rules that admit everyone are deleted at the
# cut-over, in step 7.
for range in "${cf_ranges[@]}"; do
    for port in 80 "$VPN_PORT" "${ALT_PORTS[@]}"; do
        ufw allow proto tcp from "$range" to any port "$port" comment "$CF_RULE_COMMENT" >/dev/null
    done
done
ufw status | awk -v c="# $CF_RULE_COMMENT" 'index($0, c) {print $1 " " $3}' | sort -u > "$work/cf-rules"
while read -r portspec range; do
    if printf '%s\n' "${cf_ranges[@]}" | grep -qxF "$range" \
        && printf '%s\n' 80 "$VPN_PORT" "${ALT_PORTS[@]}" | grep -qxF "${portspec%/tcp}"; then continue; fi
    ufw delete allow proto tcp from "$range" to any port "${portspec%/tcp}" >/dev/null || true
done < "$work/cf-rules"
log "80/tcp, ${VPN_PORT}/tcp and the alternative ports ${ALT_PORTS[*]} admitted from Cloudflare's ${#cf_ranges[@]} ranges"

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
site_names_re=$(printf '%s|' "${SITE_NAMES[@]}"); site_names_re=${site_names_re%|}; site_names_re=${site_names_re//./\\.}
write_nginx_conf() { # write_nginx_conf [<tls listen address>]
    # The alternative ports (ADR-0020) are served once nginx holds VPN_PORT, not
    # while its TLS side still waits on the staging port.
    local alt_listen="" p
    if [ "${1:-}" = "$VPN_PORT" ]; then
        for p in "${ALT_PORTS[@]}"; do alt_listen="$alt_listen
    listen $p ssl default_server;"; done
    fi
    cat > "$work/cover-site.conf" <<EOF
# Written by deploy-vpn.sh (ADR-0012, ADR-0013). Edits are overwritten on the next run.
server {
    listen 80 default_server;
    server_name ${SITE_NAMES[*]};
    server_tokens off;
    access_log off;
    set \$cover_host $COVER_DOMAIN;
    if (\$host ~ ^($site_names_re)\$) { set \$cover_host \$host; }
    location ^~ /.well-known/acme-challenge/ { root $ACME_ROOT; default_type text/plain; }
    location / { return 301 https://\$cover_host\$request_uri; }
}
EOF
    if [ -n "${1:-}" ]; then
        cat >> "$work/cover-site.conf" <<EOF
server {
    # No http2 here (ADR-0015): only Cloudflare connects, and a listener with http2 answers
    # an HTTP/1.1 tunnel client with raw HTTP/2 frames.
    listen $1 ssl default_server;$alt_listen
    server_name ${SITE_NAMES[*]};
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
        # proxy_pass over HTTP/1.1 (ADR-0015): the link offers HTTP/1.1 only.
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 5m;
        proxy_send_timeout 5m;
        proxy_pass http://127.0.0.1:$XHTTP_PORT;
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
    local name
    [ -s "$COVER_CERT_DIR/fullchain.pem" ] \
        && openssl x509 -in "$COVER_CERT_DIR/fullchain.pem" -noout -checkend 0 >/dev/null || return 1
    for name in "${SITE_NAMES[@]}"; do
        openssl x509 -in "$COVER_CERT_DIR/fullchain.pem" -noout -checkhost "$name" | grep -q 'does match' || return 1
    done
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

# Certificate for every site name from Let's Encrypt, by a challenge file served on
# port 80; Cloudflare passes the challenge through to this host. Requested only
# when no valid certificate covers every name. Requesting accepts Let's
# Encrypt's subscriber agreement for the owner; no email address is registered.
install -d -m 755 /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh <<'EOF'
#!/bin/sh
systemctl reload nginx
EOF
chmod 755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
if ! cert_covers_names; then
    certbot certonly --webroot -w "$ACME_ROOT" --cert-name "$COVER_DOMAIN" \
        $(printf -- '-d %s ' "${SITE_NAMES[@]}") --non-interactive --agree-tos \
        --register-unsafely-without-email > "$STATE_DIR/certbot.log" 2>&1 \
        || die "the certificate was not issued; see $STATE_DIR/certbot.log on the VPS (the tunnel is unchanged)"
    cert_covers_names || die "the issued certificate does not cover every site name"
    write_nginx_conf "$tls_listen"
    log "certificate issued for ${SITE_NAMES[*]}"
else
    log "certificate for ${SITE_NAMES[*]} is valid; kept"
fi
systemctl enable --now certbot.timer >/dev/null 2>&1
# The site must answer over TLS on loopback, with a certificate that validates
# for each name, before the cut-over.
for name in "${SITE_NAMES[@]}"; do
    serves_page --http2 --resolve "$name:$tls_port:127.0.0.1" "https://$name:$tls_port/" \
        || die "the cover site does not answer for $name on loopback (the tunnel is unchanged)"
done
log "cover site answers for every name on loopback"

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
    jq -n --arg uuid "$uuid" --arg path "$xhttp_path" --arg remark "$INBOUND_REMARK" --arg padding "$XHTTP_PADDING" \
        --arg email "$CLIENT_EMAIL" --argjson port "$XHTTP_PORT" '{
        enable: true, remark: $remark, listen: "127.0.0.1", port: $port, protocol: "vless",
        expiryTime: 0, total: 0,
        settings: {
            clients: [{id: $uuid, email: $email, flow: "", enable: true,
                       limitIp: 0, totalGB: 0, expiryTime: 0}],
            decryption: "none", fallbacks: []},
        streamSettings: {
            network: "xhttp", security: "none", externalProxy: [],
            xhttpSettings: {path: $path, host: "", headers: {}, mode: "auto", xPaddingBytes: $padding}},
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
# The inbound's name is the profile name in the client app (ADR-0011), and it
# pads its responses (ADR-0014). The panel may hand streamSettings back as a
# JSON string; it is sent back in the same form, and compared parsed.
api_ok "read inbound" "panel/api/inbounds/get/$xhttp_id" | jq '.obj | del(.clientStats)' > "$work/inbound-now.json"
jq --arg remark "$INBOUND_REMARK" --arg padding "$XHTTP_PADDING" '
    .remark = $remark | .listen = "127.0.0.1"
    | .streamSettings |= (if type == "string"
        then (fromjson | .xhttpSettings.xPaddingBytes = $padding | tojson)
        else .xhttpSettings.xPaddingBytes = $padding end)' \
    "$work/inbound-now.json" > "$work/inbound-want.json"
inbound_norm() { jq -S '.streamSettings |= (if type == "string" then fromjson else . end)' "$1"; }
if [ "$(inbound_norm "$work/inbound-now.json")" != "$(inbound_norm "$work/inbound-want.json")" ]; then
    api_ok "update inbound" "panel/api/inbounds/update/$xhttp_id" -X POST \
        -H 'Content-Type: application/json' -d @"$work/inbound-want.json" >/dev/null
    log "XHTTP inbound updated: profile name, loopback only, padding"
fi

# The relay client (ADR-0019, R-vpn-server-22): a second client ID on the same
# inbound, used only by the fallback server. Made once and kept.
relay_now=$(api panel/api/clients/get/"$RELAY_EMAIL" 2>/dev/null || true)
if printf '%s' "$relay_now" | jq -e '.success == true' >/dev/null 2>&1; then
    printf '%s' "$relay_now" | jq -e --argjson id "$xhttp_id" '.obj.inboundIds | index($id) != null' >/dev/null \
        || die "the client '$RELAY_EMAIL' exists but is not attached to the tunnel inbound; attach it in the panel and run again"
    log "relay client already exists; ID kept"
else
    relay_uuid=$(api_ok "new uuid" panel/api/server/getNewUUID | jq -r '.obj.uuid // .obj')
    printf '%s' "$relay_uuid" | grep -Eq '^[0-9a-f-]{36}$' || die "panel returned no UUID for the relay client"
    jq -n --arg id "$relay_uuid" --arg email "$RELAY_EMAIL" --argjson inbound "$xhttp_id" '{
        client: {id: $id, email: $email, flow: "", enable: true, limitIp: 0, totalGB: 0, expiryTime: 0},
        inboundIds: [$inbound]}' > "$work/relay-client.json"
    api_ok "add relay client" panel/api/clients/add -X POST \
        -H 'Content-Type: application/json' -d @"$work/relay-client.json" >/dev/null
    log "relay client created"
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
for name in "${SITE_NAMES[@]}"; do
    serves_page --http2 --resolve "$name:$VPN_PORT:127.0.0.1" "https://$name:$VPN_PORT/" \
        || die "nginx does not answer for $name on ${VPN_PORT}"
done
for p in "${ALT_PORTS[@]}"; do
    serves_page --resolve "$COVER_NAME:$p:127.0.0.1" "https://$COVER_NAME:$p/" \
        || die "nginx does not answer for $COVER_NAME on $p"
done
log "nginx holds ${VPN_PORT}/tcp and the alternative ports ${ALT_PORTS[*]}: site and tunnel path"

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

# 9. Client link, built from what the panel stores. Its fingerprint is `android`
#    because the browser fingerprints offer h2 whatever the ALPN says (ADR-0015). It names the host, not the
#    address: the client reaches Cloudflare, which reaches this server.
#    Written to a root-only file.
#    The relay link (ADR-0019) is the same link for the client `relay`.
write_link() { # write_link <client email> <profile name> <file> [port] [fragment]
api_ok "read inbound" "panel/api/inbounds/get/$xhttp_id" | jq -r \
    --arg host "$COVER_NAME" --argjson port "${4:-$VPN_PORT}" --arg email "$1" --arg name "$2" --arg frag "${5:-}" \
    --arg padding "$XHTTP_PADDING" --argjson xmux "$XHTTP_XMUX" '
    .obj as $in
    | ($in.settings | if type == "string" then fromjson else . end) as $s
    | ($in.streamSettings | if type == "string" then fromjson else . end) as $st
    | ($s.clients[] | select(.email == $email)) as $c
    | "vless://\($c.id)@\($host):\($port)?encryption=none&security=tls&sni=\($host)&fp=android&alpn=http%2F1.1&type=xhttp&host=\($host)&path=\($st.xhttpSettings.path | @uri)&mode=auto\(if $frag == "" then "" else "&fragment=" + $frag end)&extra=\({xPaddingBytes: $padding, xmux: $xmux} | tojson | @uri)#\($name | @uri)"' \
    > "$3"
chmod 600 "$3"
grep -q '^vless://' "$3" || die "the link for the client '$1' was not written"
}
write_link "$CLIENT_EMAIL" "$INBOUND_REMARK" "$LINK_FILE" "$VPN_PORT" "$LINK_FRAGMENT"
log "client link written to $LINK_FILE"
write_link "$RELAY_EMAIL" "$RELAY_EMAIL" "$RELAY_LINK_FILE"
log "relay link written to $RELAY_LINK_FILE"
# The same link on each alternative port (ADR-0020), for a network that cuts
# 443 to the name. The profile name carries the port, so the app tells them apart.
: > "$ALT_LINKS_FILE"
chmod 600 "$ALT_LINKS_FILE"
for p in "${ALT_PORTS[@]}"; do
    write_link "$CLIENT_EMAIL" "$INBOUND_REMARK $p" "$work/alt-link" "$p" "$LINK_FRAGMENT"
    cat "$work/alt-link" >> "$ALT_LINKS_FILE"
done
log "links for the alternative ports written to $ALT_LINKS_FILE"
rm -f "$STATE_DIR/subscription-url.txt"

log "final state:"
systemctl is-active x-ui
ufw status | grep -v "# $CF_RULE_COMMENT" | sed -n '1,12p'
log "plus $(ufw status | grep -c "# $CF_RULE_COMMENT") rules admitting Cloudflare's ranges to 80, ${VPN_PORT} and the alternative ports"
host_reboot_notes
log "done"
