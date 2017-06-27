#Description

This is a setup script for OpenVPN consisting out of 3 parts:
- initial.sh sets up openvpn and firewall settings
- server.sh sets up a server for openvpn ( can be run multiple times )
- client.sh sets up a client config for one of the existing servers

#Usage

This script was written in and for Ubuntu. It should work on any Debian based systems in theory. I've run and tested this script on Ubuntu versions 12 through 16.04. If anything goes wrong I suggest checking is all packages I use are installed (like ufw). In ububtu 16.04 they are by default.

##Commands

To install:
* Git clone over https
* cd /path-to-repo
* sudo bash initial.sh && sudo bash server.sh && bash client.sh
* wait


##Configuration files

You will find .ovpn files in ~/client-configs/files (home directory).

## Setting up your computer

I wrote a how to for using this script, getting a server and configuring your computer here: https://www.skillcollector.com/how-to-setup-a-vpn-server/