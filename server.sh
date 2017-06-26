# Checks
if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 1
fi

if [[ ! -e /dev/net/tun ]]; then
	echo "TUN is not available"
	exit 2
fi
IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
if [[ "$IP" = "" ]]; then
	IP=$(wget -qO- ipv4.icanhazip.com)
fi

# Get Internet network interface with default route
NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)')

# Ask for user input, used for inspiration: https://github.com/Angristan/OpenVPN-install/blob/master/openvpn-install.sh
echo "This should be your public IPv4 address."
read -p "IP address: " -e -i $IP IP


echo "What port do you want for OpenVPN?"
read -p "Port: " -e -i 1194 PORT


echo "What protocol do you want for OpenVPN?"
echo "Unless UDP is blocked, you should not use TCP (unnecessarily slower)"
while [[ $PROTOCOL != "UDP" && $PROTOCOL != "TCP" ]]; do
	read -p "Protocol [UDP/TCP]: " -e -i UDP PROTOCOL
done

echo "What DNS do you want to use with the VPN?"
echo "   1) Current system resolvers (in /etc/resolv.conf)"
echo "   2) FDN (France)"
echo "   3) DNS.WATCH (Germany)"
echo "   4) OpenDNS (Anycast: worldwide)"
echo "   5) Google (Anycast: worldwide)"
echo "   6) Yandex Basic (Russia)"
while [[ $DNS != "1" && $DNS != "2" && $DNS != "3" && $DNS != "4" && $DNS != "5" ]]; do
	read -p "DNS [1-5]: " -e -i 1 DNS
done

echo "Choose what size of Diffie-Hellman key you want to use:"
echo "   1) 2048 bits (fastest)"
echo "   2) 3072 bits (recommended, best compromise)"
echo "   3) 4096 bits (most secure)"
while [[ $DH_KEY_SIZE != "1" && $DH_KEY_SIZE != "2" && $DH_KEY_SIZE != "3" ]]; do
	read -p "DH key size [1-3]: " -e -i 2 DH_KEY_SIZE
done
case $DH_KEY_SIZE in
	1)
	DH_KEY_SIZE="2048"
	;;
	2)
	DH_KEY_SIZE="3072"
	;;
	3)
	DH_KEY_SIZE="4096"
	;;
esac

echo "Choose what size of RSA key you want to use:"
echo "   1) 2048 bits (fastest)"
echo "   2) 3072 bits (recommended, best compromise)"
echo "   3) 4096 bits (most secure)"
while [[ $RSA_KEY_SIZE != "1" && $RSA_KEY_SIZE != "2" && $RSA_KEY_SIZE != "3" ]]; do
	read -p "DH key size [1-3]: " -e -i 2 RSA_KEY_SIZE
done
case $RSA_KEY_SIZE in
	1)
	RSA_KEY_SIZE="2048"
	;;
	2)
	RSA_KEY_SIZE="3072"
	;;
	3)
	RSA_KEY_SIZE="4096"
	;;
esac

echo "Choose which cipher you want to use for the data channel:"
echo "   1) AES-128-CBC (fastest and sufficiently secure for everyone, recommended)"
echo "   2) AES-192-CBC"
echo "   3) AES-256-CBC"
while [[ $CIPHER != "1" && $CIPHER != "2" && $CIPHER != "3" ]]; do
	read -p "Cipher [1-3]: " -e -i 1 CIPHER
done
case $CIPHER in
	1)
	CIPHER="cipher AES-128-CBC"
	;;
	2)
	CIPHER="cipher AES-192-CBC"
	;;
	3)
	CIPHER="cipher AES-256-CBC"
	;;
esac

while [[ ${SERVER} = "" ]]; do
	echo "Please, use one word only, no special characters"
	read -p "Server name: " -e -i server SERVER
done

# Make certificate authority
make-cadir ~/openvpn-ca
cd ~/openvpn-ca
# Build CA
cd ~/openvpn-ca
source vars
# Override any variables from ~/openvpn-ca/vars
export KEY_NAME="${SERVER}server"
export KEY_SIZE=$RSA_KEY_SIZE
# Clean up and product keys
echo "Building CA with RSA key size ${KEY_SIZE}"
./clean-all
./build-ca --batch $SERVER

# Build keys
./build-key-server --batch "${SERVER}server"

# Build dh
if [ -d $KEY_DIR ] && [ $DH_KEY_SIZE ]; then
    $OPENSSL dhparam -out ${KEY_DIR}/dh${DH_KEY_SIZE}.pem ${DH_KEY_SIZE}
else
    echo 'Please source the vars script first (i.e. "source ./vars")'
    echo 'Make sure you have edited it to reflect your configuration.'
fi

# ta handshake key
openvpn --genkey --secret "keys/${SERVER}ta.key"

# Copy keys to openvpn folder & sae to vars
cp ~/openvpn-ca/keys/{"${SERVER}ca.crt","${SERVER}ca.key","${SERVER}server.crt","${SERVER}server.key","${SERVER}ta.key","${SERVER}dh$DH_KEY_SIZE.pem"} /etc/openvpn
# Rename CA key and crt
mv /etc/openvpn/ca.key /etc/openvpn/${SERVER}ca.key
mv /etc/openvpn/ca.crt /etc/openvpn/${SERVER}ca.crt
TA="keys/${SERVER}ta.key"
KEY="${SERVER}ca.key"
CA="${SERVER}ca.crt"
CRT="${SERVER}server.crt"
DH="${SERVER}dh$DH_KEY_SIZE.pem"

# Make server config
touch /etc/openvpn/server.conf
echo "
	port ${PORT}
	proto ${PROTOCOL}
	dh dh${DH_KEY_SIZE}.pem
	cipher ${CIPHER}
	ca ${SERVER}ca.crt
	cert ${SERVER}server.crt
	key ${SERVER}server.key
	tls-auth ${SERVER}ta.key 0
	persist-key
	persist-tun
	user nobody
	group nogroup
	server 10.8.0.0 255.255.255.0
	ifconfig-pool-persist ipp.txt
	keepalive 10 120
	dev tun
	key-direction 0
	auth SHA256
	verb 0
	explicit-exit-notify 1
"  >> /etc/openvpn/server.conf
# Reroute all traffic over vpn
echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server.conf

# DNS resolvers
case $DNS in
	1)
	# Obtain the resolvers from resolv.conf and use them for OpenVPN
	grep -v '#' /etc/resolv.conf | grep 'nameserver' | grep -E -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | while read line; do
		echo "push \"dhcp-option DNS $line\"" >> /etc/openvpn/server.conf
	done
	;;
	2) #FDN
	echo 'push "dhcp-option DNS 80.67.169.12"' >> /etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 80.67.169.40"' >> /etc/openvpn/server.conf
	;;
	3) #DNS.WATCH
	echo 'push "dhcp-option DNS 84.200.69.80"' >> /etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 84.200.70.40"' >> /etc/openvpn/server.conf
	;;
	4) #OpenDNS
	echo 'push "dhcp-option DNS 208.67.222.222"' >> /etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 208.67.220.220"' >> /etc/openvpn/server.conf
	;;
	5) #Google
	echo 'push "dhcp-option DNS 8.8.8.8"' >> /etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 8.8.4.4"' >> /etc/openvpn/server.conf
	;;
	6) #Yandex Basic
	echo 'push "dhcp-option DNS 77.88.8.8"' >> /etc/openvpn/server.conf
	echo 'push "dhcp-option DNS 77.88.8.1"' >> /etc/openvpn/server.conf
	;;
esac

# Save the parameters
echo "
	export SERVER=${SERVER}
	export IP=${IP}
	export NIC=${NIC}
	export PORT=${PORT}
	export PROTOCOL=${PROTOCOL}
	export DNS=${DNS}
	export DH_KEY_SIZE=${DH_KEY_SIZE}
	export RSA_KEY_SIZE=${RSA_KEY_SIZE}
	export CIPHER=${CIPHER}
	export CA=${CA}
	export CERT=${CERT}
	export KEY=${KEY}
	export TA=${TA}
	export DH=${DH}
" >> /etc/openvpn/${SERVER}.server


# Set up firewall
ufw allow $PORT/$PROTOCOL
systemctl start openvpn@server