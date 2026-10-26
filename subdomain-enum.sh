#!/usr/bin/env bash
# subdomain-enum.sh — passive + active subdomain enumeration, then probe which
# are alive. Useful for blackbox web targets where the real app sits on a
# subdomain (admin., api., dev., staging.) not the one you were handed.
#
# Usage: ./subdomain-enum.sh <domain> [-o output_dir]

set -euo pipefail

usage() { echo "Usage: $0 <domain> [-o output_dir]"; exit 1; }
[ $# -ge 1 ] || usage

DOMAIN=""
OUTDIR=""
while [ $# -gt 0 ]; do
    case "$1" in
        -o) OUTDIR="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "[!] Unknown option: $1"; usage ;;
        *) DOMAIN="$1"; shift ;;
    esac
done
[ -n "$DOMAIN" ] || usage
OUTDIR="${OUTDIR:-./subenum-$DOMAIN}"
mkdir -p "$OUTDIR"
log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "Domain: $DOMAIN"
RESULTS="$OUTDIR/all-subdomains.txt"
: > "$RESULTS"

if command -v subfinder >/dev/null 2>&1; then
    log "[1/4] subfinder (passive, multi-source)..."
    subfinder -d "$DOMAIN" -silent >> "$RESULTS" 2>/dev/null || true
else
    log "[!] subfinder not found (go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest)"
fi

if command -v amass >/dev/null 2>&1; then
    log "[2/4] amass (passive, slower, more thorough)..."
    amass enum -passive -d "$DOMAIN" -silent >> "$RESULTS" 2>/dev/null || true
else
    log "[!] amass not found, skipping."
fi

log "[3/4] crt.sh certificate transparency lookup..."
curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" 2>/dev/null \
    | grep -oP '"name_value":"\K[^"]+' \
    | sed 's/\*\.//g' >> "$RESULTS" || log "    crt.sh lookup failed (offline or rate-limited)"

sort -u "$RESULTS" -o "$RESULTS"
COUNT=$(wc -l < "$RESULTS")
log "Found $COUNT unique candidate subdomains -> $RESULTS"

log "[4/4] Probing which are alive..."
ALIVE="$OUTDIR/alive.txt"
if command -v httpx >/dev/null 2>&1; then
    httpx -l "$RESULTS" -silent -status-code -title -o "$ALIVE" 2>/dev/null || true
else
    log "[!] httpx not found, falling back to curl (slower, no title/status)."
    : > "$ALIVE"
    while read -r sub; do
        code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 "https://$sub" 2>/dev/null || echo "000")
        [ "$code" != "000" ] && echo "$sub [$code]" | tee -a "$ALIVE"
    done < "$RESULTS"
fi

log "Done. All candidates: $RESULTS | Alive: $ALIVE"
