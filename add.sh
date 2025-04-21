useradd net_admin  -U
passwd net_admin

#!/bin/bash

insert="net_admin ALL=(ALL) NOPASSWD: ALL"
target="# %wheel ALL=(ALL) NOPASSWD: ALL"

if ! grep -Fxq "$insert" /etc/sudoers; then
  echo "➕ Вставляем строку после '$target'..."
  tmpfile=$(mktemp)

  awk -v tgt="$target" -v ins="$insert" '
    {
      print
      if ($0 == tgt) {
        print ins
      }
    }
  ' /etc/sudoers > "$tmpfile"

  if visudo -c -f "$tmpfile"; then
    cp "$tmpfile" /etc/sudoers
    echo "✅ Строка успешно вставлена!"
  else
    echo "❌ Ошибка синтаксиса. Изменения не применены."
  fi

  rm -f "$tmpfile"
else
  echo "ℹ️ Строка уже есть в sudoers"
fi
