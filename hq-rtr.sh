
hostnamectl set-hostname hq-rtr.au-team.irpo; exec bash

if ! grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
fi
sysctl -p


sudo tee /etc/nftables/hq-rtr.nft > /dev/null <<EOF
table inet nat {
    chain POSTROUTING {
        type nat hook postrouting priority srcnat;
        oifname "ens18" masquerade
    }
}
EOF


if ! grep -q 'include "/etc/nftables/hq-rtr.nft"' /etc/sysconfig/nftables.conf; then
    echo 'include "/etc/nftables/hq-rtr.nft"' >> /etc/sysconfig/nftables.conf
fi


systemctl enable --now nftables
