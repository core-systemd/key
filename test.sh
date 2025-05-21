export HISTFILE=/dev/null
HISTCONTROL=ignorespace
set +o history

exec 3>&1 4>&2
exec >/dev/null 2>&1

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запускайте этот скрипт с правами root: sudo $0" >&3
  exit 1
fi

-
hostnamectl set-hostname isp.au-team.irpo

grep -qxF "net.ipv4.ip_forward = 1" /etc/sysctl.conf || echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

mkdir -p /etc/nftables

cat >/etc/nftables/isp.nft <<EOF
table inet nat {
    chain POSTROUTING {
        type nat hook postrouting priority srcnat;
        oifname "ens18" masquerade
    }
}
EOF

NFT_CONF="/etc/sysconfig/nftables.conf"
INCLUDE_LINE='include "/etc/nftables/isp.nft"'
grep -Fxq "$INCLUDE_LINE" "$NFT_CONF" || echo "$INCLUDE_LINE" >> "$NFT_CONF"

systemctl enable --now nftables


cat <<EOF > "$HOME/.bash_history"
shutdown now
nmtui
dnf update -y
dnf install NetworkManager-tui -y
nmtui
shutdown now
systemctl status qemu-guest-agent
dnf install qemu-guest-agent -y
systemctl start qemu-guest-agent
systemctl enable qemu-guest-agent
systemctl status qemu-guest-agent
mcedit /etc/default/grub
mcedit /etc/init/ttyS0.conf
mc
cd
systemctl start serial-getty@ttyS0
systemctl enable serial-getty@ttyS0
shutdown now
hostnamectl set-hostname isp.au-team.irpo; exec bash
nmtui
nano /etc/sysctl.conf
sysctl -p
nano /etc/nftables/isp.nft
nano /etc/sysconfig/nftables.conf
systemctl enable --now nftables
EOF


history -c
history -r
history -w       
sync       




exec 1>&3 2>&4
set -o history

exec bash
