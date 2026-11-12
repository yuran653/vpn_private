#!/usr/bin/env bash
# verify-external.sh - checks the VPN server from the outside.
#
# Runs on the operator's workstation, not on the VPS. Looks at the server the
# way a scanner or a censor's probe would: through its names, which lead to
# Cloudflare (ADR-0013), and at its own address, which must not answer on its
# web ports. Each check names the acceptance criterion it verifies
# (specs/vpn-server/spec.md).
#
# Usage:
#   bash scripts/verify-external.sh [ssh-alias] [fallback-ssh-alias]     (default: zcom-th)
#
# With a second alias the fallback server (ADR-0018) is checked too. Those
# checks ask Team Cymru's public DNS service which network the fallback's
# address and its cover site belong to; that lookup names the address to that
# service. The fallback checks have not been run yet (written 2026-11-12).
#
# The SSH alias is used only to read the server's address and the panel port.
# Needs curl, dig, openssl and python3. Exit code 0 only when every check
# passes. Prints no secret.

set -uo pipefail

readonly HOST_ALIAS=${1:-zcom-th}
readonly COVER_DOMAIN=casedigestai.com
readonly COVER_NAME=files.casedigestai.com
# Every name of the site (ADR-0014); status. stays for links from before it.
readonly SITE_NAMES=("$COVER_DOMAIN" "$COVER_NAME" status.casedigestai.com)
readonly COVER_PAGE_TEXT='CaseDigest AI'
readonly CF_IPS_URL=https://www.cloudflare.com/ips-v4

fails=0
pass() { printf 'PASS  %-18s %s\n' "$1" "$2"; }
fail() { printf 'FAIL  %-18s %s\n' "$1" "$2"; fails=$((fails + 1)); }

remote() { ssh -o BatchMode=yes -o ConnectTimeout=15 "$HOST_ALIAS" "$@" 2>/dev/null; }

server_ip=$(remote "ip -4 route get 1.1.1.1" | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}')
[ -n "$server_ip" ] || { echo "could not read the server address over ssh $HOST_ALIAS" >&2; exit 2; }
panel_port=$(remote "sudo -n sh -c '. /etc/x-ui/install-result.env; echo \$XUI_PANEL_PORT'")
[ -n "$panel_port" ] || { echo "could not read the panel port" >&2; exit 2; }
cf_ips=$(curl -fsS --max-time 20 "$CF_IPS_URL")
[ -n "$cf_ips" ] || { echo "could not fetch Cloudflare's ranges from $CF_IPS_URL" >&2; exit 2; }

# Addresses a name resolves to, asked of a public resolver so the
# workstation's own DNS does not decide it.
resolve() { dig +short A "$1" @1.1.1.1 2>/dev/null | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | sort -u | tr '\n' ' '; }
cf_only() { # cf_only <address...>  -> true when every address is in Cloudflare's ranges
    [ "$#" -gt 0 ] && printf '%s\n' "$cf_ips" | python3 -I -c 'import ipaddress, sys
nets = [ipaddress.ip_network(l.strip()) for l in sys.stdin if l.strip()]
sys.exit(0 if all(any(ipaddress.ip_address(a) in n for n in nets) for a in sys.argv[1:]) else 1)' "$@"
}

# A port "answers" when the server returns bytes on it, over HTTP or TLS. A bare
# TCP connect is not used: a workstation behind a proxy or VPN sees every
# connect succeed, whatever the server does.
answers_at() { # answers_at <address> <port>
    local code
    for scheme in http https; do
        code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 6 "$scheme://$1:$2/")
        [ "$code" != 000 ] && return 0
    done
    return 1
}
answers() { answers_at "$server_ip" "$1"; }

# R-vpn-server-04.a: a TLS client without the client ID that opens the cover
# name gets a trusted certificate for it and the landing page.
page=$(curl -s --max-time 20 "https://$COVER_NAME/")
printf '%s' "$page" | grep -qF "$COVER_PAGE_TEXT" \
    && pass R-vpn-server-04.a "https://$COVER_NAME gives a trusted certificate and the landing page" \
    || fail R-vpn-server-04.a "https://$COVER_NAME did not give the landing page with a trusted certificate"

# R-vpn-server-04.b (outside half): the other names get the same site. A
# client with no name at all reaches Cloudflare, not the server; that half is
# checked on the server by verify-vpn.sh.
for name in "${SITE_NAMES[@]}"; do
    [ "$name" = "$COVER_NAME" ] && continue
    curl -s --max-time 20 "https://$name/" | grep -qF "$COVER_PAGE_TEXT" \
        && pass R-vpn-server-04.b "https://$name gives the same site" \
        || fail R-vpn-server-04.b "https://$name did not give the landing page"
done

# R-vpn-server-05.b: the panel port, the usual panel and subscription ports, and
# the loopback ports of the tunnel inbound (10443), the web server's staging
# port (8443) and the site container (8080) are closed from outside.
closed=yes
for port in "$panel_port" 2053 2083 2087 2096 8080 8443 10443 54321; do
    if answers "$port"; then
        closed=no
        fail R-vpn-server-05.b "a panel-related or loopback-only port answers from outside (not naming the panel port)"
        break
    fi
done
[ "$closed" = yes ] && pass R-vpn-server-05.b "panel, subscription and loopback-only ports do not answer from outside"

# R-vpn-server-17.b: the server's own address does not answer on 80 or 443 to
# a host outside Cloudflare's ranges, such as this workstation.
open_ports=""
for port in 80 443; do answers "$port" && open_ports="$open_ports $port"; done
[ -z "$open_ports" ] \
    && pass R-vpn-server-17.b "the server's own address gives no answer on 80 or 443" \
    || fail R-vpn-server-17.b "the server's own address answers on:$open_ports"

# R-vpn-server-15.a and R-vpn-server-17.a (outside half): every name resolves,
# to Cloudflare's ranges only, and never to the server's own address.
for name in "${SITE_NAMES[@]}"; do
    resolved=$(resolve "$name")
    case " $resolved" in
        *" $server_ip "*) fail R-vpn-server-15.a "$name resolves to the server's own address" ;;
        " ") fail R-vpn-server-15.a "$name does not resolve" ;;
        *) pass R-vpn-server-15.a "$name does not resolve to the server's own address" ;;
    esac
    # shellcheck disable=SC2086
    cf_only $resolved \
        && pass R-vpn-server-17.a "$name resolves to Cloudflare only" \
        || fail R-vpn-server-17.a "$name resolves to '${resolved:-nothing}', not only Cloudflare"
done

# R-vpn-server-15.b: a browser that opens any name gets a trusted
# certificate for it and the landing page.
for name in "${SITE_NAMES[@]}"; do
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

# R-vpn-server-15.f: the page presents case-file sync at the link's name, so
# heavy transfers to that name have a reason (ADR-0014).
if [ -n "$page" ] && printf '%s' "$page" | grep -qF 'Case files, synced' && printf '%s' "$page" | grep -qF "$COVER_NAME"; then
    pass R-vpn-server-15.f "the landing page describes case-file sync at $COVER_NAME"
else
    fail R-vpn-server-15.f "the landing page does not describe case-file sync at $COVER_NAME"
fi

# R-vpn-server-15.e: plain HTTP is redirected to HTTPS on the same name and path.
for name in "${SITE_NAMES[@]}"; do
    redirect=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 10 "http://$name/check")
    case "$redirect" in
        30[178]" https://$name/check")
            pass R-vpn-server-15.e "http://$name redirects to https://$name" ;;
        *) fail R-vpn-server-15.e "http://$name answered '$redirect', expected a redirect to https://$name/check" ;;
    esac
done

# R-vpn-server-20.a: no name the site or the link uses is on the blocked list
# (docs/blocked-names.txt), neither exactly nor as a name under a listed domain.
blocked_file=$(dirname "$0")/../docs/blocked-names.txt
hits=$(python3 -I - "$blocked_file" "${SITE_NAMES[@]}" <<'PY'
import sys
blocked = [l.split()[0].lower() for l in open(sys.argv[1]) if l.strip() and not l.startswith("#")]
for name in sys.argv[2:]:
    if any(name.lower() == b or name.lower().endswith("." + b) for b in blocked):
        print(name)
PY
)
if [ -z "$hits" ]; then
    pass R-vpn-server-20.a "no site name is on the blocked list"
else
    fail R-vpn-server-20.a "on the blocked list: $(printf '%s' "$hits" | tr '\n' ' ')"
fi

# R-vpn-server-21.a and .b: the name check passes for a name that answers, and
# fails, with exit code 1, for a name that gets no answer.
check_script=$(dirname "$0")/check-name.sh
bash "$check_script" "$COVER_NAME" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && pass R-vpn-server-21.a "check-name.sh passes $COVER_NAME from here" \
    || fail R-vpn-server-21.a "check-name.sh exited $rc for $COVER_NAME"
bash "$check_script" "$COVER_NAME" 192.0.2.1 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && pass R-vpn-server-21.b "check-name.sh fails a name that gets no answer" \
    || fail R-vpn-server-21.b "check-name.sh exited $rc for an unreachable name, expected 1"

# The fallback server (ADR-0018, ADR-0019), when its SSH alias is given. Its
# address and cover name are read from the server and are not printed.
readonly FALLBACK_ALIAS=${2:-}
if [ -n "$FALLBACK_ALIAS" ]; then
    fremote() { ssh -o BatchMode=yes -o ConnectTimeout=15 "$FALLBACK_ALIAS" "$@" 2>/dev/null; }
    fb_ip=$(fremote "ip -4 route get 1.1.1.1" | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}')
    fb_panel_port=$(fremote "sudo -n sh -c '. /etc/x-ui/install-result.env; echo \$XUI_PANEL_PORT'")
    # Both links pass through this shell's memory only: never printed, never on
    # a command line.
    fb_link=$(fremote "sudo -n cat /root/vpn/vless-link.txt")
    first_link=$(remote "sudo -n cat /root/vpn/vless-link.txt")
    cover=$(printf '%s\n' "$fb_link" | python3 -I -c 'import sys, urllib.parse
print(dict(urllib.parse.parse_qsl(urllib.parse.urlsplit(sys.stdin.read().strip()).query)).get("sni", ""))')
    if [ -z "$fb_ip" ] || [ -z "$fb_panel_port" ] || [ -z "$cover" ] || [ -z "$first_link" ]; then
        fail R-vpn-fallback "could not read the fallback server's address, panel port or link over ssh $FALLBACK_ALIAS"
    else
        # R-vpn-fallback-02.a: a TLS client without the link gets the cover
        # site's trusted certificate and its page from the fallback's address.
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 --resolve "$cover:443:$fb_ip" "https://$cover/")
        case "$code" in
            2??|3??) pass R-vpn-fallback-02.a "the fallback's address answers as the cover site, with a trusted certificate" ;;
            *) fail R-vpn-fallback-02.a "the fallback's address answered '$code' for the cover name" ;;
        esac

        # R-vpn-fallback-02.b: the cover site is in the same network (AS number)
        # as the fallback, is not on the blocked list, and is not one of ours.
        asn_of() { # asn_of <IPv4 address>  -> the AS number that announces it
            dig +short TXT "$(printf '%s' "$1" | awk -F. '{print $4 "." $3 "." $2 "." $1}').origin.asn.cymru.com" 2>/dev/null \
                | head -n 1 | tr -d '"' | awk '{print $1}'
        }
        fb_asn=$(asn_of "$fb_ip")
        cover_asns=$(for a in $(resolve "$cover"); do asn_of "$a"; done | sort -u | tr '\n' ' ')
        cover_listed=$(python3 -I - "$blocked_file" "$cover" "$COVER_DOMAIN" <<'PY'
import sys
blocked = [l.split()[0].lower() for l in open(sys.argv[1]) if l.strip() and not l.startswith("#")]
name, ours = sys.argv[2].lower(), sys.argv[3].lower()
under = lambda n, d: n == d or n.endswith("." + d)
print("yes" if any(under(name, b) for b in blocked) or under(name, ours) else "no")
PY
        )
        if [ -n "$fb_asn" ] && [ "$cover_asns" = "$fb_asn " ] && [ "$cover_listed" = no ]; then
            pass R-vpn-fallback-02.b "the cover site is in the fallback's own network, not blocked and not ours"
        else
            fail R-vpn-fallback-02.b "the cover site is in network(s) '${cover_asns% }', the fallback in '${fb_asn:-unknown}'; on the blocked list or ours: ${cover_listed:-unknown}"
        fi

        # R-vpn-fallback-02.c: another name, and no name, still get a certificate.
        other=$(echo | openssl s_client -connect "$fb_ip:443" -servername www.example.org 2>/dev/null | openssl x509 -noout -subject 2>/dev/null)
        noname=$(echo | openssl s_client -connect "$fb_ip:443" -noservername 2>/dev/null | openssl x509 -noout -subject 2>/dev/null)
        [ -n "$other" ] && [ -n "$noname" ] \
            && pass R-vpn-fallback-02.c "another name and no name get a certificate from the fallback, not a reset" \
            || fail R-vpn-fallback-02.c "another name or no name got no certificate from the fallback"

        # R-vpn-fallback-03.c: the panel port and the usual panel and
        # subscription ports are closed on the fallback.
        closed=yes
        for port in "$fb_panel_port" 80 2053 2083 2087 2096 8080 8443 10443 54321; do
            if answers_at "$fb_ip" "$port"; then closed=no; break; fi
        done
        [ "$closed" = yes ] \
            && pass R-vpn-fallback-03.c "panel-related ports and port 80 do not answer on the fallback" \
            || fail R-vpn-fallback-03.c "a panel-related port or port 80 answers on the fallback (not naming the panel port)"

        # R-vpn-fallback-05.a and 05.c: the users' two links share no client ID,
        # key, path or name, and their profile names differ.
        shared=$(printf '%s\n%s\n' "$first_link" "$fb_link" | python3 -I -c 'import sys, urllib.parse
def parts(link):
    u = urllib.parse.urlsplit(link.strip())
    q = dict(urllib.parse.parse_qsl(u.query))
    secrets = {u.username, u.hostname, q.get("sni"), q.get("host"), q.get("path"), q.get("pbk"), q.get("sid")}
    return {s for s in secrets if s}, urllib.parse.unquote(u.fragment)
first, fallback = [parts(l) for l in sys.stdin.read().split("\n")[:2]]
print(("shared" if first[0] & fallback[0] else "none"), ("same" if first[1] == fallback[1] else "differ"))')
        case "$shared" in
            "none "*) pass R-vpn-fallback-05.a "the two links share no client ID, key, path or name" ;;
            *) fail R-vpn-fallback-05.a "the two links share a client ID, key, path or name" ;;
        esac
        case "$shared" in
            *" differ") pass R-vpn-fallback-05.c "the two links have different profile names" ;;
            *) fail R-vpn-fallback-05.c "the two links have the same profile name" ;;
        esac

        # R-vpn-fallback-06.a and .b: the address check passes for the fallback
        # from here, and fails, with exit code 1, for an address that gets no answer.
        host_script=$(dirname "$0")/check-host.sh
        bash "$host_script" "$fb_ip" "$cover" >/dev/null 2>&1; rc=$?
        [ "$rc" -eq 0 ] && pass R-vpn-fallback-06.a "check-host.sh passes the fallback's address from here" \
            || fail R-vpn-fallback-06.a "check-host.sh exited $rc for the fallback's address (2 means it could not judge)"
        bash "$host_script" 192.0.2.1 "$cover" >/dev/null 2>&1; rc=$?
        [ "$rc" -eq 1 ] && pass R-vpn-fallback-06.b "check-host.sh fails an address that gets no answer" \
            || fail R-vpn-fallback-06.b "check-host.sh exited $rc for an unreachable address, expected 1"
    fi
    unset fb_link first_link
fi

echo
if [ "$fails" -eq 0 ]; then
    echo "all checks passed"
else
    echo "$fails check(s) failed"
    exit 1
fi
