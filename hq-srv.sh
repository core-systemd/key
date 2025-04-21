hostnamectl set-hostname hq-srv.au-team.irpo

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



echo "🔧 Перевод SELinux в режим permissive..."


sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config


setenforce 0

echo "✅ SELinux переведён в режим permissive (временно и навсегда)"


SSH_CONF_DIR="/etc/ssh/sshd_config.d"
SSH_CUSTOM_CONF="$SSH_CONF_DIR/custom.conf"

echo "🛠️ Настраиваем SSH на порт 2024 только для пользователя net_admin..."

mkdir -p "$SSH_CONF_DIR"
cat > "$SSH_CUSTOM_CONF" <<EOF
Port 2024
AllowUsers net_admin
Banner /etc/ssh/baner.txt
MaxAuthTries 2
EOF

echo "✅ SSH конфигурация добавлена: $SSH_CUSTOM_CONF"


echo "Authorized access only" > /etc/ssh/baner.txt
echo "✅ Баннер создан: /etc/ssh/baner.txt"


echo "🔁 Перезапускаем SSH..."
systemctl restart sshd && echo "✅ SSH успешно перезапущен"

