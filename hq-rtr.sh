
if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запускайте этот скрипт с правами root: sudo $0"
  exit 1
fi

hostnamectl set-hostname hq-rtr.au-team.irpo


grep -qxF "net.ipv4.ip_forward = 1" /etc/sysctl.conf || echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p


mkdir -p /etc/nftables


cat >/etc/nftables/hq-rtr.nft <<EOF
table inet nat {
    chain POSTROUTING {
        type nat hook postrouting priority srcnat;
        oifname "ens18" masquerade
    }
}
EOF


NFT_CONF="/etc/sysconfig/nftables.conf"
INCLUDE_LINE='include "/etc/nftables/hq-rtr.nft"'
grep -Fxq "$INCLUDE_LINE" "$NFT_CONF" || echo "$INCLUDE_LINE" >> "$NFT_CONF"


systemctl enable --now nftables

echo -e "\n✅ Готово! NAT настроен. Проверь содержимое файла: /etc/nftables/hq-rtr.nft"
