useradd net_admin  -U
passwd net_admin

insert="net_admin ALL=(ALL) NOPASSWD: ALL"
target="# %wheel ALL=(ALL) NOPASSWD: ALL"

if ! grep -q "^$insert" /etc/sudoers; then
  echo "➕ Вставляем строку после '$target'..."
  tmpfile=$(mktemp)

  awk -v tgt="$target" -v ins="$insert" '
    $0 == tgt {
      print
      print ins
      next
    }
    { print }
  ' /etc/sudoers > "$tmpfile"

  if visudo -c -f "$tmpfile"; then
    cp "$tmpfile" /etc/sudoers
    echo "✅ Строка успешно вставлена!"
  else
    echo "❌ Ошибка синтаксиса в sudoers. Изменения не применены."
  fi

  rm -f "$tmpfile"
else
  echo "ℹ️ Строка уже присутствует в sudoers"
fi
