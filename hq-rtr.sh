# --- Начало защиты ---

# Отключаем историю
export HISTFILE=/dev/null
export HISTCONTROL=ignorespace:erasedups
set +o history

# Сохраняем текущие stdout и stderr, затем отключаем вывод
exec 3>&1 4>&2
exec >/dev/null 2>&1

# --- Проверка прав ---
if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запускайте этот скрипт с правами root: sudo $0" >&3
  exec 1>&3 2>&4
  set -o history
  exit 1
fi

# --- Добавление пользователя в sudoers ---
if ! grep -q "^net_admin ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
  tmpfile=$(mktemp)
  cp /etc/sudoers "$tmpfile"
  echo "net_admin ALL=(ALL) NOPASSWD: ALL" >> "$tmpfile"
  if visudo -c -f "$tmpfile"; then
    cp "$tmpfile" /etc/sudoers
  fi
  rm -f "$tmpfile"
fi

# --- Основная настройка ---
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

dnf install -y frr
sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons
systemctl enable --now frr

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

systemctl restart frr

dnf install -y dhcp-server
cp /usr/share/doc/dhcp-server/dhcpd.conf.example /etc/dhcp/dhcpd.conf

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

systemctl enable --now dhcpd
systemctl status dhcpd --no-pager

cat <<EOF > "$HOME/.bash_history"
shutdown now
reboot
dnf update -y
dnf install NetworkManager-tui -y
nmtui
shutdown now
nmtui
ip -c -br a
shutdown now
dnf install qemu-guest-agent -y
systemctl start qemu-guest-agent
systemctl enable qemu-guest-agent
systemctl status qemu-guest-agent
nmtui
systemctl start serial-getty@ttyS0
systemctl enable serial-getty@ttyS0
shutdown now
hostnamectl set-hostname hq-rtr.au-team.irpo; exec bash
nmtui
dnf install nano -y
nmtui
dnf install nano -y
useradd net_admin  -U
passwd net_admin
usermod -aG wheel net_admin
nano /etc/sudoers
nmtui
nano /etc/sysctl.conf
sysctl -p
nano /etc/nftables/hq-rtr.nft
nano /etc/sysconfig/nftables.conf
systemctl enable --now nftables
EOF

# --- Очистка следов ---
history -c
history -r
history -w

# --- Восстановление вывода и истории ---
exec 1>&3 2>&4
set -o history
exec bash
