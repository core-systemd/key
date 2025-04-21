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


dnf install -y bind bind-utils


cp /etc/named.conf /etc/named.conf.bak
cat > /etc/named.conf << 'EOF'
//
// named.conf
//
// Provided by Red Hat bind package to configure the ISC BIND named(8) DNS
// server as a caching only nameserver (as a localhost DNS resolver only).
//

options {
	listen-on port 53 { 127.0.0.1; 192.168.100.0/26; 192.168.100.64/28; 192.168.200.0/27; };
	listen-on-v6 port 53 { none; };
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";
	secroots-file	"/var/named/data/named.secroots";
	recursing-file	"/var/named/data/named.recursing";
	allow-query     { any; };
	forwarders	{ 8.8.8.8; };
	recursion yes;
	dnssec-validation no;
	managed-keys-directory "/var/named/dynamic";
	geoip-directory "/usr/share/GeoIP";
	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";
	include "/etc/crypto-policies/back-ends/bind.config";
};

logging {
	channel default_debug {
		file "data/named.run";
		severity dynamic;
	};
};

zone "." IN {
	type hint;
	file "named.ca";
};

zone "au-team.irpo" {
	type master;
	file "master/au-team.db";
};

zone "100.168.192.in-addr.arpa" {
	type master;
	file "master/au-team_rev.db";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
EOF


mkdir -p /var/named/master


cat > /var/named/master/au-team.db << 'EOF'
$TTL 1D
@	IN	SOA	au-team.irpo. root.au-team.irpo. (
					0	; serial
					1D	; refresh
					1H	; retry
					1W	; expire
					3H )	; minimum
	IN	NS	au-team.irpo.	
	IN	A	192.168.100.2
hq-rtr	IN	A	192.168.100.1
br-rtr	IN	A	192.168.200.1
hq-srv	IN	A	192.168.100.2
hq-cli	IN	A	192.168.100.66
br-srv	IN	A	192.168.200.2
moodle	CNAME	hq-rtr.au-team.irpo.
wiki	CNAME	hq-rtr.au-team.irpo.
EOF


cat > /var/named/master/au-team_rev.db << 'EOF'
$TTL 1D
@	IN SOA	au-team.irpo. root.au-team.irpo. (
					0	; serial
					1D	; refresh
					1H	; retry
					1W	; expire
					3H )	; minimum

	IN	NS	au-team.irpo.
1	IN	PTR	hq-rtr.au-team.irpo.
2	IN	PTR	hq-srv.au-team.irpo.
66	IN	PTR	hq-cli.au-team.irpo.
EOF


chown -R root:named /var/named/master
chmod 0640 /var/named/master/*


named-checkconf -z
systemctl enable --now named

echo "BIND DNS-сервер успешно установлен и настроен."
