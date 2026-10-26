#!/usr/bin/env bash
# setup.sh — install this toolbox so every script is runnable from anywhere,
# by its own name, without the .sh extension or a path prefix.
#
# Usage: ./setup.sh [-d install_dir]
#   default install dir: ~/.local/share/pentest-toolbox
#
# Run from inside the toolbox folder (where this script and the others live).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/share/pentest-toolbox"

while [ $# -gt 0 ]; do
    case "$1" in
        -d) INSTALL_DIR="$2"; shift 2 ;;
        -h|--help) echo "Usage: $0 [-d install_dir]"; exit 0 ;;
        *) echo "[!] Unknown option: $1"; exit 1 ;;
    esac
done

echo "[*] Installing toolbox to: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Copy every script except this one (copy, don't move — safe to re-run)
for f in "$SCRIPT_DIR"/*.sh; do
    base="$(basename "$f")"
    [ "$base" = "setup.sh" ] && continue
    cp "$f" "$INSTALL_DIR/"
done
[ -f "$SCRIPT_DIR/README.md" ] && cp "$SCRIPT_DIR/README.md" "$INSTALL_DIR/"

chmod +x "$INSTALL_DIR"/*.sh

# Create extension-less symlinks so you run `nmap-recon` instead of `nmap-recon.sh`
for f in "$INSTALL_DIR"/*.sh; do
    link="${f%.sh}"
    ln -sf "$f" "$link"
done

echo "[*] Installed $(ls "$INSTALL_DIR"/*.sh | wc -l) scripts."

# --- Add to PATH ---
detect_rc() {
    local shell_name
    shell_name="$(basename "${SHELL:-bash}")"
    case "$shell_name" in
        zsh)  echo "$HOME/.zshrc" ;;
        bash) [ -f "$HOME/.bash_profile" ] && echo "$HOME/.bash_profile" || echo "$HOME/.bashrc" ;;
        *)    echo "$HOME/.profile" ;;
    esac
}

RC_FILE="$(detect_rc)"
MARKER="# pentest-toolbox PATH (added by setup.sh)"
LINE="export PATH=\"$INSTALL_DIR:\$PATH\""

if [ -f "$RC_FILE" ] && grep -qF "$MARKER" "$RC_FILE" 2>/dev/null; then
    echo "[*] PATH entry already present in $RC_FILE, updating it..."
    # Replace the old export line that follows the marker
    awk -v marker="$MARKER" -v newline="$LINE" '
        $0 == marker { print; getline; print newline; next }
        { print }
    ' "$RC_FILE" > "$RC_FILE.tmp" && mv "$RC_FILE.tmp" "$RC_FILE"
else
    echo "[*] Adding PATH entry to $RC_FILE"
    { echo ""; echo "$MARKER"; echo "$LINE"; } >> "$RC_FILE"
fi

echo
echo "[+] Done. Scripts installed in: $INSTALL_DIR"
echo "[+] Added to PATH via: $RC_FILE"
echo
echo "Run this now to use them in your current shell:"
echo "    source \"$RC_FILE\""
echo
echo "After that, run any script from anywhere, e.g.:"
echo "    nmap-recon <target>"
echo "    gobuster-fallback <url>"
echo "    pdf-unlocker file.pdf"
