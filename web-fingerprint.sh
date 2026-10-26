#!/usr/bin/env bash
# web-fingerprint.sh — identify stack/CMS/known vulns on a web target before
# going deeper. Run this right after the port scan, before gobuster/sqlmap —
# knowing it's ArcadeDB/WordPress/Jenkins/etc. up front saves time.
#
# Usage: ./web-fingerprint.sh <url> [-o output_dir]

set -euo pipefail

usage() { echo "Usage: $0 <url> [-o output_dir]"; exit 1; }
[ $# -ge 1 ] || usage

URL=""
OUTDIR=""
while [ $# -gt 0 ]; do
    case "$1" in
        -o) OUTDIR="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "[!] Unknown option: $1"; usage ;;
        *) URL="$1"; shift ;;
    esac
done
[ -n "$URL" ] || usage
OUTDIR="${OUTDIR:-./fingerprint-$(echo "$URL" | sed -E 's#https?://##; s#[/:]#_#g')}"
mkdir -p "$OUTDIR"
log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "Target: $URL"

log "[1/4] Headers + basic banner..."
curl -skI --max-time 10 "$URL" | tee "$OUTDIR/headers.txt"

log "[2/4] whatweb (tech stack fingerprint)..."
if command -v whatweb >/dev/null 2>&1; then
    whatweb -a 3 "$URL" 2>/dev/null | tee "$OUTDIR/whatweb.txt"
else
    log "[!] whatweb not found. apt install whatweb"
fi

log "[3/4] nikto (known vuln / misconfig scan)..."
if command -v nikto >/dev/null 2>&1; then
    nikto -h "$URL" -output "$OUTDIR/nikto.txt" || true
else
    log "[!] nikto not found. apt install nikto"
fi

log "[4/4] Common fingerprint files (robots.txt, sitemap, security.txt, version files)..."
for path in robots.txt sitemap.xml .well-known/security.txt readme.html CHANGELOG.txt package.json composer.json; do
    code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 "${URL%/}/$path" 2>/dev/null || echo "000")
    if [ "$code" = "200" ]; then
        echo "FOUND [$code]: ${URL%/}/$path" | tee -a "$OUTDIR/common-files.txt"
    fi
done

log "Done. Results in $OUTDIR/"
log "Next: grep whatweb.txt for CMS/framework name, then check searchsploit for it."
