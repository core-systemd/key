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



echo "[*] Установка пакета dhcp-server..."
dnf install -y dhcp-server


echo "[*] Создание конфигурационного файла dhcpd.conf..."
cp /usr/share/doc/dhcp-server/dhcpd.conf.example /etc/dhcp/dhcpd.conf


echo "[*] Настройка параметров DHCP..."
cat <<EOF > /etc/dhcp/dhcpd.conf
subnet 192.168.100.64 netmask 255.255.255.240 {
  range 192.168.100.66 192.168.100.78;
  option domain-name-servers 192.168.100.2;
  option domain-name "au-team.irpo";
  option routers 192.168.100.65;
  default-lease-time 600;
  max-lease-time 7200;
}
EOF

echo "[*] Включение и запуск службы dhcpd..."
systemctl enable --now dhcpd


echo "[*] Проверка статуса службы dhcpd..."
systemctl status dhcpd --no-pager
