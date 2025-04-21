
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



if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запускайте от root: sudo $0"
  exit 1
fi


echo "[*] Устанавливаем FRR..."
dnf install -y frr


echo "[*] Активируем ospfd..."
sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons


echo "[*] Включаем и запускаем FRR..."
systemctl enable --now frr


echo "[*] Настраиваем OSPF через vtysh..."

vtysh <<EOF
configure terminal
router ospf
 passive-interface default
 network 192.168.100.0/26 area 0
 network 192.168.100.64/28 area 0
 network 10.10.0.0/30 area 0
 area 0 authentication
exit
interface tun1
 no ip ospf network broadcast
 no ip ospf passive
 ip ospf authentication
 ip ospf authentication-key password
exit
exit
write
EOF


echo "[*] Перезапускаем FRR..."
systemctl restart frr


echo -e "\n[*] Текущая конфигурация OSPF:"
vtysh -c "show running-config"
