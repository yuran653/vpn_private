#!/usr/bin/env bash
# verify-vpn.sh - checks the deployed VPN server from the inside.
#
# Runs on the VPS as root. Starts a temporary Xray client on loopback that
# connects with the issued client link, and checks what a client can and cannot
# do through the tunnel, plus the host state. Each check names the acceptance
# criterion it verifies (specs/vpn-server/spec.md). Changes nothing on the host.
#
# Usage:
#   sudo -n bash verify-vpn.sh
#
# Exit code 0 only when every check passes. Prints no secret.

set -uo pipefail

readonly LINK_FILE=/root/vpn/vless-link.txt
readonly XRAY=/usr/local/x-ui/bin/xray-linux-amd64
readonly XRAY_CONFIG=/usr/local/x-ui/bin/config.json
readonly SOCKS_PORT=10808
readonly VPN_PORT=443

fails=0
pass() { printf 'PASS  %-18s %s\n' "$1" "$2"; }
fail() { printf 'FAIL  %-18s %s\n' "$1" "$2"; fails=$((fails + 1)); }
check() { # check <criterion> <description> <command...>
    local id=$1 desc=$2; shift 2
    if "$@" >/dev/null 2>&1; then pass "$id" "$desc"; else fail "$id" "$desc"; fi
}

[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo -n bash $0" >&2; exit 2; }
[ -r "$LINK_FILE" ] || { echo "no client link at $LINK_FILE; run deploy-vpn.sh first" >&2; exit 2; }

work=$(mktemp -d)
client_pid=""
cleanup() { [ -n "$client_pid" ] && kill "$client_pid" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT
chmod 700 "$work"

# Client config from the link, exactly as a phone app would read it.
python3 - "$LINK_FILE" "$SOCKS_PORT" > "$work/client.json" <<'PY'
import json, sys, urllib.parse
u = urllib.parse.urlsplit(open(sys.argv[1]).read().strip())
q = dict(urllib.parse.parse_qsl(u.query))
print(json.dumps({
    "log": {"loglevel": "warning"},
    "inbounds": [{"listen": "127.0.0.1", "port": int(sys.argv[2]), "protocol": "socks", "settings": {"udp": True}}],
    "outbounds": [{
        "protocol": "vless",
        "settings": {"vnext": [{"address": u.hostname, "port": u.port, "users": [
            {"id": u.username, "encryption": "none", "flow": q["flow"]}]}]},
        "streamSettings": {"network": "tcp", "security": "reality", "realitySettings": {
            "serverName": q["sni"], "fingerprint": q["fp"], "publicKey": q["pbk"],
            "shortId": q["sid"], "spiderX": "/"}}}]}))
PY
server_ip=$(python3 -c 'import sys,urllib.parse; print(urllib.parse.urlsplit(open(sys.argv[1]).read().strip()).hostname)' "$LINK_FILE")

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
    # UDP ASSOCIATE; the datagram carries a SOCKS header naming the resolver.
    s.sendall(b"\x05\x03\x00\x01\x00\x00\x00\x00\x00\x00")
    reply = s.recv(10)
    assert reply[1] == 0
    relay = ("127.0.0.1", struct.unpack(">H", reply[8:10])[0])
    u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    u.settimeout(10)
    u.sendto(b"\x00\x00\x00\x01" + socket.inet_aton(resolver) + struct.pack(">H", 53) + q, relay)
    try:
        data = u.recvfrom(4096)[0][10:]     # drop the 10-byte SOCKS header
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

via() { curl -s --max-time 20 --socks5-hostname "127.0.0.1:$SOCKS_PORT" "$@"; }

# R-vpn-server-01.a: a client using the issued link reaches the internet, and the site
# sees an IPv4 address that is not the server's own (traffic leaves through WARP).
is_ipv4() { printf '%s' "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; }
exit_ip=$(via https://api.ipify.org)
if ! is_ipv4 "$exit_ip"; then
    fail R-vpn-server-01.a "tunnel exit address is '${exit_ip:-none}', expected an IPv4 address"
elif [ "$exit_ip" = "$server_ip" ]; then
    fail R-vpn-server-01.a "tunnel exit address is the server's own address"
else
    pass R-vpn-server-01.a "tunnel works; exit address is IPv4 and not the server's own"
fi

# R-vpn-server-02.a: the host has no global IPv6 address and cannot reach IPv6.
if ip -6 addr show scope global | grep -q inet6; then
    fail R-vpn-server-02.a "host has a global IPv6 address"
elif curl -6 -s --max-time 8 -o /dev/null https://ifconfig.co; then
    fail R-vpn-server-02.a "host reached the internet over IPv6"
else
    pass R-vpn-server-02.a "host has no IPv6 address and no IPv6 route out"
fi

# R-vpn-server-02.b: a client asking for an IPv6 destination through the tunnel is refused.
if via -o /dev/null 'https://[2606:4700:4700::1111]/'; then
    fail R-vpn-server-02.b "IPv6 destination was reachable through the tunnel"
else
    pass R-vpn-server-02.b "IPv6 destination refused through the tunnel"
fi

# R-vpn-server-02.c: a dual-stack site reached through the tunnel sees an IPv4 client address.
seen=$(via https://ifconfig.co/ip)
case "$seen" in
    *:*) fail R-vpn-server-02.c "dual-stack site saw an IPv6 address" ;;
    *) is_ipv4 "$seen" \
        && pass R-vpn-server-02.c "dual-stack site saw an IPv4 address" \
        || fail R-vpn-server-02.c "dual-stack site saw '${seen:-nothing}'" ;;
esac

# R-vpn-server-02.d: an AAAA query through the tunnel returns no IPv6 address.
aaaa=$(python3 "$work/dnsprobe.py" "$SOCKS_PORT" 1.1.1.1 google.com 28 2>/dev/null)
[ "$aaaa" = 0 ] \
    && pass R-vpn-server-02.d "AAAA query through the tunnel returned no address" \
    || fail R-vpn-server-02.d "AAAA query through the tunnel returned '${aaaa:-no reply}'"

# R-vpn-server-03.a: a DNS query sent through the tunnel is answered by the server itself,
# even when addressed to a resolver that does not exist (192.0.2.53 is a reserved test address).
# Checked over TCP and over UDP, the transport client devices use by default.
unanswered=""
for transport in tcp udp; do
    a=$(python3 "$work/dnsprobe.py" "$SOCKS_PORT" 192.0.2.53 example.com 1 "$transport" 2>/dev/null)
    [ -n "$a" ] && [ "$a" -ge 1 ] 2>/dev/null || unanswered="$unanswered $transport"
done
[ -z "$unanswered" ] \
    && pass R-vpn-server-03.a "DNS query to a non-existent resolver was answered by the server, over TCP and UDP" \
    || fail R-vpn-server-03.a "DNS query through the tunnel was not answered by the server over:$unanswered"

# R-vpn-server-03.b: every resolver the server uses for tunnel traffic is DNS-over-HTTPS.
check R-vpn-server-03.b "all tunnel DNS resolvers are DNS-over-HTTPS" \
    jq -e '(.dns.servers | length) > 0 and (.dns.servers | all(type == "string" and startswith("https")))' "$XRAY_CONFIG"

# R-vpn-server-12.a: client traffic leaves through Cloudflare WARP. Cloudflare's
# connection report says so itself.
trace=$(via https://www.cloudflare.com/cdn-cgi/trace)
warp_state=$(printf '%s\n' "$trace" | sed -n 's/^warp=//p')
case "$warp_state" in
    on|plus) pass R-vpn-server-12.a "Cloudflare reports the tunnel exit as WARP" ;;
    *) fail R-vpn-server-12.a "Cloudflare reports warp='${warp_state:-no answer}' for the tunnel exit" ;;
esac

# R-vpn-server-12.b: the exit is placed in Thailand.
exit_country=$(printf '%s\n' "$trace" | sed -n 's/^loc=//p')
[ "$exit_country" = TH ] \
    && pass R-vpn-server-12.b "tunnel exit is placed in Thailand" \
    || fail R-vpn-server-12.b "tunnel exit is placed in '${exit_country:-unknown}', expected TH"

# R-vpn-server-12.f: the tunnel reaches Cloudflare at its Bangkok site, not at a
# distant one (ADR-0009). The same report names the site.
exit_site=$(printf '%s\n' "$trace" | sed -n 's/^colo=//p')
[ "$exit_site" = BKK ] \
    && pass R-vpn-server-12.f "tunnel reaches Cloudflare at its Bangkok site" \
    || fail R-vpn-server-12.f "tunnel reaches Cloudflare at site '${exit_site:-unknown}', expected BKK"

# R-vpn-server-12.c: WARP is the only way out. No outbound can send from the server's
# own address, so a request fails when WARP is unreachable instead of leaking. The
# one other outbound, the subscription's (ADR-0010), redirects to loopback only.
check R-vpn-server-12.c "WARP is the default outbound; no outbound reaches anything but loopback" \
    jq -e '.outbounds[0].protocol == "wireguard" and .outbounds[0].tag == "warp"
        and ([.outbounds[] | select(.protocol == "freedom")
              | select(((.settings.redirect // "") | test("^127\\.0\\.0\\.1:[0-9]+$")) | not)] | length) == 0' "$XRAY_CONFIG"

# R-vpn-server-12.d: YouTube Music opens through the tunnel. From an address that
# Google places in an unsupported country it answers with a "not available" page.
ytm=$(via -L -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36' \
    'https://music.youtube.com/?hl=en')
if [ -z "$ytm" ]; then
    fail R-vpn-server-12.d "YouTube Music gave no answer through the tunnel"
elif printf '%s' "$ytm" | grep -qi 'not available in your'; then
    fail R-vpn-server-12.d "YouTube Music says it is not available at the tunnel exit"
else
    pass R-vpn-server-12.d "YouTube Music is available at the tunnel exit"
fi

# R-vpn-server-13: the subscription, requested the way the client app does it, through
# the tunnel at the reserved address (ADR-0010).
readonly SUB_URL_FILE=/root/vpn/subscription-url.txt
readonly SUB_ADDRESS=192.0.2.1
readonly SUB_NAME_GROUP='VPN ไทย'
readonly SUB_NAME_PROFILE='กรุงเทพฯ cloud.z.com'
sub_path=""
[ -r "$SUB_URL_FILE" ] && sub_path=$(sed -E 's#^http://[^/]+##' "$SUB_URL_FILE")
via -D "$work/sub.headers" -o "$work/sub.body" "http://$SUB_ADDRESS$sub_path" >/dev/null 2>&1
python3 -I - "$work/sub.headers" "$work/sub.body" "$server_ip" "$VPN_PORT" "$SUB_NAME_GROUP" "$SUB_NAME_PROFILE" > "$work/sub.result" 2>&1 <<'PY'
import base64, binascii, sys, urllib.parse
headers_file, body_file, ip, port, group, profile = sys.argv[1:7]
headers = {}
for line in open(headers_file, encoding="utf-8", errors="replace"):
    if ":" in line:
        k, v = line.split(":", 1)
        headers[k.strip().lower()] = v.strip()
body = open(body_file, "rb").read().strip()
try:
    text = base64.b64decode(body + b"=" * (-len(body) % 4)).decode()
except (binascii.Error, UnicodeDecodeError):
    text = body.decode(errors="replace")
links = [l for l in text.split() if l.startswith("vless://")]
print("a", "ok" if any(("@%s:%s?" % (ip, port)) in l for l in links) else "no vless link for %s:%s" % (ip, port))
title = headers.get("profile-title", "")
if title.startswith("base64:"):
    title = base64.b64decode(title[7:] + "=" * (-len(title[7:]) % 4)).decode()
print("b", "ok" if title == group else "title is '%s'" % title)
info = dict(p.strip().split("=", 1) for p in headers.get("subscription-userinfo", "").split(";") if "=" in p)
print("c", "ok" if info.get("total") == "0" and info.get("expire", "0") == "0" else "userinfo is '%s'" % headers.get("subscription-userinfo", "none"))
names = [urllib.parse.unquote(l.split("#", 1)[1]) for l in links if "#" in l]
print("e", "ok" if names == [profile] else "profile names are %s" % names)
PY
sub_check() { # sub_check <letter> <criterion> <description>
    local line; line=$(grep "^$1 " "$work/sub.result" | head -n1)
    if [ "${line#"$1 "}" = ok ]; then pass "$2" "$3"; else fail "$2" "$3 (${line#"$1 "}${line:-no result})"; fi
}
sub_check a R-vpn-server-13.a "the subscription carries the client link for the server's address"
sub_check b R-vpn-server-13.b "the subscription is titled '$SUB_NAME_GROUP'"
sub_check c R-vpn-server-13.c "the traffic information has no quota and no expiry"
sub_check e R-vpn-server-13.e "the profile is named '$SUB_NAME_PROFILE'"
if curl -s -o /dev/null --max-time 5 "http://$server_ip:2096/"; then
    fail R-vpn-server-13.d "the subscription port answers on the public address"
else
    pass R-vpn-server-13.d "the subscription port does not answer on the public address"
fi
reached=""
for target in http://192.0.2.2/ http://192.0.2.1:8080/ http://127.0.0.1:2096/ http://10.0.0.1/ http://169.254.169.254/; do
    via -o /dev/null "$target" && reached="$reached $target"
done
[ -z "$reached" ] \
    && pass R-vpn-server-13.f "other reserved and private addresses are refused through the tunnel" \
    || fail R-vpn-server-13.f "reachable through the tunnel:$reached"

# R-vpn-server-04.a (inside half): a TLS client without the key gets the cover site's certificate.
subject=$(echo | timeout 15 openssl s_client -connect "127.0.0.1:$VPN_PORT" \
    -servername "$(jq -r '.inbounds[] | select(.port == 443) | .streamSettings.realitySettings.serverNames[0]' "$XRAY_CONFIG")" \
    -verify_return_error 2>/dev/null | openssl x509 -noout -subject 2>/dev/null)
[ -n "$subject" ] \
    && pass R-vpn-server-04.a "unauthenticated TLS client is shown a valid third-party certificate" \
    || fail R-vpn-server-04.a "unauthenticated TLS client did not get a valid certificate"

# R-vpn-server-05.a: nothing but SSH and the VPN port listens on a public address.
# The one exception is the UDP socket Xray holds open for its WARP tunnel: it is
# the tunnel's own sending socket, on a port the firewall does not admit (05.c).
tcp_listeners=$(ss -Htlnp | awk '{print $4 " " $6}' | grep -Ev '^(127\.|\[::1\]|\[::ffff:127\.)' \
    | sed -E 's/^[^ ]*:([0-9]+) .*/\1/' | sort -un | tr '\n' ' ')
udp_other=$(ss -Hulnp | awk '{print $4 " " $6}' | grep -Ev '^(127\.|\[::1\]|\[::ffff:127\.)' \
    | grep -v '"xray-' | sed -E 's/^[^ ]*:([0-9]+) .*/\1/' | sort -un | tr '\n' ' ')
ssh_port=$(sshd -T 2>/dev/null | awk '$1 == "port" {print $2}')
expected=$(printf '%s\n%s\n' "$ssh_port" "$VPN_PORT" | sort -un | tr '\n' ' ')
if [ "$tcp_listeners" = "$expected" ] && [ -z "$udp_other" ]; then
    pass R-vpn-server-05.a "public listeners are only SSH and ${VPN_PORT}, plus the WARP tunnel's own UDP socket"
else
    fail R-vpn-server-05.a "public listeners are: tcp ${tcp_listeners:-none}; udp not owned by the proxy: ${udp_other:-none}"
fi

# R-vpn-server-05.c: the firewall admits only SSH and the VPN port.
rules=$(ufw status | awk '/ALLOW/ {print $1}' | sort -u | tr '\n' ' ')
[ "$rules" = "$(printf '%s/tcp\n%s/tcp\n' "$ssh_port" "$VPN_PORT" | sort -u | tr '\n' ' ')" ] \
    && ufw status verbose | grep -q 'deny (incoming)' \
    && pass R-vpn-server-05.c "ufw denies incoming except SSH and ${VPN_PORT}/tcp" \
    || fail R-vpn-server-05.c "ufw rules are: $rules"

# R-vpn-server-06.a: the server keeps no record of client connections.
check R-vpn-server-06.a "Xray access log and DNS log are off" \
    jq -e '.log.access == "none" and .log.dnsLog == false' "$XRAY_CONFIG"

# R-vpn-server-07.a: security updates install without an operator.
# The dump is captured first: with pipefail, grep -q closing the pipe early fails the pipeline.
apt_settings=$(apt-config dump)
if printf '%s\n' "$apt_settings" | grep -q 'APT::Periodic::Unattended-Upgrade "1"' \
    && systemctl is-enabled --quiet unattended-upgrades; then
    pass R-vpn-server-07.a "unattended upgrades are enabled"
else
    fail R-vpn-server-07.a "unattended upgrades are not enabled"
fi

# R-vpn-server-07.b: a security-update run has completed in the last 48 hours.
# The log is written at the end of every run, including one that found nothing.
uu_log=/var/log/unattended-upgrades/unattended-upgrades.log
if [ -n "$(find "$uu_log" -mmin -2880 2>/dev/null)" ]; then
    pass R-vpn-server-07.b "a security-update run completed in the last 48 hours"
else
    fail R-vpn-server-07.b "no security-update run in the last 48 hours"
fi

# R-vpn-server-07.c: an update that needs a reboot restarts the host at 04:00.
if printf '%s\n' "$apt_settings" | grep -q 'Unattended-Upgrade::Automatic-Reboot "true"' \
    && printf '%s\n' "$apt_settings" | grep -q 'Unattended-Upgrade::Automatic-Reboot-Time "04:00"'; then
    pass R-vpn-server-07.c "automatic reboot after updates is on, at 04:00"
else
    fail R-vpn-server-07.c "automatic reboot after updates is not set for 04:00"
fi

# R-vpn-server-10.a: one address cannot hold more than 1000 connections to the VPN
# port or open more than 100 new ones per second (burst 300).
vpn_rules=$(iptables -S ufw-before-input 2>/dev/null | grep -- "--dport $VPN_PORT " | grep -- '-j DROP')
if printf '%s\n' "$vpn_rules" | grep -q -- '--connlimit-above 1000 --connlimit-mask 32' \
    && printf '%s\n' "$vpn_rules" | grep -- '--hashlimit-mode srcip' \
        | grep -- '--hashlimit-above 100/sec' | grep -q -- '--hashlimit-burst 300'; then
    pass R-vpn-server-10.a "per-address connection limits are loaded on ${VPN_PORT}/tcp"
else
    fail R-vpn-server-10.a "per-address connection limits are missing on ${VPN_PORT}/tcp"
fi

# R-vpn-server-11.a: new TCP connections use BBR congestion control.
cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
[ "$cc" = bbr ] \
    && pass R-vpn-server-11.a "congestion control for new TCP connections is BBR" \
    || fail R-vpn-server-11.a "congestion control for new TCP connections is '${cc:-unknown}'"

# R-vpn-server-11.b: the server's side of a client connection to the VPN port uses BBR.
# A request through the temporary client is held open; that client dials the server's
# own address, so its connections are the ones on the VPN port whose peer is that address.
cat > "$work/hold.py" <<'PY'
import socket, struct, sys, time
s = socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=10)
s.sendall(b"\x05\x01\x00"); assert s.recv(2) == b"\x05\x00"
s.sendall(b"\x05\x01\x00\x01" + socket.inet_aton("1.1.1.1") + struct.pack(">H", 80))
assert s.recv(10)[1] == 0
s.sendall(b"GET / HTTP/1.1\r\nHost: 1.1.1.1\r\n\r\n")
time.sleep(6)
PY
python3 "$work/hold.py" "$SOCKS_PORT" >/dev/null 2>&1 &
hold_pid=$!
sleep 2
tunnel_conns=$(ss -HtinO "sport = :$VPN_PORT and dst $server_ip" 2>/dev/null)
kill "$hold_pid" 2>/dev/null
if [ -z "$tunnel_conns" ]; then
    fail R-vpn-server-11.b "no client connection to the VPN port was found to inspect"
elif printf '%s\n' "$tunnel_conns" | grep -qvw bbr; then
    fail R-vpn-server-11.b "a client connection to the VPN port does not use BBR"
else
    pass R-vpn-server-11.b "client connections to the VPN port use BBR"
fi

# R-vpn-server-11.c: the interface that carries the default route paces packets with fq.
wan_dev=$(ip -4 route show default | awk '{for (i = 1; i < NF; i++) if ($i == "dev") {print $(i + 1); exit}}')
qdiscs=$(tc qdisc show dev "${wan_dev:-none}" 2>/dev/null)
if printf '%s\n' "$qdiscs" | grep -q '^qdisc fq ' \
    && ! printf '%s\n' "$qdiscs" | grep -qv -e '^qdisc mq ' -e '^qdisc fq '; then
    pass R-vpn-server-11.c "queueing discipline on ${wan_dev} is fq"
else
    fail R-vpn-server-11.c "queueing discipline on ${wan_dev:-the default-route interface} is not fq"
fi

# R-vpn-server-11.d: a TCP connection's send and receive buffers may grow to 16 MB.
rmem_max=$(sysctl -n net.ipv4.tcp_rmem 2>/dev/null | awk '{print $3}')
wmem_max=$(sysctl -n net.ipv4.tcp_wmem 2>/dev/null | awk '{print $3}')
[ "${rmem_max:-0}" -ge 16777216 ] && [ "${wmem_max:-0}" -ge 16777216 ] \
    && pass R-vpn-server-11.d "TCP buffers may grow to at least 16 MB" \
    || fail R-vpn-server-11.d "TCP buffer limits are ${rmem_max:-unknown} (receive) and ${wmem_max:-unknown} (send) bytes"

# R-vpn-server-11.e: a connection that was idle keeps its sending rate.
[ "$(sysctl -n net.ipv4.tcp_slow_start_after_idle 2>/dev/null)" = 0 ] \
    && pass R-vpn-server-11.e "slow start after idle is off" \
    || fail R-vpn-server-11.e "slow start after idle is on"

# R-vpn-server-11.f: TCP probes for a smaller packet size when large packets are lost.
[ "$(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null)" = 1 ] \
    && pass R-vpn-server-11.f "packet size probing after loss of large packets is on" \
    || fail R-vpn-server-11.f "packet size probing after loss of large packets is off"

# R-vpn-server-08.c (boot half): IPv6 stays off across restarts. The host must have
# booted with IPv6 disabled in the kernel; a runtime switch alone is undone at boot.
check R-vpn-server-08.c "kernel booted with IPv6 disabled" \
    grep -qw 'ipv6.disable=1' /proc/cmdline

# R-vpn-server-08.d: the network finishes configuring, so a boot is not held up.
state=$(networkctl list --no-legend 2>/dev/null | awk '$3 == "ether" {print $5}' | sort -u | tr '\n' ' ')
[ "$state" = "configured " ] \
    && pass R-vpn-server-08.d "network interfaces are fully configured" \
    || fail R-vpn-server-08.d "network interface setup state is: ${state:-unknown}"

# R-vpn-server-08.b: services come back after a reboot.
check R-vpn-server-08.b "panel service is enabled at boot and running" \
    sh -c 'systemctl is-enabled --quiet x-ui && systemctl is-active --quiet x-ui'

echo
if [ "$fails" -eq 0 ]; then
    echo "all checks passed"
else
    echo "$fails check(s) failed"
    exit 1
fi
