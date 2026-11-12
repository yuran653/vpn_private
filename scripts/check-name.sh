#!/usr/bin/env bash
# check-name.sh - tries a site name from the network the script runs on, the way
# a censor's filter would meet it. Run it on a phone on mobile data (Termux:
# pkg install curl) in each target country, with no VPN, BEFORE a name goes into
# the client link (ADR-0017).
#
# Usage:
#   bash scripts/check-name.sh <name> [address]
#
# <address> pins the name to one address, for testing the script itself.
# Exit code: 0 the name passes, 1 the name fails, 2 the network cannot judge
# (the control name fails too). Prints no secret.
#
# What it looks for, from the Beeline (Moscow, mobile) measurements of
# 2026-11-12 (docs/censor-red-flags.md): a flagged name still answers a plain GET
# but hangs HTTP/2, and cuts uploads after 1 to 2 KB.

set -uo pipefail

readonly NAME=${1:?usage: check-name.sh <name> [address]}
readonly PIN=${2:-}
readonly CONTROL=www.cloudflare.com
readonly UPLOAD_SIZES=(500 5000 30000)

pin_args() { # pin_args <host>  -> curl's --resolve for the pinned name only
    [ -n "$PIN" ] && [ "$1" = "$NAME" ] && printf '%s\n' --resolve "$1:443:$PIN"
    return 0
}

# code <host> <curl options...>: the HTTP status, 000 when nothing answered.
code() {
    local host=$1; shift
    # shellcheck disable=SC2046
    curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 12 $(pin_args "$host") "$@" "https://$host/" 2>/dev/null
}
upload() { # upload <host> <bytes>
    head -c "$2" /dev/zero | code "$1" --http1.1 -X POST --data-binary @-
}

fails=0
pass() { printf 'PASS  %-22s %s\n' "$1" "$2"; }
fail() { printf 'FAIL  %-22s %s\n' "$1" "$2"; fails=$((fails + 1)); }

# Control first: if a well-known Cloudflare name cannot take a 30 KB upload from
# here, the network is the problem and the name cannot be judged from it.
if [ "$(upload "$CONTROL" 30000)" = 000 ]; then
    echo "INCONCLUSIVE  the control name $CONTROL cannot take a 30 KB upload from this network"
    exit 2
fi
pass control "$CONTROL takes a 30 KB upload"

c=$(code "$NAME" --http1.1)
case "$c" in 2??|3??) pass "get http/1.1" "$NAME answered $c" ;; *) fail "get http/1.1" "$NAME answered '$c'" ;; esac

c=$(code "$NAME" --http2)
case "$c" in 000) fail "get http/2" "$NAME hangs HTTP/2 (nothing came back)" ;; *) pass "get http/2" "$NAME answered $c" ;; esac

for n in "${UPLOAD_SIZES[@]}"; do
    c=$(upload "$NAME" "$n")
    if [ "$c" = 000 ]; then fail "upload $n bytes" "$NAME gave no answer to a $n-byte upload"
    else pass "upload $n bytes" "$NAME answered $c"; fi
done

echo
if [ "$fails" -eq 0 ]; then echo "$NAME passes from this network"; exit 0; fi
echo "$NAME fails $fails check(s) from this network"; exit 1
