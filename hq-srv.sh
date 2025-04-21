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
