#!/usr/bin/env bash
# verify-external.sh - checks the VPN server from the outside.
#
# Runs on the operator's workstation, not on the VPS. Looks at the server the
# way a scanner or a censor's probe would. Each check names the acceptance
# criterion it verifies (specs/vpn-server/spec.md).
#
# Usage:
#   bash scripts/verify-external.sh [ssh-alias]     (default: zcom-th)
#
# The SSH alias is used only to read the server's address and the panel port.
# Exit code 0 only when every check passes. Prints no secret.

set -uo pipefail

readonly HOST_ALIAS=${1:-zcom-th}
readonly VPN_PORT=443

fails=0
pass() { printf 'PASS  %-18s %s\n' "$1" "$2"; }
fail() { printf 'FAIL  %-18s %s\n' "$1" "$2"; fails=$((fails + 1)); }

remote() { ssh -o BatchMode=yes -o ConnectTimeout=15 "$HOST_ALIAS" "$@"; }

server_ip=$(remote "ip -4 route get 1.1.1.1" | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}')
[ -n "$server_ip" ] || { echo "could not read the server address over ssh $HOST_ALIAS" >&2; exit 2; }
panel_port=$(remote "sudo -n sh -c '. /etc/x-ui/install-result.env; echo \$XUI_PANEL_PORT'")
sni=$(remote "sudo -n jq -r '.inbounds[] | select(.port == $VPN_PORT) | .streamSettings.realitySettings.serverNames[0]' /usr/local/x-ui/bin/config.json")
[ -n "$panel_port" ] && [ -n "$sni" ] || { echo "could not read the panel port or cover site name" >&2; exit 2; }

# A port "answers" when the server returns bytes on it, over HTTP or TLS. A bare
# TCP connect is not used: a workstation behind a proxy or VPN sees every
# connect succeed, whatever the server does.
answers() {
    local code
    for scheme in http https; do
        code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 6 "$scheme://$server_ip:$1/")
        [ "$code" != 000 ] && return 0
    done
    return 1
}

# R-vpn-server-01.b and R-vpn-server-04.a: the VPN port answers from the internet, and a
# probe without the key sees the cover site, with a certificate that validates for
# the cover site's name.
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 --resolve "$sni:$VPN_PORT:$server_ip" "https://$sni/")
case "$code" in
    2*|3*|4*)
        pass R-vpn-server-01.b "${VPN_PORT}/tcp answers from outside"
        pass R-vpn-server-04.a "probe gets a valid certificate and an HTTP $code from the cover site" ;;
    *)
        fail R-vpn-server-01.b "${VPN_PORT}/tcp gave no valid TLS answer from outside (curl code '$code')"
        fail R-vpn-server-04.a "probe did not get the cover site's certificate" ;;
esac

# R-vpn-server-05.b: the panel port and the usual panel and subscription ports are closed from outside.
closed=yes
for port in "$panel_port" 80 2053 2083 2087 2096 8080 8443 54321; do
    if answers "$port"; then
        closed=no
        fail R-vpn-server-05.b "a panel-related port answers from outside (not naming the panel port)"
        break
    fi
done
[ "$closed" = yes ] && pass R-vpn-server-05.b "panel and subscription ports do not answer from outside"

echo
if [ "$fails" -eq 0 ]; then
    echo "all checks passed"
else
    echo "$fails check(s) failed"
    exit 1
fi
