#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

# public network interface
# usually the same, unless using tunnel
echo -n "Server public IP: "
read IPV4_INTERFACE

# name for the wireguard interface
WG_INTERFACE=wg0

# the server's domain name or ip address
echo -n "Server domain name (optional): "
read WG_SERVER_ADDRESS

# number of client configs to generate
# must < 254
echo -n "Number of clients (maximum 254): "
read WG_CLIENT_NO

# DNS server for clients
echo -n "Client DNS: "
read DNS

echo -n "Main interface name (e.g. eth0): "
read INTERFACE_NAME

# remove previously generated configs and make room for new ones
rm -vrf wgconfigs
mkdir wgconfigs

echo generating server config
# generate the [Interface] part for the server
WG_IPV4_PREFIX=10.13.37.
WG_SERVER_PORT=51820

WG_SERVER_PRIVATE_KEY=$(wg genkey)
WG_SERVER_PUBLIC_KEY=$(echo "$WG_SERVER_PRIVATE_KEY" | wg pubkey)

cat > wgconfigs/${WG_INTERFACE}.conf << EOF 
[Interface]
Address = ${WG_IPV4_PREFIX}1/24
ListenPort = ${WG_SERVER_PORT}
PrivateKey = ${WG_SERVER_PRIVATE_KEY}
SaveConfig = true
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${INTERFACE_NAME} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${INTERFACE_NAME} -j MASQUERADE
EOF

# generate client configs
CLIENT_IP_SUFFIX=2
mkdir -p wgconfigs/clientconfigs
while [ $CLIENT_IP_SUFFIX -le $[$WG_CLIENT_NO+1] ]
do
echo Generating client config with IP ${WG_IPV4_PREFIX}${CLIENT_IP_SUFFIX}

WG_CLIENT_PRIVATE_KEY=$(wg genkey)
WG_CLIENT_PUBLIC_KEY=$(echo "$WG_CLIENT_PRIVATE_KEY" | wg pubkey)
WG_CLIENT_PSK=$(wg genpsk)

cat > wgconfigs/clientconfigs/${WG_INTERFACE}c${CLIENT_IP_SUFFIX}.conf << EOF 
[Interface]
Address = ${WG_IPV4_PREFIX}${CLIENT_IP_SUFFIX}/32
PrivateKey = ${WG_CLIENT_PRIVATE_KEY}
DNS = ${DNS}

[Peer]
PublicKey = ${WG_SERVER_PUBLIC_KEY}
PresharedKey = ${WG_CLIENT_PSK}
Endpoint = ${WG_SERVER_ADDRESS}:${WG_SERVER_PORT}
AllowedIPs = 0.0.0.0/0
EOF

# add a peer to server config
cat >> wgconfigs/${WG_INTERFACE}.conf << EOF 

[Peer]
PublicKey = ${WG_CLIENT_PUBLIC_KEY}
PresharedKey = ${WG_CLIENT_PSK}
AllowedIPs = ${WG_IPV4_PREFIX}${CLIENT_IP_SUFFIX}/32
EOF

CLIENT_IP_SUFFIX=$[$CLIENT_IP_SUFFIX+1]
done

exit 0
