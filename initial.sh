# Vars for Ubuntu
SYSCTL=/etc/sysctl.conf
# Update
apt-get update
apt-get install openvpn easy-rsa -y

# Get Internet network interface with default route
NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)')


# Network configuration
# Enable net.ipv4.ip_forward for the system
sed -i '/\<net.ipv4.ip_forward\>/c\net.ipv4.ip_forward=1' $SYSCTL
if ! grep -q "\<net.ipv4.ip_forward\>" $SYSCTL; then
	echo 'net.ipv4.ip_forward=1' >> $SYSCTL
fi
# Avoid an unneeded reboot
echo 1 > /proc/sys/net/ipv4/ip_forward
# UFW based forwarding
VPNRULES="
# START OPENVPN RULES
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0] 
# Allow traffic from OpenVPN client to NIC $NIC interface
-A POSTROUTING -s 10.8.0.0/8 -o $NIC -j MASQUERADE
COMMIT
# END OPENVPN RULES
"
echo "$VPNRULES" | cat - /etc/ufw/before.rules > temp && mv temp /etc/ufw/before.rules
sed -i -e 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw


ufw allow OpenSSH
allow ssh
sudo ufw disable
sudo ufw enable