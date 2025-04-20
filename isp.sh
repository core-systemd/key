hostnamectl set-hostname isp.au-team.irpo


if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
sysctl -p


cat > /etc/nftables/isp.nft <<EOF
table inet nat {
    chain POSTROUTING {
        type nat hook postrouting priority srcnat;
        oifname "ens18" masquerade
    }
}
EOF


if ! grep -q 'include "/etc/nftables/isp.nft"' /etc/sysconfig/nftables.conf; then
    echo 'include "/etc/nftables/isp.nft"' >> /etc/sysconfig/nftables.conf
fi


systemctl enable --now nftables

