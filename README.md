#Description
For beginners, a guide: https://www.skillcollector.com/how-to-setup-a-vpn-server/

This Bash script installs and configures OpenVPN. Running it will start 2 servers:
* UDP port 1194
* TCP port 443

## Configuration specifications
The server is configured to ensure security and compatibility.
* The UDP config is for speed
* The TCP config if for networks that restrict UDP
* Both use a TLS handshake to prevent most network restrictions

At the top of the file you will find the USER INFO section. Here you can also set the cipher (encryption type) of the VPN. I recommend:
* BF-CBC (blowfish enctyption) for speed and decent security
* AES-128-CBC for good security but a higher processing power need
* AES-256-CBC for high security but a higher processing power need

In my experience AES-256 still works fine on a 1 CPU 512MB ram server so long as you don't use it with a lot of people at the same time.
##For beginners
Leave things as they are. Use the UDP where you can. Try the TCP if it doesn;t work on a specific network.
#Usage
This script was written in and for Ubuntu. It should work on any Debian based systems in theory. I've un and tested this script on Ubuntu versions 12 through 15.04. If anything goes wrong I suggest checking is all packages I use are installed (like ufw). In ububtu 15.04 they are by default.
##Commands
To install:
* Put the file on your server
* cd /path/to/setup.sh
* sudo bash setup.sh
* wait

##Configuration files
You will find 2 .ovpn files in /etc/openvpn/easy-rsa/keys. Download them both.
## Setting up your computer
I wrote a how to for using this script, getting a server and configuring your computer here: https://www.skillcollector.com/how-to-setup-a-vpn-server/