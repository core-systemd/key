
hostnamectl set-hostname hq-rtr.au-team.irpo; exec bash

if ! grep -q "^net.ipv4.ip_forward *= *1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
fi


sysctl -p


cat > /etc/nftables/hq-rtr.nft <<EOF
table inet nat {
    chain POSTROUTING {
        type nat hook postrouting priority srcnat;
        oifname "ens18" masquerade
    }
}
EOF


NFTABLES_CONF="/etc/sysconfig/nftables.conf"
INCLUDE_LINE='include "/etc/nftables/hq-rtr.nft"'

if ! grep -Fxq "$INCLUDE_LINE" "$NFTABLES_CONF"; then
    echo "$INCLUDE_LINE" >> "$NFTABLES_CONF"
fi


systemctl enable --now nftables


