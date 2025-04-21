
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
