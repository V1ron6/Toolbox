#!/usr/bin/env bash
# service-brute.sh — hydra wrapper for brute-forcing common CTF services
# (ssh, ftp, http-form, smb) with sane defaults so you're not re-deriving
# hydra's syntax mid-event.
#
# Usage: ./service-brute.sh <target> <service> [-U userlist] [-P passlist] [-u user] [-p port]
#   service: ssh | ftp | smb | http-post-form:<path>:<postdata>:<fail_string>

set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 <target> <service> [-U userlist] [-P passlist] [-u user] [-p port]

Services: ssh, ftp, smb
  $0 10.10.10.10 ssh -U users.txt -P rockyou.txt
  $0 10.10.10.10 ftp -u admin -P rockyou.txt

HTTP POST form (specify manually, hydra's http-post-form syntax):
  $0 10.10.10.10 'http-post-form:/login:user=^USER^&pass=^PASS^:Invalid login' -U users.txt -P rockyou.txt
EOF
    exit 1
}

[ $# -ge 2 ] || usage

TARGET="$1"; SERVICE="$2"; shift 2
USERLIST=""; PASSLIST=""; USER=""; PORT=""

while [ $# -gt 0 ]; do
    case "$1" in
        -U) USERLIST="$2"; shift 2 ;;
        -P) PASSLIST="$2"; shift 2 ;;
        -u) USER="$2"; shift 2 ;;
        -p) PORT="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "[!] Unknown option: $1"; usage ;;
    esac
done

command -v hydra >/dev/null 2>&1 || { echo "[!] hydra not installed. apt install hydra"; exit 1; }
[ -n "$USER" ] || [ -n "$USERLIST" ] || { echo "[!] Need -u or -U"; exit 1; }
[ -n "$PASSLIST" ] || { echo "[!] Need -P (password list)"; exit 1; }
[ -f "$PASSLIST" ] || { echo "[!] Password list not found: $PASSLIST"; exit 1; }

USER_OPT=()
[ -n "$USER" ] && USER_OPT=(-l "$USER") || USER_OPT=(-L "$USERLIST")
PORT_OPT=(); [ -n "$PORT" ] && PORT_OPT=(-s "$PORT")

echo "[*] Target: $TARGET  Service: $SERVICE"
echo "[*] This WILL lock accounts / trip IDS on real targets — CTF/authorized use only."

hydra "${USER_OPT[@]}" -P "$PASSLIST" "${PORT_OPT[@]}" -t 4 -f -o "./hydra-$SERVICE-results.txt" "$TARGET" "$SERVICE"

echo "[+] Done. Results (if any) in ./hydra-$SERVICE-results.txt"
