#######################################
########### START ACTIONS #############
#######################################

# Dependencies

sudo apt-get update #update all repos
sudo apt-get -y install openvpn easy-rsa curl wget dnsutils ufw #install openvpn and easyrsa
apt-get -y upgrade #update everything

#!/bin/bash
ipvar=$(dig +short myip.opendns.com @resolver1.opendns.com) #grab our IP
echo "$ipvar"

# USER INFO
vpnclient="UDPclient" # Name of the regular config file
vpnclientTCP="TCPclient" # Name of the TCP config file
vpncipher="BF-CBC" # BF-CBC AES-128-CBC AES-256-CBC
verbosity="0"

#RSA Variables
rsavars='export KEY_COUNTRY="NL"
export KEY_PROVINCE="NH"
export KEY_CITY="Amsterdam"
export KEY_ORG="Anonymous"
export KEY_EMAIL="not@available.com"
export KEY_OU=HQ
export KEY_CN=openvpn
export KEY_ALTNAMES="something"
export KEY_NAME=server'

# compose ufw rules
ufwrules='*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.8.0.0/8 -o eth0 -j MASQUERADE
COMMIT'

# Set openvpn client settings
ovpnsets="client
remote $ipvar 1194
dev tun0
proto udp
key-direction 1
nobind
float
persist-key
persist-tun
ns-cert-type server
comp-lzo
verb $verbosity
user nobody
group nogroup
cipher $vpncipher"
ovpnsetstcp="client
remote $ipvar 443
dev tun1
proto tcp
key-direction 1
nobind
float
persist-key
persist-tun
ns-cert-type server
comp-lzo
verb $verbosity
user nobody
group nogroup
cipher $vpncipher"
udpserver="port 1194
proto udp
dev tun0
ca ca.crt
cert server.crt
key server.key
tls-auth ta.key 0
dh dh2048.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push \"redirect-gateway def1 bypass-dhcp\"
push \"dhcp-option DNS 208.67.222.222\"
push \"dhcp-option DNS 208.67.220.220\"
duplicate-cn
keepalive 10 120
cipher $vpncipher
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb $verbosity"
tcpserver="port 443
proto tcp
dev tun1
ca ca.crt
cert server.crt
key server.key
tls-auth ta.key 0
dh dh2048.pem
server 10.8.8.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push \"redirect-gateway def1 bypass-dhcp\"
push \"dhcp-option DNS 208.67.222.222\"
push \"dhcp-option DNS 208.67.220.220\"
duplicate-cn
keepalive 10 120
cipher $vpncipher
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb $verbosity"

#Auto security update rules
updaterules='echo "**************" >> /var/log/apt-security-updates
date >> /var/log/apt-security-updates
aptitude update >> /var/log/apt-security-updates
aptitude safe-upgrade -o Aptitude::Delete-Unused=false --assume-yes --target-release `lsb_release -cs`-security >> /var/log/apt-security-updates
echo "Security updates (if any) installed"'
rotaterules='/var/log/apt-security-updates {
        rotate 2
        weekly
        size 250k
        compress
        notifempty
}'

#######################################
########### START ACTIONS #############
#######################################


# UDP Server
touch /etc/openvpn/udpserver.conf
echo "$udpserver" > /etc/openvpn/udpserver.conf

# TCP Server
touch /etc/openvpn/tcpserver.conf
echo "$tcpserver" > /etc/openvpn/tcpserver.conf

#enable packet forwarding in this session
echo 1 > /proc/sys/net/ipv4/ip_forward

#enable packet forwarding persistently
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

# uncomplicated firewall (ufw) configuration
ufw allow ssh
ufw allow 1194/udp
ufw allow 443/tcp
sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw #enable packet forwarding for firewall also
beforerules=$(awk -v ufwholder="$ufwrules" '!/^#/ && !p {print ufwholder; p=1} 1' /etc/ufw/before.rules) #write ufw rules
echo "$beforerules" > /etc/ufw/before.rules
yes | ufw enable

################## Key generation ##############

# easy-rsa scripts
cp -r /usr/share/easy-rsa/ /etc/openvpn
mkdir /etc/openvpn/easy-rsa/keys
sed -i '/^#/d' /etc/openvpn/easy-rsa/vars # Remove all commented lines
# remove default var values
sed -i '/^export KEY_COUNTRY/d' /etc/openvpn/easy-rsa/vars
sed -i '/^export KEY_PROVINCE/d' /etc/openvpn/easy-rsa/vars
sed -i '/^export KEY_CITY/d' /etc/openvpn/easy-rsa/vars
sed -i '/^export KEY_ORG/d' /etc/openvpn/easy-rsa/vars
sed -i '/^export KEY_EMAIL/d' /etc/openvpn/easy-rsa/vars
sed -i '/^export KEY_OU/d' /etc/openvpn/easy-rsa/vars
sed -i '/^export KEY_NAME/d' /etc/openvpn/easy-rsa/vars

#writing my var values
echo "$rsavars" >> /etc/openvpn/easy-rsa/vars
# Generate DH
openssl dhparam -out /etc/openvpn/dh2048.pem 2048
#build certificate authority
cd /etc/openvpn/easy-rsa
source ./vars
./clean-all
./build-ca --batch
# Fix easyrsa batch bug
perl -p -i -e 's|^(subjectAltName=)|#$1|;' /etc/openvpn/easy-rsa/openssl-1.0.0.cnf
# generate server certificate and key
./build-key-server --batch server

#move server certificates
cp /etc/openvpn/easy-rsa/keys/{server.crt,server.key,ca.crt} /etc/openvpn

# handshake generation
openvpn --genkey --secret ta.key
cp ta.key /etc/openvpn/ta.key

#restart openvpn
service openvpn stop
sudo openvpn --mktun --dev tun0
sudo openvpn --mktun --dev tun1
service openvpn start
service openvpn restart
service openvpn status

########### UDP ###############

#build client keys
KEY_CN=$vpnclient ./build-key --batch $vpnclient
touch /etc/openvpn/easy-rsa/keys/$vpnclient.ovpn
echo "$ovpnsets" >> /etc/openvpn/easy-rsa/keys/$vpnclient.ovpn

# insert client keys into ovpn
clientkeys="
<ca>
"$(</etc/openvpn/ca.crt)"
</ca>
<cert>
"$(</etc/openvpn/easy-rsa/keys/$vpnclient.crt)"
</cert>
<key>
"$(</etc/openvpn/easy-rsa/keys/$vpnclient.key)"
</key>
<tls-auth>
"$(</etc/openvpn/ta.key)"
</tls-auth>
"
echo "$clientkeys" >> /etc/openvpn/easy-rsa/keys/$vpnclient.ovpn

############ TCP ################

#build client keys

KEY_CN=$vpnclientTCP ./build-key --batch $vpnclientTCP
touch /etc/openvpn/easy-rsa/keys/$vpnclientTCP.ovpn
echo "$ovpnsetstcp" >> /etc/openvpn/easy-rsa/keys/$vpnclientTCP.ovpn

# insert client keys into ovpn
clientkeystcp="
<ca>
"$(</etc/openvpn/ca.crt)"
</ca>
<cert>
"$(</etc/openvpn/easy-rsa/keys/$vpnclientTCP.crt)"
</cert>
<key>
"$(</etc/openvpn/easy-rsa/keys/$vpnclientTCP.key)"
</key>
<tls-auth>
"$(</etc/openvpn/ta.key)"
</tls-auth>
"
echo "$clientkeystcp" >> /etc/openvpn/easy-rsa/keys/$vpnclientTCP.ovpn
# auto security updates
touch /etc/cron.daily/apt-security-updates
touch /etc/logrotate.d/apt-security-updates
echo $updaterules > /etc/cron.daily/apt-security-updates
echo $rotaterules > /etc/logrotate.d/apt-security-updates
sudo chmod +x /etc/cron.daily/apt-security-updates
cp /etc/openvpn/easy-rsa/keys/$vpnclientTCP.ovpn ~
cp /etc/openvpn/easy-rsa/keys/$vpnclient.ovpn ~
sudo reboot