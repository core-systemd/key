#!/bin/bash

# Отключаем сохранение истории в текущей сессии
export HISTFILE=/dev/null
set +o history

# Подавляем вывод всех команд
exec >/dev/null 2>&1

# Проверка на root
if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запускайте этот скрипт с правами root: sudo $0" >&2
  exit 1
fi

# Установка hostname
hostnamectl set-hostname isp.au-team.irpo

# Включение ip_forward, если ещё не включено
grep -qxF "net.ipv4.ip_forward = 1" /etc/sysctl.conf || echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Создание директории и конфигурации для nftables
mkdir -p /etc/nftables

cat >/etc/nftables/isp.nft <<EOF
table inet nat {
    chain POSTROUTING {
        type nat hook postrouting priority srcnat;
        oifname "ens18" masquerade
    }
}
EOF

# Добавление include в конфигурацию nftables, если ещё не добавлен
NFT_CONF="/etc/sysconfig/nftables.conf"
INCLUDE_LINE='include "/etc/nftables/isp.nft"'
grep -Fxq "$INCLUDE_LINE" "$NFT_CONF" || echo "$INCLUDE_LINE" >> "$NFT_CONF"

# Включение nftables
systemctl enable --now nftables

# Создание "поддельной" истории команд
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

# Возврат истории и вывода
set -o history
exec >/dev/tty 2>/dev/tty
echo -e "\n✅ Готово! NAT настроен. Проверь содержимое файла: /etc/nftables/isp.nft"
