echo "What is the server name (without.server)?"
echo "Options:"
ls /etc/openvpn/*.server
while [[ $SERVERNAME = "" ]]; do
	read -p "Server name: " -e -i server SERVERNAME
done

echo "What is the client name?"
while [[ $CLIENT = "" ]]; do
	echo "Please, use one word only, no special characters"
	read -p "Client name: " -e -i client CLIENT
done

# import server settings
source /etc/openvpn/$SERVERNAME.server

# Client key
cd ~/openvpn-ca
source vars
./build-key --batch $CLIENT nopass

# Client .ovpn
mkdir -p ~/client-configs/files
chmod 700 ~/client-configs/files

# Generate config
touch ~/client-configs/files/$CLIENT.ovpn
echo "
	client
	remote ${IP} ${PORT}
	proto ${PROTOCOL}
	cipher ${CIPHER}
	key-direction 1
	dev tun
	persist-key
	persist-tun
	remote-cert-tls server
	user nobody
	group nogroup
	auth SHA256
	mute 20
	verb 3
" >> ~/client-configs/files/$CLIENT.ovpn

thekeys="
<ca>
"$(</etc/openvpn/${CA})"
</ca>
<cert>
"$(<~/openvpn-ca/keys/${CLIENT}.crt)"
</cert>
<key>
"$(<~/openvpn-ca/keys/${CLIENT}.key)"
</key>
<tls-auth>
"$(<~/openvpn-ca/${TA})"
</tls-auth>
"
echo "$thekeys" >> ~/client-configs/files/$CLIENT.ovpn