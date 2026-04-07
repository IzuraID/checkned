#!/bin/bash

read -p "Masukkan Nomor Peserta (contoh: 10): " X < /dev/tty

if ! command -v fping &> /dev/null; then
  echo "fping belum terinstall. Menginstall..."
  sudo apt install -y fping
fi

echo ""
echo "=============================="
echo "     NETWORK CHECK"
echo "=============================="

order=("PUBLIC" "PRIVATE" "CLIENT")

declare -A networks=(
  ["PUBLIC"]="172.26.$X.0/27"
  ["PRIVATE"]="192.168.$X.0/27"
  ["CLIENT"]="10.10.$X.0/24"
)

total_up=0

for name in "${order[@]}"; do
  net=${networks[$name]}

  echo "===== Checking $name ($net) ====="

  alive_ips=$(fping -a -q -g $net 2>/dev/null)

  for ip in $alive_ips; do
    raw_hostnames=$(host $ip 2>/dev/null | awk '/pointer/ {print $5}' | sed 's/\.$//')

    if [ -z "$raw_hostnames" ]; then
        final_hostname="$ip"
    else
        final_hostname=""

        for h in $raw_hostnames; do
            if [ -z "$final_hostname" ]; then
                final_hostname="$h"
                    else
                final_hostname="${final_hostname},$h"
            fi
        done
    fi

    printf "[UP] %-15s - %s\n" "$ip" "$final_hostname"

    ((total_up++))
  done

  echo ""
done

echo "Total host UP: $total_up"

echo ""
echo "=============================="
echo "        DNS CHECK"
echo "=============================="

echo ""
echo "[ROOT DOMAIN]"
domain="lks2026.diy"
a_record=$(dig +short $domain A)

if [ -n "$a_record" ]; then
  echo "$domain -> $a_record"
else
  echo "$domain -> Tidak ada A record"
fi

echo ""
echo "[MX RECORD]"
mx=$(dig +short $domain MX)

if [ -n "$mx" ]; then
  echo "$mx"
else
  echo "Tidak ada MX record"
fi

echo ""
echo "[SUBDOMAIN CHECK]"

subs=("www" "mail" "ftp" "ns1" "ns2" "ldap")

for sub in "${subs[@]}"; do
  fqdn="$sub.$domain"

  cname=$(dig +short $fqdn CNAME)

  if [ -n "$cname" ]; then
    echo "$fqdn -> $cname (CNAME)"
    continue
  fi

  ip=$(dig +short $fqdn A)

  if [ -n "$ip" ]; then
    mx_sub=$(dig +short $fqdn MX)

    if [ -n "$mx_sub" ]; then
      echo "$fqdn -> $ip (MX)"
    else
      echo "$fqdn -> $ip"
    fi
  fi
done
