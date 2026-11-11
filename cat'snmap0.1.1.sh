#!/usr/bin/env bash
# Cat's Nmap 1.0 | © AC Kondo 1999–2026
set -u
usage() { printf 'Cat\047s Nmap 1.0\nUsage: %s HOST [-p PORTS] [-t TIMEOUT] [-6] [-q]\n  -p  80,443,8000-8010 (default: common ports)\n  -t  seconds per connection (default: 1)\n  -6  IPv6 mode\n  -q  show open ports only\n' "$0"; }
command -v nc >/dev/null 2>&1 || { echo 'Error: netcat (nc) is required.' >&2; exit 1; }
[[ $# -gt 0 ]] || { usage; exit 2; }
host=$1; shift
ports='21,22,23,25,53,80,110,139,143,443,445,587,993,995,1433,3306,3389,5432,5900,6379,8080,8443'
timeout=1; family=-4; quiet=0
while (($#)); do
 case $1 in
  -p) [[ $# -ge 2 ]] || { usage; exit 2; }; ports=$2; shift 2;;
  -t) [[ $# -ge 2 ]] || { usage; exit 2; }; timeout=$2; shift 2;;
  -6) family=-6; shift;;
  -q) quiet=1; shift;;
  -h|--help) usage; exit 0;;
  *) echo "Unknown option: $1" >&2; usage; exit 2;;
 esac
done
[[ $timeout =~ ^[0-9]+$ ]] && ((timeout >= 1 && timeout <= 60)) || { echo 'Timeout must be 1–60 seconds' >&2; exit 2; }
[[ $host != -* && -n $host ]] || { echo 'Invalid host' >&2; exit 2; }
declare -a selected=()
IFS=',' read -r -a chunks <<< "$ports"
for chunk in "${chunks[@]}"; do
 if [[ $chunk =~ ^([0-9]+)-([0-9]+)$ ]]; then
  a=${BASH_REMATCH[1]}; b=${BASH_REMATCH[2]}
  ((10#$a >= 1 && 10#$b <= 65535 && 10#$a <= 10#$b)) || { echo 'Invalid range' >&2; exit 2; }
  ((10#$b - 10#$a <= 4095)) || { echo 'Limit each range to 4096 ports' >&2; exit 2; }
  for ((p=10#$a;p<=10#$b;p++)); do selected+=("$p"); done
 elif [[ $chunk =~ ^[0-9]+$ ]]; then
  p=$((10#$chunk)); ((p>=1 && p<=65535)) || { echo 'Invalid port' >&2; exit 2; }; selected+=("$p")
 else echo "Invalid port specification: $chunk" >&2; exit 2; fi
done
((${#selected[@]} > 0 && ${#selected[@]} <= 4096)) || { echo 'Select 1–4096 ports' >&2; exit 2; }
service() { case $1 in
  21) echo ftp;; 22) echo ssh;; 23) echo telnet;; 25) echo smtp;; 53) echo dns;; 80) echo http;; 110) echo pop3;; 139) echo netbios;; 143) echo imap;; 443) echo https;; 445) echo smb;; 587) echo submission;; 993) echo imaps;; 995) echo pop3s;; 1433) echo mssql;; 3306) echo mysql;; 3389) echo rdp;; 5432) echo postgresql;; 5900) echo vnc;; 6379) echo redis;; 8080) echo http-alt;; 8443) echo https-alt;; *) echo unknown;; esac; }
((quiet)) || { printf "Cat's Nmap 1.0 | TCP connect scan\nTarget: %s | Ports: %s | Timeout: %ss\n\n" "$host" "${#selected[@]}" "$timeout"; printf 'PORT       STATE  SERVICE\n'; }
open=0
for p in "${selected[@]}"; do
 if nc "$family" -z -w "$timeout" "$host" "$p" >/dev/null 2>&1; then
  printf '%-10s %-6s %s\n' "$p/tcp" open "$(service "$p")"
  ((open+=1))
 fi
done
((quiet)) || printf '\nDone: %d open port(s) of %d checked.\n' "$open" "${#selected[@]}"
