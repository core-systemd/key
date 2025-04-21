useradd net_admin  -U
passwd net_admin



LINE_TO_FIND="# %wheel        ALL=(ALL)       NOPASSWD: ALL"
NEW_LINE="net_admin ALL=(ALL) NOPASSWD: ALL"

if grep -Fxq "$NEW_LINE" /etc/sudoers; then
  echo "ℹ️ Строка уже существует в sudoers"
  exit 0
fi

TMP_FILE=$(mktemp)

awk -v find="$LINE_TO_FIND" -v insert="$NEW_LINE" '
{
  print
  if ($0 == find) {
    print insert
  }
}' /etc/sudoers > "$TMP_FILE"

if visudo -c -f "$TMP_FILE"; then
  cp "$TMP_FILE" /etc/sudoers
  echo "✅ Успешно вставлено!"
else
  echo "❌ Ошибка в sudoers! Не трогаем оригинал."
fi


rm -f "$TMP_FILE"

