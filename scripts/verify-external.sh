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
readonly COVER_DOMAIN=casedigestai.com
readonly COVER_NAME=status.casedigestai.com
readonly COVER_PAGE_TEXT='CaseDigest AI'

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
# probe without the key gets the cover site: a certificate that validates for
# the cover name, and the landing page.
page=$(curl -s --max-time 20 --resolve "$sni:$VPN_PORT:$server_ip" "https://$sni/")
if [ "$sni" = "$COVER_NAME" ] && printf '%s' "$page" | grep -qF "$COVER_PAGE_TEXT"; then
    pass R-vpn-server-01.b "${VPN_PORT}/tcp answers from outside"
    pass R-vpn-server-04.a "probe gets a valid certificate for $COVER_NAME and the landing page"
else
    fail R-vpn-server-01.b "${VPN_PORT}/tcp gave no valid TLS answer from outside for '$sni'"
    fail R-vpn-server-04.a "probe did not get the landing page with a valid certificate for $COVER_NAME"
fi

# R-vpn-server-04.b: the bare domain, and a client that sends no name at all,
# get the same site's certificate instead of a reset.
bare=$(curl -s --max-time 20 --resolve "$COVER_DOMAIN:$VPN_PORT:$server_ip" "https://$COVER_DOMAIN/")
noname=$(echo | openssl s_client -connect "$server_ip:$VPN_PORT" -noservername 2>/dev/null \
    | openssl x509 -noout -checkhost "$COVER_NAME" 2>/dev/null)
if printf '%s' "$bare" | grep -qF "$COVER_PAGE_TEXT" && printf '%s' "$noname" | grep -q 'does match'; then
    pass R-vpn-server-04.b "the bare domain and a client with no server name get the site's certificate"
else
    fail R-vpn-server-04.b "the bare domain or a client with no server name did not get the site's certificate"
fi

# R-vpn-server-05.b: the panel port, the usual panel and subscription ports, and
# the loopback ports of the web server (8443) and the site container (8080) are
# closed from outside.
closed=yes
for port in "$panel_port" 2053 2083 2087 2096 8080 8443 54321; do
    if answers "$port"; then
        closed=no
        fail R-vpn-server-05.b "a panel-related or loopback-only port answers from outside (not naming the panel port)"
        break
    fi
done
[ "$closed" = yes ] && pass R-vpn-server-05.b "panel, subscription and loopback-only ports do not answer from outside"

# R-vpn-server-15.a: both names resolve to the server's address and to no other.
# Asked of a public resolver, so the workstation's own DNS does not decide it.
for name in "$COVER_DOMAIN" "$COVER_NAME"; do
    resolved=$(dig +short A "$name" @1.1.1.1 2>/dev/null | sort -u | tr '\n' ' ')
    [ "$resolved" = "$server_ip " ] \
        && pass R-vpn-server-15.a "$name resolves to the server's address only" \
        || fail R-vpn-server-15.a "$name resolves to '${resolved:-nothing}', expected the server's address only"
done

# R-vpn-server-15.b: a browser that opens either name gets a trusted
# certificate for it and the landing page. No address is forced here: the name
# is looked up the way a visitor's browser would.
for name in "$COVER_DOMAIN" "$COVER_NAME"; do
    curl -s --max-time 20 "https://$name/" | grep -qF "$COVER_PAGE_TEXT" \
        && pass R-vpn-server-15.b "https://$name shows the landing page with a trusted certificate" \
        || fail R-vpn-server-15.b "https://$name did not show the landing page with a trusted certificate"
done

# R-vpn-server-15.c: the page loads nothing from another host and has no form
# and no script. It may refer only to paths on its own host.
if [ -z "$page" ]; then
    fail R-vpn-server-15.c "no page to inspect"
elif printf '%s' "$page" | grep -Eiq '<script|<form|<iframe|<object|<embed|https?:|@import|(src|href|action)="[^/]|(src|href|action)="//|url\('; then
    fail R-vpn-server-15.c "the landing page has a script, a form or a reference to another host"
else
    pass R-vpn-server-15.c "the landing page has no script, no form and no reference to another host"
fi

# R-vpn-server-15.d: the page mentions neither a VPN nor Thailand.
if [ -n "$page" ] && ! printf '%s' "$page" | grep -Eiq 'vpn|proxy|tunnel|thai|bangkok'; then
    pass R-vpn-server-15.d "the landing page mentions neither a VPN nor Thailand"
else
    fail R-vpn-server-15.d "the landing page is missing or mentions a VPN or Thailand"
fi

# R-vpn-server-15.e: plain HTTP is redirected to HTTPS on the same name and path.
for name in "$COVER_DOMAIN" "$COVER_NAME"; do
    redirect=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 10 \
        --resolve "$name:80:$server_ip" "http://$name/check")
    [ "$redirect" = "301 https://$name/check" ] \
        && pass R-vpn-server-15.e "http://$name redirects to https://$name" \
        || fail R-vpn-server-15.e "http://$name answered '$redirect', expected a 301 to https://$name/check"
done

echo
if [ "$fails" -eq 0 ]; then
    echo "all checks passed"
else
    echo "$fails check(s) failed"
    exit 1
fi
