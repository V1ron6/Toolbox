#!/usr/bin/env bash
# hash-crack.sh — identify a hash's likely type, then crack it with hashcat
# (falls back to john). Point it at a hash string or a file of hashes.
#
# Usage: ./hash-crack.sh <hash_or_file> [-w wordlist] [-m hashcat_mode]

set -euo pipefail

usage() { echo "Usage: $0 <hash_or_file> [-w wordlist] [-m hashcat_mode]"; exit 1; }
[ $# -ge 1 ] || usage

INPUT=""
WORDLIST="/usr/share/wordlists/rockyou.txt"
MODE=""
while [ $# -gt 0 ]; do
    case "$1" in
        -w) WORDLIST="$2"; shift 2 ;;
        -m) MODE="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "[!] Unknown option: $1"; usage ;;
        *) INPUT="$1"; shift ;;
    esac
done
[ -n "$INPUT" ] || usage

if [ -f "$INPUT" ]; then
    HASHFILE="$INPUT"
    SAMPLE=$(head -1 "$INPUT")
else
    HASHFILE=$(mktemp)
    echo "$INPUT" > "$HASHFILE"
    SAMPLE="$INPUT"
fi

echo "[*] Sample hash: $SAMPLE"
echo "[*] Length: ${#SAMPLE}"

if command -v hashid >/dev/null 2>&1; then
    echo "[1/2] hashid guess:"
    hashid "$SAMPLE"
elif command -v hash-identifier >/dev/null 2>&1; then
    echo "[1/2] hash-identifier guess:"
    echo "$SAMPLE" | hash-identifier
else
    echo "[!] hashid/hash-identifier not found. apt install hashid"
    echo "    Quick manual guide by length:"
    echo "    32 hex  = MD5 or NTLM        40 hex = SHA1"
    echo "    64 hex  = SHA256             128 hex = SHA512"
    echo "    \$1\$ = MD5crypt   \$2y\$/\$2a\$ = bcrypt   \$6\$ = SHA512crypt"
fi

if [ -z "$MODE" ]; then
    case "${#SAMPLE}" in
        32) MODE=0 ;;      # MD5
        40) MODE=100 ;;    # SHA1
        64) MODE=1400 ;;   # SHA256
        128) MODE=1700 ;;  # SHA512
        *)
            case "$SAMPLE" in
                \$2[ayb]\$*) MODE=3200 ;;  # bcrypt
                \$6\$*) MODE=1800 ;;        # sha512crypt
                \$1\$*) MODE=500 ;;         # md5crypt
                *) MODE="" ;;
            esac
            ;;
    esac
fi

if [ -z "$MODE" ]; then
    echo "[!] Couldn't auto-detect hashcat mode. Pass one with -m (see: hashcat --help | grep -i <algo>)"
    exit 1
fi
echo "[*] Using hashcat mode: $MODE"

[ -f "$WORDLIST" ] || { echo "[!] Wordlist not found: $WORDLIST (pass one with -w)"; exit 1; }

echo "[2/2] Cracking..."
if command -v hashcat >/dev/null 2>&1; then
    hashcat -m "$MODE" -a 0 "$HASHFILE" "$WORDLIST" --force
    echo "[*] Results (if cracked):"
    hashcat -m "$MODE" "$HASHFILE" --show
elif command -v john >/dev/null 2>&1; then
    echo "[!] hashcat not found, falling back to john."
    john --wordlist="$WORDLIST" "$HASHFILE"
    john --show "$HASHFILE"
else
    echo "[!] Neither hashcat nor john installed."
    exit 1
fi
