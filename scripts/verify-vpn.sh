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

# One DNS query over TCP through the SOCKS proxy; prints the number of answers.
cat > "$work/dnsprobe.py" <<'PY'
import socket, struct, sys
port, resolver, name, qtype = int(sys.argv[1]), sys.argv[2], sys.argv[3], int(sys.argv[4])
s = socket.create_connection(("127.0.0.1", port), timeout=10)
s.sendall(b"\x05\x01\x00"); assert s.recv(2) == b"\x05\x00"
s.sendall(b"\x05\x01\x00\x01" + socket.inet_aton(resolver) + struct.pack(">H", 53))
assert s.recv(10)[1] == 0
q = struct.pack(">HHHHHH", 0x1234, 0x0100, 1, 0, 0, 0)
q += b"".join(bytes([len(p)]) + p.encode() for p in name.split(".")) + b"\x00" + struct.pack(">HH", qtype, 1)
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

# R-vpn-server-01.a: a client using the issued link reaches the internet from the server's IPv4 address.
exit_ip=$(via https://api.ipify.org)
[ -n "$exit_ip" ] && [ "$exit_ip" = "$server_ip" ] \
    && pass R-vpn-server-01.a "tunnel works; exit address is the server's IPv4" \
    || fail R-vpn-server-01.a "tunnel exit address is '${exit_ip:-none}', expected the server's IPv4"

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
    "$server_ip") pass R-vpn-server-02.c "dual-stack site saw the server's IPv4 address" ;;
    *) fail R-vpn-server-02.c "dual-stack site saw '${seen:-nothing}'" ;;
esac

# R-vpn-server-02.d: an AAAA query through the tunnel returns no IPv6 address.
aaaa=$(python3 "$work/dnsprobe.py" "$SOCKS_PORT" 1.1.1.1 google.com 28 2>/dev/null)
[ "$aaaa" = 0 ] \
    && pass R-vpn-server-02.d "AAAA query through the tunnel returned no address" \
    || fail R-vpn-server-02.d "AAAA query through the tunnel returned '${aaaa:-no reply}'"

# R-vpn-server-03.a: a DNS query sent through the tunnel is answered by the server itself,
# even when addressed to a resolver that does not exist (192.0.2.53 is a reserved test address).
a=$(python3 "$work/dnsprobe.py" "$SOCKS_PORT" 192.0.2.53 example.com 1 2>/dev/null)
[ -n "$a" ] && [ "$a" -ge 1 ] 2>/dev/null \
    && pass R-vpn-server-03.a "DNS query to a non-existent resolver was answered by the server" \
    || fail R-vpn-server-03.a "DNS query through the tunnel was not answered by the server"

# R-vpn-server-03.b: every resolver the server uses for tunnel traffic is DNS-over-HTTPS.
check R-vpn-server-03.b "all tunnel DNS resolvers are DNS-over-HTTPS" \
    jq -e '(.dns.servers | length) > 0 and (.dns.servers | all(type == "string" and startswith("https")))' "$XRAY_CONFIG"

# R-vpn-server-04.a (inside half): a TLS client without the key gets the cover site's certificate.
subject=$(echo | timeout 15 openssl s_client -connect "127.0.0.1:$VPN_PORT" \
    -servername "$(jq -r '.inbounds[] | select(.port == 443) | .streamSettings.realitySettings.serverNames[0]' "$XRAY_CONFIG")" \
    -verify_return_error 2>/dev/null | openssl x509 -noout -subject 2>/dev/null)
[ -n "$subject" ] \
    && pass R-vpn-server-04.a "unauthenticated TLS client is shown a valid third-party certificate" \
    || fail R-vpn-server-04.a "unauthenticated TLS client did not get a valid certificate"

# R-vpn-server-05.a: nothing but SSH and the VPN port listens on a public address.
public_listeners=$(ss -Htlnu | awk '{print $5}' | grep -Ev '^(127\.|\[::1\]|\[::ffff:127\.)' \
    | sed -E 's/.*:([0-9]+)$/\1/' | sort -un | tr '\n' ' ')
ssh_port=$(sshd -T 2>/dev/null | awk '$1 == "port" {print $2}')
expected=$(printf '%s\n%s\n' "$ssh_port" "$VPN_PORT" | sort -un | tr '\n' ' ')
[ "$public_listeners" = "$expected" ] \
    && pass R-vpn-server-05.a "public listeners are only SSH and ${VPN_PORT}" \
    || fail R-vpn-server-05.a "public listeners are: $public_listeners"

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
