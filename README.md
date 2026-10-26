# Pentest Toolbox

Scripts for CTF / blackbox web+network targets. All take `-h` for usage.

## Setup

```
./setup.sh
source ~/.zshrc   # or ~/.bashrc, whatever setup.sh says it edited
```

Installs everything to `~/.local/share/pentest-toolbox`, adds it to `PATH`, and
creates extension-less aliases (`nmap-recon` instead of `nmap-recon.sh`) so
you can run any script from anywhere:

```
nmap-recon 10.10.10.10
gobuster-fallback http://target.htb
pdf-unlocker locked.pdf
```

Re-running `./setup.sh` after adding new scripts to this folder re-syncs the
install. Use `-d <dir>` to install somewhere else.

| Script | Use for | Needs |
|---|---|---|
| `nmap-recon.sh` | Full 65535-port sweep + fingerprint (don't miss non-default ports like ArcadeDB's 2480) | nmap |
| `subdomain-enum.sh` | Find subdomains (admin./api./staging.) + check which are alive | subfinder, amass, httpx (optional) |
| `web-fingerprint.sh` | ID the stack/CMS, known vulns, common exposed files | whatweb, nikto |
| `gobuster-fallback.sh` | Escalate a failed dir brute-force: bigger wordlist, slower rate, vhosts, ffuf | gobuster, ffuf |
| `service-brute.sh` | hydra wrapper for ssh/ftp/smb/http-form login brute-force | hydra |
| `hash-crack.sh` | ID a hash type, crack with hashcat (falls back to john) | hashcat or john, hashid |
| `revshell-helper.sh` | Generate reverse shell one-liners for your IP/port + optional listener | nc, rlwrap (optional) |
| `pdf-unlocker.sh` | Strip PDF owner-password restrictions instantly, or crack a user-password that blocks opening | qpdf, pdfcrack (or python3+pikepdf) |
| `rbash-escape.sh` | rbash/restricted-shell breakout cheatsheet; `--probe` run on the target lists what's actually escapable there | none (probe mode uses bash builtins) |
| `cve-locator.sh` | Find CVEs + known public exploits for a product/version (e.g. from whatweb/nmap -sV) | searchsploit (exploitdb), curl, jq (optional) |

## Suggested order for a fresh target
1. `nmap-recon.sh <target>` — know every open port first
2. `web-fingerprint.sh <url>` — know what you're dealing with
3. `cve-locator.sh "<product> <version>"` — check for known exploits on what you found
4. `subdomain-enum.sh <domain>` — if it's a domain, not a bare IP
5. `gobuster-fallback.sh <url>` — content discovery
6. `service-brute.sh` / `hash-crack.sh` — once you have creds/hashes to work
7. `revshell-helper.sh <your_ip> <port> --listen` — once you have a way to execute code

Missing tools are reported with the apt/go install command — install as needed per distro.
