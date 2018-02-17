# Vars for Ubuntu
SYSCTL=/etc/sysctl.conf
# Update
curl -s https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add
echo "deb http://build.openvpn.net/debian/openvpn/stable xenial main" > /etc/apt/sources.list.d/openvpn-aptrepo.list
apt-get update
apt-get install openvpn easy-rsa -y

# Get Internet network interface with default route
NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)')


## Network configuration
# Enable net.ipv4.ip_forward for the system
sed -i '/\<net.ipv4.ip_forward\>/c\net.ipv4.ip_forward=1' $SYSCTL
if ! grep -q "\<net.ipv4.ip_forward\>" $SYSCTL; then
	echo 'net.ipv4.ip_forward=1' >> $SYSCTL
fi
# Enable net.ipv6.conf.all.forwarding= for the system
sed -i '/\<net.ipv6.conf.all.forwarding\>/c\net.ipv6.conf.all.forwarding=1' $SYSCTL
if ! grep -q "\<net.ipv6.conf.all.forwarding\>" $SYSCTL; then
	echo 'net.ipv6.conf.all.forwarding=1' >> $SYSCTL
fi
# Apply changes through sysctl reload
sysctl -p /etc/sysctl.conf

## Ther below was only needed because sysctl -p /etc/sysctl.conf wasn't in the script before. Leaving it here for reference purposes.
# Avoid an unneeded reboot by enabling forwarding through proc
# echo 1 > /proc/sys/net/ipv4/ip_forward
# echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

# UFW based forwarding
VPNRULES="
# START OPENVPN RULES
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0] 
# Allow traffic from OpenVPN client to NIC $NIC interface
-A POSTROUTING -s 10.8.0.0/8 -o ${NIC} -j MASQUERADE
COMMIT
# END OPENVPN RULES
"
echo "$VPNRULES" | cat - /etc/ufw/before.rules > temp && mv temp /etc/ufw/before.rules
sed -i -e 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw


ufw allow OpenSSH
ufw allow ssh
ufw disable
yes | ufw enable