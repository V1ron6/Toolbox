#!/usr/bin/env bash
# pdf-unlocker.sh — remove PDF restrictions/passwords.
# Two different problems, handled separately:
#   1. Owner-password restrictions (print/copy/edit disabled, but opens fine)
#      -> stripped instantly, no cracking needed (qpdf/pikepdf).
#   2. User-password (PDF won't even open without a password)
#      -> needs brute-forcing (pdfcrack / john).
#
# Usage: ./pdf-unlocker.sh <file.pdf> [-w wordlist] [-o output_file]

set -euo pipefail

usage() { echo "Usage: $0 <file.pdf> [-w wordlist] [-o output_file]"; exit 1; }
[ $# -ge 1 ] || usage

PDF=""
WORDLIST="/usr/share/wordlists/rockyou.txt"
OUT=""
while [ $# -gt 0 ]; do
    case "$1" in
        -w) WORDLIST="$2"; shift 2 ;;
        -o) OUT="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "[!] Unknown option: $1"; usage ;;
        *) PDF="$1"; shift ;;
    esac
done
[ -n "$PDF" ] || usage
[ -f "$PDF" ] || { echo "[!] File not found: $PDF"; exit 1; }
OUT="${OUT:-${PDF%.pdf}-unlocked.pdf}"

echo "[*] File: $PDF"

# --- Step 1: does it open without a password at all? ---
OPENS_FREE=0
if command -v qpdf >/dev/null 2>&1; then
    if qpdf --check "$PDF" >/dev/null 2>&1; then
        OPENS_FREE=1
    fi
fi

if [ "$OPENS_FREE" -eq 1 ]; then
    echo "[*] Opens without a password — likely just owner-password restrictions (print/copy/edit locked)."
    echo "[1/1] Stripping restrictions with qpdf..."
    qpdf --decrypt "$PDF" "$OUT" && { echo "[+] Done -> $OUT"; exit 0; }
fi

echo "[*] Requires a password to open (or qpdf unavailable) — attempting removal/crack."

# --- Step 2: try empty/common passwords quickly via qpdf/pikepdf before brute force ---
if command -v qpdf >/dev/null 2>&1; then
    echo "[1/3] Trying empty password..."
    if qpdf --password='' --decrypt "$PDF" "$OUT" 2>/dev/null; then
        echo "[+] Empty password worked -> $OUT"
        exit 0
    fi
fi

# --- Step 3: brute force the user password ---
echo "[2/3] Need to brute-force the user password."

if command -v pdfcrack >/dev/null 2>&1; then
    echo "    Using pdfcrack with $WORDLIST ..."
    [ -f "$WORDLIST" ] || { echo "[!] Wordlist not found: $WORDLIST (pass one with -w)"; exit 1; }
    RESULT=$(pdfcrack -f "$PDF" -w "$WORDLIST" 2>&1) || true
    echo "$RESULT"
    FOUND=$(echo "$RESULT" | grep -oP "found user-password: '\K[^']+" || true)
    if [ -n "$FOUND" ]; then
        echo "[+] Password found: $FOUND"
        if command -v qpdf >/dev/null 2>&1; then
            qpdf --password="$FOUND" --decrypt "$PDF" "$OUT" && echo "[+] Decrypted -> $OUT"
        fi
        exit 0
    fi
elif command -v python3 >/dev/null 2>&1 && python3 -c "import pikepdf" 2>/dev/null; then
    echo "    pdfcrack not found, falling back to pikepdf python brute force (slower)..."
    [ -f "$WORDLIST" ] || { echo "[!] Wordlist not found: $WORDLIST (pass one with -w)"; exit 1; }
    python3 - "$PDF" "$WORDLIST" "$OUT" <<'PYEOF'
import sys, pikepdf
pdf_path, wordlist, out = sys.argv[1], sys.argv[2], sys.argv[3]
with open(wordlist, "r", encoding="latin-1", errors="ignore") as f:
    for i, line in enumerate(f):
        pw = line.rstrip("\n")
        try:
            with pikepdf.open(pdf_path, password=pw) as pdf:
                pdf.save(out)
                print(f"[+] Password found: {pw!r} -> {out}")
                sys.exit(0)
        except pikepdf.PasswordError:
            if i % 5000 == 0:
                print(f"    tried {i} passwords...")
            continue
print("[!] Exhausted wordlist, no password found.")
sys.exit(1)
PYEOF
    exit $?
else
    echo "[!] Need pdfcrack or python3+pikepdf for brute force."
    echo "    apt install pdfcrack   OR   pip install pikepdf --break-system-packages"
    exit 1
fi

echo "[!] Password not found in wordlist. Try john --wrap=pdf as another option:"
echo "    pdf2john.pl \"$PDF\" > hash.txt && john --wordlist=$WORDLIST hash.txt"
