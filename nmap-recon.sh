#!/usr/bin/env bash
# nmap-recon.sh — full-port recon toolbox script.
# Default nmap only scans the top 1000 ports; this always does a full
# 65535-port sweep first, then fingerprints only what's open.
#
# Usage: ./nmap-recon.sh <target> [-o output_dir] [-u] [--fast]
#   -o DIR      output directory (default: ./recon-<target>)
#   -u          also run full UDP top-1000 sweep (slow)
#   --fast      lower min-rate for unstable/rate-limited targets
#   -h          help

set -euo pipefail

usage() {
    echo "Usage: $0 <target> [-o output_dir] [-u] [--fast]"
    exit 1
}

[ $# -ge 1 ] || usage

TARGET=""
OUTDIR=""
UDP_FULL=0
MIN_RATE=2000

while [ $# -gt 0 ]; do
    case "$1" in
        -o) OUTDIR="$2"; shift 2 ;;
        -u) UDP_FULL=1; shift ;;
        --fast) MIN_RATE=300; shift ;;
        -h|--help) usage ;;
        -*) echo "[!] Unknown option: $1"; usage ;;
        *) TARGET="$1"; shift ;;
    esac
done

[ -n "$TARGET" ] || usage
OUTDIR="${OUTDIR:-./recon-$(echo "$TARGET" | tr '/:' '__')}"

command -v nmap >/dev/null 2>&1 || { echo "[!] nmap not installed. apt install nmap"; exit 1; }

mkdir -p "$OUTDIR"
LOG="$OUTDIR/run.log"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

log "Target: $TARGET"
log "Output: $OUTDIR"

NMAP_OPTS=(-Pn)
# Only root/CAP_NET_RAW gets SYN scan; fall back to connect scan otherwise.
if [ "$(id -u)" -eq 0 ]; then
    NMAP_OPTS+=(-sS)
else
    log "Not running as root — using TCP connect scan (-sT), slower but no privileges needed."
    NMAP_OPTS+=(-sT)
fi

log "[1/4] Full TCP port sweep (all 65535 ports)..."
nmap -p- --min-rate "$MIN_RATE" -T4 "${NMAP_OPTS[@]}" "$TARGET" -oN "$OUTDIR/01-allports.txt" | tee -a "$LOG"

PORTS=$(grep -oP '^\d+(?=/tcp\s+open)' "$OUTDIR/01-allports.txt" | paste -sd, -)

if [ -z "$PORTS" ]; then
    log "[!] No open TCP ports found."
    log "    Try: rerun with --fast (host may be dropping fast probes),"
    log "    check firewall/VPN connectivity, or try -u for UDP."
    exit 1
fi

log "Open ports: $PORTS"

log "[2/4] Service/version detection + default scripts on open ports..."
nmap -p "$PORTS" -sV -sC -Pn "$TARGET" -oN "$OUTDIR/02-services.txt" | tee -a "$LOG"

log "[3/4] UDP scan..."
if [ "$UDP_FULL" -eq 1 ]; then
    log "    Full top-1000 UDP (this is slow)..."
    nmap -sU --top-ports 1000 -Pn "$TARGET" -oN "$OUTDIR/03-udp.txt" 2>>"$LOG" || true
else
    log "    Top-100 UDP (pass -u for the full top-1000 sweep)..."
    nmap -sU --top-ports 100 -Pn "$TARGET" -oN "$OUTDIR/03-udp.txt" 2>>"$LOG" || true
fi

log "[4/4] Writing known-service cheatsheet..."
{
    echo "--- Non-default ports worth remembering (common in CTFs) ---"
    echo "2424/2480  ArcadeDB (binary / HTTP+Studio)"
    echo "27017      MongoDB"
    echo "6379       Redis"
    echo "5432       PostgreSQL"
    echo "3306       MySQL"
    echo "9200       Elasticsearch"
    echo "8009/8080  Tomcat / common web alt-ports"
    echo "5000       Flask/dev servers"
    echo "9000       PHP-FPM / various admin panels"
    echo "11211      Memcached"
    echo "5984       CouchDB"
    echo "7001       WebLogic"
} > "$OUTDIR/04-known-ports-cheatsheet.txt"

log "Done. Results in $OUTDIR/"
log "Open ports summary: $PORTS"
