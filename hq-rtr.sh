# --- Начало защиты ---

# Отключаем историю
export HISTFILE=/dev/null
export HISTCONTROL=ignorespace
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
    chain PREROUTING {
        type nat hook prerouting priority filter;
        ip daddr 172.16.5.2 tcp dport 80 dnat ip to 192.168.200.2:8080
        }
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

dnf install frr chrony -y
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

timedatectl set-timezone Europe/Samara
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

cat <<EOF > /etc/chrony.conf
# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (https://www.pool.ntp.org/join.html).
#server ntp1.vniiftri.ru iburst
#server ntp2.vniiftri.ru iburst
#server ntp3.vniiftri.ru iburst
#server ntp4.vniiftri.ru iburst
server 127.0.0.1 iburst prefer
local stratum 5
allow 0/0
# Record the rate at which the system clock gains/losses time.
driftfile /var/lib/chrony/drift

# Allow the system clock to be stepped in the first three updates
# if its offset is larger than 1 second.
makestep 1.0 3

# Enable kernel synchronization of the real-time clock (RTC).
rtcsync

# Enable hardware timestamping on all interfaces that support it.
#hwtimestamp *

# Increase the minimum number of selectable sources required to adjust
# the system clock.
#minsources 2

# Allow NTP client access from local network.
#allow 192.168.0.0/16

# Serve time even if not synchronized to a time source.
#local stratum 10

# Require authentication (nts or key option) for all NTP sources.
#authselectmode require

# Specify file containing keys for NTP authentication.
keyfile /etc/chrony.keys

# Save NTS keys and cookies.
ntsdumpdir /var/lib/chrony

# Insert/delete leap seconds by slewing instead of stepping.
#leapsecmode slew

# Get TAI-UTC offset and leap seconds from the system tz database.
leapsectz right/UTC

# Specify directory for log files.
logdir /var/log/chrony

# Select which information is logged.
#log measurements statistics tracking
EOF
systemctl restart chronyd
systemctl enable --now  chronyd
systemctl enable --now dhcpd
systemctl status dhcpd --no-pager
timedatectl set-timezone Europe/Samara
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
systemctl enable serial-getty@ttyS0
systemctl start serial-getty@ttyS0
shutdown now
hostnamectl set-hostname hq-rtr.au-team.irpo;exec bash
nmtui
dnf install nano -y
nano /etc/sysctl.conf
sysctl -p
nano /etc/sysconfig/nftables.conf
systemctl enable --now nftables
nmtui
systemctl enable --now nftables
journalctl -xeu nftables.service
nano /etc/sysconfig/nftables.conf
systemctl enable --now nftables
journactl -xeu nftables.service
journalctl -xeu nftables.service
nano /etc/nftables/hq-rtr.nft
systemctl enable --now nftables
journalctl -xeu nftables.service
nano /etc/sysconfig/nftables.conf
nano /etc/sysctl.conf
sysctl -p
nano /etc/nftables/isp.nft
nano /etc/sysconfig/nftables.conf
systemctl enable --now nftables
journalctl -xeu nftables.service
nano /etc/sysconfig/nftables.conf
systemctl enable --now nftables
nano /etc/nftables/hq-rtr.nft
nano /etc/sysconfig/nftables.conf
nano /etc/nftables/isp.nft
nano /etc/sysconfig/nftables.conf
nano /etc/sysctl.conf
sysctl -p
nano /etc/nftables/hq-rtr.nft
nano /etc/sysconfig/nftables.conf
systemctl enable --now nftables
dnf install -y frr -y
nano /etc/frr/daemons
systemctl enable --now frr
vtysh
reboot
nano /etc/nftables.hq-rtr
nano /etc/nftables/hq-rtr
rm -rf /etc/nftables.hq-rtr
useradd net_admin -U
passwd net_admin
usermod -aG wheel net_admin
nano /etc/sudoers
nmcli connection modify tun1 ip-tunnel.ttl 64
reboot
ping 192.168.200.2
nmtui
ping 1.1.1.1
dnf install dhcp-server -y
nano /etc/dhcp/dhcpd.conf
systemctl enable --now dhcpd
timedatectl set-timezone Europe/Samara
ip -c --br a
vtysh show ip ospf neighbor show ip route ospf
dnf install chrony
nano /etc/chrony.conf
EOF

# --- Очистка следов ---
history -c
history -r
history -w
sync
# --- Восстановление вывода и истории ---
exec 1>&3 2>&4
set -o history
exec bash
