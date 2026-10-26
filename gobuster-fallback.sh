#!/usr/bin/env bash
# gobuster-fallback.sh — fallback content-discovery when gobuster/dirb comes up empty.
# Escalates through bigger wordlists, extensions, slower rate-limit-safe
# scanning, broader status codes, vhost fuzzing, and a second engine (ffuf).
#
# Usage: ./gobuster-fallback.sh <url> [-w wordlist] [-x ext1,ext2] [-o output_dir]

set -euo pipefail

usage() {
    echo "Usage: $0 <url> [-w wordlist] [-x ext1,ext2] [-o output_dir]"
    exit 1
}

[ $# -ge 1 ] || usage

URL=""
WORDLIST=""
EXT="php,txt,html,bak,zip,json,config"
OUTDIR=""

while [ $# -gt 0 ]; do
    case "$1" in
        -w) WORDLIST="$2"; shift 2 ;;
        -x) EXT="$2"; shift 2 ;;
        -o) OUTDIR="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "[!] Unknown option: $1"; usage ;;
        *) URL="$1"; shift ;;
    esac
done

[ -n "$URL" ] || usage
OUTDIR="${OUTDIR:-./gobuster-$(echo "$URL" | sed -E 's#https?://##; s#[/:]#_#g')}"
mkdir -p "$OUTDIR"
LOG="$OUTDIR/run.log"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

# Find a usable wordlist if none given, checking common locations across distros.
if [ -z "$WORDLIST" ]; then
    for candidate in \
        /usr/share/wordlists/dirb/common.txt \
        /usr/share/dirb/wordlists/common.txt \
        /usr/share/wordlists/seclists/Discovery/Web-Content/common.txt \
        /opt/SecLists/Discovery/Web-Content/common.txt
    do
        if [ -f "$candidate" ]; then WORDLIST="$candidate"; break; fi
    done
fi

if [ -z "$WORDLIST" ] || [ ! -f "$WORDLIST" ]; then
    log "[!] No wordlist found. Pass one with -w, or install seclists:"
    log "    apt install seclists   (then try /usr/share/wordlists/seclists/...)"
    exit 1
fi

BIG_WORDLIST=""
for candidate in \
    /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt \
    /usr/share/wordlists/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt
do
    [ -f "$candidate" ] && BIG_WORDLIST="$candidate" && break
done

command -v gobuster >/dev/null 2>&1 || { log "[!] gobuster not installed. apt install gobuster"; exit 1; }

log "Target: $URL"
log "Wordlist: $WORDLIST"
log "Output: $OUTDIR"

run_gobuster() {
    local wl="$1" label="$2"; shift 2
    [ -f "$wl" ] || { log "[!] Skipping $label — wordlist not found: $wl"; return; }
    log "gobuster dir: $label"
    gobuster dir -u "$URL" -w "$wl" -t 50 -k -q "$@" \
        -o "$OUTDIR/gobuster-$label.txt" 2>>"$LOG" || true
}

log "[1/5] Baseline run..."
run_gobuster "$WORDLIST" "baseline" -x "$EXT"

log "[2/5] Bigger wordlist..."
if [ -n "$BIG_WORDLIST" ]; then
    run_gobuster "$BIG_WORDLIST" "medium" -x "$EXT"
else
    log "[!] No medium/large wordlist found, skipping. (seclists recommended)"
fi

log "[3/5] Slow + status-code-broadened retry (catches WAF rate-limit drops and filtered codes)..."
gobuster dir -u "$URL" -w "$WORDLIST" -t 10 --delay 200ms -k -q \
    -s "200,204,301,302,307,401,403,500" \
    -o "$OUTDIR/gobuster-slow-statuscodes.txt" 2>>"$LOG" || true

log "[4/5] Vhost-based discovery (separate from path discovery — easy to miss)..."
HOST_ONLY=$(echo "$URL" | sed -E 's#^https?://##; s#[/:].*##')
if [ -n "$HOST_ONLY" ]; then
    gobuster vhost -u "$URL" -w "$WORDLIST" -t 30 -k -q \
        -o "$OUTDIR/gobuster-vhost.txt" 2>>"$LOG" || true
fi

log "[5/5] Cross-check with ffuf (different engine, sometimes gets through where gobuster is blocked)..."
if command -v ffuf >/dev/null 2>&1; then
    ffuf -u "${URL%/}/FUZZ" -w "$WORDLIST" -mc 200,204,301,302,307,401,403 \
        -o "$OUTDIR/ffuf-results.json" -of json -t 50 2>>"$LOG" || true
else
    log "[!] ffuf not installed, skipping. (apt install ffuf)"
fi

log "Done. Review results in $OUTDIR/"
log "Still nothing? Check: non-standard port, app-level routing (SPA 404s every path),"
log "robots.txt / sitemap.xml by hand, or auth-gated paths needing a session cookie (-c)."
