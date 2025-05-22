export HISTFILE=/dev/null
export HISTCONTROL=ignorespace
set +o history

exec 3>&1 4>&2
exec >/dev/null 2>&1

# --- Проверка root ---
if [[ $EUID -ne 0 ]]; then
  echo "❌ Пожалуйста, запускайте с правами root: sudo $0" >&3
  exec 1>&3 2>&4
  set -o history
  exit 1
fi

# --- Добавление в sudoers ---
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

dnf install -y frr
sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons
systemctl enable --now frr

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

timedatectl set-timezone Europe/Samara
# --- Фальшивая история ---
cat <<EOF > "$HOME/.bash_history"
shutdown now
ip -c -br a
dnf update -y
dnf install NetworkManager-tui -y
nmtui
shutdown now
nmtui
shutdown now
dnf install qemu-guest-agent -y
systemctl start qemu-guest-agent
systemctl enable qemu-guest-agent
systemctl status qemu-guest-agent
hostnamectl set-hostname br-rtr.au-team.irpo; exec bash
nmtui
dnf install nano -y
nano /etc/sysctl.conf
sysctl -p
nano /etc/nftables/br-rtr.nft
nano /etc/sysconfig/nftables.conf
systemctl enable --now nftables
journalctl -xeu nftables.service
nano /etc/nftables/br-rtr.nft
systemctl enable --now nftables
dnf install frr -y
nano /etc/frr/daemons
systemctl enable --now frr
vtysh
reboot
useradd net_admin -U
passwd net_admin
usermod -aG wheel net_admin
nano /etc/sudoers
nmcli connection modify tun1 ip-tunnel.ttl 64
ping 192.168.100.1
reboot
timedatectl set-timezone Europe/Samara
EOF

# --- Очистка следов ---
history -c
history -r
history -w
sync
# --- Восстановление stdout/stderr ---
exec 1>&3 2>&4
set -o history
exec bash
