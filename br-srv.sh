
export HISTFILE=/dev/null
export HISTCONTROL=ignorespace
set +o history

# Сохраняем текущий вывод
exec 3>&1 4>&2
exec >/dev/null 2>&1

# Проверка прав
if [[ $EUID -ne 0 ]]; then
  echo "Запусти скрипт от root: sudo $0" >&3
  exec 1>&3 2>&4
  set -o history
  exit 1
fi

# --- ⚙️ Основная часть ---

hostnamectl set-hostname br-srv.au-team.irpo

if ! grep -q "^sshuser ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
  tmpfile=$(mktemp)
  cp /etc/sudoers "$tmpfile"
  echo "sshuser ALL=(ALL) NOPASSWD: ALL" >> "$tmpfile"

  if visudo -c -f "$tmpfile"; then
    cp "$tmpfile" /etc/sudoers
  fi
  rm -f "$tmpfile"
fi

# Отключаем SELinux
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
setenforce 0

# Настройка SSH
SSH_CONFIG="/etc/ssh/sshd_config"

sed -i 's/^#Port 22/Port 2024/' "$SSH_CONFIG"
sed -i 's/^Port .*/Port 2024/' "$SSH_CONFIG"

if ! grep -q "^AllowUsers" "$SSH_CONFIG"; then
  echo "AllowUsers sshuser" >> "$SSH_CONFIG"
else
  sed -i 's/^AllowUsers.*/AllowUsers sshuser/' "$SSH_CONFIG"
fi

sed -i 's/^#MaxAuthTries.*/MaxAuthTries 2/' "$SSH_CONFIG"
sed -i 's/^MaxAuthTries.*/MaxAuthTries 2/' "$SSH_CONFIG"

sed -i 's|^#Banner.*|Banner /etc/ssh-banner|' "$SSH_CONFIG"
echo "Authorized access only" > /etc/ssh-banner

systemctl restart sshd

# --- 🧹 Очистка и финал ---
cat <<EOF > "$HOME/.bash_history"
shutdown now
dnf update -y
ip -c -br a
dnf update -y
reboot 
dnf update -y
dnf install NetworkManager-tui -y
nmtui
shutdown now
dnf install qemu-quest-agent -y
ip -c -br a
dnf install qemu-quest-agent -y
reboot 
dnf install qemu-quest-agent -y
dnf update -y
systemctl status qemu-quest-agent
dnf install qemu-quest-agent -y
dnf install qemu-guest-agent
systemctl start qemu-quest-agent
systemctl start qemu-guest-agent
systemctl enable qemu-guest-agent
systemctl status qemu-guest-agent
systemctl start serial-getty@ttyS0
systemctl enable serial-getty@ttyS0
shutdown now
nmtui
hostnamectl set-hostname br-srv.au-team.irpo;exec bash
dnf install nano -y
usermod -aG wheel sshuser
nano /etc/sudoers
nano /etc/selinux/config
setenforce 0
nano /etc/ssh/sshd_config
nano /etc/ssh-banner
systemctl restart sshd
journalctl -xeu sshd.service
nano /etc/ssh/sshd_config
systemctl restart sshd
ping 192.168.100.1
reboot
nmtui
ping au-team.irpo
ping hq-cli.au-team.irpo
ping hq-rtr.au-team.irpo
ping br-rtr.au-team.irpo
EOF

history -c
history -r
history -w
sync

exec 1>&3 2>&4
set -o history
exec bash
