echo "This scrit is run AFTER server setup"
echo "Press enter to continue..."
read

echo "What is the server name (without.server)?"
echo "Options:"
ls /etc/openvpn/*.server
while [[ $SERVERNAME = "" ]]; do
	echo "No SERVER var is specified, "
	read -p "Server name: " -e -i server SERVERNAME
done

echo "What is the client name?"
while [[ $CLIENT = "" ]]; do
	echo "Please, use one word only, no special characters"
	read -p "Client name: " -e -i client CLIENT
done

# import server settings
source /etc/openvpn/SERVERNAME.server

# Client key
cd ~/openvpn-ca
source vars
./build-key $CLIENT

# Client .ovpn
mkdir -p ~/client-configs/files
chmod 700 ~/client-configs/files

# Generate config
touch ~/client-configs/files/$CLIENT.ovpn
echo "
	client
	remote $IP $PORT
	proto $PROTOCOL
	cipher $CIPHER
	key-direction 1
	dev tun
	persist-key
	persist-tun
	user nobody
	group nogroup
	auth SHA256
	mute 20
	verb 3
" >> ~/client-configs/files/$CLIENT.ovpn

thekeys="
<ca>
"$(</etc/openvpn/$CA)"
</ca>
<cert>
"$(</etc/openvpn/$CERT)"
</cert>
<key>
"$(</etc/openvpn/easy-rsa/keys/$KEY.key)"
</key>
<tls-auth>
"$(</etc/openvpn/$TA.key)"
</tls-auth>
"
echo thekeys >> ~/client-configs/files/$CLIENT.ovpn