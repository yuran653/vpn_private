#!/usr/bin/env bash
# verify-fallback.sh - checks the deployed fallback server from the inside.
#
# Runs on the fallback VPS as root. Starts a temporary Xray client on loopback
# that connects with the issued fallback link, and checks what a client can and
# cannot do through it, plus the host state. Each check names the acceptance
# criterion it verifies (the vpn-fallback capability; until the change
# add-fallback-reality-server is archived, its delta in changes/). Changes
# nothing on the host.
#
# Usage:
#   sudo -n bash verify-fallback.sh
#
# Exit code 0 only when every check passes. Prints no secret, and not the cover
# name. Not yet run on a server (written 2026-11-12).

set -uo pipefail

readonly LINK_FILE=/root/vpn/vless-link.txt
readonly RELAY_LINK_FILE=/root/vpn/relay-link.txt
readonly XRAY=/usr/local/x-ui/bin/xray-linux-amd64
readonly XRAY_CONFIG=/usr/local/x-ui/bin/config.json
readonly SOCKS_PORT=10808
readonly VPN_PORT=443
# The first server's profile name; the fallback's must differ (R-vpn-fallback-05.c).
readonly FIRST_PROFILE='กรุงเทพฯ cloud.z.com'

fails=0
pass() { printf 'PASS  %-20s %s\n' "$1" "$2"; }
fail() { printf 'FAIL  %-20s %s\n' "$1" "$2"; fails=$((fails + 1)); }
check() { # check <criterion> <description> <command...>
    local id=$1 desc=$2; shift 2
    if "$@" >/dev/null 2>&1; then pass "$id" "$desc"; else fail "$id" "$desc"; fi
}

[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo -n bash $0" >&2; exit 2; }
[ -r "$LINK_FILE" ] || { echo "no client link at $LINK_FILE; run deploy-fallback.sh first" >&2; exit 2; }
[ -r "$RELAY_LINK_FILE" ] || { echo "no relay link at $RELAY_LINK_FILE" >&2; exit 2; }

work=$(mktemp -d)
client_pid=""
cleanup() { [ -n "$client_pid" ] && kill "$client_pid" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT
chmod 700 "$work"

# One field of a link, read from the file so no secret is on a command line.
link_field() { # link_field <file> <host|port|id|name|query key>
    python3 -I -c '
import sys, urllib.parse
u = urllib.parse.urlsplit(open(sys.argv[1]).read().strip())
q = dict(urllib.parse.parse_qsl(u.query))
k = sys.argv[2]
print({"host": u.hostname or "", "port": str(u.port or ""), "id": u.username or "",
       "name": urllib.parse.unquote(u.fragment)}.get(k, q.get(k, "")))' "$1" "$2"
}

# Client config from the link, as a phone app would read it.
python3 -I - "$LINK_FILE" "$SOCKS_PORT" > "$work/client.json" <<'PY'
import json, sys, urllib.parse
u = urllib.parse.urlsplit(open(sys.argv[1]).read().strip())
q = dict(urllib.parse.parse_qsl(u.query))
print(json.dumps({
    "log": {"loglevel": "warning"},
    "inbounds": [{"listen": "127.0.0.1", "port": int(sys.argv[2]), "protocol": "socks", "settings": {"udp": True}}],
    "outbounds": [{
        "protocol": "vless",
        "settings": {"vnext": [{"address": u.hostname, "port": u.port, "users": [
            {"id": u.username, "encryption": "none", "flow": q.get("flow", "")}]}]},
        "streamSettings": {"network": q.get("type", "tcp"), "security": q.get("security", ""),
            "realitySettings": {"serverName": q.get("sni", ""), "fingerprint": q.get("fp", ""),
                "publicKey": q.get("pbk", ""), "shortId": q.get("sid", ""), "spiderX": q.get("spx", "/")}}}]}))
PY
server_ip=$(ip -4 route get 1.1.1.1 | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}')
cover=$(link_field "$LINK_FILE" sni)
relay_host=$(link_field "$RELAY_LINK_FILE" host)

# One DNS query through the SOCKS proxy, over TCP (default) or UDP; prints the
# number of answers. Prints nothing and fails when no reply comes.
cat > "$work/dnsprobe.py" <<'PY'
import socket, struct, sys
port, resolver, name, qtype = int(sys.argv[1]), sys.argv[2], sys.argv[3], int(sys.argv[4])
transport = sys.argv[5] if len(sys.argv) > 5 else "tcp"
q = struct.pack(">HHHHHH", 0x1234, 0x0100, 1, 0, 0, 0)
q += b"".join(bytes([len(p)]) + p.encode() for p in name.split(".")) + b"\x00" + struct.pack(">HH", qtype, 1)
s = socket.create_connection(("127.0.0.1", port), timeout=10)
s.sendall(b"\x05\x01\x00"); assert s.recv(2) == b"\x05\x00"
if transport == "udp":
    s.sendall(b"\x05\x03\x00\x01\x00\x00\x00\x00\x00\x00")
    reply = s.recv(10)
    assert reply[1] == 0
    relay = ("127.0.0.1", struct.unpack(">H", reply[8:10])[0])
    u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    u.settimeout(10)
    u.sendto(b"\x00\x00\x00\x01" + socket.inet_aton(resolver) + struct.pack(">H", 53) + q, relay)
    try:
        data = u.recvfrom(4096)[0][10:]
    except socket.timeout:
        sys.exit(1)
    if len(data) < 12:
        sys.exit(1)
    print(struct.unpack(">H", data[6:8])[0])
    sys.exit(0)
s.sendall(b"\x05\x01\x00\x01" + socket.inet_aton(resolver) + struct.pack(">H", 53))
assert s.recv(10)[1] == 0
s.sendall(struct.pack(">H", len(q)) + q)
data = b""
while len(data) < 12:
    chunk = s.recv(4096)
    if not chunk:
        break
    data += chunk
if len(data) < 12:
    sys.exit(1)
print(struct.unpack(">H", data[8:10])[0])
PY

"$XRAY" run -c "$work/client.json" > "$work/client.log" 2>&1 &
client_pid=$!
for _ in $(seq 1 10); do
    ss -Htln "sport = :$SOCKS_PORT" | grep -q . && break
    sleep 1
done

via() { curl -s --max-time 25 --socks5-hostname "127.0.0.1:$SOCKS_PORT" "$@"; }
is_ipv4() { printf '%s' "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; }

# R-vpn-fallback-01.a: a client using the fallback link reaches the internet,
# and the site sees an IPv4 address that is not this server's. That it is not
# the first server's either follows from R-vpn-fallback-04.d (the exit is WARP).
exit_ip=$(via https://api.ipify.org)
if ! is_ipv4 "$exit_ip"; then
    fail R-vpn-fallback-01.a "tunnel exit address is '${exit_ip:-none}', expected an IPv4 address"
elif [ "$exit_ip" = "$server_ip" ]; then
    fail R-vpn-fallback-01.a "tunnel exit address is this server's own address"
else
    pass R-vpn-fallback-01.a "tunnel works; exit address is IPv4 and not this server's own"
fi

# R-vpn-fallback-01.b: the link names this server's address on 443, and nothing
# of the first server.
if [ "$(link_field "$LINK_FILE" host)" = "$server_ip" ] && [ "$(link_field "$LINK_FILE" port)" = "$VPN_PORT" ] \
    && [ -n "$relay_host" ] && ! grep -qF "$relay_host" "$LINK_FILE"; then
    pass R-vpn-fallback-01.b "the link names this server's address on ${VPN_PORT} and no name of the first server"
else
    fail R-vpn-fallback-01.b "the link does not name this server's address on ${VPN_PORT}, or carries the first server's name"
fi

# R-vpn-fallback-02.a (inside half): a TLS client without the key gets the
# cover site's publicly trusted certificate and an HTTP answer.
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 --resolve "$cover:$VPN_PORT:127.0.0.1" "https://$cover/")
case "$code" in
    2??|3??) pass R-vpn-fallback-02.a "a client without the key gets the cover site's certificate and page" ;;
    *) fail R-vpn-fallback-02.a "a client without the key got '$code' instead of the cover site" ;;
esac

# R-vpn-fallback-02.c (inside half): another name, and no name at all, still
# get a certificate from the cover site, not a reset.
other=$(echo | timeout 15 openssl s_client -connect "127.0.0.1:$VPN_PORT" -servername www.example.org 2>/dev/null | openssl x509 -noout -subject 2>/dev/null)
noname=$(echo | timeout 15 openssl s_client -connect "127.0.0.1:$VPN_PORT" -noservername 2>/dev/null | openssl x509 -noout -subject 2>/dev/null)
if [ -n "$other" ] && [ -n "$noname" ]; then
    pass R-vpn-fallback-02.c "a client with another name or no name gets a certificate, not a reset"
else
    fail R-vpn-fallback-02.c "a client with another name or no name got no certificate"
fi

# R-vpn-fallback-03.a: nothing but SSH and the VPN port listens on a public
# address, and no UDP socket at all (this host has no WARP tunnel).
tcp_listeners=$(ss -Htlnp | awk '{print $4 " " $6}' | grep -Ev '^(127\.|\[::1\]|\[::ffff:127\.)' \
    | sed -E 's/^[^ ]*:([0-9]+) .*/\1/' | sort -un | tr '\n' ' ')
udp_public=$(ss -Hulnp | awk '{print $4 " " $6}' | grep -Ev '^(127\.|\[::1\]|\[::ffff:127\.)' \
    | sed -E 's/^[^ ]*:([0-9]+) .*/\1/' | sort -un | tr '\n' ' ')
ssh_port=$(sshd -T 2>/dev/null | awk '$1 == "port" {print $2}')
expected=$(printf '%s\n%s\n' "$ssh_port" "$VPN_PORT" | sort -un | tr '\n' ' ')
if [ "$tcp_listeners" = "$expected" ] && [ -z "$udp_public" ]; then
    pass R-vpn-fallback-03.a "public listeners are only SSH and ${VPN_PORT}, and no UDP socket"
else
    fail R-vpn-fallback-03.a "public listeners are: tcp ${tcp_listeners:-none}; udp ${udp_public:-none}"
fi

# R-vpn-fallback-03.b: the firewall admits the VPN port from anywhere and SSH
# from listed sources only, and nothing else.
ufw_rules=$(ufw status | awk '/ ALLOW / {print $1 " " $3}' | sort -u)
ufw_verbose=$(ufw status verbose)
other_ports=$(printf '%s\n' "$ufw_rules" | awk -v s="${ssh_port}/tcp" -v v="${VPN_PORT}/tcp" '$1 != s && $1 != v' | tr '\n' ';')
if grep -qx "${VPN_PORT}/tcp Anywhere" <<<"$ufw_rules" \
    && grep -q "^${ssh_port}/tcp " <<<"$ufw_rules" \
    && ! grep -qx "${ssh_port}/tcp Anywhere" <<<"$ufw_rules" \
    && [ -z "$other_ports" ] && grep -q 'deny (incoming)' <<<"$ufw_verbose"; then
    pass R-vpn-fallback-03.b "ufw denies incoming except ${VPN_PORT}/tcp from anywhere and SSH from listed sources"
else
    fail R-vpn-fallback-03.b "ufw admits something else, or SSH from anywhere${other_ports:+ (other rules: $other_ports)}"
fi

# R-vpn-fallback-04.a: no IPv6 on the host, and none through the tunnel.
if ip -6 addr show scope global | grep -q inet6; then
    fail R-vpn-fallback-04.a "host has a global IPv6 address"
elif curl -6 -s --max-time 8 -o /dev/null https://ifconfig.co; then
    fail R-vpn-fallback-04.a "host reached the internet over IPv6"
elif via -o /dev/null 'https://[2606:4700:4700::1111]/'; then
    fail R-vpn-fallback-04.a "IPv6 destination was reachable through the tunnel"
else
    pass R-vpn-fallback-04.a "host has no IPv6, and an IPv6 destination is refused through the tunnel"
fi

# R-vpn-fallback-04.b: a DNS query through the tunnel is answered (by the first
# server), even when addressed to a resolver that does not exist, and this
# server resolves nothing itself for client traffic.
unanswered=""
for transport in tcp udp; do
    a=$(python3 "$work/dnsprobe.py" "$SOCKS_PORT" 192.0.2.53 example.com 1 "$transport" 2>/dev/null)
    [ -n "$a" ] && [ "$a" -ge 1 ] 2>/dev/null || unanswered="$unanswered $transport"
done
if [ -z "$unanswered" ] && jq -e '((.dns // {}) | (.servers // []) | length) == 0
        and (.routing.domainStrategy // "AsIs") == "AsIs"' "$XRAY_CONFIG" >/dev/null 2>&1; then
    pass R-vpn-fallback-04.b "DNS through the tunnel is answered over TCP and UDP; this server resolves nothing for clients"
else
    fail R-vpn-fallback-04.b "DNS through the tunnel unanswered over:${unanswered:- none}, or this server has resolvers of its own"
fi

# R-vpn-fallback-04.c: no activity record, and the relay to the first server's
# name is the only way out: no direct outbound and no WARP tunnel here.
relay_address=$(jq -r '.outbounds[0].settings.vnext[0].address // empty' "$XRAY_CONFIG" 2>/dev/null)
if jq -e '.log.access == "none" and .log.dnsLog == false
        and .outbounds[0].protocol == "vless" and .outbounds[0].tag == "relay"
        and ([.outbounds[] | select(.protocol == "freedom" or .protocol == "wireguard")] | length) == 0' "$XRAY_CONFIG" >/dev/null 2>&1 \
    && [ -n "$relay_host" ] && [ "$relay_address" = "$relay_host" ] && ! is_ipv4 "$relay_address"; then
    pass R-vpn-fallback-04.c "logs are off and the relay to the first server's name is the only way out"
else
    fail R-vpn-fallback-04.c "a log is on, or there is a way out that is not the relay to the first server's name"
fi

# R-vpn-fallback-04.d: the exit is the first server's, through WARP, in Thailand.
trace=$(via https://www.cloudflare.com/cdn-cgi/trace)
warp_state=$(printf '%s\n' "$trace" | sed -n 's/^warp=//p')
exit_country=$(printf '%s\n' "$trace" | sed -n 's/^loc=//p')
case "$warp_state $exit_country" in
    "on TH"|"plus TH") pass R-vpn-fallback-04.d "the exit is WARP, placed in Thailand" ;;
    *) fail R-vpn-fallback-04.d "the exit reports warp='${warp_state:-no answer}' loc='${exit_country:-unknown}', expected WARP in TH" ;;
esac

# R-vpn-fallback-05.a (inside half) and 05.c: the users' link shares no client
# ID with the relay link, and its profile name is not the first server's.
own_id=$(link_field "$LINK_FILE" id)
relay_id=$(link_field "$RELAY_LINK_FILE" id)
[ -n "$own_id" ] && [ "$own_id" != "$relay_id" ] \
    && pass R-vpn-fallback-05.a "the fallback link and the relay link have different client IDs" \
    || fail R-vpn-fallback-05.a "the fallback link reuses the relay's client ID"
profile=$(link_field "$LINK_FILE" name)
[ -n "$profile" ] && [ "$profile" != "$FIRST_PROFILE" ] \
    && pass R-vpn-fallback-05.c "the profile name differs from the first server's" \
    || fail R-vpn-fallback-05.c "the profile name is missing or the same as the first server's"

# R-vpn-fallback-07.a: security updates install and reboot the host unattended.
apt_settings=$(apt-config dump)
if grep -q 'APT::Periodic::Unattended-Upgrade "1"' <<<"$apt_settings" \
    && systemctl is-enabled --quiet unattended-upgrades \
    && grep -q 'Unattended-Upgrade::Automatic-Reboot "true"' <<<"$apt_settings" \
    && grep -q 'Unattended-Upgrade::Automatic-Reboot-Time "01:00"' <<<"$apt_settings" \
    && [ "$(timedatectl show -p Timezone --value 2>/dev/null)" = Asia/Bangkok ]; then
    pass R-vpn-fallback-07.a "unattended upgrades are on, with an automatic reboot at 01:00 Asia/Bangkok"
else
    fail R-vpn-fallback-07.a "unattended upgrades or the automatic reboot at 01:00 Asia/Bangkok are not set"
fi

# R-vpn-fallback-07.c (boot half): IPv6 stays off across restarts and the panel
# comes back.
check R-vpn-fallback-07.c "kernel booted with IPv6 disabled, panel enabled at boot and running" \
    sh -c "grep -qw 'ipv6.disable=1' /proc/cmdline && systemctl is-enabled --quiet x-ui && systemctl is-active --quiet x-ui"

# R-vpn-fallback-07.d (file half): the links are readable by root only.
if [ "$(stat -c '%a %U' "$LINK_FILE")" = "600 root" ] && [ "$(stat -c '%a %U' "$RELAY_LINK_FILE")" = "600 root" ]; then
    pass R-vpn-fallback-07.d "the client link and the relay link are readable by root only"
else
    fail R-vpn-fallback-07.d "a link file is readable by others"
fi

echo
if [ "$fails" -eq 0 ]; then
    echo "all checks passed"
else
    echo "$fails check(s) failed"
    exit 1
fi
