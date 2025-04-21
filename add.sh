

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
