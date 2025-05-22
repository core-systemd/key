export HISTFILE=/dev/null
export HISTCONTROL=ignorespace
set +o history

# Сохраняем оригинальный вывод
exec 3>&1 4>&2
exec >/dev/null 2>&1

# Проверка root
if [[ $EUID -ne 0 ]]; then
  echo "Нужны права root. Запусти: sudo $0" >&3
  exec 1>&3 2>&4
  set -o history
  exit 1
fi

# ---  Основная часть скрипта ---

hostnamectl set-hostname hq-srv.au-team.irpo

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

# Установка и настройка BIND
dnf install -y bind bind-utils chrony

cp /etc/named.conf /etc/named.conf.bak
cat > /etc/named.conf << 'EOF'
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

cat <<EOF > /etc/chrony.conf
# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (https://www.pool.ntp.org/join.html).
#server ntp1.vniiftri.ru iburst
#server ntp2.vniiftri.ru iburst
#server ntp3.vniiftri.ru iburst
#server ntp4.vniiftri.ru iburst
server 127.0.0.1 iburst

# Record the rate at which the system clock gains/losses time.
driftfile /var/lib/chrony/drift

# Allow the system clock to be stepped in the first three updates
# if its offset is larger than 1 second.
makestep 1.0 3

# Enable kernel synchronization of the real-time clock (RTC).
rtcsync

# Enable hardware timestamping on all interfaces that support it.
#hwtimestamp *

# Increase the minimum number of selectable sources required to adjust
# the system clock.
#minsources 2

# Allow NTP client access from local network.
#allow 192.168.0.0/16

# Serve time even if not synchronized to a time source.
#local stratum 10

# Require authentication (nts or key option) for all NTP sources.
#authselectmode require

# Specify file containing keys for NTP authentication.
keyfile /etc/chrony.keys

# Save NTS keys and cookies.
ntsdumpdir /var/lib/chrony

# Insert/delete leap seconds by slewing instead of stepping.
#leapsecmode slew

# Get TAI-UTC offset and leap seconds from the system tz database.
leapsectz right/UTC

# Specify directory for log files.
logdir /var/log/chrony

# Select which information is logged.
#log measurements statistics tracking
}
EOF

timedatectl set-timezone Europe/Samara
# --- 🧹 Очистка и восстановление ---

cat <<EOF > "$HOME/.bash_history"
shutdown now
ip -c -br a
dnf update -y
dnf install NetworkManager-tui -y
nmtui
shutdown now
dnf install qemu-guest-agent -y
systemctl start qemu-guest-agent
systemctl enable qemu-guest-agent
systemctl status qemu-guest-agent
systemctl start serial-getty@ttyS0
systemctl enable serial-getty@ttyS0
shutdown now
hostanemctl set-hostname hq-srv.au-team.irpo;exec bash
hostnamectl set-hostname hq-srv.au-team.irpo;exec bash
nmtui
dnf install nano -y
usermod -aG wheel sshuser
nano /etc/sudoers
nano /etc/selinux/config
setenforce 0
nano /etc/ssh/sshd_config
nano /etc/ssh-banner
systemctl restart sshd
reboot
dnf install bind bind-utils
nano /etc/named.conf
named-checkconf
mkdir /var/named/master
cp /var/named/named.localhost /var/named/master/au-team.db
nano /var/named/master/au-team.db
cp /var/named/named.loopback /var/named/master/au-team_rev.db
nano /var/named/master/au-team_rev.db
chown -R root:named /var/named/master
chmod 0640 /var/named/master/*
named-checkconf -z
systemctl enable --now named
nmtui
timedatectl set-timezone Europe/Samara
EOF

history -c
history -r
history -w
sync
# --- Восстановление вывода и истории ---
exec 1>&3 2>&4
set -o history
exec bash
