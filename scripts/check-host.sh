#!/usr/bin/env bash
# check-host.sh - tries a server address from the network the script runs on,
# the way a censor's filter would meet the fallback link. Run it on a phone on
# mobile data (Termux: pkg install curl), with no VPN, BEFORE a candidate
# server is kept or its link handed out (ADR-0018, R-vpn-fallback-06).
#
# Usage:
#   bash scripts/check-host.sh <address> <cover name> [path]
#
# <address> is the candidate server's IPv4 address, <cover name> the site whose
# name the server borrows. Every request names the cover site but goes to the
# address, as the fallback link does. [path] is an object on the cover site
# larger than 64 KB (default: /), for sites whose front page is small.
#
# Before the server is deployed, run it against the cover site's own address:
# it then shows how this network treats that provider's range.
#
# Exit code: 0 the address passes, 1 it fails, 2 this run cannot judge (the
# control name fails too, or the object is too small). Prints no secret.
#
# What it looks for: a filter that lets the handshake through and then stops
# the transfer, as Russian networks do to foreign hosting ranges after about
# 16 KB, and one that cuts uploads, as Beeline did on 2026-11-12
# (docs/censor-red-flags.md).

set -uo pipefail

readonly ADDRESS=${1:?usage: check-host.sh <address> <cover name> [path]}
readonly COVER=${2:?usage: check-host.sh <address> <cover name> [path]}
readonly OBJECT=${3:-/}
readonly CONTROL=www.cloudflare.com
readonly MIN_DOWNLOAD=65536
readonly UPLOAD_BYTES=30000

printf '%s' "$ADDRESS" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' \
    || { echo "the address must be an IPv4 address" >&2; exit 2; }

fails=0
unsure=0
pass() { printf 'PASS  %-18s %s\n' "$1" "$2"; }
fail() { printf 'FAIL  %-18s %s\n' "$1" "$2"; fails=$((fails + 1)); }
warn() { printf 'WARN  %-18s %s\n' "$1" "$2"; unsure=$((unsure + 1)); }

# to_host <curl options...>: a request for the cover name sent to the address.
to_host() { curl -s --connect-timeout 5 --resolve "$COVER:443:$ADDRESS" "$@"; }

# Control first: if a well-known name cannot take the upload from here, the
# network is the problem and the address cannot be judged from it.
control=$(head -c "$UPLOAD_BYTES" /dev/zero | curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 \
    --max-time 12 --http1.1 -X POST --data-binary @- "https://$CONTROL/" 2>/dev/null)
if [ "$control" = 000 ] || [ -z "$control" ]; then
    echo "INCONCLUSIVE  the control name $CONTROL cannot take a 30 KB upload from this network"
    exit 2
fi
pass control "$CONTROL takes a 30 KB upload"

# Handshake: the address answers TLS for the cover name with a certificate the
# phone trusts, and an HTTP status comes back.
code=$(to_host -o /dev/null -w '%{http_code}' --max-time 12 "https://$COVER/" 2>/dev/null)
case "$code" in
    2??|3??) pass handshake "$ADDRESS answered $code for $COVER" ;;
    000|"") fail handshake "$ADDRESS gave no answer for $COVER" ;;
    *) warn handshake "$ADDRESS answered $code for $COVER; pick a cover page that returns 200" ;;
esac

# Download: more than 64 KB must arrive whole. A transfer that stops part-way
# is the filter this check exists for.
result=$(to_host -L -o /dev/null -w '%{size_download} %{http_code}' --max-time 25 --compressed "https://$COVER$OBJECT" 2>/dev/null)
rc=$?
size=${result%% *}; size=${size%%.*}
case "$size" in ''|*[!0-9]*) size=0 ;; esac
if [ "$rc" -ne 0 ]; then
    fail download "the transfer stopped after $size bytes (curl exit $rc)"
elif [ "$size" -ge "$MIN_DOWNLOAD" ]; then
    pass download "$size bytes arrived whole"
else
    warn download "only $size bytes at $OBJECT; pass a path to an object over 64 KB"
fi

# Upload: 30 KB sent to the address. A site may refuse a POST before it has
# read it all, which proves nothing either way.
result=$(head -c "$UPLOAD_BYTES" /dev/zero | to_host -o /dev/null -w '%{size_upload} %{http_code}' --max-time 15 \
    --http1.1 -X POST --data-binary @- "https://$COVER/" 2>/dev/null)
sent=${result%% *}; sent=${sent%%.*}; code=${result##* }
case "$sent" in ''|*[!0-9]*) sent=0 ;; esac
if [ "$code" = 000 ] || [ -z "$code" ]; then
    fail upload "no answer to a $UPLOAD_BYTES-byte upload ($sent bytes went out)"
elif [ "$sent" -ge "$UPLOAD_BYTES" ]; then
    pass upload "$UPLOAD_BYTES bytes went out, answered $code"
else
    warn upload "the site answered $code after $sent bytes, before the upload was complete"
fi

echo
if [ "$fails" -gt 0 ]; then echo "$ADDRESS fails $fails check(s) from this network"; exit 1; fi
if [ "$unsure" -gt 0 ]; then echo "$ADDRESS could not be judged on $unsure check(s) from this network"; exit 2; fi
echo "$ADDRESS passes from this network"; exit 0
