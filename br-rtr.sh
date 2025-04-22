

useradd net_admin  -U
passwd net_admin


if ! grep -q "^net_admin ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
  echo "➕ Добавляем net_admin в sudoers без пароля..."
  tmpfile=$(mktemp)
  cp /etc/sudoers "$tmpfile"
  echo "net_admin ALL=(ALL) NOPASSWD: ALL" >> "$tmpfile"

  if visudo -c -f "$tmpfile"; then
    cp "$tmpfile" /etc/sudoers
    echo "✅ Успешно добавлено!"
  else
    echo "❌ Ошибка синтаксиса в sudoers. Изменения не применены."
  fi
  rm -f "$tmpfile"
else
  echo "ℹ️ net_admin уже есть в sudoers"
fi



if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запускайте этот скрипт с правами root: sudo $0"
  exit 1
fi

hostnamectl set-hostname br-rtr.au-team.irpo


grep -qxF "net.ipv4.ip_forward = 1" /etc/sysctl.conf || echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p


mkdir -p /etc/nftables


cat >/etc/nftables/br-rtr.nft <<EOF
table inet nat {
    chain POSTROUTING {
        type nat hook postrouting priority srcnat;
        oifname "ens18" masquerade
    }
}
EOF


NFT_CONF="/etc/sysconfig/nftables.conf"
INCLUDE_LINE='include "/etc/nftables/br-rtr.nft"'
grep -Fxq "$INCLUDE_LINE" "$NFT_CONF" || echo "$INCLUDE_LINE" >> "$NFT_CONF"


systemctl enable --now nftables
nmcli connection modify tun1 ip-tunnel.ttl 64
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
 network 192.168.200.0/27 area 0
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
