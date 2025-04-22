hostnamectl set-hostname br-srv.au-team.irpo

useradd sshuser -u 1010 -U
passwd sshuser


if ! grep -q "^sshuser ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
  echo "➕ Добавляем sshuser в sudoers без пароля..."
  tmpfile=$(mktemp)
  cp /etc/sudoers "$tmpfile"
  echo "sshuser ALL=(ALL) NOPASSWD: ALL" >> "$tmpfile"

  if visudo -c -f "$tmpfile"; then
    cp "$tmpfile" /etc/sudoers
    echo "✅ Успешно добавлено!"
  else
    echo "❌ Ошибка синтаксиса в sudoers. Изменения не применены."
  fi
  rm -f "$tmpfile"
else
  echo "ℹ️ sshuser уже есть в sudoers"
fi



echo "[*] Отключаем SELinux (меняем enforcing на permissive)..."
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config


echo "[*] Временно отключаем SELinux..."
setenforce 0


echo "[*] Настройка SSH..."

SSH_CONFIG="/etc/ssh/sshd_config"


sed -i 's/^#Port 22/Port 2024/' $SSH_CONFIG
sed -i 's/^Port .*/Port 2024/' $SSH_CONFIG


if ! grep -q "^AllowUsers" $SSH_CONFIG; then
  echo "AllowUsers sshuser" >> $SSH_CONFIG
else
  sed -i 's/^AllowUsers.*/AllowUsers sshuser/' $SSH_CONFIG
fi


sed -i 's/^#MaxAuthTries.*/MaxAuthTries 2/' $SSH_CONFIG
sed -i 's/^MaxAuthTries.*/MaxAuthTries 2/' $SSH_CONFIG


sed -i 's|^#Banner.*|Banner /etc/ssh-banner|' $SSH_CONFIG
echo "Authorized access only" > /etc/ssh-banner


echo "[*] Перезапуск sshd..."
systemctl restart sshd

echo "[+] Настройка завершена."
